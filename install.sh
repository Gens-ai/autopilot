#!/bin/bash

# Autopilot Install Script
# Creates symlinks from this repo to ~/.claude/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Autopilot commands..."

# Create directories if they don't exist
mkdir -p ~/.claude/commands

# Symlink command files
for cmd in prd.md tasks.md autopilot.md; do
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

echo ""
echo "Installation complete!"
echo ""
echo "Commands available:"
echo "  /prd        - Create a PRD"
echo "  /tasks      - Convert PRD to tasks"
echo "  /autopilot  - Run autonomous TDD execution"
echo ""
echo "See README.md for usage instructions."
