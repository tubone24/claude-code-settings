#!/bin/bash
# Claude Code Plugin Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/tubone24/everything-claude-code/main/.claude-plugin/install.sh | bash

set -e

PLUGIN_NAME="everything-claude-code"
CLAUDE_DIR="$HOME/.claude"
PLUGIN_DIR="$CLAUDE_DIR/plugins/$PLUGIN_NAME"

echo "Installing $PLUGIN_NAME..."

# Create directories
mkdir -p "$CLAUDE_DIR/plugins"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills"

# Clone or update
if [ -d "$PLUGIN_DIR" ]; then
  echo "Updating existing installation..."
  cd "$PLUGIN_DIR" && git pull
else
  echo "Cloning repository..."
  git clone https://github.com/tubone24/everything-claude-code.git "$PLUGIN_DIR"
fi

# Symlink components
ln -sf "$PLUGIN_DIR/commands"/* "$CLAUDE_DIR/commands/" 2>/dev/null || true
ln -sf "$PLUGIN_DIR/agents"/* "$CLAUDE_DIR/agents/" 2>/dev/null || true

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Copy hooks: cp $PLUGIN_DIR/hooks/hooks.json ~/.claude/settings.json"
echo "2. Copy MCP configs you need to ~/.claude.json"
echo "3. Restart Claude Code"
