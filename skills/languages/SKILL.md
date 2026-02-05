---
name: coding-standards
description: コーディング標準とベストプラクティス。TypeScript、JavaScript、React、Node.js開発の品質基準に使用。
---

# コーディング標準

すべてのプロジェクトに適用可能な普遍的なコーディング標準。

## 有効化するタイミング

- 新しいコードの作成
- コードレビュー
- リファクタリング
- 品質基準の確認

## コード品質の原則

| 原則 | 説明 |
|------|------|
| **KISS** | 動作する最もシンプルなソリューション |
| **DRY** | 共通ロジックを関数に抽出 |
| **YAGNI** | 必要になる前に機能を構築しない |
| **可読性第一** | コードは書くより読む回数が多い |

## TypeScript/JavaScript標準

### 命名規則

```typescript
// ✅ 変数: 説明的な名前
const marketSearchQuery = 'election'
const isUserAuthenticated = true

// ✅ 関数: 動詞-名詞パターン
async function fetchMarketData(marketId: string) { }
function calculateSimilarity(a: number[], b: number[]) { }
function isValidEmail(email: string): boolean { }
```

### イミュータビリティ（クリティカル）

```typescript
// ✅ 常にスプレッド演算子を使用
const updatedUser = { ...user, name: 'New Name' }
const updatedArray = [...items, newItem]

// ❌ 絶対に直接ミューテートしない
user.name = 'New Name'  // 悪い
items.push(newItem)     // 悪い
```

### エラーハンドリング

```typescript
async function fetchData(url: string) {
  try {
    const response = await fetch(url)
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    return await response.json()
  } catch (error) {
    console.error('Fetch failed:', error)
    throw new Error('Failed to fetch data')
  }
}
```

### Async/Await

```typescript
// ✅ 可能な場合は並列実行
const [users, markets, stats] = await Promise.all([
  fetchUsers(),
  fetchMarkets(),
  fetchStats()
])

// ❌ 不要な順次実行は避ける
```

### 型安全性

```typescript
// ✅ 適切な型定義
interface Market {
  id: string
  name: string
  status: 'active' | 'resolved' | 'closed'
}

// ❌ 'any'は禁止
```

## React標準

### コンポーネント構造

```typescript
interface ButtonProps {
  children: React.ReactNode
  onClick: () => void
  disabled?: boolean
  variant?: 'primary' | 'secondary'
}

export function Button({
  children,
  onClick,
  disabled = false,
  variant = 'primary'
}: ButtonProps) {
  return (
    <button onClick={onClick} disabled={disabled} className={`btn-${variant}`}>
      {children}
    </button>
  )
}
```

### 状態更新

```typescript
// ✅ 前の状態に基づく場合は関数型更新
setCount(prev => prev + 1)

// ❌ 直接状態参照（古くなる可能性）
setCount(count + 1)
```

### 条件付きレンダリング

```typescript
// ✅ 明確な条件付きレンダリング
{isLoading && <Spinner />}
{error && <ErrorMessage error={error} />}
{data && <DataDisplay data={data} />}

// ❌ 三項演算子の地獄は避ける
```

## コードスメル検出

### 長い関数

```typescript
// ❌ 50行以上の関数
// ✅ 小さな関数に分割
function processMarketData() {
  const validated = validateData()
  const transformed = transformData(validated)
  return saveData(transformed)
}
```

### 深いネスト

```typescript
// ✅ 早期リターンを使用
if (!user) return
if (!user.isAdmin) return
if (!market) return

// 処理を続行
```

### マジックナンバー

```typescript
// ✅ 名前付き定数
const MAX_RETRIES = 3
const DEBOUNCE_DELAY_MS = 500

if (retryCount > MAX_RETRIES) { }
```

## コメント指針

```typescript
// ✅ 「何を」ではなく「なぜ」を説明
// 障害時にAPIを圧倒しないよう指数バックオフを使用
const delay = Math.min(1000 * Math.pow(2, retryCount), 30000)

// ❌ 明らかなことを述べない
// カウンターを1増やす
count++
```

## 詳細リファレンス

- `references/typescript.md` - TypeScript型システム詳細
