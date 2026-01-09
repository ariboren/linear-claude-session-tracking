#!/bin/bash
# post-bash.sh - Detect new commits by comparing HEAD before/after Bash command
#
# Hook input (stdin JSON):
# {
#   "session_id": "abc123",
#   "tool_name": "Bash",
#   "tool_input": { "command": "..." },
#   "tool_response": { ... },
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
TOOL_NAME=$(json_get "$INPUT" '.tool_name')
CWD=$(json_get "$INPUT" '.cwd')

# Only process Bash tool
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Only track if we have a session with Linear issue
if ! state_exists "$SESSION_ID"; then
    exit 0
fi

ISSUE_ID=$(state_get "$SESSION_ID" '.linear_issue_id')
if [[ -z "$ISSUE_ID" ]]; then
    exit 0
fi

# Change to working directory
if [[ -n "$CWD" ]] && [[ -d "$CWD" ]]; then
    cd "$CWD"
fi

# Check if we're in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

# Get the pre-command HEAD
PRE_HEAD_FILE="/tmp/claude-session-${SESSION_ID}-pre-head"
if [[ ! -f "$PRE_HEAD_FILE" ]]; then
    exit 0
fi

PRE_HEAD=$(cat "$PRE_HEAD_FILE")
rm -f "$PRE_HEAD_FILE"  # Clean up

if [[ -z "$PRE_HEAD" ]]; then
    exit 0
fi

# Get current HEAD
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_HEAD" ]]; then
    exit 0
fi

# Compare - if HEAD changed, we have new commit(s)
if [[ "$PRE_HEAD" == "$CURRENT_HEAD" ]]; then
    exit 0  # No new commits
fi

log "HEAD changed: $PRE_HEAD -> $CURRENT_HEAD"

# Find all new commits between pre-HEAD and current HEAD
# This handles single commits, merges, rebases, etc.
NEW_COMMITS=$(git rev-list "$PRE_HEAD".."$CURRENT_HEAD" 2>/dev/null || echo "$CURRENT_HEAD")

if [[ -z "$NEW_COMMITS" ]]; then
    # Fallback: just use current HEAD
    NEW_COMMITS="$CURRENT_HEAD"
fi

# Process each new commit
COMMIT_COUNT=0
for COMMIT_HASH in $NEW_COMMITS; do
    COMMIT_COUNT=$((COMMIT_COUNT + 1))

    # Get short hash for display
    SHORT_HASH=$(git rev-parse --short "$COMMIT_HASH" 2>/dev/null || echo "$COMMIT_HASH")

    # Skip if we've already tracked this commit
    EXISTING_COMMITS=$(state_get "$SESSION_ID" '.commits')
    if echo "$EXISTING_COMMITS" | grep -q "$SHORT_HASH"; then
        log "Commit $SHORT_HASH already tracked, skipping"
        continue
    fi

    log "Processing commit: $SHORT_HASH"

    # Get commit details
    COMMIT_MSG=$(git log -1 --format='%s' "$COMMIT_HASH" 2>/dev/null || echo "Unknown")
    COMMIT_BODY=$(git log -1 --format='%b' "$COMMIT_HASH" 2>/dev/null || echo "")

    # Get file changes
    FILES_CHANGED=$(git show --stat --format='' "$COMMIT_HASH" 2>/dev/null | head -20 || echo "")

    # Build comment body
    COMMENT="### Commit \`$SHORT_HASH\`

**Message:** $COMMIT_MSG
"

    if [[ -n "$COMMIT_BODY" ]]; then
        COMMENT+="
$COMMIT_BODY
"
    fi

    COMMENT+="
**Files changed:**
\`\`\`
$FILES_CHANGED
\`\`\`

Part of $ISSUE_ID"

    # Add comment to Linear issue
    log "Adding commit comment to $ISSUE_ID"
    linear_add_comment "$ISSUE_ID" "$COMMENT"

    # Store commit in state
    state_append "$SESSION_ID" '.commits' "\"$SHORT_HASH\""
done

# Update issue title with latest commit summary
if [[ $COMMIT_COUNT -gt 0 ]]; then
    # Get the most recent commit message for title
    LATEST_MSG=$(git log -1 --format='%s' "$CURRENT_HEAD" 2>/dev/null || echo "Updates")

    TOTAL_COMMITS=$(state_get "$SESSION_ID" '.commits | length')
    PROJECT_NAME=$(state_get "$SESSION_ID" '.project')
    BRANCH=$(state_get "$SESSION_ID" '.branch')

    # Create a brief title based on commit message
    SHORT_MSG="${LATEST_MSG:0:50}"
    if [[ ${#LATEST_MSG} -gt 50 ]]; then
        SHORT_MSG="${SHORT_MSG}..."
    fi

    if [[ "$TOTAL_COMMITS" -eq 1 ]]; then
        NEW_TITLE="[Claude] $PROJECT_NAME/$BRANCH - $SHORT_MSG"
    else
        NEW_TITLE="[Claude] $PROJECT_NAME/$BRANCH - $SHORT_MSG (+$((TOTAL_COMMITS - 1)) more)"
    fi

    log "Updating issue title: $NEW_TITLE"
    linear_update_title "$ISSUE_ID" "$NEW_TITLE"
fi

log "Tracked $COMMIT_COUNT new commit(s)"
exit 0
