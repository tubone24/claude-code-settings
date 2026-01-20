---
name: architecture
description: アプリケーションアーキテクチャ設計。DDD、クリーンアーキテクチャ、マイクロサービス、イベント駆動設計時に使用。
---

# アプリケーションアーキテクチャ

スケーラブルで保守性の高いアプリケーション設計のためのパターンとガイドライン。

## 有効化するタイミング

- 新規プロジェクトのアーキテクチャ設計
- レイヤー構造の決定
- ドメインモデルの設計
- サービス分割の検討
- 技術的負債の解消

## アーキテクチャスタイル

| スタイル | 適用場面 |
|----------|----------|
| **レイヤードアーキテクチャ** | シンプルなCRUDアプリ |
| **クリーンアーキテクチャ** | ビジネスロジックが複雑 |
| **DDD** | 複雑なドメイン、長期運用 |
| **マイクロサービス** | 大規模、チーム分割 |
| **イベント駆動** | 非同期処理、疎結合 |

## クリーンアーキテクチャ基本構造

```
src/
├── domain/          # ビジネスルール（依存なし）
│   ├── entities/
│   └── value-objects/
├── application/     # ユースケース
│   ├── use-cases/
│   └── ports/       # インターフェース
├── infrastructure/  # 外部サービス実装
│   ├── repositories/
│   └── services/
└── presentation/    # UI/API
    ├── controllers/
    └── views/
```

## 依存方向ルール

```
presentation → application → domain
      ↓              ↓
infrastructure ← (ports)
```

**重要**: 依存は常に内側（domain）に向かう。domainは何にも依存しない。

## クイック設計チェックリスト

- [ ] ドメインロジックがインフラに依存していない
- [ ] 外部サービスはインターフェース経由
- [ ] ユースケースが単一責任
- [ ] エンティティがビジネスルールを持つ
- [ ] 値オブジェクトで不変性を確保

## 詳細リファレンス

- `references/clean-architecture.md` - クリーンアーキテクチャ詳細
- `references/ddd-patterns.md` - DDDパターン集
- `references/microservices.md` - マイクロサービス設計
- `references/event-driven.md` - イベント駆動アーキテクチャ
