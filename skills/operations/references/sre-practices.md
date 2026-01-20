# SRE 実践ガイド

## SLI/SLO/SLA 定義

### 用語
- **SLI** (Service Level Indicator): 測定可能な指標
- **SLO** (Service Level Objective): 目標値
- **SLA** (Service Level Agreement): 顧客との契約

### SLI の種類

| カテゴリ | SLI | 計算式 |
|----------|-----|--------|
| 可用性 | リクエスト成功率 | 成功リクエスト / 全リクエスト |
| レイテンシー | p99レイテンシー | 99パーセンタイルの応答時間 |
| スループット | 処理能力 | リクエスト/秒 |
| エラー率 | エラー発生率 | エラー数 / 全リクエスト |
| 鮮度 | データ更新頻度 | 最終更新からの経過時間 |

### SLO 設定例

```yaml
# slo.yaml
services:
  - name: api-gateway
    slos:
      - name: availability
        description: "API の可用性"
        sli:
          type: availability
          good_events: "http_requests_total{status!~'5..'}"
          total_events: "http_requests_total"
        objective: 99.9  # 99.9%
        window: 30d      # 30日間

      - name: latency
        description: "API のレイテンシー"
        sli:
          type: latency
          threshold: 500ms
          percentile: 99
        objective: 99    # p99 が 500ms 以下であること
        window: 30d

  - name: payment-service
    slos:
      - name: availability
        description: "決済処理の可用性"
        sli:
          type: availability
        objective: 99.99  # 99.99% (より厳格)
        window: 30d
```

## エラーバジェット

### 計算方法

```
月間エラーバジェット = (1 - SLO) × 月間リクエスト数

例: SLO 99.9%, 月間100万リクエストの場合
エラーバジェット = (1 - 0.999) × 1,000,000 = 1,000 エラー
```

### エラーバジェットポリシー

```markdown
## エラーバジェット残量に応じたアクション

### 残量 > 50%
- 通常の開発を継続
- 新機能のデプロイ可能

### 残量 25-50%
- リスクの高い変更は慎重に
- 変更時のモニタリング強化

### 残量 10-25%
- 新機能開発を一時停止
- 安定性向上に集中
- すべての変更にシニアレビュー必須

### 残量 < 10%
- 緊急の修正以外のデプロイ停止
- 根本原因分析を優先
- インシデント対応モード

### バジェット枯渇
- 全デプロイ停止
- 信頼性改善タスクのみ実行
- 経営層へのエスカレーション
```

### エラーバジェット追跡

```typescript
// Prometheus クエリ
const errorBudgetRemaining = `
  1 - (
    sum(increase(http_requests_total{status=~"5.."}[30d])) /
    sum(increase(http_requests_total[30d]))
  ) / (1 - 0.999)  // SLO: 99.9%
`

// Grafana パネル設定
{
  "title": "Error Budget Remaining",
  "type": "gauge",
  "targets": [{
    "expr": errorBudgetRemaining
  }],
  "thresholds": {
    "steps": [
      { "value": 0,   "color": "red" },
      { "value": 0.25, "color": "orange" },
      { "value": 0.5,  "color": "yellow" },
      { "value": 0.75, "color": "green" }
    ]
  }
}
```

## トイル削減

### トイルの定義
- 手動作業
- 繰り返し発生
- 自動化可能
- 戦術的（長期的価値なし）
- サービススケールに比例

### トイル追跡

```markdown
## 週次トイルレポート

| タスク | 頻度 | 時間/回 | 合計時間 | 自動化可能性 |
|--------|------|---------|----------|-------------|
| 手動デプロイ | 5回 | 30分 | 2.5時間 | 高 |
| ログ調査 | 10回 | 15分 | 2.5時間 | 中 |
| 証明書更新 | 1回 | 1時間 | 1時間 | 高 |
| 権限付与 | 3回 | 10分 | 30分 | 高 |

**合計トイル時間**: 6.5時間/週
**トイル率**: 16% (目標: < 50%)
```

### 自動化優先度

```
優先度 = (頻度 × 時間 × 自動化容易さ) / 開発コスト

高優先度:
1. 証明書更新 → Let's Encrypt + cert-manager
2. 手動デプロイ → CI/CDパイプライン
3. 権限付与 → セルフサービスポータル
```

## カオスエンジニアリング

### 基本原則
1. 定常状態の仮説を立てる
2. 現実世界のイベントを模擬
3. 本番環境で実験
4. 爆発半径を限定
5. 自動化して継続的に実行

### 実験例

```yaml
# chaos-experiment.yaml (LitmusChaos)
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosExperiment
metadata:
  name: pod-delete
spec:
  definition:
    scope: Namespaced
    permissions:
      - apiGroups: [""]
        resources: ["pods"]
        verbs: ["delete"]
    args:
      - -c
      - ./experiments/pod-delete
    env:
      - name: TOTAL_CHAOS_DURATION
        value: '30'
      - name: CHAOS_INTERVAL
        value: '10'
      - name: FORCE
        value: 'false'
```

### ゲームデイ

```markdown
## ゲームデイ計画書

**日時**: YYYY-MM-DD HH:MM
**参加者**: [チームメンバー]
**対象システム**: [サービス名]

### シナリオ
1. **シナリオ1**: データベース接続障害
   - 実験: DBへの接続をブロック
   - 期待: サーキットブレーカーが作動、キャッシュからフォールバック

2. **シナリオ2**: 高負荷
   - 実験: 通常の10倍のトラフィック
   - 期待: オートスケーリングで対応

### 安全措置
- ロールバック手順を準備
- モニタリングを強化
- 顧客影響が発生した場合は即時中止

### 結果記録
[実験後に記入]
```

## 容量計画

### 使用率ベースの計画

```python
# 容量計画計算
current_usage = 70  # 現在のCPU使用率%
growth_rate = 0.1   # 月間成長率10%
target_usage = 50   # 目標使用率%
lead_time = 2       # リードタイム（月）

# N ヶ月後の必要容量
def capacity_needed(months):
    return current_usage * (1 + growth_rate) ** months

# スケールアウトが必要な時期
months_until_scale = 0
while capacity_needed(months_until_scale) < target_usage:
    months_until_scale += 1

# リードタイムを考慮した発注タイミング
order_time = months_until_scale - lead_time
```

### 容量レポート

```markdown
## 月次容量レポート

### 現在の使用状況
| リソース | 現在 | 上限 | 使用率 |
|----------|------|------|--------|
| CPU | 70 cores | 100 cores | 70% |
| Memory | 280 GB | 400 GB | 70% |
| Storage | 2 TB | 5 TB | 40% |
| DB接続 | 80 | 100 | 80% |

### 予測
| 期間 | CPU使用率予測 | アクション |
|------|--------------|-----------|
| +1ヶ月 | 77% | 監視継続 |
| +3ヶ月 | 93% | スケールアウト必要 |
| +6ヶ月 | 113% | 容量不足 |

### 推奨アクション
1. 2ヶ月以内にCPUを50%増強
2. DB接続プール最適化を検討
```

## ベストプラクティス

1. **測定から始める** - SLI/SLOを定義してから最適化
2. **自動化を優先** - トイルを50%以下に抑える
3. **エラーバジェットを活用** - 信頼性と速度のバランス
4. **ポストモーテムを学習に** - 非難なし、改善に集中
5. **カオスを取り入れる** - 障害に強いシステムを構築
6. **容量を先読み** - 問題が起きる前に対処
