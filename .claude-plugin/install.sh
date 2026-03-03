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

# ===== hooks.json 自動マージ =====
merge_hooks() {
  local SETTINGS_FILE="$CLAUDE_DIR/settings.json"
  local HOOKS_FILE="$PLUGIN_DIR/hooks/hooks.json"

  echo ""
  echo "Merging hooks into settings.json..."

  # jqコマンドの確認
  if ! command -v jq >/dev/null 2>&1; then
    echo ""
    echo "WARNING: jq is not installed. Cannot auto-merge hooks."
    echo "Please install jq first:"
    echo "  macOS:  brew install jq"
    echo "  Ubuntu: sudo apt-get install jq"
    echo "  Other:  https://jqlang.github.io/jq/download/"
    echo ""
    echo "Then manually merge hooks:"
    echo "  cat $HOOKS_FILE"
    echo "  # Copy the 'hooks' object to $SETTINGS_FILE"
    return 0
  fi

  # hooks.jsonの存在確認
  if [ ! -f "$HOOKS_FILE" ]; then
    echo "WARNING: $HOOKS_FILE not found. Skipping hooks merge."
    return 0
  fi

  # settings.jsonが存在しない場合 → hooksキーだけ抽出して新規作成
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Creating new settings.json..."
    jq '{ hooks: .hooks }' "$HOOKS_FILE" > "$SETTINGS_FILE"
    echo "Created $SETTINGS_FILE"
    return 0
  fi

  # settings.jsonの既存内容を検証
  if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
    echo "ERROR: $SETTINGS_FILE is not valid JSON. Skipping merge."
    echo "Please fix the file and re-run the installer."
    return 0
  fi

  # バックアップ作成
  local BACKUP_FILE="${SETTINGS_FILE}.bak.$(date '+%Y%m%d%H%M%S')"
  cp "$SETTINGS_FILE" "$BACKUP_FILE"
  echo "Backup created: $BACKUP_FILE"

  # イベントごとに配列をマージ（descriptionで重複排除）
  local MERGED
  MERGED=$(jq -s '
    .[0] as $existing | .[1] as $plugin |
    ($existing.hooks // {}) as $eh |
    ($plugin.hooks // {}) as $ph |
    ([$eh | keys[], $ph | keys[]] | unique) as $events |
    reduce $events[] as $event (
      {};
      . + {
        ($event): (
          (($eh[$event] // []) + ($ph[$event] // []))
          | group_by(.description)
          | map(last)
        )
      }
    ) as $merged_hooks |
    $existing + { "hooks": $merged_hooks }
  ' "$SETTINGS_FILE" "$HOOKS_FILE" 2>/dev/null)

  # マージ結果の検証 + アトミック書き込み
  if [ $? -eq 0 ] && [ -n "$MERGED" ] && echo "$MERGED" | jq empty 2>/dev/null; then
    local TEMP_FILE
    TEMP_FILE=$(mktemp "${SETTINGS_FILE}.tmp.XXXXXXXX")
    if echo "$MERGED" | jq '.' > "$TEMP_FILE" 2>/dev/null; then
      mv "$TEMP_FILE" "$SETTINGS_FILE"
      echo "Hooks merged successfully into $SETTINGS_FILE"
    else
      rm -f "$TEMP_FILE"
      echo "ERROR: Failed to write merged settings."
      echo "Restored from backup: $BACKUP_FILE"
      cp "$BACKUP_FILE" "$SETTINGS_FILE"
      return 0
    fi
  else
    echo "ERROR: Failed to merge hooks. Your original settings.json is preserved."
    echo "Backup: $BACKUP_FILE"
    return 0
  fi
}

merge_hooks

# ===== 完了メッセージ =====
echo ""
echo "Installation complete!"
echo ""
echo "Installed:"
echo "  - Commands:     ~/.claude/commands/"
echo "  - Agents:       ~/.claude/agents/"
echo "  - Skills:       ~/.claude/skills/"
echo "  - Rules:        ~/.claude/rules/"
echo "  - Hook scripts: ~/.claude/hooks/scripts/"
echo "  - Hooks:        Merged into ~/.claude/settings.json"
echo ""
echo "Next steps:"
echo "1. (Optional) Slack通知を有効にする場合:"
echo "   export SLACK_WEBHOOK_URL=\"https://hooks.slack.com/services/YOUR/WEBHOOK/URL\""
echo "   # ~/.zshrc or ~/.bashrc に追加して永続化してください"
echo "2. (Optional) Obsidian連携を有効にする場合:"
echo "   export OBSIDIAN_VAULT_PATH=\"/path/to/your/vault\""
echo "3. Restart Claude Code"
echo ""
echo "For more info: https://github.com/tubone24/everything-claude-code"
