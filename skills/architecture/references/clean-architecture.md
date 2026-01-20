# クリーンアーキテクチャ詳細ガイド

## レイヤー構成

### 1. Domain Layer（エンティティ）

ビジネスルールの中核。外部依存なし。

```typescript
// domain/entities/User.ts
export class User {
  constructor(
    public readonly id: string,
    public readonly email: Email,
    public readonly name: string,
    private _status: UserStatus
  ) {}

  get status(): UserStatus {
    return this._status
  }

  activate(): void {
    if (this._status === 'suspended') {
      throw new Error('Suspended user cannot be activated')
    }
    this._status = 'active'
  }

  suspend(): void {
    this._status = 'suspended'
  }
}

// domain/value-objects/Email.ts
export class Email {
  private constructor(public readonly value: string) {}

  static create(value: string): Email {
    if (!this.isValid(value)) {
      throw new Error('Invalid email format')
    }
    return new Email(value)
  }

  private static isValid(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }

  equals(other: Email): boolean {
    return this.value === other.value
  }
}
```

### 2. Application Layer（ユースケース）

アプリケーション固有のビジネスルール。

```typescript
// application/use-cases/CreateUser.ts
import { User } from '@/domain/entities/User'
import { Email } from '@/domain/value-objects/Email'
import { UserRepository } from '@/application/ports/UserRepository'
import { IdGenerator } from '@/application/ports/IdGenerator'

interface CreateUserInput {
  email: string
  name: string
}

interface CreateUserOutput {
  id: string
  email: string
  name: string
}

export class CreateUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private idGenerator: IdGenerator
  ) {}

  async execute(input: CreateUserInput): Promise<CreateUserOutput> {
    const email = Email.create(input.email)

    // 重複チェック
    const existing = await this.userRepository.findByEmail(email)
    if (existing) {
      throw new Error('User already exists')
    }

    const user = new User(
      this.idGenerator.generate(),
      email,
      input.name,
      'pending'
    )

    await this.userRepository.save(user)

    return {
      id: user.id,
      email: user.email.value,
      name: user.name
    }
  }
}
```

### 3. Application Ports（インターフェース）

インフラ層への依存を逆転。

```typescript
// application/ports/UserRepository.ts
import { User } from '@/domain/entities/User'
import { Email } from '@/domain/value-objects/Email'

export interface UserRepository {
  findById(id: string): Promise<User | null>
  findByEmail(email: Email): Promise<User | null>
  save(user: User): Promise<void>
  delete(id: string): Promise<void>
}

// application/ports/IdGenerator.ts
export interface IdGenerator {
  generate(): string
}
```

### 4. Infrastructure Layer（実装）

外部サービスとの接続。

```typescript
// infrastructure/repositories/PrismaUserRepository.ts
import { PrismaClient } from '@prisma/client'
import { User } from '@/domain/entities/User'
import { Email } from '@/domain/value-objects/Email'
import { UserRepository } from '@/application/ports/UserRepository'

export class PrismaUserRepository implements UserRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    const data = await this.prisma.user.findUnique({
      where: { id }
    })

    if (!data) return null

    return new User(
      data.id,
      Email.create(data.email),
      data.name,
      data.status as UserStatus
    )
  }

  async findByEmail(email: Email): Promise<User | null> {
    const data = await this.prisma.user.findUnique({
      where: { email: email.value }
    })

    if (!data) return null

    return new User(
      data.id,
      Email.create(data.email),
      data.name,
      data.status as UserStatus
    )
  }

  async save(user: User): Promise<void> {
    await this.prisma.user.upsert({
      where: { id: user.id },
      update: {
        email: user.email.value,
        name: user.name,
        status: user.status
      },
      create: {
        id: user.id,
        email: user.email.value,
        name: user.name,
        status: user.status
      }
    })
  }

  async delete(id: string): Promise<void> {
    await this.prisma.user.delete({ where: { id } })
  }
}

// infrastructure/services/UuidGenerator.ts
import { v4 as uuidv4 } from 'uuid'
import { IdGenerator } from '@/application/ports/IdGenerator'

export class UuidGenerator implements IdGenerator {
  generate(): string {
    return uuidv4()
  }
}
```

### 5. Presentation Layer（コントローラー）

外部とのインターフェース。

```typescript
// presentation/controllers/UserController.ts
import { NextRequest, NextResponse } from 'next/server'
import { CreateUserUseCase } from '@/application/use-cases/CreateUser'
import { z } from 'zod'

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100)
})

export class UserController {
  constructor(private createUserUseCase: CreateUserUseCase) {}

  async create(request: NextRequest): Promise<NextResponse> {
    try {
      const body = await request.json()
      const input = createUserSchema.parse(body)

      const result = await this.createUserUseCase.execute(input)

      return NextResponse.json(
        { success: true, data: result },
        { status: 201 }
      )
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          { success: false, error: 'Validation failed', details: error.errors },
          { status: 400 }
        )
      }

      return NextResponse.json(
        { success: false, error: (error as Error).message },
        { status: 500 }
      )
    }
  }
}
```

## 依存性注入（DI）

```typescript
// infrastructure/container.ts
import { PrismaClient } from '@prisma/client'
import { PrismaUserRepository } from './repositories/PrismaUserRepository'
import { UuidGenerator } from './services/UuidGenerator'
import { CreateUserUseCase } from '@/application/use-cases/CreateUser'
import { UserController } from '@/presentation/controllers/UserController'

// 依存関係の組み立て
const prisma = new PrismaClient()
const userRepository = new PrismaUserRepository(prisma)
const idGenerator = new UuidGenerator()

const createUserUseCase = new CreateUserUseCase(userRepository, idGenerator)
export const userController = new UserController(createUserUseCase)
```

## テスト容易性

```typescript
// テスト用のモック
class InMemoryUserRepository implements UserRepository {
  private users: Map<string, User> = new Map()

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null
  }

  async save(user: User): Promise<void> {
    this.users.set(user.id, user)
  }
}

// ユースケースのテスト
describe('CreateUserUseCase', () => {
  it('creates a new user', async () => {
    const userRepo = new InMemoryUserRepository()
    const idGen = { generate: () => 'test-id' }
    const useCase = new CreateUserUseCase(userRepo, idGen)

    const result = await useCase.execute({
      email: 'test@example.com',
      name: 'Test User'
    })

    expect(result.id).toBe('test-id')
    expect(result.email).toBe('test@example.com')
  })
})
```

## ディレクトリ構成例（Next.js）

```
src/
├── app/                    # Next.js App Router
│   └── api/
│       └── users/
│           └── route.ts    # ルートハンドラー
├── domain/
│   ├── entities/
│   │   └── User.ts
│   └── value-objects/
│       └── Email.ts
├── application/
│   ├── use-cases/
│   │   └── CreateUser.ts
│   └── ports/
│       └── UserRepository.ts
├── infrastructure/
│   ├── repositories/
│   │   └── PrismaUserRepository.ts
│   ├── services/
│   │   └── UuidGenerator.ts
│   └── container.ts
└── presentation/
    └── controllers/
        └── UserController.ts
```

## アンチパターン

### NG: ドメインがインフラに依存

```typescript
// NG
import { PrismaClient } from '@prisma/client'

export class User {
  async save(prisma: PrismaClient) {
    await prisma.user.create({ data: this })
  }
}
```

### NG: ユースケースにUIロジック

```typescript
// NG
export class CreateUserUseCase {
  execute(input) {
    // HTTPレスポンスを返している
    return new Response(JSON.stringify(user), { status: 201 })
  }
}
```

### NG: コントローラーにビジネスロジック

```typescript
// NG
async create(req) {
  // ビジネスルールがコントローラーに漏れている
  if (await this.userRepo.findByEmail(email)) {
    throw new Error('User exists')
  }
  const user = new User(...)
  await this.userRepo.save(user)
}
```
