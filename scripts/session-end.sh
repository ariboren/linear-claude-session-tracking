#!/bin/bash
# session-end.sh - Mark Linear issue as Done when session ends
#
# Hook input (stdin JSON):
# {
#   "session_id": "abc123",
#   "reason": "clear|logout|prompt_input_exit|other",
#   ...
# }

set -euo pipefail

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

log "Session ending ($REASON), marking $ISSUE_ID as Done"

# Set status to Done
linear_update_state "$ISSUE_ID" "Done"

# Add closing comment
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
linear_add_comment "$ISSUE_ID" "Session ended at $TIMESTAMP (reason: $REASON)"

log "Session $SESSION_ID completed"
exit 0
