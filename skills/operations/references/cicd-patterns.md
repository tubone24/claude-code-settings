# CI/CD パターン集

## GitHub Actions 基本テンプレート

### Node.js/TypeScript プロジェクト

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-type-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v2
        with:
          version: 8

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm type-check

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v2
        with:
          version: 8

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - run: pnpm install --frozen-lockfile
      - run: pnpm test -- --coverage

      - uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  build:
    runs-on: ubuntu-latest
    needs: [lint-and-type-check, test]
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v2
        with:
          version: 8

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
```

### デプロイワークフロー

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Staging
        run: |
          # デプロイスクリプト
          echo "Deploying to staging..."

      - name: Smoke Test
        run: |
          curl -f https://staging.example.com/health

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Production
        run: |
          echo "Deploying to production..."

      - name: Verify Deployment
        run: |
          curl -f https://example.com/health
```

## デプロイ戦略

### ブルー/グリーン デプロイ

```yaml
deploy:
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to Green
      run: |
        gcloud run deploy myapp-green \
          --image gcr.io/project/myapp:${{ github.sha }}

    - name: Health Check Green
      run: |
        curl -f https://myapp-green-xxx.run.app/health

    - name: Switch Traffic
      run: |
        gcloud run services update-traffic myapp \
          --to-revisions myapp-green=100

    - name: Cleanup Blue
      run: |
        # 古いバージョンを削除（オプション）
        echo "Cleanup old revision"
```

### カナリアデプロイ

```yaml
deploy-canary:
  runs-on: ubuntu-latest
  steps:
    - name: Deploy Canary (10%)
      run: |
        gcloud run services update-traffic myapp \
          --to-revisions myapp-canary=10,myapp-stable=90

    - name: Monitor Canary
      run: |
        # エラー率をチェック
        sleep 300  # 5分待機
        ./scripts/check-error-rate.sh

    - name: Promote or Rollback
      run: |
        if [ "$ERROR_RATE" -lt "1" ]; then
          gcloud run services update-traffic myapp \
            --to-revisions myapp-canary=100
        else
          gcloud run services update-traffic myapp \
            --to-revisions myapp-stable=100
        fi
```

### ローリングデプロイ（Kubernetes）

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 追加できるPod数
      maxUnavailable: 0  # 停止できるPod数
  template:
    spec:
      containers:
        - name: myapp
          image: myapp:latest
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
```

## 環境管理

### 環境変数の管理

```yaml
# GitHub Environments を使用
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          ./deploy.sh
```

### マトリクスビルド

```yaml
jobs:
  test:
    strategy:
      matrix:
        node: [18, 20, 22]
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
```

## キャッシュ戦略

```yaml
- name: Cache pnpm store
  uses: actions/cache@v4
  with:
    path: |
      ~/.pnpm-store
      node_modules
    key: pnpm-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}
    restore-keys: |
      pnpm-${{ runner.os }}-

- name: Cache Next.js
  uses: actions/cache@v4
  with:
    path: .next/cache
    key: nextjs-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}-${{ hashFiles('**/*.ts', '**/*.tsx') }}
    restore-keys: |
      nextjs-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}-
      nextjs-${{ runner.os }}-
```

## ロールバック

```yaml
rollback:
  runs-on: ubuntu-latest
  if: failure()
  needs: deploy
  steps:
    - name: Rollback
      run: |
        gcloud run services update-traffic myapp \
          --to-revisions LATEST=0,PREVIOUS=100

    - name: Notify
      uses: slackapi/slack-github-action@v1
      with:
        payload: |
          {
            "text": "Deployment failed, rolled back to previous version"
          }
```

## ベストプラクティス

1. **高速フィードバック** - lint/type-checkは並列実行
2. **キャッシュ活用** - 依存関係、ビルド成果物
3. **環境分離** - staging → production
4. **自動ロールバック** - 失敗時の復旧
5. **承認ゲート** - 本番デプロイは手動承認
6. **通知** - Slack/Teams連携
