---
name: nextjs
description: Next.js App Router patterns
---

# Next.js

## App Router

```
app/
├── layout.tsx      # Root layout
├── page.tsx        # Home page
├── (auth)/         # Route group
│   ├── login/
│   └── register/
└── api/
    └── [...]/route.ts
```

## Server Components (default)

```typescript
// Server Component - no 'use client'
export default async function Page() {
  const data = await fetchData() // Direct DB/API call
  return <List data={data} />
}
```

## Client Components

```typescript
'use client'
// Only when needed: interactivity, browser APIs, hooks
export function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>
}
```

## Data Fetching

- Server: `fetch()` with caching
- Client: React Query / SWR
- Revalidation: `revalidatePath()` / `revalidateTag()`
