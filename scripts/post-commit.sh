#!/bin/bash
# post-commit.sh - Detect git commits and update Linear issue
#
# Hook input (stdin JSON):
# {
#   "session_id": "abc123",
#   "tool_name": "Bash",
#   "tool_input": { "command": "git commit -m \"...\"" },
#   "tool_response": { "stdout": "...", "stderr": "...", "exit_code": 0 },
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
COMMAND=$(json_get "$INPUT" '.tool_input.command')

# tool_response can be a string or object - handle both
TOOL_RESPONSE=$(json_get "$INPUT" '.tool_response')
if [[ "$TOOL_RESPONSE" == "null" ]] || [[ -z "$TOOL_RESPONSE" ]]; then
    # Try getting it as a string directly
    TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty')
fi

# Try to extract stdout/stderr/exit_code if it's an object
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // .tool_response.content // .tool_response // empty' 2>/dev/null)
STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // .tool_response.exitCode // "0"' 2>/dev/null)

# Only process Bash tool
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Check if this looks like a git commit command
if [[ ! "$COMMAND" =~ git[[:space:]]+(commit|c) ]]; then
    exit 0
fi

# Check if commit succeeded (exit code 0 or empty means success)
if [[ -n "$EXIT_CODE" ]] && [[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]]; then
    exit 0
fi

# Try to extract commit hash from output
# Git commit output typically looks like: "[branch abc1234] Commit message"
COMMIT_HASH=""

# Check stdout first, then stderr (git sometimes outputs to stderr)
COMBINED_OUTPUT="$STDOUT $STDERR"

# Pattern: [branch-name hash] or [branch hash]
if [[ "$COMBINED_OUTPUT" =~ \[([^][:space:]]+)[[:space:]]([a-f0-9]{7,40})\] ]]; then
    COMMIT_HASH="${BASH_REMATCH[2]}"
fi

# If no hash found, try to get HEAD from the working directory
CWD=$(json_get "$INPUT" '.cwd')
if [[ -z "$COMMIT_HASH" ]] && [[ -n "$CWD" ]]; then
    COMMIT_HASH=$(cd "$CWD" && git rev-parse --short HEAD 2>/dev/null || echo "")
fi

# Fallback to current directory
if [[ -z "$COMMIT_HASH" ]]; then
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "")
fi

if [[ -z "$COMMIT_HASH" ]]; then
    log "Could not extract commit hash, skipping"
    exit 0
fi

# Change to working directory for git operations
if [[ -n "$CWD" ]] && [[ -d "$CWD" ]]; then
    cd "$CWD"
fi

# Validate it's a real commit
if ! git cat-file -t "$COMMIT_HASH" >/dev/null 2>&1; then
    log "Invalid commit hash: $COMMIT_HASH"
    exit 0
fi

log "Detected commit: $COMMIT_HASH"

# Check if we have state for this session
if ! state_exists "$SESSION_ID"; then
    log "No state file for session $SESSION_ID, skipping"
    exit 0
fi

ISSUE_ID=$(state_get "$SESSION_ID" '.linear_issue_id')
if [[ -z "$ISSUE_ID" ]]; then
    log "No Linear issue ID in state, skipping"
    exit 0
fi

# Get commit details
COMMIT_MSG=$(git log -1 --format='%s' "$COMMIT_HASH" 2>/dev/null || echo "Unknown")
COMMIT_BODY=$(git log -1 --format='%b' "$COMMIT_HASH" 2>/dev/null || echo "")
COMMIT_AUTHOR=$(git log -1 --format='%an' "$COMMIT_HASH" 2>/dev/null || echo "Unknown")
COMMIT_DATE=$(git log -1 --format='%ci' "$COMMIT_HASH" 2>/dev/null || echo "")

# Get file changes
FILES_CHANGED=$(git show --stat --format='' "$COMMIT_HASH" 2>/dev/null | head -20 || echo "")

# Build comment body
COMMENT="### Commit \`$COMMIT_HASH\`

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

# Update issue title with latest commit summary
# Get all commits for this session to create a summary
COMMITS_COUNT=$(state_get "$SESSION_ID" '.commits | length')
COMMITS_COUNT=$((COMMITS_COUNT + 1))

PROJECT_NAME=$(state_get "$SESSION_ID" '.project')
BRANCH=$(state_get "$SESSION_ID" '.branch')

# Create a brief title based on commit message
# Truncate to first 50 chars if needed
SHORT_MSG="${COMMIT_MSG:0:50}"
if [[ ${#COMMIT_MSG} -gt 50 ]]; then
    SHORT_MSG="${SHORT_MSG}..."
fi

if [[ "$COMMITS_COUNT" -eq 1 ]]; then
    NEW_TITLE="[Claude] $PROJECT_NAME/$BRANCH - $SHORT_MSG"
else
    NEW_TITLE="[Claude] $PROJECT_NAME/$BRANCH - $SHORT_MSG (+$((COMMITS_COUNT - 1)) more)"
fi

log "Updating issue title: $NEW_TITLE"
linear_update_title "$ISSUE_ID" "$NEW_TITLE"

# Store commit in state
state_append "$SESSION_ID" '.commits' "\"$COMMIT_HASH\""

log "Commit tracked successfully"
exit 0
