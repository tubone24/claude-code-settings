---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/app/**/*.ts"
  - "**/pages/**/*.ts"
  - "**/components/**/*"
---

# フレームワークベストプラクティス

## React

- 関数コンポーネント + Hooks
- コンポジション優先（継承禁止）
- `use client`は必要な箇所のみ
- useMemo/useCallbackは測定後に追加
- useEffectの依存配列を正確に

## Next.js

- App Router使用
- Server Componentsをデフォルトに
- Image/Link/Fontコンポーネント使用
- ISR/SSG活用
- 動的インポートでコード分割

## TypeScript

- strictモード必須
- any禁止（unknown使用）
- 型推論を活用
- `import type`で型インポート
- Branded types推奨（`type UserId = string & { _brand: 'UserId' }`）

## 状態管理

- サーバー状態: Tanstack Query
- クライアント状態: Zustand
- 複雑な状態: useReducer
- propsドリリング回避: Context

## パフォーマンス

- 画像最適化（next/image, sharp）
- バンドル分析（@next/bundle-analyzer）
- Web Vitals監視
- キャッシュ戦略明確化
