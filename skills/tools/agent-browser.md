---
name: agent-browser
description: Vercel agent-browser CLI reference for AI-native browser automation. Use instead of Playwright MCP for context-efficient browser control.
---

# agent-browser CLI

Vercel製のAIエージェント向けブラウザ自動化CLI。コンテキスト使用量を最大93%削減。

## インストール

```bash
npm install -g agent-browser
agent-browser install  # Chromiumをダウンロード
```

## 基本コマンド

### ナビゲーション
```bash
agent-browser open <url>           # URLを開く
agent-browser open https://example.com

agent-browser back                 # 戻る
agent-browser forward              # 進む
agent-browser reload               # リロード
```

### 要素操作（Snapshot + Refs）
```bash
# スナップショットでインタラクティブ要素を取得
agent-browser snapshot -i

# 出力例:
# @e1: button "Sign In"
# @e2: input[type=email]
# @e3: link "About Us"

# refを使ってクリック
agent-browser click @e1

# refを使って入力
agent-browser fill @e2 "user@example.com"
```

### フォーム操作
```bash
agent-browser fill <selector> <text>     # クリアして入力
agent-browser type <selector> <text>     # 追記入力
agent-browser select <selector> <value>  # ドロップダウン選択
agent-browser check <selector>           # チェックボックスON
agent-browser uncheck <selector>         # チェックボックスOFF
```

### スクリーンショット
```bash
agent-browser screenshot                 # 現在の画面
agent-browser screenshot ./path/to/file.png
agent-browser screenshot --full-page     # フルページ
```

### ページ情報
```bash
agent-browser snapshot                   # アクセシビリティツリー全体
agent-browser snapshot -i                # インタラクティブ要素のみ
agent-browser console                    # コンソールログを取得
agent-browser network                    # ネットワークリクエスト
```

### 待機
```bash
agent-browser wait <selector>            # 要素を待機
agent-browser wait-visible <selector>    # 表示を待機
agent-browser wait-hidden <selector>     # 非表示を待機
agent-browser wait-navigation            # ナビゲーション完了を待機
```

### セッション管理
```bash
# 複数セッションの管理
agent-browser open https://example.com --session=session1
agent-browser open https://other.com --session=session2

# または環境変数で
AGENT_BROWSER_SESSION=session1 agent-browser snapshot
```

## コンテキスト効率化のポイント

### 1. snapshot -i を優先
```bash
# 全ツリーではなくインタラクティブ要素のみ
agent-browser snapshot -i
```

### 2. Refs（@e1, @e2...）を使う
```bash
# CSSセレクタより安定し、コンテキスト効率が高い
agent-browser click @e1
agent-browser fill @e2 "text"
```

### 3. 必要な情報だけ取得
```bash
# フルスナップショットは避ける
agent-browser snapshot -i  # 操作対象のみ
```

## Playwrightとの使い分け

| 用途 | agent-browser | Playwright |
|------|---------------|------------|
| AIエージェントのブラウザ操作 | **推奨** | - |
| E2Eテスト（CI/CD） | - | **推奨** |
| スクリーンショット撮影 | **推奨** | - |
| 複雑なテストシナリオ | - | **推奨** |
| コンテキスト節約 | **93%削減** | 大量消費 |

## 典型的なワークフロー

```bash
# 1. ページを開く
agent-browser open https://app.example.com/login

# 2. インタラクティブ要素を確認
agent-browser snapshot -i
# @e1: input[type=email] "Email"
# @e2: input[type=password] "Password"
# @e3: button "Sign In"

# 3. フォームに入力
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"

# 4. 送信
agent-browser click @e3

# 5. ナビゲーション完了を待機
agent-browser wait-navigation

# 6. 結果を確認
agent-browser snapshot -i
```

## トラブルシューティング

```bash
# デーモンの状態確認
agent-browser status

# デーモン再起動
agent-browser restart

# ヘッドモードでデバッグ
agent-browser open <url> --headed
```

## 参考リンク

- [GitHub](https://github.com/vercel-labs/agent-browser)
- [npm](https://www.npmjs.com/package/agent-browser)
