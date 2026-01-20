# モニタリング設定ガイド

## メトリクス収集

### Prometheus + Grafana

```typescript
// prom-client を使用
import { Registry, Counter, Histogram, collectDefaultMetrics } from 'prom-client'

const register = new Registry()
collectDefaultMetrics({ register })

// カスタムメトリクス
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register]
})

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 5],
  registers: [register]
})

// ミドルウェア
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer({ method: req.method, path: req.path })

  res.on('finish', () => {
    httpRequestsTotal.inc({
      method: req.method,
      path: req.path,
      status: res.statusCode
    })
    end()
  })

  next()
})

// メトリクスエンドポイント
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType)
  res.send(await register.metrics())
})
```

### 主要メトリクス（RED Method）

```
Rate:   リクエスト数/秒
Errors: エラー率
Duration: レイテンシー（p50, p95, p99）
```

### Grafana ダッシュボード設定

```json
{
  "panels": [
    {
      "title": "Request Rate",
      "type": "graph",
      "targets": [{
        "expr": "rate(http_requests_total[5m])",
        "legendFormat": "{{method}} {{path}}"
      }]
    },
    {
      "title": "Error Rate",
      "type": "singlestat",
      "targets": [{
        "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100"
      }]
    },
    {
      "title": "Latency p99",
      "type": "graph",
      "targets": [{
        "expr": "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))"
      }]
    }
  ]
}
```

## 構造化ロギング

### Winston

```typescript
import winston from 'winston'

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'myapp',
    version: process.env.APP_VERSION
  },
  transports: [
    new winston.transports.Console(),
    // 本番環境では Cloud Logging 等に送信
  ]
})

// 使用例
logger.info('User created', {
  userId: user.id,
  email: maskEmail(user.email),
  requestId: req.id
})

logger.error('Database error', {
  error: error.message,
  stack: error.stack,
  query: 'SELECT * FROM users',
  requestId: req.id
})
```

### リクエストID追跡

```typescript
import { v4 as uuidv4 } from 'uuid'

// ミドルウェア
app.use((req, res, next) => {
  req.id = req.headers['x-request-id'] || uuidv4()
  res.setHeader('x-request-id', req.id)
  next()
})

// 子サービスへの伝播
async function callService(req: Request) {
  return fetch('https://api.example.com', {
    headers: {
      'x-request-id': req.id
    }
  })
}
```

## 分散トレーシング

### OpenTelemetry

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT
  }),
  instrumentations: [getNodeAutoInstrumentations()]
})

sdk.start()

// カスタムスパン
import { trace } from '@opentelemetry/api'

const tracer = trace.getTracer('myapp')

async function processOrder(orderId: string) {
  return tracer.startActiveSpan('processOrder', async (span) => {
    try {
      span.setAttribute('order.id', orderId)

      // 処理
      const result = await doProcess(orderId)

      span.setStatus({ code: SpanStatusCode.OK })
      return result
    } catch (error) {
      span.recordException(error)
      span.setStatus({ code: SpanStatusCode.ERROR })
      throw error
    } finally {
      span.end()
    }
  })
}
```

## アラート設定

### Prometheus Alertmanager

```yaml
# alertmanager.yml
groups:
  - name: app-alerts
    rules:
      # 高エラー率
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) /
          sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # 高レイテンシー
      - alert: HighLatency
        expr: |
          histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "p99 latency is {{ $value }}s"

      # Pod再起動
      - alert: PodRestartLoop
        expr: |
          increase(kube_pod_container_status_restarts_total[1h]) > 5
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Pod restart loop"
```

### PagerDuty/Slack通知

```yaml
# alertmanager routing
route:
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
    - match:
        severity: warning
      receiver: 'slack'

receivers:
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: '<key>'
        severity: '{{ .GroupLabels.severity }}'

  - name: 'slack'
    slack_configs:
      - api_url: '<webhook>'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ .Annotations.description }}'
```

## ヘルスチェック

```typescript
// /health エンドポイント
app.get('/health', async (req, res) => {
  const checks = {
    database: await checkDatabase(),
    redis: await checkRedis(),
    externalApi: await checkExternalApi()
  }

  const healthy = Object.values(checks).every(c => c.status === 'healthy')

  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'healthy' : 'unhealthy',
    checks,
    timestamp: new Date().toISOString()
  })
})

async function checkDatabase(): Promise<HealthCheck> {
  try {
    await db.$queryRaw`SELECT 1`
    return { status: 'healthy' }
  } catch (error) {
    return { status: 'unhealthy', error: error.message }
  }
}
```

## ダッシュボード例

### サービス概要
- リクエスト率（RPS）
- エラー率
- レイテンシー（p50, p95, p99）
- アクティブ接続数

### インフラ
- CPU使用率
- メモリ使用率
- ディスク使用率
- ネットワークI/O

### ビジネス
- アクティブユーザー数
- トランザクション数
- コンバージョン率
