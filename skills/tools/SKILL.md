---
name: cli-tools
description: CLIツールリファレンス。GitHub CLI、データベースCLI、デプロイCLI、ブラウザ自動化ツールのコマンド参照に使用。
---

# CLIツールリファレンス

開発で頻繁に使用するCLIツールのクイックリファレンス。

## 有効化するタイミング

- GitHub操作（PR、Issue、リリース）
- データベース操作（マイグレーション、クエリ）
- デプロイ操作（Vercel、Railway、Cloudflare）
- ブラウザ自動化・デバッグ

## ツール一覧

| ツール | 用途 | 参照 |
|--------|------|------|
| **gh** | GitHub CLI | `references/github-cli.md` |
| **agent-browser** | AIネイティブブラウザ自動化 | `references/agent-browser.md` |
| **Chrome DevTools** | ブラウザデバッグ | `references/chrome-devtools.md` |
| **Supabase/Prisma/Drizzle** | データベース操作 | `references/database-cli.md` |
| **Vercel/Railway/Fly.io** | デプロイ | `references/deploy-cli.md` |

## クイックリファレンス

### GitHub CLI (gh)

```bash
gh pr create --title "..." --body "..."
gh pr list --state open
gh pr view [number]
gh issue create --title "..." --body "..."
gh release create [tag] --notes "..."
```

### agent-browser

```bash
agent-browser open <url>
agent-browser snapshot -i          # インタラクティブ要素のみ
agent-browser click @e1            # refでクリック
agent-browser fill @e2 "text"      # refで入力
agent-browser screenshot
```

### データベースCLI

```bash
# Supabase
npx supabase db diff -f [name]
npx supabase migration new [name]
npx supabase gen types typescript --local > types/supabase.ts

# Prisma
npx prisma migrate dev --name [name]
npx prisma generate
npx prisma studio
```

### デプロイCLI

```bash
# Vercel
vercel --prod
vercel env pull

# Railway
railway up
railway logs
```

## ツール選択ガイド

### ブラウザ自動化

| 用途 | 推奨ツール |
|------|-----------|
| AIエージェントのブラウザ操作 | **agent-browser** |
| パフォーマンス分析 | **Chrome DevTools** |
| E2Eテスト（CI/CD） | **Playwright** |
| コンテキスト節約 | **agent-browser**（93%削減） |

### データベース

| 用途 | 推奨ツール |
|------|-----------|
| Supabaseプロジェクト | **supabase cli** |
| TypeScript ORM | **Prisma** or **Drizzle** |
| 直接SQL操作 | **psql** |

## 詳細リファレンス

各ツールの詳細なコマンドとオプションは`references/`配下を参照：

- `references/github-cli.md` - gh CLI完全リファレンス
- `references/agent-browser.md` - agent-browser CLI
- `references/chrome-devtools.md` - DevToolsデバッグ
- `references/database-cli.md` - DB CLI集
- `references/deploy-cli.md` - デプロイCLI集
