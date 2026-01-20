---
name: monorepo
description: モノレポ設計とツール（Turborepo/Nx/pnpm workspace）。パッケージ構造、依存関係管理、ビルド最適化時に使用。
---

# モノレポ設計スキル

複数のパッケージ/アプリを単一リポジトリで管理するためのベストプラクティス。

## 有効化するタイミング

- 新しいモノレポの設計
- パッケージ構造の決定
- 依存関係の管理
- ビルドパイプラインの最適化
- CI/CDの設定

## 推奨ツール

| ツール | 用途 |
|--------|------|
| **Turborepo** | タスクランナー、キャッシング |
| **pnpm** | パッケージマネージャー |
| **Nx** | 大規模モノレポ、依存関係グラフ |
| **Changesets** | バージョン管理、リリース |

## 基本構造

```
monorepo/
├── apps/
│   ├── web/           # Next.jsアプリ
│   ├── api/           # バックエンドAPI
│   └── mobile/        # React Native
├── packages/
│   ├── ui/            # 共有UIコンポーネント
│   ├── config/        # 共有設定（eslint, tsconfig）
│   ├── utils/         # 共有ユーティリティ
│   └── types/         # 共有型定義
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

## クイックセットアップ

```bash
# Turborepo + pnpm
pnpm dlx create-turbo@latest

# 既存プロジェクトに追加
pnpm add -Dw turbo
```

## 重要なルール

1. **内部パッケージは `workspace:*`** - バージョン指定しない
2. **設定は共有パッケージに** - eslint, tsconfig等
3. **循環依存を避ける** - 一方向の依存のみ
4. **パッケージは単一責任** - 小さく保つ
5. **キャッシュを活用** - Turborepoのリモートキャッシュ

## 詳細リファレンス

- `references/turborepo-config.md` - Turborepo設定ガイド
- `references/package-structure.md` - パッケージ設計パターン
- `references/ci-optimization.md` - CI/CD最適化
