# プロジェクトCLAUDE.mdの例

これはプロジェクトレベルのCLAUDE.mdファイルの例です。プロジェクトルートに配置してください。

## プロジェクト概要

[プロジェクトの簡単な説明 - 何をするか、技術スタック]

## コンテキスト最適化

このプロジェクトではコンテキストウィンドウの効率的な使用を重視します。

### MCPよりサブエージェントを優先
- ブラウザ操作: browser-automation（agent-browser CLI）
- デバッグ: browser-debug（Puppeteer/Lighthouse）
- ドキュメント検索: docs-lookup（WebSearch/WebFetch）
- GitHub: github-ops（gh CLI）
- DB: database-ops（supabase/prisma CLI）

### 出力ルール
- サブエージェントからはサマリーのみ返却
- 大量データはファイルに保存
- 長いログは要約して報告
- 詳細はリンク/ファイルパスで参照

### 並列実行
- 独立したタスクは常に並列で実行
- 依存関係があるタスクのみ順次実行

## 重要なルール

### 1. コード構成

- 少数の大きなファイルより多数の小さなファイル
- 高凝集、低結合
- 通常200-400行、ファイルあたり最大800行
- タイプ別ではなく機能/ドメイン別に整理

### 2. コードスタイル

- コード、コメント、ドキュメントに絵文字を使わない
- 常にイミュータビリティ - オブジェクトや配列を絶対にミューテートしない
- 本番コードにconsole.logを入れない
- try/catchによる適切なエラーハンドリング
- Zodなどによる入力検証

### 3. テスト

- TDD: テストを先に書く
- 最低80%のカバレッジ
- ユーティリティにはユニットテスト
- APIには統合テスト
- 重要なフローにはE2Eテスト

### 4. セキュリティ

- ハードコードされた秘密情報なし
- 機密データには環境変数
- すべてのユーザー入力を検証
- パラメータ化クエリのみ
- CSRF保護を有効化

## ファイル構造

```
src/
|-- app/              # Next.js app router
|-- components/       # 再利用可能なUIコンポーネント
|-- hooks/            # カスタムReactフック
|-- lib/              # ユーティリティライブラリ
|-- types/            # TypeScript型定義
```

## 主要なパターン

### APIレスポンス形式

```typescript
interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: string
}
```

### エラーハンドリング

```typescript
try {
  const result = await operation()
  return { success: true, data: result }
} catch (error) {
  console.error('Operation failed:', error)
  return { success: false, error: 'ユーザーフレンドリーなメッセージ' }
}
```

## 環境変数

```bash
# 必須
DATABASE_URL=
API_KEY=

# オプション
DEBUG=false
```

## 利用可能なコマンド

- `/tdd` - テスト駆動開発ワークフロー
- `/plan` - 実装計画を作成
- `/code-review` - コード品質をレビュー
- `/build-fix` - ビルドエラーを修正

## Gitワークフロー

- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- mainに直接コミットしない
- PRにはレビューが必要
- マージ前にすべてのテストが通る必要あり
