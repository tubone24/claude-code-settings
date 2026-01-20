# Obsidian 作業ログ記録

Claude Codeでの作業経過をObsidianに記録する。

## 使い方

### /obsidian-log [タイトル]

作業経過をObsidianに記録する。タイトルを省略した場合は日時がタイトルになる。

## 記録先

- **Vaultパス**: `~/Documents/Obsidian Vault`
- **フォルダ**: `Claude-Logs/[プロジェクト名]/`
- **ファイル名**: `[プロジェクト名].md`

## 記録フォーマット

```markdown
## [日時] [タイトル]

### 会話サマリー
- 目的: [何を達成しようとしたか]
- 結果: [達成できたか、どこまで進んだか]
- 学び: [気づいたこと、次回への教訓]

### 作業ログ
- 変更ファイル: [変更したファイル一覧]
- 実行コマンド: [主要なコマンド]
- エラー/問題: [発生した問題と解決策]

### 次のステップ
- [ ] [残タスク1]
- [ ] [残タスク2]

---
```

## 実行手順

1. **プロジェクト名を取得**
   ```bash
   basename $(git rev-parse --show-toplevel 2>/dev/null || pwd)
   ```

2. **変更ファイルを取得**
   ```bash
   git diff --name-only HEAD~1 2>/dev/null || git status --short
   ```

3. **記録を追記**
   ```bash
   # フォルダ作成
   mkdir -p ~/Documents/Obsidian Vault/Claude-Logs/[プロジェクト名]

   # ファイルに追記（なければ作成）
   cat >> ~/Documents/Obsidian Vault/Claude-Logs/[プロジェクト名]/[プロジェクト名].md
   ```

## タグ

Obsidianで検索しやすいよう、以下のタグを付与:
- `#claude-code`
- `#作業ログ`
- `#[プロジェクト名]`

## 注意事項

- 機密情報（APIキー、パスワード等）は記録しない
- 長いコード出力は要約する
- 日本語で記録する
