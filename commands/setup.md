---
name: setup
description: Configure Linear session tracking settings (team, project, label)
---

# Linear Session Tracking Setup

Help the user configure the Linear session tracking plugin by creating a config file.

## Steps

1. First, check if the `linear` CLI is installed and authenticated:

   ```bash
   linear team list
   ```

2. If not authenticated, guide them to run `linear auth login`

3. List available teams and ask which one to use:

   ```bash
   linear team list
   ```

4. Ask for the Linear project name (default: "Claude sessions")
   - They may need to create this project in Linear first

5. Ask for the label to apply to issues (default: "claude")

6. Create the config directory and file:

   ```bash
   mkdir -p ~/.config/linear-claude-session-tracking
   ```

7. Write the config file at `~/.config/linear-claude-session-tracking/config`:

   ```bash
   LINEAR_TEAM="<selected_team>"
   LINEAR_PROJECT="<project_name>"
   LINEAR_LABEL="<label>"
   ```

8. Test the configuration by creating a test issue:

   ```bash
   linear issue create --title "[Test] Linear session tracking setup" --project "<project>" --team "<team>" --label "<label>" --no-interactive
   ```

9. If successful, offer to delete the test issue or leave it for reference

10. Confirm setup is complete and explain how to start using it:
    - New Claude Code sessions will automatically create Linear issues
    - Commits made during sessions will be tracked
    - Sessions can be resumed using the command shown in each issue

## Config File Format

The config file uses shell variable syntax:

```
LINEAR_TEAM="MAN"
LINEAR_PROJECT="Claude sessions"
LINEAR_LABEL="claude"
```

These can also be set as environment variables to override the config file.
