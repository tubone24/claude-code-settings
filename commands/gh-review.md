# GitHub PRレビュー

## 使用方法

```
/gh-review [PR番号またはURL]
```

## 実行内容

1. PR情報を取得
   ```bash
   gh pr view [番号] --json title,body,files,commits
   ```

2. 変更差分を確認
   ```bash
   gh pr diff [番号]
   ```

3. レビュー観点
   - セキュリティ問題
   - パフォーマンス影響
   - テストカバレッジ
   - コード品質
   - 破壊的変更

4. コメント投稿
   ```bash
   gh pr review [番号] --comment --body "..."
   ```
