# セキュリティツール一覧

## 静的解析（SAST）

### npm audit
```bash
# 脆弱性チェック
npm audit

# JSON出力
npm audit --json

# 高以上の重大度のみ
npm audit --audit-level=high

# 自動修正
npm audit fix
npm audit fix --force  # breaking changesを許容
```

### ESLint Security Plugin
```bash
npm install -D eslint-plugin-security
```

```json
// .eslintrc.json
{
  "plugins": ["security"],
  "extends": ["plugin:security/recommended"]
}
```

検出項目:
- `eval()` の使用
- 非リテラルの `require()`
- 非リテラルの `fs` 操作
- SQLインジェクションパターン
- オブジェクトインジェクション

### Semgrep
```bash
# インストール
pip install semgrep

# 実行
semgrep --config=auto .

# 特定ルールセット
semgrep --config=p/javascript .
semgrep --config=p/typescript .
semgrep --config=p/owasp-top-ten .
```

### tfsec（Terraform）
```bash
# インストール
brew install tfsec

# 実行
tfsec .

# JSON出力
tfsec . --format=json
```

### checkov（IaC全般）
```bash
# インストール
pip install checkov

# Terraform
checkov -d .

# CloudFormation
checkov -f template.yaml

# Kubernetes
checkov -f deployment.yaml
```

## 秘密情報検出

### git-secrets
```bash
# インストール
brew install git-secrets

# 初期設定
git secrets --install
git secrets --register-aws

# 全コミットをスキャン
git secrets --scan-history
```

### TruffleHog
```bash
# ファイルシステムをスキャン
trufflehog filesystem .

# Git履歴をスキャン
trufflehog git file://. --since-commit HEAD~10

# GitHub
trufflehog github --repo https://github.com/user/repo
```

### Gitleaks
```bash
# インストール
brew install gitleaks

# スキャン
gitleaks detect

# Git履歴
gitleaks detect --source . --verbose
```

## 依存関係スキャン（SCA）

### Snyk
```bash
# インストール
npm install -g snyk

# 認証
snyk auth

# テスト
snyk test

# 監視
snyk monitor
```

### OWASP Dependency-Check
```bash
# Docker経由で実行
docker run --rm \
  -v $(pwd):/src \
  owasp/dependency-check \
  --scan /src \
  --format HTML \
  --out /src/reports
```

## 動的解析（DAST）

### OWASP ZAP
```bash
# Docker
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t https://your-app.com

# APIスキャン
docker run -t owasp/zap2docker-stable zap-api-scan.py \
  -t https://your-app.com/openapi.json
```

### Nikto
```bash
nikto -h https://your-app.com
```

## コンテナセキュリティ

### Trivy
```bash
# イメージスキャン
trivy image myapp:latest

# ファイルシステムスキャン
trivy fs .

# Kubernetes
trivy k8s --report summary cluster
```

### Docker Scout
```bash
# イメージ分析
docker scout quickview myapp:latest

# CVE一覧
docker scout cves myapp:latest
```

## CI/CD統合

### GitHub Actions

```yaml
# .github/workflows/security.yml
name: Security Scan

on: [push, pull_request]

jobs:
  npm-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm audit --audit-level=high

  semgrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: returntocorp/semgrep-action@v1
        with:
          config: p/owasp-top-ten

  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'HIGH,CRITICAL'

  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 推奨ツールセット

### 最小構成
- `npm audit` - 依存関係
- `eslint-plugin-security` - コード品質
- `gitleaks` - 秘密情報

### 標準構成
上記に加えて:
- `semgrep` - 高度な静的解析
- `trivy` - コンテナ/IaC
- `snyk` - 継続的監視

### エンタープライズ構成
上記に加えて:
- `OWASP ZAP` - DAST
- `SonarQube` - コード品質管理
- `Checkmarx/Veracode` - 商用SAST
