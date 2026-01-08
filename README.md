# Linear Claude Session Tracking

A Claude Code plugin that automatically tracks your coding sessions in Linear, providing visibility and traceability for AI-assisted development work.

## Features

- **Automatic issue creation**: Each new Claude Code session creates a Linear issue
- **Commit tracking**: Git commits are logged as comments with file changes
- **Session resume**: Resumed sessions continue updating the same issue
- **Cross-referencing**: Issues include session IDs and resume commands

## Requirements

- [Linear CLI](https://github.com/evangelosmeklis/linear-cli) installed and authenticated
- `jq` for JSON parsing

## Installation

### 1. Add the marketplace

```
/plugin marketplace add ariboren/claude-plugins
```

### 2. Install the plugin

```
/plugin install linear-claude-session-tracking@ariboren
```

### 3. Restart Claude Code

Close and reopen Claude Code to load the plugin.

## Setup

### Option A: Interactive setup (recommended)

Run the setup command:

```
/linear-claude-session-tracking:setup
```

This will guide you through selecting your team, project, and label.

### Option B: Manual configuration

1. Create the config directory:

   ```bash
   mkdir -p ~/.config/linear-claude-session-tracking
   ```

2. Create the config file at `~/.config/linear-claude-session-tracking/config`:

   ```bash
   LINEAR_TEAM="YOUR_TEAM_KEY"
   LINEAR_PROJECT="Claude sessions"
   LINEAR_LABEL="claude"
   ```

   To find your team key, run `linear team list`.

3. Create a "Claude sessions" project in Linear (or use an existing project name)

4. Create a "claude" label in Linear (or use an existing label name)

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

## Configuration Options

| Variable         | Description                                              | Default           |
| ---------------- | -------------------------------------------------------- | ----------------- |
| `LINEAR_TEAM`    | Your Linear team key (run `linear team list` to find it) | Required          |
| `LINEAR_PROJECT` | Project name for session issues                          | `Claude sessions` |
| `LINEAR_LABEL`   | Label to apply to session issues                         | `claude`          |

These can also be set as environment variables to override the config file.

## License

MIT
