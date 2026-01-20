---
name: terraform
description: Terraform/IaCワークフロー。インフラ変更、モジュール設計、ステート管理、CI/CDパイプライン統合時に使用。
---

# Terraform ワークフロー

Infrastructure as Code (IaC) のベストプラクティスとワークフロー。

## 有効化するタイミング

- 新しいインフラリソースの作成
- 既存インフラの変更
- Terraformモジュールの設計
- ステート管理の設定
- CI/CDパイプラインでのインフラ自動化

## 標準ワークフロー

```
1. terraform fmt     # コードフォーマット
2. terraform validate # 構文検証
3. terraform plan    # 変更プレビュー
4. (レビュー)         # 変更内容を確認
5. terraform apply   # 変更適用
```

## ディレクトリ構造

```
infrastructure/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
├── modules/
│   ├── networking/
│   ├── compute/
│   └── database/
└── shared/
    └── backend.tf
```

## 重要なルール

1. **ステートは常にリモート** - S3/GCS + DynamoDB/GCS lockingを使用
2. **シークレットはコードに含めない** - 環境変数またはSecrets Manager
3. **モジュール化** - 再利用可能なモジュールで DRY を維持
4. **バージョン固定** - プロバイダとモジュールのバージョンをロック
5. **plan出力を保存** - `terraform plan -out=plan.tfplan`
6. **PRベースの変更** - 直接applyしない、必ずレビュー

## クイックチェックリスト

- [ ] `terraform fmt` 実行済み
- [ ] `terraform validate` 成功
- [ ] `.tfvars` がgitignoreに含まれている
- [ ] バックエンド設定済み（リモートステート）
- [ ] プロバイダバージョン固定
- [ ] センシティブな出力に `sensitive = true`

## 詳細リファレンス

モジュール設計、ステート管理、CI/CD統合の詳細:
- `references/module-patterns.md` - モジュール設計パターン
- `references/state-management.md` - ステート管理ガイド
- `references/cicd-integration.md` - CI/CDパイプライン統合
- `references/security-checklist.md` - セキュリティチェックリスト
