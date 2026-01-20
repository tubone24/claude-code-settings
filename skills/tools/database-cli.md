---
name: database-cli
description: Database CLI tools reference
---

# Database CLIs

## Supabase
```bash
npx supabase init
npx supabase start
npx supabase db diff -f [name]
npx supabase migration new [name]
npx supabase db push
npx supabase gen types typescript --local > types/supabase.ts
```

## Prisma
```bash
npx prisma init
npx prisma db pull
npx prisma migrate dev --name [name]
npx prisma migrate deploy
npx prisma generate
npx prisma studio
```

## Drizzle
```bash
npx drizzle-kit generate
npx drizzle-kit push
npx drizzle-kit migrate
npx drizzle-kit studio
```

## psql
```bash
psql $DATABASE_URL
\dt           # テーブル一覧
\d [table]    # テーブル定義
\di           # インデックス一覧
\q            # 終了
```
