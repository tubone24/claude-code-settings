---
name: deploy-cli
description: Deployment CLI tools reference
---

# Deploy CLIs

## Vercel
```bash
vercel                    # プレビュー
vercel --prod             # 本番
vercel ls                 # デプロイ一覧
vercel logs [url]         # ログ
vercel env pull           # 環境変数
vercel env add [KEY]      # 環境変数追加
```

## Railway
```bash
railway login
railway init
railway up                # デプロイ
railway logs              # ログ
railway status
railway variables         # 環境変数
railway variables set KEY=value
```

## Cloudflare Workers
```bash
npx wrangler init
npx wrangler dev          # ローカル開発
npx wrangler deploy       # デプロイ
npx wrangler tail         # ログ
npx wrangler secret put [KEY]
```

## Fly.io
```bash
fly launch
fly deploy
fly logs
fly secrets set KEY=value
```
