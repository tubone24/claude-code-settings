---
name: typescript
description: TypeScript best practices and patterns
---

# TypeScript

## 型定義

```typescript
// Branded types for type safety
type UserId = string & { _brand: 'UserId' }
type OrderId = string & { _brand: 'OrderId' }

// Utility types
type Nullable<T> = T | null
type AsyncResult<T> = Promise<Result<T, Error>>
```

## 設定

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

## パターン

- `any`禁止 → `unknown`使用
- 型アサーション最小化
- `import type`で型インポート
- discriminated unions活用
- exhaustive check with `never`
