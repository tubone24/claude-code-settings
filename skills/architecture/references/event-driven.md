# イベント駆動アーキテクチャ

## 基本概念

### イベントの種類

| 種類 | 説明 | 例 |
|------|------|-----|
| **ドメインイベント** | ビジネス上の出来事 | OrderPlaced, PaymentReceived |
| **統合イベント** | サービス間通信用 | OrderCreatedIntegrationEvent |
| **コマンド** | 処理の要求 | PlaceOrder, ProcessPayment |

### 基本パターン

```
┌──────────┐    イベント    ┌──────────┐
│ Producer │ ──────────→ │ Consumer │
└──────────┘              └──────────┘

┌──────────┐              ┌──────────┐
│ Producer │              │ Consumer │
└────┬─────┘              └────┬─────┘
     │                         │
     ▼                         ▼
┌────────────────────────────────────┐
│          Message Broker            │
│     (Kafka / SQS / EventBridge)    │
└────────────────────────────────────┘
```

## 実装パターン

### イベント定義

```typescript
// 基底イベント
export interface DomainEvent {
  eventId: string
  eventType: string
  aggregateId: string
  aggregateType: string
  occurredAt: Date
  version: number
  payload: Record<string, unknown>
}

// 具体的なイベント
export class OrderPlaced implements DomainEvent {
  eventType = 'OrderPlaced'
  aggregateType = 'Order'

  constructor(
    public readonly eventId: string,
    public readonly aggregateId: string,
    public readonly occurredAt: Date,
    public readonly version: number,
    public readonly payload: {
      customerId: string
      items: Array<{ productId: string; quantity: number }>
      totalAmount: number
    }
  ) {}
}
```

### イベントストア

```typescript
interface EventStore {
  append(aggregateId: string, events: DomainEvent[]): Promise<void>
  getEvents(aggregateId: string, fromVersion?: number): Promise<DomainEvent[]>
}

class PostgresEventStore implements EventStore {
  constructor(private db: PrismaClient) {}

  async append(aggregateId: string, events: DomainEvent[]): Promise<void> {
    await this.db.$transaction(async (tx) => {
      for (const event of events) {
        await tx.eventStore.create({
          data: {
            eventId: event.eventId,
            eventType: event.eventType,
            aggregateId: event.aggregateId,
            aggregateType: event.aggregateType,
            version: event.version,
            payload: event.payload as any,
            occurredAt: event.occurredAt
          }
        })
      }
    })
  }

  async getEvents(aggregateId: string, fromVersion = 0): Promise<DomainEvent[]> {
    const events = await this.db.eventStore.findMany({
      where: {
        aggregateId,
        version: { gte: fromVersion }
      },
      orderBy: { version: 'asc' }
    })

    return events.map(this.toDomainEvent)
  }

  private toDomainEvent(record: any): DomainEvent {
    return {
      eventId: record.eventId,
      eventType: record.eventType,
      aggregateId: record.aggregateId,
      aggregateType: record.aggregateType,
      version: record.version,
      payload: record.payload,
      occurredAt: record.occurredAt
    }
  }
}
```

### イベントソーシング

```typescript
// イベントから状態を再構築
abstract class EventSourcedAggregate {
  private _version = 0
  private _uncommittedEvents: DomainEvent[] = []

  get version(): number {
    return this._version
  }

  get uncommittedEvents(): DomainEvent[] {
    return [...this._uncommittedEvents]
  }

  protected apply(event: DomainEvent): void {
    this.when(event)
    this._version = event.version
    this._uncommittedEvents.push(event)
  }

  loadFromHistory(events: DomainEvent[]): void {
    for (const event of events) {
      this.when(event)
      this._version = event.version
    }
  }

  clearUncommittedEvents(): void {
    this._uncommittedEvents = []
  }

  protected abstract when(event: DomainEvent): void
}

// 注文集約
class Order extends EventSourcedAggregate {
  private _id!: string
  private _status!: string
  private _items: OrderItem[] = []
  private _totalAmount!: number

  get id(): string { return this._id }
  get status(): string { return this._status }
  get items(): readonly OrderItem[] { return this._items }

  static create(id: string, customerId: string, items: OrderItem[]): Order {
    const order = new Order()
    const totalAmount = items.reduce((sum, item) => sum + item.price * item.quantity, 0)

    order.apply(new OrderPlaced(
      crypto.randomUUID(),
      id,
      new Date(),
      1,
      { customerId, items, totalAmount }
    ))

    return order
  }

  confirm(): void {
    if (this._status !== 'pending') {
      throw new Error('Can only confirm pending orders')
    }

    this.apply(new OrderConfirmed(
      crypto.randomUUID(),
      this._id,
      new Date(),
      this._version + 1,
      {}
    ))
  }

  protected when(event: DomainEvent): void {
    switch (event.eventType) {
      case 'OrderPlaced':
        this._id = event.aggregateId
        this._status = 'pending'
        this._items = event.payload.items as OrderItem[]
        this._totalAmount = event.payload.totalAmount as number
        break
      case 'OrderConfirmed':
        this._status = 'confirmed'
        break
    }
  }
}
```

### イベントバス

```typescript
// インメモリイベントバス
type EventHandler<T extends DomainEvent> = (event: T) => Promise<void>

class InMemoryEventBus {
  private handlers = new Map<string, EventHandler<any>[]>()

  subscribe<T extends DomainEvent>(
    eventType: string,
    handler: EventHandler<T>
  ): void {
    const handlers = this.handlers.get(eventType) || []
    handlers.push(handler)
    this.handlers.set(eventType, handlers)
  }

  async publish(event: DomainEvent): Promise<void> {
    const handlers = this.handlers.get(event.eventType) || []

    await Promise.all(
      handlers.map(handler => handler(event))
    )
  }
}

// AWS EventBridge
import { EventBridgeClient, PutEventsCommand } from '@aws-sdk/client-eventbridge'

class EventBridgeEventBus {
  private client = new EventBridgeClient({})

  async publish(event: DomainEvent): Promise<void> {
    await this.client.send(new PutEventsCommand({
      Entries: [{
        Source: 'order-service',
        DetailType: event.eventType,
        Detail: JSON.stringify(event),
        EventBusName: 'default'
      }]
    }))
  }
}
```

### プロジェクション（読み取りモデル）

```typescript
// イベントから読み取りモデルを構築
class OrderSummaryProjection {
  constructor(private db: PrismaClient) {}

  async handle(event: DomainEvent): Promise<void> {
    switch (event.eventType) {
      case 'OrderPlaced':
        await this.handleOrderPlaced(event)
        break
      case 'OrderConfirmed':
        await this.handleOrderConfirmed(event)
        break
      case 'OrderShipped':
        await this.handleOrderShipped(event)
        break
    }
  }

  private async handleOrderPlaced(event: DomainEvent): Promise<void> {
    await this.db.orderSummary.create({
      data: {
        orderId: event.aggregateId,
        customerId: event.payload.customerId as string,
        totalAmount: event.payload.totalAmount as number,
        status: 'pending',
        itemCount: (event.payload.items as any[]).length,
        createdAt: event.occurredAt
      }
    })
  }

  private async handleOrderConfirmed(event: DomainEvent): Promise<void> {
    await this.db.orderSummary.update({
      where: { orderId: event.aggregateId },
      data: {
        status: 'confirmed',
        confirmedAt: event.occurredAt
      }
    })
  }

  private async handleOrderShipped(event: DomainEvent): Promise<void> {
    await this.db.orderSummary.update({
      where: { orderId: event.aggregateId },
      data: {
        status: 'shipped',
        shippedAt: event.occurredAt
      }
    })
  }
}
```

## メッセージング基盤

### Kafka

```typescript
import { Kafka, Producer, Consumer } from 'kafkajs'

class KafkaEventBus {
  private kafka: Kafka
  private producer: Producer
  private consumer: Consumer

  constructor() {
    this.kafka = new Kafka({
      clientId: 'order-service',
      brokers: ['localhost:9092']
    })
    this.producer = this.kafka.producer()
    this.consumer = this.kafka.consumer({ groupId: 'order-service-group' })
  }

  async publish(topic: string, event: DomainEvent): Promise<void> {
    await this.producer.send({
      topic,
      messages: [{
        key: event.aggregateId,
        value: JSON.stringify(event),
        headers: {
          eventType: event.eventType
        }
      }]
    })
  }

  async subscribe(
    topics: string[],
    handler: (event: DomainEvent) => Promise<void>
  ): Promise<void> {
    await this.consumer.subscribe({ topics, fromBeginning: false })

    await this.consumer.run({
      eachMessage: async ({ message }) => {
        const event = JSON.parse(message.value!.toString())
        await handler(event)
      }
    })
  }
}
```

### AWS SQS + SNS

```typescript
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns'
import { SQSHandler } from 'aws-lambda'

// パブリッシャー
class SnsEventPublisher {
  private sns = new SNSClient({})

  async publish(event: DomainEvent): Promise<void> {
    await this.sns.send(new PublishCommand({
      TopicArn: process.env.ORDER_EVENTS_TOPIC,
      Message: JSON.stringify(event),
      MessageAttributes: {
        eventType: {
          DataType: 'String',
          StringValue: event.eventType
        }
      }
    }))
  }
}

// サブスクライバー（Lambda）
export const handler: SQSHandler = async (sqsEvent) => {
  for (const record of sqsEvent.Records) {
    const snsMessage = JSON.parse(record.body)
    const event: DomainEvent = JSON.parse(snsMessage.Message)

    await processEvent(event)
  }
}
```

## 信頼性パターン

### アウトボックスパターン

```typescript
// トランザクション内でイベントを保存
async function placeOrder(data: CreateOrderDto): Promise<Order> {
  return await db.$transaction(async (tx) => {
    // 注文を保存
    const order = await tx.order.create({ data })

    // アウトボックスにイベントを保存（同じトランザクション）
    await tx.outbox.create({
      data: {
        eventType: 'OrderPlaced',
        aggregateId: order.id,
        payload: { orderId: order.id, items: data.items },
        status: 'pending'
      }
    })

    return order
  })
}

// 別プロセスでアウトボックスをポーリング
async function publishOutboxEvents(): Promise<void> {
  const events = await db.outbox.findMany({
    where: { status: 'pending' },
    take: 100
  })

  for (const event of events) {
    try {
      await eventBus.publish(event)
      await db.outbox.update({
        where: { id: event.id },
        data: { status: 'published' }
      })
    } catch (error) {
      console.error('Failed to publish event', event.id, error)
    }
  }
}
```

### 冪等性

```typescript
// 処理済みイベントを記録
async function handleEvent(event: DomainEvent): Promise<void> {
  // 既に処理済みかチェック
  const processed = await db.processedEvent.findUnique({
    where: { eventId: event.eventId }
  })

  if (processed) {
    console.log('Event already processed', event.eventId)
    return
  }

  // イベント処理（トランザクション内）
  await db.$transaction(async (tx) => {
    await processEventLogic(event, tx)

    // 処理済みとして記録
    await tx.processedEvent.create({
      data: { eventId: event.eventId, processedAt: new Date() }
    })
  })
}
```

## ベストプラクティス

1. **イベントはイミュータブル** - 一度発行したら変更しない
2. **冪等性を確保** - 同じイベントを複数回処理しても安全に
3. **アウトボックスパターン** - 確実な配信を保証
4. **バージョニング** - イベントスキーマの互換性を維持
5. **モニタリング** - 遅延、エラー率を監視
6. **デッドレターキュー** - 処理失敗イベントを保存
