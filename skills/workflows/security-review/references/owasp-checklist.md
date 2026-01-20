# OWASP Top 10 チェックリスト

## A01:2021 - アクセス制御の不備

### チェック項目
- [ ] すべてのAPIエンドポイントで認証チェック
- [ ] 認可チェックがリソースごとに実施されている
- [ ] JWTトークンの署名と有効期限を検証
- [ ] 直接オブジェクト参照（IDOR）の防止
- [ ] CORSポリシーが適切に設定されている
- [ ] HTTPメソッドの制限（OPTIONS, TRACE等）

### 脆弱なコード例
```typescript
// NG: 認可チェックなし
app.get('/api/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id)
  res.json(user)  // 誰でも他人のデータを取得可能
})

// OK: 認可チェックあり
app.get('/api/users/:id', authenticate, async (req, res) => {
  if (req.user.id !== req.params.id && !req.user.isAdmin) {
    return res.status(403).json({ error: 'Forbidden' })
  }
  const user = await db.users.findById(req.params.id)
  res.json(user)
})
```

---

## A02:2021 - 暗号化の失敗

### チェック項目
- [ ] パスワードはbcrypt/argon2でハッシュ化
- [ ] 機密データは保存時に暗号化
- [ ] HTTPS強制（HSTS設定）
- [ ] 弱い暗号アルゴリズムを使用していない（MD5, SHA1）
- [ ] 暗号化キーが安全に管理されている
- [ ] TLS 1.2以上を使用

### 脆弱なコード例
```typescript
// NG: MD5は脆弱
const hash = crypto.createHash('md5').update(password).digest('hex')

// OK: bcryptを使用
import bcrypt from 'bcrypt'
const hash = await bcrypt.hash(password, 12)
```

---

## A03:2021 - インジェクション

### チェック項目
- [ ] SQLクエリはパラメータ化
- [ ] NoSQLクエリはサニタイズ
- [ ] OSコマンドインジェクション対策
- [ ] LDAPインジェクション対策
- [ ] XPathインジェクション対策
- [ ] ユーザー入力をコードとして実行しない（eval禁止）

### 脆弱なコード例
```typescript
// NG: SQLインジェクション
const query = `SELECT * FROM users WHERE email = '${email}'`

// OK: パラメータ化クエリ
const result = await db.query('SELECT * FROM users WHERE email = $1', [email])

// NG: コマンドインジェクション
exec(`ping ${userInput}`)

// OK: ライブラリを使用
import dns from 'dns'
dns.lookup(userInput, callback)
```

---

## A04:2021 - 安全でない設計

### チェック項目
- [ ] 脅威モデリングを実施
- [ ] セキュアなデザインパターンを使用
- [ ] 多層防御を実装
- [ ] 最小権限の原則を適用
- [ ] 失敗時は安全側に倒れる設計

---

## A05:2021 - セキュリティの設定ミス

### チェック項目
- [ ] 不要な機能/サービスを無効化
- [ ] デフォルト認証情報を変更
- [ ] エラーメッセージに詳細情報を含めない
- [ ] セキュリティヘッダーを設定
- [ ] ディレクトリリスティングを無効化
- [ ] デバッグモードを本番で無効化

### セキュリティヘッダー
```typescript
// Next.js next.config.js
const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-XSS-Protection', value: '1; mode=block' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  {
    key: 'Content-Security-Policy',
    value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
  }
]
```

---

## A06:2021 - 脆弱で古いコンポーネント

### チェック項目
- [ ] `npm audit` でCVEをチェック
- [ ] 依存関係を定期的に更新
- [ ] 使用していない依存関係を削除
- [ ] サポート終了のライブラリを使用していない
- [ ] Dependabotまたは類似ツールを有効化

### コマンド
```bash
# 脆弱性チェック
npm audit
npm audit --audit-level=high

# 自動修正
npm audit fix

# 依存関係更新
npm update
npm outdated
```

---

## A07:2021 - 識別と認証の失敗

### チェック項目
- [ ] 強力なパスワードポリシー
- [ ] ブルートフォース対策（レート制限、アカウントロック）
- [ ] 多要素認証（MFA）対応
- [ ] セッション管理が安全
- [ ] パスワードリセットが安全
- [ ] セッションIDのローテーション

### 実装例
```typescript
// レート制限
import rateLimit from 'express-rate-limit'

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15分
  max: 5,  // 5回まで
  message: 'Too many login attempts'
})

app.post('/login', loginLimiter, loginHandler)
```

---

## A08:2021 - ソフトウェアとデータの整合性の不備

### チェック項目
- [ ] CI/CDパイプラインのセキュリティ
- [ ] 依存関係の整合性チェック（lock file）
- [ ] コード署名の検証
- [ ] 安全でないデシリアライゼーション対策

### コマンド
```bash
# ロックファイルからインストール
npm ci  # npm installではなくこちらを使用
```

---

## A09:2021 - セキュリティログと監視の不備

### チェック項目
- [ ] 認証イベントをログ
- [ ] アクセス制御失敗をログ
- [ ] 入力検証失敗をログ
- [ ] ログに機密情報を含めない
- [ ] ログの監視とアラート設定
- [ ] インシデント対応計画

### ログ例
```typescript
// 構造化ログ
logger.info('User login', {
  userId: user.id,
  ip: req.ip,
  userAgent: req.headers['user-agent'],
  success: true
})

logger.warn('Login failed', {
  email: maskEmail(email),  // マスキング
  ip: req.ip,
  reason: 'invalid_password'
})
```

---

## A10:2021 - サーバーサイドリクエストフォージェリ（SSRF）

### チェック項目
- [ ] ユーザー提供URLのバリデーション
- [ ] 許可リストによるドメイン制限
- [ ] 内部ネットワークへのアクセス禁止
- [ ] リダイレクトの制限

### 実装例
```typescript
// NG: SSRF脆弱性
const response = await fetch(userProvidedUrl)

// OK: ドメインを制限
const allowedHosts = ['api.example.com', 'cdn.example.com']

function validateUrl(url: string): boolean {
  try {
    const parsed = new URL(url)
    return allowedHosts.includes(parsed.hostname)
  } catch {
    return false
  }
}

if (!validateUrl(userProvidedUrl)) {
  throw new Error('Invalid URL')
}
const response = await fetch(userProvidedUrl)
```
