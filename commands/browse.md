---
description: AI-native browser automation using agent-browser CLI. Navigate, interact, and capture web pages with 93% less context usage than MCP.
---

# Browseコマンド

このコマンドは**browser-automation**エージェントを呼び出し、agent-browser CLIを使用してWebブラウザを自動操作します。

## このコマンドの機能

1. **ページナビゲーション** - URLを開く、戻る、進む、リロード
2. **要素操作** - クリック、入力、選択、チェック
3. **スクリーンショット撮影** - 現在の画面またはフルページ
4. **ページ情報取得** - インタラクティブ要素、コンソール、ネットワーク

## 使用するタイミング

以下の場合に`/browse`を使用:
- Webページの内容を確認したい
- フォームに自動入力したい
- ログインフローをテストしたい
- スクリーンショットを撮影したい
- UIの動作を確認したい

## 動作の仕組み

browser-automationエージェントは:

1. **agent-browser CLIを使用** - MCP不要、Bashツールで動作
2. **Snapshot + Refsシステム** - `@e1`, `@e2`のような参照で要素を操作
3. **コンテキスト効率** - 従来比93%のコンテキスト削減
4. **結果サマリーのみ返却** - メインコンテキストを圧迫しない

## 使用例

```
ユーザー: /browse https://example.com にアクセスしてログインフォームを入力

エージェント（browser-automation）:
# ブラウザ操作結果

## 実行内容

1. https://example.com を開きました
2. インタラクティブ要素を検出:
   - @e1: input[type=email] "Email"
   - @e2: input[type=password] "Password"
   - @e3: button "Sign In"
3. フォームに入力しました
4. Sign Inボタンをクリックしました

## 結果

ログイン成功。ダッシュボードページに遷移しました。

スクリーンショット: ./screenshots/dashboard.png
```

## E2Eテストとの違い

| /browse (agent-browser) | /e2e (Playwright) |
|------------------------|-------------------|
| インタラクティブな操作 | 自動テスト実行 |
| 単発のブラウザ操作 | 複数テストケース |
| コンテキスト効率重視 | カバレッジ重視 |
| スクリーンショット | テストレポート |

## セットアップ

初回のみ:
```bash
npm install -g agent-browser
agent-browser install
```

## 関連エージェント

このコマンドは`~/.claude/agents/browser-automation.md`を呼び出します。

## よく使うコマンド

```bash
# ページを開く
agent-browser open https://example.com

# インタラクティブ要素を取得
agent-browser snapshot -i

# 要素をクリック
agent-browser click @e1

# 入力
agent-browser fill @e2 "text"

# スクリーンショット
agent-browser screenshot ./screenshot.png
```
