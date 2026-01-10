#!/bin/bash

# Autopilot Install Script
# Creates symlinks from this repo to ~/.claude/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Autopilot commands..."

# Create directories if they don't exist
mkdir -p ~/.claude/commands

# Symlink command files
for cmd in prd.md tasks.md autopilot.md init.md; do
    if [ -L ~/.claude/commands/$cmd ]; then
        rm ~/.claude/commands/$cmd
    elif [ -f ~/.claude/commands/$cmd ]; then
        echo "Backing up existing $cmd to $cmd.bak"
        mv ~/.claude/commands/$cmd ~/.claude/commands/$cmd.bak
    fi
    ln -s "$SCRIPT_DIR/commands/$cmd" ~/.claude/commands/$cmd
    echo "  Linked: $cmd"
done

# Symlink AGENTS.md
if [ -L ~/.claude/AGENTS.md ]; then
    rm ~/.claude/AGENTS.md
elif [ -f ~/.claude/AGENTS.md ]; then
    echo "Backing up existing AGENTS.md to AGENTS.md.bak"
    mv ~/.claude/AGENTS.md ~/.claude/AGENTS.md.bak
fi
ln -s "$SCRIPT_DIR/AGENTS.md" ~/.claude/AGENTS.md
echo "  Linked: AGENTS.md"

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

echo ""
echo "Installation complete!"
echo ""
echo "Commands available:"
echo "  /prd            - Create a PRD (inside Claude)"
echo "  /tasks          - Convert PRD to tasks (inside Claude)"
echo "  /autopilot      - Run TDD execution (inside Claude)"
echo "  /autopilot init - Initialize project configuration (inside Claude)"
echo ""
echo "  autopilot       - Token-frugal wrapper (from terminal)"
echo ""
echo "Usage:"
echo "  autopilot docs/tasks/prds/feature.json    # Fresh context per requirement"
echo "  autopilot tasks.json --batch 3            # 3 requirements per session"
echo ""
echo "Run '/autopilot init' in your project to set up configuration."
echo ""
echo "Note: Ensure ~/.local/bin is in your PATH. Add to ~/.bashrc or ~/.zshrc:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
