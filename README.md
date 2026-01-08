# Linear Claude Session Tracking

A Claude Code plugin that automatically tracks your coding sessions in Linear, providing visibility and traceability for AI-assisted development work.

## Features

- **Automatic issue creation**: Each new Claude Code session creates a Linear issue
- **Commit tracking**: Git commits are logged as comments with file changes
- **Session resume**: Resumed sessions continue updating the same issue
- **Cross-referencing**: Issues include session IDs and resume commands

## Installation

### From GitHub

```bash
# Add the plugin marketplace
/plugin marketplace add yourname/linear-claude-session-tracking

# Install the plugin
/plugin install linear-claude-session-tracking
```

### Local Development

```bash
claude --plugin-dir ~/Code/linear-claude-session-tracking
```

## Setup

After installation, run the setup command to configure your Linear settings:

```
/linear-claude-session-tracking:setup
```

This will guide you through:

1. Selecting your Linear team
2. Choosing a project (default: "Claude sessions")
3. Setting a label (default: "claude")

## Configuration

Configuration is stored at `~/.config/linear-claude-session-tracking/config`:

```bash
LINEAR_TEAM="MAN"           # Your Linear team key
LINEAR_PROJECT="Claude sessions"  # Project name for issues
LINEAR_LABEL="claude"       # Label to apply to issues
```

You can also set these as environment variables to override the config file.

## Requirements

- [Linear CLI](https://github.com/linear/linear-cli) installed and authenticated
- `jq` for JSON parsing

## How It Works

### On Session Start

When you start a new Claude Code session, the plugin:

1. Creates a Linear issue with session metadata
2. Includes the session ID and resume command
3. Stores state for tracking commits

### On Git Commit

When you make a commit via Claude's Bash tool:

1. Detects the commit from command output
2. Extracts commit hash, message, and file changes
3. Adds a comment to the Linear issue
4. Updates the issue title to reflect work done

### On Session Resume

When you resume a session with `claude --resume <id>`:

1. Loads existing state
2. Continues updating the same Linear issue
3. Adds a "Session resumed" comment

## Example Linear Issue

```markdown
## Claude Code Session

**Session ID:** `abc123-def456`
**Branch:** `feature/new-feature`
**Directory:** `/Users/you/Code/project`

### Resume Command

claude --resume abc123-def456

### Commits

_Updated via comments_
```

## License

MIT
