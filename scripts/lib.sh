#!/bin/bash
# lib.sh - Shared functions for Linear session tracking hooks

# Configuration - can be overridden via environment variables
# or config file at ~/.config/linear-claude-session-tracking/config
LINEAR_TEAM="${LINEAR_TEAM:-}"
LINEAR_PROJECT="${LINEAR_PROJECT:-Claude sessions}"
LINEAR_LABEL="${LINEAR_LABEL:-claude}"

# Load config file if exists
CONFIG_FILE="${HOME}/.config/linear-claude-session-tracking/config"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# State file location (based on session ID)
get_state_file() {
    local session_id="$1"
    echo "/tmp/claude-session-${session_id}.json"
}

# Read JSON from stdin (hook input)
read_hook_input() {
    cat
}

# Extract field from JSON using jq
json_get() {
    local json="$1"
    local path="$2"
    echo "$json" | jq -r "$path // empty"
}

# Check if state file exists for session
state_exists() {
    local session_id="$1"
    local state_file
    state_file=$(get_state_file "$session_id")
    [[ -f "$state_file" ]]
}

# Read state file
read_state() {
    local session_id="$1"
    local state_file
    state_file=$(get_state_file "$session_id")
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "{}"
    fi
}

# Write state file atomically
write_state() {
    local session_id="$1"
    local state="$2"
    local state_file
    state_file=$(get_state_file "$session_id")
    local tmp_file="${state_file}.tmp"
    echo "$state" > "$tmp_file" && mv "$tmp_file" "$state_file"
}

# Get field from state
state_get() {
    local session_id="$1"
    local path="$2"
    local state
    state=$(read_state "$session_id")
    json_get "$state" "$path"
}

# Update state field
state_set() {
    local session_id="$1"
    local path="$2"
    local value="$3"
    local state
    state=$(read_state "$session_id")
    state=$(echo "$state" | jq "$path = $value")
    write_state "$session_id" "$state"
}

# Append to state array
state_append() {
    local session_id="$1"
    local path="$2"
    local value="$3"
    local state
    state=$(read_state "$session_id")
    state=$(echo "$state" | jq "$path += [$value]")
    write_state "$session_id" "$state"
}

# Create new Linear issue
# Returns: issue ID (e.g., "MAN-123")
linear_create_issue() {
    local title="$1"
    local description="$2"
    local project="${3:-$LINEAR_PROJECT}"
    local team="${4:-$LINEAR_TEAM}"
    local label="${5:-$LINEAR_LABEL}"

    # Build command arguments
    local args=(
        --title "$title"
        --description "$description"
        --no-interactive
        --no-color
    )

    # Add optional arguments if set
    [[ -n "$project" ]] && args+=(--project "$project")
    [[ -n "$team" ]] && args+=(--team "$team")
    [[ -n "$label" ]] && args+=(--label "$label")

    # Create issue and capture output
    local output
    output=$(linear issue create "${args[@]}" 2>&1)

    # Extract issue ID from output (format: "Created issue TEAM-123")
    local issue_id
    issue_id=$(echo "$output" | grep -oE '[A-Z]+-[0-9]+' | head -1)

    if [[ -n "$issue_id" ]]; then
        echo "$issue_id"
        return 0
    else
        echo "ERROR: Failed to create issue: $output" >&2
        return 1
    fi
}

# Update Linear issue title
linear_update_title() {
    local issue_id="$1"
    local title="$2"

    linear issue update "$issue_id" --title "$title" --no-color >/dev/null 2>&1
}

# Update Linear issue state
linear_update_state() {
    local issue_id="$1"
    local state="$2"

    linear issue update "$issue_id" --state "$state" --no-color >/dev/null 2>&1
}

# Add comment to Linear issue
linear_add_comment() {
    local issue_id="$1"
    local body="$2"

    linear issue comment add "$issue_id" --body "$body" >/dev/null 2>&1
}

# Get issue URL from ID
linear_issue_url() {
    local issue_id="$1"
    linear issue url "$issue_id" 2>/dev/null
}

# Get current git branch
get_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# Get git project root
get_git_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Log message to stderr (for debugging)
log() {
    echo "[linear-session-tracking] $*" >&2
}

# Log error and exit
die() {
    log "ERROR: $*"
    exit 1
}
