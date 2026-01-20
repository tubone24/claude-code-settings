# DDD（ドメイン駆動設計）パターン集

## 戦略的設計

### 境界づけられたコンテキスト

```
┌─────────────────┐  ┌─────────────────┐
│   注文コンテキスト  │  │  在庫コンテキスト  │
│                   │  │                   │
│  Order           │  │  Stock            │
│  OrderLine       │  │  Warehouse        │
│  Customer(ID)    │  │  Product          │
└─────────────────┘  └─────────────────┘
         │                    │
         └──────┬─────────────┘
                │
       ┌────────▼────────┐
       │  コンテキストマップ  │
       └─────────────────┘
```

### ユビキタス言語

```typescript
// ドメインエキスパートと同じ用語を使用
interface 注文 {
  注文ID: string
  顧客: 顧客ID
  注文明細: 注文明細[]
  合計金額: 金額
  
  確定する(): void
  キャンセルする(): void
}

// 英語でも同様
interface Order {
  orderId: string
  customer: CustomerId
  orderLines: OrderLine[]
  totalAmount: Money
  
  confirm(): void
  cancel(): void
}
```

## 戦術的設計

### エンティティ

識別子を持ち、ライフサイクルがある。

```typescript
export class Order {
  private _status: OrderStatus = 'draft'

  constructor(
    public readonly id: OrderId,
    public readonly customerId: CustomerId,
    private _lines: OrderLine[] = []
  ) {}

  get status(): OrderStatus {
    return this._status
  }

  get totalAmount(): Money {
    return this._lines.reduce(
      (sum, line) => sum.add(line.amount),
      Money.zero('JPY')
    )
  }

  addLine(product: ProductId, quantity: number, unitPrice: Money): void {
    if (this._status !== 'draft') {
      throw new Error('Cannot modify confirmed order')
    }
    this._lines.push(new OrderLine(product, quantity, unitPrice))
  }

  confirm(): void {
    if (this._lines.length === 0) {
      throw new Error('Cannot confirm empty order')
    }
    this._status = 'confirmed'
  }

  cancel(): void {
    if (this._status === 'shipped') {
      throw new Error('Cannot cancel shipped order')
    }
    this._status = 'cancelled'
  }
}
```

### 値オブジェクト

識別子を持たず、属性で比較。イミュータブル。

```typescript
export class Money {
  private constructor(
    public readonly amount: number,
    public readonly currency: string
  ) {
    if (amount < 0) {
      throw new Error('Amount cannot be negative')
    }
  }

  static create(amount: number, currency: string): Money {
    return new Money(amount, currency)
  }

  static zero(currency: string): Money {
    return new Money(0, currency)
  }

  add(other: Money): Money {
    this.ensureSameCurrency(other)
    return new Money(this.amount + other.amount, this.currency)
  }

  subtract(other: Money): Money {
    this.ensureSameCurrency(other)
    return new Money(this.amount - other.amount, this.currency)
  }

  multiply(factor: number): Money {
    return new Money(this.amount * factor, this.currency)
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency
  }

  private ensureSameCurrency(other: Money): void {
    if (this.currency !== other.currency) {
      throw new Error('Currency mismatch')
    }
  }
}

export class Address {
  private constructor(
    public readonly postalCode: string,
    public readonly prefecture: string,
    public readonly city: string,
    public readonly street: string
  ) {}

  static create(
    postalCode: string,
    prefecture: string,
    city: string,
    street: string
  ): Address {
    // バリデーション
    if (!/^\d{3}-\d{4}$/.test(postalCode)) {
      throw new Error('Invalid postal code format')
    }
    return new Address(postalCode, prefecture, city, street)
  }

  get fullAddress(): string {
    return `${this.postalCode} ${this.prefecture}${this.city}${this.street}`
  }
}
```

### 集約

一貫性境界。集約ルートを通じてのみ操作。

```typescript
// Order が集約ルート
export class Order {
  private _lines: OrderLine[] = []  // OrderLineは集約内部

  // OrderLineへの操作は必ずOrderを通じて行う
  addLine(product: ProductId, quantity: number, unitPrice: Money): void {
    // 不変条件を保証
    if (this._lines.length >= 100) {
      throw new Error('Maximum order lines exceeded')
    }
    this._lines.push(new OrderLine(product, quantity, unitPrice))
  }

  removeLine(index: number): void {
    if (index < 0 || index >= this._lines.length) {
      throw new Error('Invalid line index')
    }
    this._lines.splice(index, 1)
  }

  // 外部からは読み取り専用
  get lines(): readonly OrderLine[] {
    return [...this._lines]
  }
}

// OrderLineは集約外から直接操作しない
class OrderLine {
  constructor(
    public readonly productId: ProductId,
    public readonly quantity: number,
    public readonly unitPrice: Money
  ) {}

  get amount(): Money {
    return this.unitPrice.multiply(this.quantity)
  }
}
```

### リポジトリ

集約の永続化を抽象化。

```typescript
export interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>
  findByCustomer(customerId: CustomerId): Promise<Order[]>
  save(order: Order): Promise<void>
  delete(id: OrderId): Promise<void>
}

// 集約単位で保存（部分保存はしない）
export class PostgresOrderRepository implements OrderRepository {
  async save(order: Order): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      // 集約全体をアトミックに保存
      await tx.order.upsert({
        where: { id: order.id.value },
        update: { status: order.status },
        create: {
          id: order.id.value,
          customerId: order.customerId.value,
          status: order.status
        }
      })

      // 既存の明細を削除して再作成
      await tx.orderLine.deleteMany({
        where: { orderId: order.id.value }
      })

      await tx.orderLine.createMany({
        data: order.lines.map((line, index) => ({
          orderId: order.id.value,
          lineNumber: index,
          productId: line.productId.value,
          quantity: line.quantity,
          unitPrice: line.unitPrice.amount
        }))
      })
    })
  }
}
```

### ドメインサービス

エンティティに属さないビジネスロジック。

```typescript
export class PricingService {
  constructor(
    private discountPolicy: DiscountPolicy,
    private taxCalculator: TaxCalculator
  ) {}

  calculateFinalPrice(order: Order, customer: Customer): Money {
    const subtotal = order.totalAmount

    // 顧客ランクに応じた割引
    const discount = this.discountPolicy.calculate(subtotal, customer.rank)
    const afterDiscount = subtotal.subtract(discount)

    // 税金計算
    const tax = this.taxCalculator.calculate(afterDiscount)

    return afterDiscount.add(tax)
  }
}

export class TransferService {
  constructor(private accountRepository: AccountRepository) {}

  async transfer(
    fromId: AccountId,
    toId: AccountId,
    amount: Money
  ): Promise<void> {
    const from = await this.accountRepository.findById(fromId)
    const to = await this.accountRepository.findById(toId)

    if (!from || !to) {
      throw new Error('Account not found')
    }

    from.withdraw(amount)  // ビジネスルールはエンティティ内
    to.deposit(amount)

    await this.accountRepository.save(from)
    await this.accountRepository.save(to)
  }
}
```

### ドメインイベント

ドメインで起きた重要な出来事。

```typescript
export interface DomainEvent {
  readonly occurredAt: Date
  readonly eventType: string
}

export class OrderConfirmed implements DomainEvent {
  readonly eventType = 'OrderConfirmed'
  readonly occurredAt = new Date()

  constructor(
    public readonly orderId: OrderId,
    public readonly customerId: CustomerId,
    public readonly totalAmount: Money
  ) {}
}

// 集約からイベントを発行
export class Order {
  private _events: DomainEvent[] = []

  confirm(): void {
    if (this._lines.length === 0) {
      throw new Error('Cannot confirm empty order')
    }
    this._status = 'confirmed'

    // イベントを記録
    this._events.push(new OrderConfirmed(
      this.id,
      this.customerId,
      this.totalAmount
    ))
  }

  get events(): readonly DomainEvent[] {
    return this._events
  }

  clearEvents(): void {
    this._events = []
  }
}

// イベントハンドラー
export class OrderConfirmedHandler {
  constructor(
    private emailService: EmailService,
    private inventoryService: InventoryService
  ) {}

  async handle(event: OrderConfirmed): Promise<void> {
    // メール送信
    await this.emailService.sendOrderConfirmation(event.customerId, event.orderId)

    // 在庫予約
    await this.inventoryService.reserveStock(event.orderId)
  }
}
```

### ファクトリー

複雑なオブジェクト生成をカプセル化。

```typescript
export class OrderFactory {
  constructor(
    private idGenerator: IdGenerator,
    private pricingService: PricingService
  ) {}

  createFromCart(cart: Cart, customerId: CustomerId): Order {
    const orderId = new OrderId(this.idGenerator.generate())
    const order = new Order(orderId, customerId)

    for (const item of cart.items) {
      const unitPrice = this.pricingService.getPrice(item.productId)
      order.addLine(item.productId, item.quantity, unitPrice)
    }

    return order
  }
}
```

## ディレクトリ構成

```
src/
├── domain/
│   ├── order/
│   │   ├── Order.ts           # 集約ルート
│   │   ├── OrderLine.ts       # 集約内エンティティ
│   │   ├── OrderId.ts         # 識別子（値オブジェクト）
│   │   ├── OrderRepository.ts # リポジトリインターフェース
│   │   └── events/
│   │       └── OrderConfirmed.ts
│   ├── shared/
│   │   ├── Money.ts
│   │   └── Address.ts
│   └── services/
│       └── PricingService.ts
├── application/
│   └── order/
│       ├── ConfirmOrderUseCase.ts
│       └── CreateOrderUseCase.ts
└── infrastructure/
    └── persistence/
        └── PostgresOrderRepository.ts
```
