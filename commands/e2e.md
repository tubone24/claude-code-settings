---
description: Generate and run end-to-end tests with Playwright. Creates test journeys, runs tests, captures screenshots/videos/traces, and uploads artifacts.
---

# E2Eコマンド

このコマンドは**e2e-runner**エージェントを呼び出し、Playwrightを使用したエンドツーエンドテストの生成、メンテナンス、実行を行います。

## このコマンドの機能

1. **テストジャーニーの生成** - ユーザーフローのPlaywrightテストを作成
2. **E2Eテストの実行** - 複数ブラウザでテストを実行
3. **アーティファクトのキャプチャ** - 失敗時のスクリーンショット、ビデオ、トレース
4. **結果のアップロード** - HTMLレポートとJUnit XML
5. **不安定なテストの特定** - 不安定なテストを隔離

## 使用するタイミング

以下の場合に`/e2e`を使用:
- 重要なユーザージャーニーのテスト（ログイン、取引、支払い）
- マルチステップフローがエンドツーエンドで動作することの検証
- UIインタラクションとナビゲーションのテスト
- フロントエンドとバックエンド間の統合の検証
- 本番デプロイの準備

## 動作の仕組み

e2e-runnerエージェントは以下を行います:

1. **ユーザーフローを分析**し、テストシナリオを特定
2. **Playwrightテストを生成**（Page Object Modelパターンを使用）
3. **複数ブラウザでテストを実行**（Chrome、Firefox、Safari）
4. **失敗をキャプチャ**（スクリーンショット、ビデオ、トレース）
5. **レポートを生成**（結果とアーティファクト付き）
6. **不安定なテストを特定**し、修正を推奨

## 使用例

```
ユーザー: /e2e マーケット検索と表示フローをテスト

エージェント（e2e-runner）:
# E2Eテスト生成: マーケット検索と表示フロー

## 特定されたテストシナリオ

**ユーザージャーニー:** マーケット検索 → 結果表示 → マーケットクリック → 詳細表示

**テストカバレッジ:**
1. マーケットページに移動
2. セマンティック検索を実行
3. 検索結果を検証
4. 最初の結果をクリック
5. マーケット詳細ページの読み込みを検証
6. チャートのレンダリングを検証

## 生成されたテストコード

```typescript
// tests/e2e/markets/search-and-view.spec.ts
import { test, expect } from '@playwright/test'
import { MarketsPage } from '../../pages/MarketsPage'
import { MarketDetailsPage } from '../../pages/MarketDetailsPage'

test.describe('マーケット検索と表示フロー', () => {
  test('ユーザーがマーケットを検索して詳細を表示できる', async ({ page }) => {
    // 1. マーケットページに移動
    const marketsPage = new MarketsPage(page)
    await marketsPage.goto()

    // ページが読み込まれたことを確認
    await expect(page).toHaveTitle(/Markets/)
    await expect(page.locator('h1')).toContainText('Markets')

    // 2. セマンティック検索を実行
    await marketsPage.searchMarkets('election')

    // APIレスポンスを待機
    await page.waitForResponse(resp =>
      resp.url().includes('/api/markets/search') && resp.status() === 200
    )

    // 3. 検索結果を検証
    const marketCards = marketsPage.marketCards
    await expect(marketCards.first()).toBeVisible()
    const resultCount = await marketCards.count()
    expect(resultCount).toBeGreaterThan(0)

    // 検索結果のスクリーンショットを撮影
    await page.screenshot({ path: 'artifacts/search-results.png' })

    // 4. 最初の結果をクリック
    const firstMarketTitle = await marketCards.first().textContent()
    await marketCards.first().click()

    // 5. マーケット詳細ページの読み込みを検証
    await expect(page).toHaveURL(/\/markets\/[a-z0-9-]+/)

    const detailsPage = new MarketDetailsPage(page)
    await expect(detailsPage.marketName).toBeVisible()
    await expect(detailsPage.marketDescription).toBeVisible()

    // 6. チャートのレンダリングを検証
    await expect(detailsPage.priceChart).toBeVisible()

    // マーケット名が一致することを確認
    const detailsTitle = await detailsPage.marketName.textContent()
    expect(detailsTitle?.toLowerCase()).toContain(
      firstMarketTitle?.toLowerCase().substring(0, 20) || ''
    )

    // マーケット詳細のスクリーンショットを撮影
    await page.screenshot({ path: 'artifacts/market-details.png' })
  })

  test('結果なしの検索で空の状態を表示', async ({ page }) => {
    const marketsPage = new MarketsPage(page)
    await marketsPage.goto()

    // 存在しないマーケットを検索
    await marketsPage.searchMarkets('xyznonexistentmarket123456')

    // 空の状態を検証
    await expect(page.locator('[data-testid="no-results"]')).toBeVisible()
    await expect(page.locator('[data-testid="no-results"]')).toContainText(
      /no.*results|no.*markets/i
    )

    const marketCount = await marketsPage.marketCards.count()
    expect(marketCount).toBe(0)
  })

  test('検索をクリアしてすべてのマーケットを再表示できる', async ({ page }) => {
    const marketsPage = new MarketsPage(page)
    await marketsPage.goto()

    // 初期のマーケット数
    const initialCount = await marketsPage.marketCards.count()

    // 検索を実行
    await marketsPage.searchMarkets('trump')
    await page.waitForLoadState('networkidle')

    // フィルタリングされた結果を検証
    const filteredCount = await marketsPage.marketCards.count()
    expect(filteredCount).toBeLessThan(initialCount)

    // 検索をクリア
    await marketsPage.searchInput.clear()
    await page.waitForLoadState('networkidle')

    // すべてのマーケットが再表示されることを確認
    const finalCount = await marketsPage.marketCards.count()
    expect(finalCount).toBe(initialCount)
  })
})
```

## テストの実行

```bash
# 生成されたテストを実行
npx playwright test tests/e2e/markets/search-and-view.spec.ts

3つのワーカーを使用して3つのテストを実行中

  ✓  [chromium] › search-and-view.spec.ts:5:3 › ユーザーがマーケットを検索して詳細を表示できる (4.2s)
  ✓  [chromium] › search-and-view.spec.ts:52:3 › 結果なしの検索で空の状態を表示 (1.8s)
  ✓  [chromium] › search-and-view.spec.ts:67:3 › 検索をクリアしてすべてのマーケットを再表示できる (2.9s)

  3 passed (9.1s)

生成されたアーティファクト:
- artifacts/search-results.png
- artifacts/market-details.png
- playwright-report/index.html
```

## テストレポート

```
╔══════════════════════════════════════════════════════════════╗
║                    E2Eテスト結果                              ║
╠══════════════════════════════════════════════════════════════╣
║ ステータス:     ✅ 全テスト合格                               ║
║ 合計:          3テスト                                       ║
║ 合格:          3 (100%)                                      ║
║ 失敗:          0                                             ║
║ 不安定:        0                                             ║
║ 所要時間:      9.1秒                                         ║
╚══════════════════════════════════════════════════════════════╝

アーティファクト:
📸 スクリーンショット: 2ファイル
📹 ビデオ: 0ファイル（失敗時のみ）
🔍 トレース: 0ファイル（失敗時のみ）
📊 HTMLレポート: playwright-report/index.html

レポートを表示: npx playwright show-report
```

✅ E2Eテストスイートがci/cd統合の準備完了！
```

## テストアーティファクト

テスト実行時に以下のアーティファクトがキャプチャされます:

**全テストで:**
- タイムラインと結果を含むHTMLレポート
- CI統合用のJUnit XML

**失敗時のみ:**
- 失敗状態のスクリーンショット
- テストのビデオ録画
- デバッグ用トレースファイル（ステップバイステップのリプレイ）
- ネットワークログ
- コンソールログ

## アーティファクトの表示

```bash
# ブラウザでHTMLレポートを表示
npx playwright show-report

# 特定のトレースファイルを表示
npx playwright show-trace artifacts/trace-abc123.zip

# スクリーンショットはartifacts/ディレクトリに保存されます
open artifacts/search-results.png
```

## 不安定なテストの検出

テストが断続的に失敗する場合:

```
⚠️  不安定なテストを検出: tests/e2e/markets/trade.spec.ts

テストは10回中7回合格（70%の合格率）

よくある失敗:
"要素 '[data-testid="confirm-btn"]' を待機中にタイムアウト"

推奨される修正:
1. 明示的な待機を追加: await page.waitForSelector('[data-testid="confirm-btn"]')
2. タイムアウトを増加: { timeout: 10000 }
3. コンポーネント内の競合状態をチェック
4. 要素がアニメーションで隠れていないか確認

隔離の推奨: 修正されるまで test.fixme() としてマーク
```

## ブラウザ設定

デフォルトでテストは複数のブラウザで実行されます:
- ✅ Chromium（デスクトップChrome）
- ✅ Firefox（デスクトップ）
- ✅ WebKit（デスクトップSafari）
- ✅ モバイルChrome（オプション）

ブラウザを調整するには`playwright.config.ts`で設定してください。

## CI/CD統合

CIパイプラインに追加:

```yaml
# .github/workflows/e2e.yml
- name: Playwrightをインストール
  run: npx playwright install --with-deps

- name: E2Eテストを実行
  run: npx playwright test

- name: アーティファクトをアップロード
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: playwright-report
    path: playwright-report/
```

## PMX固有の重要フロー

PMXでは、以下のE2Eテストを優先してください:

**🔴 クリティカル（常に合格必須）:**
1. ユーザーがウォレットを接続できる
2. ユーザーがマーケットを閲覧できる
3. ユーザーがマーケットを検索できる（セマンティック検索）
4. ユーザーがマーケット詳細を表示できる
5. ユーザーが取引を実行できる（テスト資金で）
6. マーケットが正しく解決される
7. ユーザーが資金を引き出せる

**🟡 重要:**
1. マーケット作成フロー
2. ユーザープロフィール更新
3. リアルタイム価格更新
4. チャートレンダリング
5. マーケットのフィルタとソート
6. モバイルレスポンシブレイアウト

## ベストプラクティス

**推奨:**
- ✅ 保守性のためPage Object Modelを使用
- ✅ セレクタにdata-testid属性を使用
- ✅ 任意のタイムアウトではなくAPIレスポンスを待機
- ✅ 重要なユーザージャーニーをエンドツーエンドでテスト
- ✅ mainにマージする前にテストを実行
- ✅ テスト失敗時にアーティファクトをレビュー

**非推奨:**
- ❌ 脆弱なセレクタを使用（CSSクラスは変更される可能性あり）
- ❌ 実装の詳細をテスト
- ❌ 本番環境に対してテストを実行
- ❌ 不安定なテストを無視
- ❌ 失敗時のアーティファクトレビューをスキップ
- ❌ E2Eですべてのエッジケースをテスト（ユニットテストを使用）

## 重要な注意事項

**PMXにとってクリティカル:**
- 実際のお金を伴うE2Eテストはテストネット/ステージング環境でのみ実行する必要があります
- 本番環境に対して取引テストを絶対に実行しない
- 金融テストには`test.skip(process.env.NODE_ENV === 'production')`を設定
- 少額のテスト資金を持つテストウォレットのみを使用

## 他のコマンドとの統合

- `/plan`を使用してテストする重要なジャーニーを特定
- `/tdd`をユニットテストに使用（より高速で詳細）
- `/e2e`を統合テストとユーザージャーニーテストに使用
- `/code-review`を使用してテスト品質を検証

## 関連エージェント

このコマンドは以下にある`e2e-runner`エージェントを呼び出します:
`~/.claude/agents/e2e-runner.md`

## クイックコマンド

```bash
# すべてのE2Eテストを実行
npx playwright test

# 特定のテストファイルを実行
npx playwright test tests/e2e/markets/search.spec.ts

# ヘッドモードで実行（ブラウザを表示）
npx playwright test --headed

# テストをデバッグ
npx playwright test --debug

# テストコードを生成
npx playwright codegen http://localhost:3000

# レポートを表示
npx playwright show-report
```
