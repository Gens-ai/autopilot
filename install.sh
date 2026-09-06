#!/bin/bash

# Autopilot Install Script
# Creates symlinks from this repo to ~/.claude/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Autopilot commands..."

# Create directories if they don't exist
mkdir -p ~/.claude/commands
mkdir -p ~/.claude/hooks

# Symlink command files
for cmd in prd.md tasks.md autopilot.md analyze.md cancel.md stop.md test-user-stories.md; do
    if [ -f "$SCRIPT_DIR/commands/$cmd" ]; then
        if [ -L ~/.claude/commands/$cmd ]; then
            rm ~/.claude/commands/$cmd
        elif [ -f ~/.claude/commands/$cmd ]; then
            echo "Backing up existing $cmd to $cmd.bak"
            mv ~/.claude/commands/$cmd ~/.claude/commands/$cmd.bak
        fi
        ln -s "$SCRIPT_DIR/commands/$cmd" ~/.claude/commands/$cmd
        echo "  Linked: $cmd"
    fi
done

# Symlink namespaced subcommands: commands/autopilot/<name>.md -> /autopilot:<name>
if [ -d "$SCRIPT_DIR/commands/autopilot" ]; then
    mkdir -p ~/.claude/commands/autopilot
    for sub in "$SCRIPT_DIR"/commands/autopilot/*.md; do
        [ -f "$sub" ] || continue
        name=$(basename "$sub")
        rm -f ~/.claude/commands/autopilot/"$name"
        ln -s "$sub" ~/.claude/commands/autopilot/"$name"
        echo "  Linked: autopilot/$name"
    done
fi

# Symlink AGENTS.md
if [ -L ~/.claude/AGENTS.md ]; then
    rm ~/.claude/AGENTS.md
elif [ -f ~/.claude/AGENTS.md ]; then
    echo "Backing up existing AGENTS.md to AGENTS.md.bak"
    mv ~/.claude/AGENTS.md ~/.claude/AGENTS.md.bak
fi
ln -s "$SCRIPT_DIR/AGENTS.md" ~/.claude/AGENTS.md
echo "  Linked: AGENTS.md"

# Install stop-hook for loop mechanism
echo ""
echo "Installing loop hooks..."

if [ -L ~/.claude/hooks/autopilot-stop-hook.sh ]; then
    rm ~/.claude/hooks/autopilot-stop-hook.sh
elif [ -f ~/.claude/hooks/autopilot-stop-hook.sh ]; then
    echo "Backing up existing autopilot-stop-hook.sh"
    mv ~/.claude/hooks/autopilot-stop-hook.sh ~/.claude/hooks/autopilot-stop-hook.sh.bak
fi
ln -s "$SCRIPT_DIR/hooks/stop-hook.sh" ~/.claude/hooks/autopilot-stop-hook.sh
chmod +x ~/.claude/hooks/autopilot-stop-hook.sh
echo "  Linked: stop-hook.sh → ~/.claude/hooks/autopilot-stop-hook.sh"

# Symlink git-commit mutex for parallel agent support
if [ -L ~/.claude/hooks/git-commit ]; then
    rm ~/.claude/hooks/git-commit
elif [ -f ~/.claude/hooks/git-commit ]; then
    echo "Backing up existing git-commit to git-commit.bak"
    mv ~/.claude/hooks/git-commit ~/.claude/hooks/git-commit.bak
fi
ln -s "$SCRIPT_DIR/hooks/git-commit" ~/.claude/hooks/git-commit
chmod +x ~/.claude/hooks/git-commit
echo "  Linked: git-commit → ~/.claude/hooks/git-commit"

# Symlink update-analytics.sh
if [ -L ~/.claude/hooks/update-analytics.sh ]; then
    rm ~/.claude/hooks/update-analytics.sh
elif [ -f ~/.claude/hooks/update-analytics.sh ]; then
    echo "Backing up existing update-analytics.sh to update-analytics.sh.bak"
    mv ~/.claude/hooks/update-analytics.sh ~/.claude/hooks/update-analytics.sh.bak
fi
ln -s "$SCRIPT_DIR/hooks/update-analytics.sh" ~/.claude/hooks/update-analytics.sh
chmod +x ~/.claude/hooks/update-analytics.sh
echo "  Linked: update-analytics.sh → ~/.claude/hooks/update-analytics.sh"

# Register the Stop hook in ~/.claude/settings.json — the file Claude Code
# actually reads. (Older installs wrote ~/.claude/hooks.json, which Claude Code
# ignores entirely, so the loop hook never fired.)
SETTINGS_JSON=~/.claude/settings.json
HOOK_ENTRY='{"hooks":[{"type":"command","command":"~/.claude/hooks/autopilot-stop-hook.sh"}]}'
if command -v jq >/dev/null 2>&1; then
    if [ ! -f "$SETTINGS_JSON" ]; then
        echo '{}' > "$SETTINGS_JSON"
    fi
    if jq -e '.hooks.Stop[]?.hooks[]? | select(.command | contains("autopilot-stop-hook"))' "$SETTINGS_JSON" >/dev/null 2>&1; then
        echo "  Stop hook already registered in $SETTINGS_JSON"
    else
        SETTINGS_TMP=$(mktemp)
        if jq --argjson entry "$HOOK_ENTRY" '.hooks.Stop = ((.hooks.Stop // []) + [$entry])' "$SETTINGS_JSON" > "$SETTINGS_TMP"; then
            mv "$SETTINGS_TMP" "$SETTINGS_JSON"
            echo "  Registered Stop hook in $SETTINGS_JSON"
            echo "  (Restart running Claude Code sessions to pick it up)"
        else
            rm -f "$SETTINGS_TMP"
            echo "  Could not update $SETTINGS_JSON — add this under \"hooks\" manually:"
            echo '    "Stop": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/autopilot-stop-hook.sh"}]}]'
        fi
    fi
else
    echo "  jq not found — add this to $SETTINGS_JSON manually under \"hooks\":"
    echo '    "Stop": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/autopilot-stop-hook.sh"}]}]'
fi

# Clean up the obsolete hooks.json from older installs (never read by Claude Code)
HOOKS_JSON=~/.claude/hooks.json
if [ -f "$HOOKS_JSON" ] && grep -q "autopilot-stop-hook" "$HOOKS_JSON" 2>/dev/null; then
    if command -v jq >/dev/null 2>&1 && \
       jq -e '(keys == ["hooks"]) and (.hooks | keys == ["stop"]) and ([.hooks.stop[].command] | all(contains("autopilot-stop-hook")))' "$HOOKS_JSON" >/dev/null 2>&1; then
        rm "$HOOKS_JSON"
        echo "  Removed obsolete $HOOKS_JSON (contained only the autopilot hook)"
    else
        echo "  Note: the autopilot entry in $HOOKS_JSON is obsolete and can be removed"
    fi
fi

# Symlink run.sh to ~/.local/bin/autopilot
mkdir -p ~/.local/bin
if [ -L ~/.local/bin/autopilot ]; then
    rm ~/.local/bin/autopilot
elif [ -f ~/.local/bin/autopilot ]; then
    echo "Backing up existing ~/.local/bin/autopilot to autopilot.bak"
    mv ~/.local/bin/autopilot ~/.local/bin/autopilot.bak
fi
ln -s "$SCRIPT_DIR/run.sh" ~/.local/bin/autopilot
echo "  Linked: run.sh → ~/.local/bin/autopilot"

# Symlink cleanup.sh
if [ -L ~/.local/bin/autopilot-cleanup ]; then
    rm ~/.local/bin/autopilot-cleanup
elif [ -f ~/.local/bin/autopilot-cleanup ]; then
    echo "Backing up existing ~/.local/bin/autopilot-cleanup to autopilot-cleanup.bak"
    mv ~/.local/bin/autopilot-cleanup ~/.local/bin/autopilot-cleanup.bak
fi
ln -s "$SCRIPT_DIR/cleanup.sh" ~/.local/bin/autopilot-cleanup
echo "  Linked: cleanup.sh → ~/.local/bin/autopilot-cleanup"

# Symlink status.sh
if [ -L ~/.local/bin/autopilot-status ]; then
    rm ~/.local/bin/autopilot-status
elif [ -f ~/.local/bin/autopilot-status ]; then
    echo "Backing up existing ~/.local/bin/autopilot-status to autopilot-status.bak"
    mv ~/.local/bin/autopilot-status ~/.local/bin/autopilot-status.bak
fi
ln -s "$SCRIPT_DIR/status.sh" ~/.local/bin/autopilot-status
echo "  Linked: status.sh → ~/.local/bin/autopilot-status"

# Symlink autopilot-queue
if [ -L ~/.local/bin/autopilot-queue ]; then
    rm ~/.local/bin/autopilot-queue
elif [ -f ~/.local/bin/autopilot-queue ]; then
    echo "Backing up existing ~/.local/bin/autopilot-queue to autopilot-queue.bak"
    mv ~/.local/bin/autopilot-queue ~/.local/bin/autopilot-queue.bak
fi
ln -s "$SCRIPT_DIR/autopilot-queue" ~/.local/bin/autopilot-queue
echo "  Linked: autopilot-queue → ~/.local/bin/autopilot-queue"

# Symlink autopilot-test-stories
if [ -L ~/.local/bin/autopilot-test-stories ]; then
    rm ~/.local/bin/autopilot-test-stories
elif [ -f ~/.local/bin/autopilot-test-stories ]; then
    echo "Backing up existing ~/.local/bin/autopilot-test-stories to autopilot-test-stories.bak"
    mv ~/.local/bin/autopilot-test-stories ~/.local/bin/autopilot-test-stories.bak
fi
ln -s "$SCRIPT_DIR/autopilot-test-stories" ~/.local/bin/autopilot-test-stories
echo "  Linked: autopilot-test-stories → ~/.local/bin/autopilot-test-stories"

echo ""
echo "Installation complete!"
echo ""
echo "Commands available:"
echo "  /prd               - Create a PRD (inside Claude)"
echo "  /tasks             - Convert PRD to tasks (inside Claude)"
echo "  /autopilot         - Run TDD execution (inside Claude)"
echo "  /autopilot init    - Initialize project configuration (inside Claude)"
echo "  /autopilot stop    - Stop run.sh wrapper gracefully (inside Claude)"
echo "  /autopilot cancel  - Cancel hook-based loop (inside Claude)"
echo "  /autopilot status  - Read-only health check on any active loop (inside Claude)"
echo "  /autopilot analyze - Analyze session analytics (inside Claude)"
echo "  /test-user-stories - Parse domain file and generate testing task JSON (inside Claude)"
echo ""
echo "  autopilot                              - Token-frugal wrapper; no args = work the task queue"
echo "  autopilot queue [add|rm|hold|list]     - Manage the project task queue (from terminal)"
echo "  autopilot test-stories <domain.md>     - Audit user stories against existing features"
echo "  autopilot-cleanup                      - Kill orphaned Claude processes (from terminal)"
echo "  autopilot-status [taskfile]            - Read-only health check, no Claude session needed (from terminal)"
echo ""
echo "Usage:"
echo "  autopilot docs/autopilot/feature/feature.json    # Fresh context per requirement"
echo "  autopilot tasks.json --batch 3                   # 3 requirements per session"
echo "  autopilot queue add docs/autopilot/feature/feature.json   # Queue a task file"
echo "  autopilot                                        # Drain the queue, entry by entry"
echo "  autopilot test-stories docs/testing/domains/01-feature-area.md"
echo ""
echo "Run '/autopilot init' in your project to set up configuration."
echo ""
echo "Note: Ensure ~/.local/bin is in your PATH. Add to ~/.bashrc or ~/.zshrc:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
