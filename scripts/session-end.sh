#!/bin/bash
# session-end.sh - Mark Linear issue as Done when session ends
#
# Hook input (stdin JSON):
# {
#   "session_id": "abc123",
#   "reason": "clear|logout|prompt_input_exit|other",
#   ...
# }

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Read hook input from stdin
INPUT=$(read_hook_input)

# Extract fields
SESSION_ID=$(json_get "$INPUT" '.session_id')
REASON=$(json_get "$INPUT" '.reason')

# Validate required fields
if [[ -z "$SESSION_ID" ]]; then
    log "No session_id in hook input, skipping"
    exit 0
fi

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

# Check if there were any commits in this session
COMMITS_COUNT=$(state_get "$SESSION_ID" '.commits | length')

if [[ "$COMMITS_COUNT" -eq 0 ]] || [[ -z "$COMMITS_COUNT" ]] || [[ "$COMMITS_COUNT" == "null" ]]; then
    # No commits - delete the issue
    log "Session ending with no commits, deleting issue $ISSUE_ID"
    linear_delete_issue "$ISSUE_ID"
else
    # Has commits - mark as Done
    log "Session ending ($REASON) with $COMMITS_COUNT commit(s), marking $ISSUE_ID as Done"
    linear_update_state "$ISSUE_ID" "Done"

    # Add closing comment
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    linear_add_comment "$ISSUE_ID" "Session ended at $TIMESTAMP (reason: $REASON) - $COMMITS_COUNT commit(s)"
    log "Session $SESSION_ID completed"
fi

# Clean up state file
STATE_FILE=$(get_state_file "$SESSION_ID")
rm -f "$STATE_FILE"

exit 0
