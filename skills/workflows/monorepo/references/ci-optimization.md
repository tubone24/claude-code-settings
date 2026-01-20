# モノレポ CI/CD 最適化

## GitHub Actions with Turborepo

### 基本設定

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2  # 差分検出用

      - uses: pnpm/action-setup@v2
        with:
          version: 8

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build
        run: pnpm build

      - name: Lint
        run: pnpm lint

      - name: Test
        run: pnpm test
```

### リモートキャッシュ

```yaml
- name: Build with Remote Cache
  run: pnpm build
  env:
    TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
    TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```

### 変更されたパッケージのみビルド

```yaml
- name: Build affected packages
  run: pnpm turbo build --filter='[HEAD^1]'
```

## 高度な最適化

### マトリクス戦略

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      packages: ${{ steps.filter.outputs.changes }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            web:
              - 'apps/web/**'
            api:
              - 'apps/api/**'
            ui:
              - 'packages/ui/**'

  build:
    needs: detect-changes
    if: needs.detect-changes.outputs.packages != '[]'
    strategy:
      matrix:
        package: ${{ fromJson(needs.detect-changes.outputs.packages) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pnpm turbo build --filter=@repo/${{ matrix.package }}
```

### 依存関係キャッシュ

```yaml
- name: Cache Turbo
  uses: actions/cache@v4
  with:
    path: .turbo
    key: turbo-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}
    restore-keys: |
      turbo-${{ runner.os }}-

- name: Cache node_modules
  uses: actions/cache@v4
  with:
    path: |
      node_modules
      apps/*/node_modules
      packages/*/node_modules
    key: modules-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}
```

### 並列ジョブ

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint

  type-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm type-check

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm test

  build:
    needs: [lint, type-check, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
```

## デプロイ最適化

### 条件付きデプロイ

```yaml
deploy-web:
  needs: build
  if: |
    github.ref == 'refs/heads/main' &&
    contains(needs.build.outputs.affected, 'web')
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to Vercel
      run: vercel deploy --prod
      env:
        VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}

deploy-api:
  needs: build
  if: |
    github.ref == 'refs/heads/main' &&
    contains(needs.build.outputs.affected, 'api')
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to Cloud Run
      run: gcloud run deploy api --source apps/api
```

### Vercel モノレポ設定

```json
// apps/web/vercel.json
{
  "buildCommand": "cd ../.. && pnpm turbo build --filter=@repo/web",
  "installCommand": "cd ../.. && pnpm install",
  "framework": "nextjs",
  "outputDirectory": ".next"
}
```

## Nx との比較

### Turborepo

```bash
# 変更されたパッケージ
turbo build --filter='[HEAD^1]'

# 依存関係を含む
turbo build --filter=@repo/web...
```

### Nx

```bash
# 変更されたパッケージ
nx affected:build --base=HEAD^1

# 依存関係グラフ
nx graph
```

## パフォーマンス計測

```yaml
- name: Build with timing
  run: |
    start=$(date +%s)
    pnpm build
    end=$(date +%s)
    echo "Build time: $((end-start)) seconds"
```

## セキュリティスキャン

```yaml
security:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: pnpm install --frozen-lockfile
    - run: pnpm audit --audit-level=high
    - name: Run Trivy
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
```

## ベストプラクティス

1. **リモートキャッシュ活用** - CI時間を大幅短縮
2. **変更検出** - 影響を受けたパッケージのみ処理
3. **並列実行** - 独立したタスクは並列で
4. **依存関係キャッシュ** - node_modulesをキャッシュ
5. **条件付きデプロイ** - 変更があったアプリのみデプロイ
6. **セキュリティスキャン** - 定期的な脆弱性チェック
