---
name: react
description: React patterns and best practices
---

# React

## コンポーネント設計

```typescript
// Composition over inheritance
interface Props {
  children: React.ReactNode
  variant?: 'primary' | 'secondary'
}

export function Button({ children, variant = 'primary' }: Props) {
  return <button className={`btn-${variant}`}>{children}</button>
}
```

## Hooks

```typescript
// Custom hook pattern
function useToggle(initial = false) {
  const [value, setValue] = useState(initial)
  const toggle = useCallback(() => setValue(v => !v), [])
  return [value, toggle] as const
}
```

## パフォーマンス

- `React.memo()`: 純粋コンポーネントのみ
- `useMemo()`: 計算コストが高い場合のみ
- `useCallback()`: 子に渡す関数
- 測定してから最適化

## アンチパターン

- useEffect内でのfetch（React Queryを使用）
- propsドリリング（Contextを使用）
- インラインオブジェクト/配列（メモ化または外部化）
