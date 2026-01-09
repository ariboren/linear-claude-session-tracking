#!/bin/bash
# pre-bash.sh - Store current HEAD before Bash command runs
#
# Hook input (stdin JSON):
# {
#   "session_id": "abc123",
#   "tool_name": "Bash",
#   "tool_input": { "command": "..." },
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

# Change to working directory
if [[ -n "$CWD" ]] && [[ -d "$CWD" ]]; then
    cd "$CWD"
fi

# Check if we're in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

# Store current HEAD before command runs
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")
if [[ -n "$CURRENT_HEAD" ]]; then
    PRE_HEAD_FILE="/tmp/claude-session-${SESSION_ID}-pre-head"
    echo "$CURRENT_HEAD" > "$PRE_HEAD_FILE"
fi

exit 0
