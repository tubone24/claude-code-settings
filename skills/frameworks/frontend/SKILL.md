---
name: frontend
description: フロントエンド開発パターン。React、Next.js、状態管理、パフォーマンス最適化、UIベストプラクティスに使用。
---

# フロントエンド開発パターン

React、Next.js、およびパフォーマンスの高いユーザーインターフェースのためのモダンなフロントエンドパターン。

## 有効化するタイミング

- Reactコンポーネントの設計
- カスタムフックの作成
- 状態管理の実装
- パフォーマンス最適化
- Next.js App Routerの使用

## コンポーネントパターン

### 継承よりコンポジション

```typescript
interface CardProps {
  children: React.ReactNode
  variant?: 'default' | 'outlined'
}

export function Card({ children, variant = 'default' }: CardProps) {
  return <div className={`card card-${variant}`}>{children}</div>
}

export function CardHeader({ children }: { children: React.ReactNode }) {
  return <div className="card-header">{children}</div>
}

// 使用例
<Card>
  <CardHeader>Title</CardHeader>
  <CardBody>Content</CardBody>
</Card>
```

### 複合コンポーネント

```typescript
const TabsContext = createContext<TabsContextValue | undefined>(undefined)

export function Tabs({ children, defaultTab }: Props) {
  const [activeTab, setActiveTab] = useState(defaultTab)
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      {children}
    </TabsContext.Provider>
  )
}

export function Tab({ id, children }: { id: string, children: React.ReactNode }) {
  const context = useContext(TabsContext)
  if (!context) throw new Error('Tab must be used within Tabs')
  return (
    <button
      className={context.activeTab === id ? 'active' : ''}
      onClick={() => context.setActiveTab(id)}
    >
      {children}
    </button>
  )
}
```

## カスタムフックパターン

### デバウンスフック

```typescript
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value)

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedValue(value), delay)
    return () => clearTimeout(handler)
  }, [value, delay])

  return debouncedValue
}
```

### トグルフック

```typescript
export function useToggle(initial = false): [boolean, () => void] {
  const [value, setValue] = useState(initial)
  const toggle = useCallback(() => setValue(v => !v), [])
  return [value, toggle]
}
```

## パフォーマンス最適化

### メモ化

```typescript
// 高コストな計算にはuseMemo
const sortedMarkets = useMemo(() => {
  return markets.sort((a, b) => b.volume - a.volume)
}, [markets])

// 子に渡す関数にはuseCallback
const handleSearch = useCallback((query: string) => {
  setSearchQuery(query)
}, [])

// 純粋なコンポーネントにはReact.memo
export const MarketCard = React.memo<Props>(({ market }) => {
  return <div>{market.name}</div>
})
```

### コード分割と遅延読み込み

```typescript
const HeavyChart = lazy(() => import('./HeavyChart'))

export function Dashboard() {
  return (
    <Suspense fallback={<ChartSkeleton />}>
      <HeavyChart data={data} />
    </Suspense>
  )
}
```

## 状態管理

### Context + Reducer

```typescript
type Action =
  | { type: 'SET_MARKETS'; payload: Market[] }
  | { type: 'SELECT_MARKET'; payload: Market }

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'SET_MARKETS':
      return { ...state, markets: action.payload }
    case 'SELECT_MARKET':
      return { ...state, selectedMarket: action.payload }
    default:
      return state
  }
}
```

## アンチパターン

- useEffect内でのfetch（React Queryを使用）
- propsドリリング（Contextを使用）
- インラインオブジェクト/配列（メモ化または外部化）
- 過度なメモ化（測定してから最適化）

## 詳細リファレンス

- `references/react.md` - Reactパターン詳細
- `references/nextjs.md` - Next.js App Router
