# マイクロサービス設計ガイド

## 採用判断基準

### 採用すべき場合

- チームが複数（3チーム以上）
- 独立したデプロイが必要
- 異なるスケーリング要件
- 技術スタックの多様性が必要
- 障害分離が重要

### 採用すべきでない場合

- 小規模チーム（5人以下）
- MVP/プロトタイプ段階
- ドメイン理解が不十分
- 運用体制が未整備

## サービス分割パターン

### 境界づけられたコンテキストによる分割

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ 注文サービス │  │ 在庫サービス │  │ 配送サービス │
│             │  │             │  │             │
│ POST /orders│  │ GET /stock  │  │ POST /ship  │
│ GET /orders │  │ PUT /reserve│  │ GET /track  │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┴────────────────┘
                        │
              ┌─────────▼─────────┐
              │   メッセージバス    │
              │   (Kafka/SQS)     │
              └───────────────────┘
```

### 分割の原則

1. **高凝集** - 関連する機能は同じサービス
2. **低結合** - サービス間の依存を最小化
3. **ビジネス能力** - 技術ではなくビジネスで分割
4. **チーム境界** - コンウェイの法則を活用

## 通信パターン

### 同期通信（REST/gRPC）

```typescript
// APIゲートウェイ
import express from 'express'

const app = express()

app.post('/api/orders', async (req, res) => {
  // 1. 注文サービスに注文作成
  const order = await fetch('http://order-service/orders', {
    method: 'POST',
    body: JSON.stringify(req.body)
  }).then(r => r.json())

  // 2. 在庫サービスに在庫確認（同期）
  const stockCheck = await fetch(
    `http://inventory-service/stock/check`,
    {
      method: 'POST',
      body: JSON.stringify({ items: order.items })
    }
  ).then(r => r.json())

  if (!stockCheck.available) {
    return res.status(400).json({ error: 'Out of stock' })
  }

  return res.json(order)
})
```

### 非同期通信（イベント駆動）

```typescript
// 注文サービス - イベント発行
import { SNS } from '@aws-sdk/client-sns'

const sns = new SNS()

async function confirmOrder(orderId: string): Promise<void> {
  // 注文確定処理
  await db.orders.update({ where: { id: orderId }, data: { status: 'confirmed' } })

  // イベント発行
  await sns.publish({
    TopicArn: process.env.ORDER_EVENTS_TOPIC,
    Message: JSON.stringify({
      eventType: 'OrderConfirmed',
      orderId,
      timestamp: new Date().toISOString()
    })
  })
}

// 在庫サービス - イベント購読
import { SQSHandler } from 'aws-lambda'

export const handler: SQSHandler = async (event) => {
  for (const record of event.Records) {
    const message = JSON.parse(record.body)

    if (message.eventType === 'OrderConfirmed') {
      await reserveStock(message.orderId)
    }
  }
}
```

## データ管理

### Database per Service

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ 注文サービス │     │ 在庫サービス │     │ 顧客サービス │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
   ┌───▼───┐           ┌───▼───┐           ┌───▼───┐
   │Order  │           │Stock  │           │Customer│
   │ DB    │           │ DB    │           │ DB     │
   └───────┘           └───────┘           └───────┘
```

### Sagaパターン（分散トランザクション）

```typescript
// Choreography-based Saga
// 各サービスがイベントを発行し、次のサービスが反応

// 注文サービス
class OrderService {
  async createOrder(data: CreateOrderDto): Promise<Order> {
    const order = await this.orderRepo.create(data)

    // イベント発行 → 在庫サービスが購読
    await this.eventBus.publish(new OrderCreated(order))

    return order
  }

  // 補償トランザクション
  async handleStockReservationFailed(event: StockReservationFailed) {
    await this.orderRepo.updateStatus(event.orderId, 'cancelled')
  }
}

// 在庫サービス
class InventoryService {
  async handleOrderCreated(event: OrderCreated) {
    try {
      await this.reserveStock(event.items)
      await this.eventBus.publish(new StockReserved(event.orderId))
    } catch (error) {
      // 失敗時は補償イベント
      await this.eventBus.publish(new StockReservationFailed(event.orderId))
    }
  }
}
```

### CQRS（コマンドクエリ責務分離）

```typescript
// コマンド側（書き込み）
class OrderCommandService {
  constructor(private orderRepo: OrderRepository) {}

  async createOrder(command: CreateOrderCommand): Promise<string> {
    const order = new Order(command)
    await this.orderRepo.save(order)

    // 読み取り側に非同期で反映
    await this.eventBus.publish(new OrderCreated(order))

    return order.id
  }
}

// クエリ側（読み取り）
class OrderQueryService {
  constructor(private readDb: ReadDatabase) {}

  async getOrderSummary(orderId: string): Promise<OrderSummary> {
    // 読み取り専用DBから取得（非正規化データ）
    return this.readDb.orderSummaries.findOne({ orderId })
  }

  async searchOrders(filters: OrderFilters): Promise<OrderSummary[]> {
    return this.readDb.orderSummaries.find(filters)
  }
}

// プロジェクション（イベントから読み取りモデルを構築）
class OrderProjection {
  async handleOrderCreated(event: OrderCreated): Promise<void> {
    await this.readDb.orderSummaries.insert({
      orderId: event.orderId,
      customerName: event.customerName,
      totalAmount: event.totalAmount,
      status: 'created',
      createdAt: event.timestamp
    })
  }
}
```

## サービス間通信のレジリエンス

### サーキットブレーカー

```typescript
import CircuitBreaker from 'opossum'

const options = {
  timeout: 3000,           // タイムアウト
  errorThresholdPercentage: 50,  // エラー率閾値
  resetTimeout: 30000      // リセットまでの時間
}

const breaker = new CircuitBreaker(callExternalService, options)

breaker.fallback(() => {
  return { cached: true, data: getCachedData() }
})

breaker.on('open', () => console.log('Circuit opened'))
breaker.on('halfOpen', () => console.log('Circuit half-open'))
breaker.on('close', () => console.log('Circuit closed'))

async function getInventory(productId: string) {
  return breaker.fire(productId)
}
```

### リトライとタイムアウト

```typescript
import retry from 'async-retry'

async function callWithRetry<T>(fn: () => Promise<T>): Promise<T> {
  return retry(
    async (bail, attempt) => {
      try {
        return await fn()
      } catch (error) {
        // リトライ不可能なエラーは即座に失敗
        if (error.status === 404) {
          bail(error)
        }
        throw error
      }
    },
    {
      retries: 3,
      factor: 2,        // 指数バックオフ
      minTimeout: 1000,
      maxTimeout: 5000
    }
  )
}
```

## サービスメッシュ

### Istio設定例

```yaml
# VirtualService
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts:
    - order-service
  http:
    - timeout: 5s
      retries:
        attempts: 3
        perTryTimeout: 2s
      route:
        - destination:
            host: order-service
            port:
              number: 80

# DestinationRule（サーキットブレーカー）
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: order-service
spec:
  host: order-service
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

## 監視とトレーシング

### 分散トレーシング（OpenTelemetry）

```typescript
import { trace, SpanKind } from '@opentelemetry/api'

const tracer = trace.getTracer('order-service')

async function processOrder(orderId: string) {
  return tracer.startActiveSpan(
    'processOrder',
    { kind: SpanKind.SERVER },
    async (span) => {
      try {
        span.setAttribute('order.id', orderId)

        // 子スパンを作成
        const result = await tracer.startActiveSpan(
          'validateOrder',
          async (childSpan) => {
            const valid = await validateOrder(orderId)
            childSpan.setAttribute('order.valid', valid)
            childSpan.end()
            return valid
          }
        )

        span.setStatus({ code: SpanStatusCode.OK })
        return result
      } catch (error) {
        span.recordException(error)
        span.setStatus({ code: SpanStatusCode.ERROR })
        throw error
      } finally {
        span.end()
      }
    }
  )
}
```

## ベストプラクティス

1. **小さく始める** - モノリスから段階的に分割
2. **API First** - 契約を先に定義
3. **自動化必須** - CI/CD、インフラ自動化
4. **監視重視** - ログ、メトリクス、トレース
5. **障害を前提** - サーキットブレーカー、リトライ
6. **データ整合性** - 結果整合性を受け入れる
