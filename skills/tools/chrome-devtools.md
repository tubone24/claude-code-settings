---
name: chrome-devtools
description: Chrome DevTools CLI reference for browser debugging, performance analysis, and network inspection. Use this skill for debugging web applications.
---

# Chrome DevTools CLI

ブラウザデバッグ、パフォーマンス分析、ネットワーク監視のためのCLI参照。

## セットアップ

```bash
# グローバルインストール
npm install -g chrome-devtools-mcp

# または npx で直接実行
npx chrome-devtools-mcp@latest
```

## 基本コマンド（CLI経由）

Chrome DevToolsは通常MCPサーバーとして動作しますが、以下のようにCLI経由でも活用できます。

### Puppeteer経由でのDevTools操作

```bash
# デバッグポート付きでChromeを起動
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug
```

### Node.jsスクリプトでDevTools Protocol使用

```javascript
// devtools-script.js
const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: false,
    devtools: true
  });

  const page = await browser.newPage();
  await page.goto('http://localhost:3000');

  // パフォーマンストレースを取得
  await page.tracing.start({ path: 'trace.json' });
  // ... 操作 ...
  await page.tracing.stop();

  // コンソールログを監視
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));

  // ネットワークリクエストを監視
  page.on('request', req => console.log('REQUEST:', req.url()));
  page.on('response', res => console.log('RESPONSE:', res.url(), res.status()));
})();
```

## DevTools Protocol カテゴリ

### 1. Input（入力操作）
```javascript
// クリック
await page.click('button#submit');

// テキスト入力
await page.type('input#email', 'user@example.com');

// キーボード操作
await page.keyboard.press('Enter');
```

### 2. Navigation（ナビゲーション）
```javascript
// URLに移動
await page.goto('https://example.com');

// 戻る・進む
await page.goBack();
await page.goForward();

// リロード
await page.reload();
```

### 3. Debugging（デバッグ）
```javascript
// コンソールログを取得
page.on('console', msg => {
  console.log(`${msg.type()}: ${msg.text()}`);
});

// エラーを取得
page.on('pageerror', error => {
  console.error('Page error:', error.message);
});

// ブレークポイント設定（CDPプロトコル）
const client = await page.target().createCDPSession();
await client.send('Debugger.enable');
await client.send('Debugger.setBreakpointByUrl', {
  lineNumber: 10,
  url: 'http://localhost:3000/main.js'
});
```

### 4. Network（ネットワーク）
```javascript
// リクエスト監視
page.on('request', request => {
  console.log(request.method(), request.url());
});

// レスポンス監視
page.on('response', response => {
  console.log(response.status(), response.url());
});

// リクエストのインターセプト
await page.setRequestInterception(true);
page.on('request', request => {
  if (request.url().includes('ads')) {
    request.abort();
  } else {
    request.continue();
  }
});
```

### 5. Performance（パフォーマンス）
```javascript
// トレース記録
await page.tracing.start({
  path: 'trace.json',
  screenshots: true
});
// ... 操作 ...
await page.tracing.stop();

// メトリクス取得
const metrics = await page.metrics();
console.log('JS Heap Size:', metrics.JSHeapUsedSize);
console.log('DOM Nodes:', metrics.Nodes);

// Core Web Vitals
const vitals = await page.evaluate(() => {
  return new Promise(resolve => {
    new PerformanceObserver(list => {
      const entries = list.getEntries();
      resolve({
        lcp: entries.find(e => e.entryType === 'largest-contentful-paint'),
        fid: entries.find(e => e.entryType === 'first-input'),
        cls: entries.find(e => e.entryType === 'layout-shift')
      });
    }).observe({ entryTypes: ['largest-contentful-paint', 'first-input', 'layout-shift'] });
  });
});
```

### 6. Emulation（エミュレーション）
```javascript
// モバイルエミュレーション
await page.emulate(puppeteer.devices['iPhone 12']);

// ネットワーク速度制限
const client = await page.target().createCDPSession();
await client.send('Network.emulateNetworkConditions', {
  offline: false,
  downloadThroughput: 1.5 * 1024 * 1024 / 8, // 1.5 Mbps
  uploadThroughput: 750 * 1024 / 8,           // 750 Kbps
  latency: 40                                  // 40ms
});

// Geolocation
await page.setGeolocation({ latitude: 35.6762, longitude: 139.6503 }); // Tokyo
```

## スクリーンショットとPDF

```javascript
// スクリーンショット
await page.screenshot({ path: 'screenshot.png', fullPage: true });

// 要素のスクリーンショット
const element = await page.$('.chart');
await element.screenshot({ path: 'chart.png' });

// PDF出力
await page.pdf({ path: 'page.pdf', format: 'A4' });
```

## コンテキスト節約のヒント

1. **必要な情報だけ取得** - 全ネットワークログではなく、特定URLのみフィルタ
2. **サブエージェントで実行** - デバッグ情報はサブエージェントで処理し、サマリーのみ返す
3. **トレースファイルを活用** - 生データはファイルに保存し、分析結果のみ報告

## agent-browserとの使い分け

| 用途 | Chrome DevTools | agent-browser |
|------|-----------------|---------------|
| パフォーマンス分析 | **推奨** | - |
| ネットワークデバッグ | **推奨** | - |
| コンソールログ監視 | **推奨** | 基本対応 |
| 単純なUI操作 | - | **推奨** |
| スクリーンショット | 両方可 | **推奨** |
| コンテキスト効率 | 中程度 | **93%削減** |

## 参考リンク

- [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Puppeteer API](https://pptr.dev/)
