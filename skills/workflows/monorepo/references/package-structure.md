# モノレポ パッケージ設計パターン

## 推奨ディレクトリ構造

```
monorepo/
├── apps/                    # アプリケーション
│   ├── web/                 # フロントエンド
│   ├── api/                 # バックエンドAPI
│   ├── admin/               # 管理画面
│   └── docs/                # ドキュメントサイト
│
├── packages/                # 共有パッケージ
│   ├── ui/                  # UIコンポーネント
│   ├── utils/               # ユーティリティ関数
│   ├── types/               # 共有型定義
│   ├── config/              # 設定ファイル
│   │   ├── eslint/
│   │   ├── typescript/
│   │   └── tailwind/
│   └── database/            # DB操作、スキーマ
│
├── tooling/                 # 開発ツール
│   ├── scripts/
│   └── generators/
│
└── infrastructure/          # インフラ（Terraform等）
```

## パッケージ種類

### 1. UIコンポーネントパッケージ

```
packages/ui/
├── src/
│   ├── components/
│   │   ├── Button/
│   │   │   ├── Button.tsx
│   │   │   ├── Button.test.tsx
│   │   │   └── index.ts
│   │   └── index.ts
│   └── index.ts
├── package.json
└── tsconfig.json
```

```json
// packages/ui/package.json
{
  "name": "@repo/ui",
  "version": "0.0.0",
  "private": true,
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": "./src/index.ts",
    "./button": "./src/components/Button/index.ts"
  },
  "peerDependencies": {
    "react": "^18.0.0"
  },
  "devDependencies": {
    "@repo/config-typescript": "workspace:*"
  }
}
```

### 2. 設定パッケージ

```
packages/config/
├── eslint/
│   ├── base.js
│   ├── react.js
│   ├── next.js
│   └── package.json
├── typescript/
│   ├── base.json
│   ├── react.json
│   ├── next.json
│   └── package.json
└── tailwind/
    ├── tailwind.config.js
    └── package.json
```

```json
// packages/config/typescript/package.json
{
  "name": "@repo/config-typescript",
  "version": "0.0.0",
  "private": true,
  "files": ["*.json"]
}
```

```json
// apps/web/tsconfig.json
{
  "extends": "@repo/config-typescript/next.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src", "next-env.d.ts"],
  "exclude": ["node_modules"]
}
```

### 3. 型定義パッケージ

```typescript
// packages/types/src/index.ts
export interface User {
  id: string
  email: string
  name: string
  createdAt: Date
}

export interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: string
}

export type UserRole = 'admin' | 'user' | 'guest'
```

### 4. ユーティリティパッケージ

```typescript
// packages/utils/src/index.ts
export * from './format'
export * from './validation'
export * from './date'

// packages/utils/src/format.ts
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('ja-JP', {
    style: 'currency',
    currency: 'JPY'
  }).format(amount)
}
```

### 5. データベースパッケージ（Prisma）

```
packages/database/
├── prisma/
│   ├── schema.prisma
│   └── migrations/
├── src/
│   ├── client.ts
│   └── index.ts
└── package.json
```

```typescript
// packages/database/src/client.ts
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' 
      ? ['query', 'error', 'warn'] 
      : ['error'],
  })

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma
}
```

## 依存関係の方向

```
apps/web
  ↓
packages/ui
  ↓
packages/utils
  ↓
packages/types
```

**重要**: 依存は常に上から下へ。循環依存は禁止。

## バージョン管理（Changesets）

```bash
# セットアップ
pnpm add -Dw @changesets/cli
pnpm changeset init

# 変更を記録
pnpm changeset

# バージョン更新
pnpm changeset version

# パブリッシュ
pnpm changeset publish
```

```json
// .changeset/config.json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [["@repo/ui", "@repo/utils"]],
  "access": "restricted",
  "baseBranch": "main",
  "updateInternalDependencies": "patch"
}
```

## パッケージ間のインポート

```typescript
// apps/web/src/pages/index.tsx
import { Button } from '@repo/ui'
import { formatCurrency } from '@repo/utils'
import type { User } from '@repo/types'

export default function Home() {
  return <Button>Click me</Button>
}
```

## TypeScript パス解決

```json
// tsconfig.json（ルート）
{
  "compilerOptions": {
    "paths": {
      "@repo/ui": ["./packages/ui/src"],
      "@repo/utils": ["./packages/utils/src"],
      "@repo/types": ["./packages/types/src"]
    }
  }
}
```

## ベストプラクティス

1. **小さく保つ** - パッケージは単一責任
2. **明確なエクスポート** - index.tsで公開APIを制御
3. **peer dependencies活用** - React等は重複を避ける
4. **private: true** - 内部パッケージは公開しない
5. **workspace:\*** - 内部依存はバージョン指定しない
6. **設定は共有** - eslint, tsconfig等は集約
