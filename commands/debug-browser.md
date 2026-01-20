---
description: Debug web applications using Chrome DevTools. Analyze performance, monitor console logs, inspect network requests, and detect memory leaks.
---

# Debug Browserコマンド

このコマンドは**browser-debug**エージェントを呼び出し、Chrome DevToolsを使用してWebアプリケーションをデバッグします。

## このコマンドの機能

1. **パフォーマンス分析** - Core Web Vitals、Lighthouseスコア
2. **コンソールログ監視** - エラー、警告、ログの収集
3. **ネットワーク監視** - 失敗したリクエスト、遅いAPI
4. **メモリリーク検出** - ヒープサイズ、DOMノード数の変化

## 使用するタイミング

以下の場合に`/debug-browser`を使用:
- ページの読み込みが遅い
- コンソールにエラーが出ている
- APIリクエストが失敗している
- メモリ使用量が増え続けている
- Core Web Vitalsのスコアが低い

## 使用例

```
ユーザー: /debug-browser https://localhost:3000 のパフォーマンスを分析して

エージェント（browser-debug）:
## デバッグ結果サマリー

**URL:** https://localhost:3000
**分析時刻:** 2026-01-20 15:30

### パフォーマンス
- LCP: 2.8s (要改善) - 目標: 2.5s以下
- FID: 45ms (良好)
- CLS: 0.15 (要改善) - 目標: 0.1以下

### 検出された問題
1. [重大] 画像の遅延読み込みなし - hero.png (2.3MB)
2. [警告] 未使用のJavaScript - vendor.js の40%が未使用
3. [警告] レイアウトシフト - 広告バナーの読み込み時

### 推奨アクション
1. hero.pngをWebP形式に変換し、lazy loadingを追加
2. コード分割でvendor.jsを最適化
3. 広告バナーに固定サイズを指定

詳細レポート: ./lighthouse-report.html
```

## /browseとの違い

| /debug-browser | /browse |
|---------------|---------|
| パフォーマンス分析 | UI操作 |
| エラー調査 | フォーム入力 |
| ネットワーク監視 | スクリーンショット |
| 開発者向け | エンドユーザー操作 |

## セットアップ

```bash
# Puppeteerが必要
npm install puppeteer

# Lighthouseも推奨
npm install -g lighthouse
```

## 関連エージェント

このコマンドは`~/.claude/agents/browser-debug.md`を呼び出します。
