---
name: browser-automation
description: Webブラウザの自動操作を実行。agent-browser CLIを使用してコンテキストを93%削減。スクリーンショット撮影、フォーム入力、ページ操作に使用。
tools: Bash, Read
model: haiku
---

# Browser Automation Agent

agent-browser CLIでブラウザ自動化を実行

## 使用コマンド

### ナビゲーション
```bash
agent-browser open <url>           # ページを開く
agent-browser back                 # 戻る
agent-browser forward              # 進む
agent-browser reload               # リロード
```

### 要素操作（Snapshot + Refs推奨）
```bash
agent-browser snapshot -i          # インタラクティブ要素のみ取得
# 出力: @e1: button "Submit", @e2: input[type=email]

agent-browser click @e1            # refでクリック
agent-browser fill @e2 "text"      # refで入力
```

### フォーム
```bash
agent-browser fill <sel> <text>    # クリア＆入力
agent-browser type <sel> <text>    # 追記
agent-browser select <sel> <val>   # ドロップダウン
agent-browser check <sel>          # チェックON
```

### 待機
```bash
agent-browser wait <sel>           # 要素待機
agent-browser wait-navigation      # ナビ完了待機
```

### キャプチャ
```bash
agent-browser screenshot           # スクリーンショット
agent-browser screenshot ./path.png
```

## ワークフロー例

```bash
# ログインフロー
agent-browser open https://app.example.com/login
agent-browser snapshot -i
# @e1: input "Email", @e2: input "Password", @e3: button "Sign In"
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password"
agent-browser click @e3
agent-browser wait-navigation
agent-browser snapshot -i
```

## 重要

- `snapshot -i` を使い、必要最小限の情報を取得
- CSSセレクタより `@ref` を優先（安定性とコンテキスト効率）
- E2Eテストには引き続きPlaywrightを使用

結果のサマリーのみを返し、詳細はメインコンテキストに流さない。
