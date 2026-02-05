---
name: backend
description: バックエンド開発パターン。API設計、データベース最適化、認証、キャッシング、エラーハンドリングに使用。
---

# バックエンド開発パターン

スケーラブルなサーバーサイドアプリケーションのためのバックエンドアーキテクチャパターン。

## 有効化するタイミング

- API設計とエンドポイント作成
- データベースクエリ最適化
- 認証・認可の実装
- キャッシング戦略の設計
- エラーハンドリングの設計

## API設計パターン

### RESTful API構造

```typescript
GET    /api/markets                 # リソース一覧
GET    /api/markets/:id             # 単一リソース取得
POST   /api/markets                 # リソース作成
PUT    /api/markets/:id             # リソース置換
PATCH  /api/markets/:id             # リソース更新
DELETE /api/markets/:id             # リソース削除

// フィルタリング、ソート、ページネーション
GET /api/markets?status=active&sort=volume&limit=20&offset=0
```

### リポジトリパターン

```typescript
interface MarketRepository {
  findAll(filters?: MarketFilters): Promise<Market[]>
  findById(id: string): Promise<Market | null>
  create(data: CreateMarketDto): Promise<Market>
  update(id: string, data: UpdateMarketDto): Promise<Market>
  delete(id: string): Promise<void>
}

class SupabaseMarketRepository implements MarketRepository {
  async findAll(filters?: MarketFilters): Promise<Market[]> {
    let query = supabase.from('markets').select('*')
    if (filters?.status) query = query.eq('status', filters.status)
    if (filters?.limit) query = query.limit(filters.limit)
    const { data, error } = await query
    if (error) throw new Error(error.message)
    return data
  }
}
```

### ミドルウェアパターン

```typescript
export function withAuth(handler: NextApiHandler): NextApiHandler {
  return async (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '')
    if (!token) return res.status(401).json({ error: 'Unauthorized' })
    try {
      const user = await verifyToken(token)
      req.user = user
      return handler(req, res)
    } catch (error) {
      return res.status(401).json({ error: 'Invalid token' })
    }
  }
}
```

## データベースパターン

### N+1クエリ問題の防止

```typescript
// ❌ 悪い例: N+1クエリ問題
const markets = await getMarkets()
for (const market of markets) {
  market.creator = await getUser(market.creator_id)
}

// ✅ 良い例: バッチ取得
const markets = await getMarkets()
const creatorIds = markets.map(m => m.creator_id)
const creators = await getUsers(creatorIds)
const creatorMap = new Map(creators.map(c => [c.id, c]))
markets.forEach(market => {
  market.creator = creatorMap.get(market.creator_id)
})
```

### クエリ最適化

```typescript
// ✅ 必要なカラムのみ選択
const { data } = await supabase
  .from('markets')
  .select('id, name, status, volume')
  .eq('status', 'active')
  .order('volume', { ascending: false })
  .limit(10)
```

## キャッシング戦略

### Cache-Asideパターン

```typescript
async function getMarketWithCache(id: string): Promise<Market> {
  const cacheKey = `market:${id}`
  const cached = await redis.get(cacheKey)
  if (cached) return JSON.parse(cached)

  const market = await db.markets.findUnique({ where: { id } })
  if (!market) throw new Error('Market not found')

  await redis.setex(cacheKey, 300, JSON.stringify(market))
  return market
}
```

## エラーハンドリング

### 集中型エラーハンドラー

```typescript
class ApiError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public isOperational = true
  ) {
    super(message)
  }
}

export function errorHandler(error: unknown, req: Request): Response {
  if (error instanceof ApiError) {
    return NextResponse.json({
      success: false,
      error: error.message
    }, { status: error.statusCode })
  }

  if (error instanceof z.ZodError) {
    return NextResponse.json({
      success: false,
      error: 'Validation failed',
      details: error.errors
    }, { status: 400 })
  }

  return NextResponse.json({
    success: false,
    error: 'Internal server error'
  }, { status: 500 })
}
```

### 指数バックオフ付きリトライ

```typescript
async function fetchWithRetry<T>(fn: () => Promise<T>, maxRetries = 3): Promise<T> {
  let lastError: Error
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error as Error
      if (i < maxRetries - 1) {
        const delay = Math.pow(2, i) * 1000
        await new Promise(resolve => setTimeout(resolve, delay))
      }
    }
  }
  throw lastError!
}
```

## 認証と認可

### ロールベースアクセス制御

```typescript
const rolePermissions: Record<User['role'], Permission[]> = {
  admin: ['read', 'write', 'delete', 'admin'],
  moderator: ['read', 'write', 'delete'],
  user: ['read', 'write']
}

export function hasPermission(user: User, permission: Permission): boolean {
  return rolePermissions[user.role].includes(permission)
}
```

## レート制限

```typescript
class RateLimiter {
  private requests = new Map<string, number[]>()

  async checkLimit(identifier: string, maxRequests: number, windowMs: number): Promise<boolean> {
    const now = Date.now()
    const requests = this.requests.get(identifier) || []
    const recentRequests = requests.filter(time => now - time < windowMs)

    if (recentRequests.length >= maxRequests) return false

    recentRequests.push(now)
    this.requests.set(identifier, recentRequests)
    return true
  }
}
```
