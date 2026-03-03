#!/bin/bash
# Slack Webhook通知スクリプト
# Notificationイベントで呼び出され、Slack incoming webhookに通知を送信する
# 環境変数 SLACK_WEBHOOK_URL が未設定の場合はサイレントにスキップ

# ~/.claude/.envから環境変数を安全に読み込み（source不使用でインジェクション防止）
if [ -f "$HOME/.claude/.env" ]; then
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "$key=$value"
    fi
  done < "$HOME/.claude/.env"
fi

# SLACK_WEBHOOK_URL未設定ならサイレントに終了
if [ -z "$SLACK_WEBHOOK_URL" ]; then
  exit 0
fi

# stdinからJSON入力を読み取り
input=$(cat)

# ホスト名・タイムスタンプ
hostname=$(hostname 2>/dev/null || echo "unknown")
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# jqが利用可能な場合: jqで安全にペイロードを構築（自動エスケープ）
if command -v jq >/dev/null 2>&1; then
  message=$(echo "$input" | jq -r '.message // "承認待ちです"')
  cwd=$(echo "$input" | jq -r '.cwd // "unknown"')
  session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

  payload=$(jq -n \
    --arg msg "$message" \
    --arg cwd "$cwd" \
    --arg sid "$session_id" \
    --arg host "$hostname" \
    --arg ts "$timestamp" \
    '{
      text: ":bell: Claude Code 承認待ち",
      blocks: [
        { type: "header", text: { type: "plain_text", text: "Claude Code - 承認待ち", emoji: true } },
        { type: "section", fields: [
          { type: "mrkdwn", text: ("*メッセージ:*\n" + $msg) },
          { type: "mrkdwn", text: ("*作業ディレクトリ:*\n`" + $cwd + "`") }
        ]},
        { type: "context", elements: [
          { type: "mrkdwn", text: (":computer: " + $host + " | :clock1: " + $ts + " | Session: `" + $sid + "`") }
        ]}
      ]
    }')
else
  # jqなしのフォールバック: 最低限のプレーンテキスト通知
  cwd="$(pwd)"
  payload="{\"text\":\":bell: Claude Code 承認待ち (dir: ${cwd})\"}"
fi

# curl送信（エラー時はstderrにログ出力、全体はエラーにしない）
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H 'Content-type: application/json' \
  --data "$payload" \
  "$SLACK_WEBHOOK_URL" \
  --max-time 5 2>/dev/null) || true

if [ "$response" != "200" ] && [ "$response" != "000" ] && [ -n "$response" ]; then
  echo "[slack-notify] Warning: Slack API returned HTTP $response" >&2
fi

exit 0
