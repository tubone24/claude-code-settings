# Turborepo 設定ガイド

## 基本設定

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "lint": {
      "dependsOn": ["^lint"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**/*.tsx", "src/**/*.ts", "test/**/*.ts"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "type-check": {
      "dependsOn": ["^build"]
    }
  }
}
```

## pnpm-workspace.yaml

```yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

## ルートpackage.json

```json
{
  "name": "monorepo",
  "private": true,
  "scripts": {
    "build": "turbo build",
    "dev": "turbo dev",
    "lint": "turbo lint",
    "test": "turbo test",
    "type-check": "turbo type-check",
    "clean": "turbo clean && rm -rf node_modules"
  },
  "devDependencies": {
    "turbo": "^1.12.0"
  },
  "packageManager": "pnpm@8.14.0"
}
```

## 内部パッケージの参照

```json
// apps/web/package.json
{
  "name": "@repo/web",
  "dependencies": {
    "@repo/ui": "workspace:*",
    "@repo/utils": "workspace:*"
  }
}
```

## キャッシュ設定

### ローカルキャッシュ

```bash
# キャッシュの場所
node_modules/.cache/turbo

# キャッシュクリア
turbo clean
```

### リモートキャッシュ（Vercel）

```bash
# ログイン
npx turbo login

# リンク
npx turbo link

# 環境変数でも可
TURBO_TOKEN=xxx
TURBO_TEAM=your-team
```

### セルフホストリモートキャッシュ

```bash
# ducktape (OSS)
docker run -p 3000:3000 ducktape/cache

# turbo.json
{
  "remoteCache": {
    "signature": true
  }
}

# 環境変数
TURBO_API=http://localhost:3000
TURBO_TOKEN=your-token
```

## フィルタリング

```bash
# 特定パッケージのみ
turbo build --filter=@repo/web

# 依存関係を含む
turbo build --filter=@repo/web...

# 変更されたパッケージのみ
turbo build --filter=[origin/main]

# 特定パッケージを除外
turbo build --filter=!@repo/docs
```

## 並列実行制御

```bash
# 並列度を制限
turbo build --concurrency=4

# CPUコア数の50%
turbo build --concurrency=50%
```

## 環境変数

```json
// turbo.json
{
  "globalEnv": ["CI", "NODE_ENV"],
  "pipeline": {
    "build": {
      "env": ["DATABASE_URL", "API_KEY"]
    }
  }
}
```

## タスク依存関係

```json
{
  "pipeline": {
    // 自パッケージの依存パッケージのbuildを先に実行
    "build": {
      "dependsOn": ["^build"]
    },
    // 自パッケージのbuildを先に実行
    "test": {
      "dependsOn": ["build"]
    },
    // 依存関係なし（並列実行可能）
    "lint": {}
  }
}
```

## 出力設定

```json
{
  "pipeline": {
    "build": {
      "outputs": [
        "dist/**",
        ".next/**",
        "!.next/cache/**"  // 除外
      ]
    }
  }
}
```

## デバッグ

```bash
# 実行グラフを確認
turbo build --graph

# ドライラン
turbo build --dry-run

# 詳細ログ
turbo build --verbosity=2

# タスク情報を表示
turbo build --summarize
```

## よくある問題

### キャッシュが効かない

```bash
# 入力ファイルを確認
turbo build --dry-run=json | jq '.tasks[].inputs'

# グローバル依存を確認
turbo build --dry-run=json | jq '.globalCacheInputs'
```

### 循環依存

```bash
# 依存グラフを可視化
turbo build --graph=graph.png
```

### ビルド順序の問題

```json
// 明示的な依存を追加
{
  "pipeline": {
    "build": {
      "dependsOn": ["^build", "generate"]
    },
    "generate": {
      "outputs": ["src/generated/**"]
    }
  }
}
```
