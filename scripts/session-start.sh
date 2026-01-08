#!/bin/bash
# session-start.sh - Create or resume Linear issue for Claude Code session
#
# Hook input (stdin JSON):
# {
#   "session_id": "abc123",
#   "source": "startup|resume|clear|compact",
#   "transcript_path": "/path/to/transcript",
#   "cwd": "/current/working/directory",
#   ...
# }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Read hook input from stdin
INPUT=$(read_hook_input)

# Extract fields
SESSION_ID=$(json_get "$INPUT" '.session_id')
SOURCE=$(json_get "$INPUT" '.source')
CWD=$(json_get "$INPUT" '.cwd')

# Validate required fields
if [[ -z "$SESSION_ID" ]]; then
    log "No session_id in hook input, skipping"
    exit 0
fi

# Get git info
BRANCH=$(get_git_branch)
GIT_ROOT=$(get_git_root)
PROJECT_NAME=$(basename "$GIT_ROOT")

# Check if we already have state for this session
if state_exists "$SESSION_ID"; then
    # Resuming existing session
    ISSUE_ID=$(state_get "$SESSION_ID" '.linear_issue_id')

    if [[ -n "$ISSUE_ID" ]]; then
        log "Resuming session $SESSION_ID with issue $ISSUE_ID"

        # Add resume comment if source is "resume"
        if [[ "$SOURCE" == "resume" ]]; then
            TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
            linear_add_comment "$ISSUE_ID" "Session resumed at $TIMESTAMP"
        fi

        # Export issue ID if CLAUDE_ENV_FILE is set
        if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
            echo "export LINEAR_SESSION_ISSUE_ID='$ISSUE_ID'" >> "$CLAUDE_ENV_FILE"
        fi

        exit 0
    fi
fi

# New session - create Linear issue
log "Creating new Linear issue for session $SESSION_ID"

TITLE="[Claude] $PROJECT_NAME/$BRANCH - New session"

DESCRIPTION="## Claude Code Session

**Session ID:** \`$SESSION_ID\`
**Branch:** \`$BRANCH\`
**Directory:** \`$CWD\`
**Project:** \`$PROJECT_NAME\`

### Resume Command
\`\`\`bash
claude --resume $SESSION_ID
\`\`\`

### Commits
_No commits yet_
"

# Create the issue
ISSUE_ID=$(linear_create_issue "$TITLE" "$DESCRIPTION")

if [[ -z "$ISSUE_ID" ]]; then
    log "Failed to create Linear issue"
    exit 0  # Don't block session on failure
fi

log "Created Linear issue: $ISSUE_ID"

# Get issue URL
ISSUE_URL=$(linear_issue_url "$ISSUE_ID" 2>/dev/null || echo "")

# Save state
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
STATE=$(jq -n \
    --arg issue_id "$ISSUE_ID" \
    --arg issue_url "$ISSUE_URL" \
    --arg session_id "$SESSION_ID" \
    --arg branch "$BRANCH" \
    --arg cwd "$CWD" \
    --arg project "$PROJECT_NAME" \
    --arg started_at "$TIMESTAMP" \
    '{
        linear_issue_id: $issue_id,
        linear_issue_url: $issue_url,
        session_id: $session_id,
        branch: $branch,
        cwd: $cwd,
        project: $project,
        commits: [],
        started_at: $started_at
    }')

write_state "$SESSION_ID" "$STATE"

# Export issue ID if CLAUDE_ENV_FILE is set
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "export LINEAR_SESSION_ISSUE_ID='$ISSUE_ID'" >> "$CLAUDE_ENV_FILE"
fi

log "Session tracking initialized: $ISSUE_ID"
exit 0
