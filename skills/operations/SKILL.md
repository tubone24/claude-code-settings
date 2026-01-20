---
name: operations
description: 運用スキル。CI/CD、モニタリング、アラート、インシデント対応、SRE実践時に使用。
---

# 運用スキル

本番環境の信頼性を維持するためのベストプラクティスとワークフロー。

## 有効化するタイミング

- CI/CDパイプラインの設計
- モニタリング/アラート設定
- インシデント対応
- SLO/SLI定義
- 障害対応プロセス構築

## 主要トピック

| 領域 | 内容 |
|------|------|
| **CI/CD** | ビルド、テスト、デプロイ自動化 |
| **モニタリング** | メトリクス、ログ、トレース |
| **アラート** | 閾値設定、オンコール |
| **インシデント対応** | 検知、対応、ポストモーテム |
| **SRE** | SLO、エラーバジェット |

## CI/CDパイプライン基本構成

```yaml
# PR時
lint → type-check → test → build → preview deploy

# main マージ時
lint → type-check → test → build → staging deploy → smoke test → prod deploy
```

## モニタリング4つの柱

1. **メトリクス** - CPU、メモリ、レイテンシー、エラー率
2. **ログ** - 構造化ログ、検索可能
3. **トレース** - 分散トレーシング、リクエストフロー
4. **アラート** - 閾値ベース、異常検知

## SLO/SLI 例

```
可用性 SLO: 99.9%（月間43分のダウンタイム許容）
レイテンシー SLO: p99 < 500ms
エラー率 SLO: < 0.1%
```

## インシデント対応フロー

```
検知 → トリアージ → 対応 → 復旧 → ポストモーテム
```

## 詳細リファレンス

- `references/cicd-patterns.md` - CI/CDパターン集
- `references/monitoring-setup.md` - モニタリング設定
- `references/incident-response.md` - インシデント対応
- `references/sre-practices.md` - SRE実践ガイド
