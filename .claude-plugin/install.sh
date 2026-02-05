#!/bin/bash
# Claude Code Plugin Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/tubone24/claude-code-settings/main/.claude-plugin/install.sh | bash

set -e

PLUGIN_NAME="claude-code-settings"
REPO_URL="https://github.com/tubone24/claude-code-settings.git"
CLAUDE_DIR="$HOME/.claude"
PLUGIN_DIR="$CLAUDE_DIR/plugins/$PLUGIN_NAME"

echo "Installing $PLUGIN_NAME..."

# Create directories
mkdir -p "$CLAUDE_DIR/plugins"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/rules"
mkdir -p "$CLAUDE_DIR/hooks/scripts"
mkdir -p "$CLAUDE_DIR/logs"

# Clone or update
if [ -d "$PLUGIN_DIR" ]; then
  echo "Updating existing installation..."
  cd "$PLUGIN_DIR" && git pull
else
  echo "Cloning repository..."
  git clone "$REPO_URL" "$PLUGIN_DIR"
fi

# Symlink components
echo "Creating symlinks..."

# Commands
if [ -d "$PLUGIN_DIR/commands" ]; then
  for f in "$PLUGIN_DIR/commands"/*; do
    [ -e "$f" ] && ln -sf "$f" "$CLAUDE_DIR/commands/" 2>/dev/null || true
  done
fi

# Agents
if [ -d "$PLUGIN_DIR/agents" ]; then
  for f in "$PLUGIN_DIR/agents"/*; do
    [ -e "$f" ] && ln -sf "$f" "$CLAUDE_DIR/agents/" 2>/dev/null || true
  done
fi

# Skills (directory structure preserved)
if [ -d "$PLUGIN_DIR/skills" ]; then
  for d in "$PLUGIN_DIR/skills"/*; do
    if [ -d "$d" ]; then
      dirname=$(basename "$d")
      mkdir -p "$CLAUDE_DIR/skills/$dirname"
      ln -sf "$d"/* "$CLAUDE_DIR/skills/$dirname/" 2>/dev/null || true
    fi
  done
fi

# Rules
if [ -d "$PLUGIN_DIR/rules" ]; then
  mkdir -p "$CLAUDE_DIR/rules"
  for f in "$PLUGIN_DIR/rules"/*; do
    [ -e "$f" ] && ln -sf "$f" "$CLAUDE_DIR/rules/" 2>/dev/null || true
  done
fi

# Hook scripts
if [ -d "$PLUGIN_DIR/hooks/scripts" ]; then
  for f in "$PLUGIN_DIR/hooks/scripts"/*; do
    [ -e "$f" ] && ln -sf "$f" "$CLAUDE_DIR/hooks/scripts/" 2>/dev/null || true
  done
fi

echo ""
echo "Installation complete!"
echo ""
echo "Installed:"
echo "  - Commands:     ~/.claude/commands/"
echo "  - Agents:       ~/.claude/agents/"
echo "  - Skills:       ~/.claude/skills/"
echo "  - Rules:        ~/.claude/rules/"
echo "  - Hook scripts: ~/.claude/hooks/scripts/"
echo ""
echo "Next steps:"
echo ""
echo "1. Add hooks to your settings.json:"
echo "   cat $PLUGIN_DIR/hooks/hooks.json"
echo "   # Copy the 'hooks' object to ~/.claude/settings.json"
echo ""
echo "2. (Optional) Set environment variables for Obsidian integration:"
echo "   export OBSIDIAN_VAULT_PATH=\"/path/to/your/vault\""
echo ""
echo "3. Restart Claude Code"
echo ""
echo "For more info: https://github.com/tubone24/everything-claude-code"
