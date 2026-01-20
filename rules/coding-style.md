---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---

# コーディングスタイル

## イミュータビリティ（クリティカル）

常に新しいオブジェクトを作成し、絶対にミューテートしない:

```javascript
// 間違い: ミューテーション
function updateUser(user, name) {
  user.name = name  // ミューテーション！
  return user
}

// 正解: イミュータビリティ
function updateUser(user, name) {
  return {
    ...user,
    name
  }
}
```

## 関数型プログラミング

副作用を最小限にし、純粋関数を優先する:

```typescript
// 間違い: 副作用のある関数
let total = 0
function addToTotal(value) {
  total += value  // 外部状態を変更
  return total
}

// 正解: 純粋関数
function add(a, b) {
  return a + b
}

// 間違い: 命令型ループ
const results = []
for (const item of items) {
  if (item.active) {
    results.push(item.name)
  }
}

// 正解: 宣言型（map/filter/reduce）
const results = items
  .filter(item => item.active)
  .map(item => item.name)
```

**関数型プログラミングの原則:**
- 純粋関数: 同じ入力には常に同じ出力、副作用なし
- イミュータビリティ: データを変更せず、新しいデータを作成
- 高階関数: map、filter、reduceを活用
- 関数合成: 小さな関数を組み合わせて複雑な処理を構築
- 宣言型: 「何をするか」を記述、「どうやるか」ではなく

## ファイル構成

少数の大きなファイル < 多数の小さなファイル:
- 高凝集、低結合
- 通常200-400行、最大800行
- 大きなコンポーネントからユーティリティを抽出
- タイプ別ではなく機能/ドメイン別に整理

## エラーハンドリング

常にエラーを包括的に処理:

```typescript
try {
  const result = await riskyOperation()
  return result
} catch (error) {
  console.error('Operation failed:', error)
  throw new Error('詳細でユーザーフレンドリーなメッセージ')
}
```

## 入力検証

常にユーザー入力を検証:

```typescript
import { z } from 'zod'

const schema = z.object({
  email: z.string().email(),
  age: z.number().int().min(0).max(150)
})

const validated = schema.parse(input)
```

## コード品質チェックリスト

作業完了とマークする前に:
- [ ] コードが読みやすく適切に命名されている
- [ ] 関数が小さい（50行未満）
- [ ] ファイルが焦点を絞っている（800行未満）
- [ ] 深いネストがない（4レベル以上）
- [ ] 適切なエラーハンドリング
- [ ] console.log文がない
- [ ] ハードコードされた値がない
- [ ] ミューテーションがない（イミュータブルパターンを使用）
