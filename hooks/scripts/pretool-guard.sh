#!/bin/bash
# PreToolUse 自動判定ガード
# 安全なコマンド → 自動許可 (permissionDecision: allow)
# 危険なコマンド → 自動拒否 (permissionDecision: deny)
# グレーゾーン   → ユーザーに確認 (permissionDecision: ask)

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

# --- ヘルパー関数 ---

allow() {
  jq -n --arg ctx "${1:-}" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: $ctx
    }
  }'
  exit 0
}

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

ask() {
  jq -n --arg ctx "${1:-}" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      additionalContext: $ctx
    }
  }'
  exit 0
}

# =========================================================
# 1. ファイル操作ツール (Read / Edit / Write) のガード
# =========================================================
if [ "$tool_name" = "Read" ] || [ "$tool_name" = "Edit" ] || [ "$tool_name" = "Write" ]; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

  # 機密ファイルのブロックリスト
  BLOCKED_PATTERNS=(
    ".env"
    ".env.local"
    ".env.production"
    ".env.development"
    ".env.staging"
    "credentials"
    "secrets"
    ".ssh"
    "id_rsa"
    "id_ed25519"
    ".pem"
    ".key"
    ".p12"
    ".pfx"
    "serviceAccount"
    ".npmrc"
    ".pypirc"
    ".netrc"
    "token.json"
    "oauth"
    ".aws/credentials"
    ".gcloud"
    "keystore"
  )

  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$file_path" == *"$pattern"* ]]; then
      deny "機密ファイルへのアクセスはブロックされました: $file_path (パターン: $pattern)"
    fi
  done

  # Read は基本的に安全 → 自動許可
  if [ "$tool_name" = "Read" ]; then
    allow
  fi

  # Edit/Write はパススルー（既存のpermission rulesに委ねる）
  echo "$input"
  exit 0
fi

# =========================================================
# 2. Bash コマンドのガード
# =========================================================
if [ "$tool_name" = "Bash" ]; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

  # --- 2a. 絶対ブロック（破壊的・危険なコマンド） ---

  # Force push
  if echo "$cmd" | grep -qE 'git\s+push\s+.*(--force\b|-f\b)' 2>/dev/null; then
    deny "Force push は禁止されています。--force-with-lease を使用してください。"
  fi

  # 致命的な破壊コマンド
  if echo "$cmd" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f?\s+(/|~|\$HOME)' 2>/dev/null; then
    deny "ルートディレクトリまたはホームディレクトリへの rm -rf は禁止されています。"
  fi
  if echo "$cmd" | grep -qE ':\(\)\s*\{\s*:\|:&\s*\}\s*;' 2>/dev/null; then
    deny "Fork bomb が検出されました。"
  fi
  if echo "$cmd" | grep -qE '>\s*/dev/sd|mkfs\.|dd\s+if=' 2>/dev/null; then
    deny "ディスク破壊コマンドが検出されました。"
  fi

  # .env ファイルへのアクセス
  if echo "$cmd" | grep -qE '(cat|less|more|head|tail|nano|vim?|code|open)\s+.*\.env' 2>/dev/null; then
    deny ".env ファイルの内容参照は禁止されています。"
  fi
  if echo "$cmd" | grep -qE '(source|\.)\s+.*\.env' 2>/dev/null; then
    deny ".env ファイルの読み込みは禁止されています。"
  fi

  # git reset --hard
  if echo "$cmd" | grep -qE 'git\s+reset\s+--hard' 2>/dev/null; then
    deny "git reset --hard は危険です。git stash を使うか、明示的に確認してください。"
  fi

  # git clean -f
  if echo "$cmd" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f' 2>/dev/null; then
    deny "git clean -f はファイルを不可逆的に削除します。"
  fi

  # データベース破壊操作
  if echo "$cmd" | grep -qiE '(drop\s+(database|table|schema)|truncate\s+table|delete\s+from\s+\w+\s*;|alter\s+table.*drop)' 2>/dev/null; then
    deny "データベースの破壊的操作が検出されました: DROP/TRUNCATE/DELETE without WHERE"
  fi

  # curl で機密情報を外部に送信
  if echo "$cmd" | grep -qE 'curl.*(-d|--data).*(\$\{?[A-Z_]*KEY|\$\{?[A-Z_]*TOKEN|\$\{?[A-Z_]*SECRET)' 2>/dev/null; then
    deny "機密情報を含む可能性のある外部送信が検出されました。"
  fi

  # chmod 777
  if echo "$cmd" | grep -qE 'chmod\s+(777|a\+rwx)' 2>/dev/null; then
    deny "chmod 777 はセキュリティリスクです。適切な権限を設定してください。"
  fi

  # --- 2b. 安全なコマンド → 自動許可 ---

  # 読み取り専用コマンド
  if echo "$cmd" | grep -qE '^(ls|cat|head|tail|wc|file|stat|which|pwd|tree|echo|printf|date|whoami|hostname|uname|id|env|printenv)\b' 2>/dev/null; then
    allow "読み取り専用コマンド"
  fi

  # Git 読み取り系
  if echo "$cmd" | grep -qE '^git\s+(status|log|diff|show|branch|tag|remote|stash list|rev-parse|describe|shortlog|blame|ls-files|ls-tree)' 2>/dev/null; then
    allow "Git 読み取りコマンド"
  fi

  # パッケージマネージャのインストール・ビルド
  if echo "$cmd" | grep -qE '^(npm|yarn|pnpm|bun)\s+(install|ci|run|test|build|lint|format|typecheck|type-check|check|dev|start|exec|dlx|create)\b' 2>/dev/null; then
    allow "パッケージマネージャコマンド"
  fi
  if echo "$cmd" | grep -qE '^npx\s+' 2>/dev/null; then
    allow "npx コマンド"
  fi

  # Python
  if echo "$cmd" | grep -qE '^(python3?|pip3?|poetry|pdm|uv|ruff|mypy|pytest|black|isort|flake8)\s+' 2>/dev/null; then
    allow "Python ツールコマンド"
  fi

  # Rust
  if echo "$cmd" | grep -qE '^cargo\s+(build|test|check|clippy|fmt|run|doc|bench)\b' 2>/dev/null; then
    allow "Cargo コマンド"
  fi

  # Go
  if echo "$cmd" | grep -qE '^go\s+(build|test|vet|fmt|run|mod|generate)\b' 2>/dev/null; then
    allow "Go コマンド"
  fi

  # Docker 読み取り系
  if echo "$cmd" | grep -qE '^docker\s+(ps|images|logs|inspect|stats|top|port|version|info)\b' 2>/dev/null; then
    allow "Docker 読み取りコマンド"
  fi

  # Make
  if echo "$cmd" | grep -qE '^make\b' 2>/dev/null; then
    allow "Make コマンド"
  fi

  # jq, grep, rg, fd, fzf, ag, sed (読み取り系ツール)
  if echo "$cmd" | grep -qE '^(jq|grep|rg|fd|fzf|ag|awk)\s+' 2>/dev/null; then
    allow "テキスト検索・処理コマンド"
  fi

  # diff, md5, sha
  if echo "$cmd" | grep -qE '^(diff|md5|md5sum|shasum|sha256sum)\s+' 2>/dev/null; then
    allow "比較・チェックサムコマンド"
  fi

  # mkdir（ディレクトリ作成は基本安全）
  if echo "$cmd" | grep -qE '^mkdir\s+' 2>/dev/null; then
    allow "ディレクトリ作成"
  fi

  # touch（ファイル作成は基本安全）
  if echo "$cmd" | grep -qE '^touch\s+' 2>/dev/null; then
    allow "ファイル作成"
  fi

  # cp（コピーは基本安全）
  if echo "$cmd" | grep -qE '^cp\s+' 2>/dev/null; then
    allow "ファイルコピー"
  fi

  # gh CLI 読み取り系
  if echo "$cmd" | grep -qE '^gh\s+(pr|issue|repo|run|release)\s+(list|view|status|diff|checks|comments)\b' 2>/dev/null; then
    allow "GitHub CLI 読み取りコマンド"
  fi

  # gh api (GET)
  if echo "$cmd" | grep -qE '^gh\s+api\s+' 2>/dev/null; then
    if ! echo "$cmd" | grep -qE '(-X\s*(POST|PUT|PATCH|DELETE)|--method\s*(POST|PUT|PATCH|DELETE))' 2>/dev/null; then
      allow "GitHub API GET リクエスト"
    fi
  fi

  # --- 2c. 要確認コマンド（askにフォールスルー） ---

  # git push（force以外）→ 確認を求める
  if echo "$cmd" | grep -qE '^git\s+push' 2>/dev/null; then
    ask "git push を実行しようとしています。リモートに変更が反映されます。"
  fi

  # git commit → 確認を求める
  if echo "$cmd" | grep -qE '^git\s+commit' 2>/dev/null; then
    ask "git commit を実行しようとしています。"
  fi

  # rm（限定的な削除）→ 確認を求める
  if echo "$cmd" | grep -qE '^rm\s+' 2>/dev/null; then
    ask "ファイル削除コマンドです。対象: $cmd"
  fi

  # docker run / docker compose up → 確認を求める
  if echo "$cmd" | grep -qE '^docker\s+(run|compose|build|push|pull|exec)\b' 2>/dev/null; then
    ask "Docker 操作コマンドです。"
  fi

  # curl/wget（外部通信）→ 確認を求める
  if echo "$cmd" | grep -qE '^(curl|wget|http)\s+' 2>/dev/null; then
    ask "外部通信コマンドです。"
  fi

  # sed / awk でファイル変更 (-i)
  if echo "$cmd" | grep -qE '(sed|awk)\s+-i' 2>/dev/null; then
    ask "ファイルをインプレース編集するコマンドです。"
  fi

  # mv（ファイル移動）→ 確認を求める
  if echo "$cmd" | grep -qE '^mv\s+' 2>/dev/null; then
    ask "ファイル移動コマンドです。"
  fi

  # パイプを含むコマンドで先頭がマッチしなかった場合
  # デフォルトはパススルー（既存のpermission rulesに委ねる）
  echo "$input"
  exit 0
fi

# =========================================================
# 3. その他のツール → パススルー
# =========================================================
echo "$input"
exit 0
