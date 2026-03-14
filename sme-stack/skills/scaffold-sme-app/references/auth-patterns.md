# Auth Patterns

Multi-area authentication with Auth.js v5 (NextAuth), supporting separate auth flows for clients (magic link / credentials) and employees (SSO).

## Auth.js configuration

```typescript
// src/auth.ts
import NextAuth from "next-auth"
import { DrizzleAdapter } from "@auth/drizzle-adapter"
import { db } from "@/db"
import * as schema from "@/db/schema"

// Import providers based on project requirements
import MicrosoftEntraId from "next-auth/providers/microsoft-entra-id"
import Resend from "next-auth/providers/resend"
import Credentials from "next-auth/providers/credentials"

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: DrizzleAdapter(db, {
    usersTable: schema.users,
    accountsTable: schema.accounts,
    sessionsTable: schema.sessions,
    verificationTokensTable: schema.verificationTokens,
  }),
  session: { strategy: "jwt" },
  providers: [
    // Employee SSO — configure based on SSO_PROVIDER input
    MicrosoftEntraId({
      clientId: process.env.AUTH_MICROSOFT_ENTRA_ID_ID,
      clientSecret: process.env.AUTH_MICROSOFT_ENTRA_ID_SECRET,
      tenantId: process.env.AUTH_MICROSOFT_ENTRA_ID_TENANT_ID,
    }),

    // Client auth — magic link
    Resend({
      from: process.env.EMAIL_FROM,
    }),

    // Client auth — credentials (optional, less secure)
    // Credentials({
    //   credentials: {
    //     email: { label: "Email", type: "email" },
    //     password: { label: "Password", type: "password" },
    //   },
    //   authorize: async (credentials) => {
    //     // Validate credentials against DB
    //     // Return user object or null
    //   },
    // }),
  ],
  callbacks: {
    async jwt({ token, account, user }) {
      // Tag role on first sign-in based on auth provider
      if (account) {
        token.role = account.provider === "microsoft-entra-id" ? "employee" : "client"
      }
      // Persist role from DB user record
      if (user) {
        token.role = (user as any).role ?? token.role
      }
      return token
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.sub!
        session.user.role = token.role as string
      }
      return session
    },
  },
  pages: {
    signIn: "/login",
    error: "/error",
  },
})
```

## Route handler

```typescript
// src/app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/auth"

export const { GET, POST } = handlers
```

## TypeScript session augmentation

```typescript
// src/types/next-auth.d.ts
import "next-auth"

declare module "next-auth" {
  interface Session {
    user: {
      id: string
      name?: string | null
      email?: string | null
      image?: string | null
      role: string
    }
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    role?: string
  }
}
```

## Route protection middleware

```typescript
// src/middleware.ts
import { auth } from "@/auth"

export default auth((req) => {
  const { pathname } = req.nextUrl
  const session = req.auth

  // Portal routes — any authenticated user
  if (pathname.startsWith("/portal")) {
    if (!session) {
      return Response.redirect(new URL("/login?callbackUrl=" + pathname, req.url))
    }
  }

  // Internal routes — employees only
  if (pathname.startsWith("/internal")) {
    if (!session) {
      return Response.redirect(new URL("/login?callbackUrl=" + pathname, req.url))
    }
    if (session.user.role !== "employee") {
      return Response.redirect(new URL("/unauthorized", req.url))
    }
  }
})

export const config = {
  matcher: ["/portal/:path*", "/internal/:path*"],
}
```

## Using auth in Server Components

```typescript
import { auth } from "@/auth"
import { redirect } from "next/navigation"

export default async function PortalDashboard() {
  const session = await auth()
  if (!session) redirect("/login")

  return <h1>Welcome, {session.user.name}</h1>
}
```

## Using auth in Server Actions

```typescript
"use server"

import { auth } from "@/auth"

export async function createAppointment(data: FormData) {
  const session = await auth()
  if (!session) throw new Error("Unauthorized")

  // session.user.id is the authenticated user
  // session.user.role determines access level
}
```

## Using auth in Client Components

```typescript
"use client"

import { useSession } from "next-auth/react"

export function UserMenu() {
  const { data: session, status } = useSession()

  if (status === "loading") return <Skeleton />
  if (!session) return <LoginButton />

  return <div>{session.user.name} ({session.user.role})</div>
}
```

Wrap the app with `SessionProvider` in the root layout:

```typescript
// src/app/layout.tsx
import { SessionProvider } from "next-auth/react"

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>{children}</SessionProvider>
      </body>
    </html>
  )
}
```

## Provider selection guide

| User type | Recommended provider | Notes |
|---|---|---|
| Employees (corp SSO) | `microsoft-entra-id`, `google`, or `okta` | Auto-assigns `role: "employee"` |
| Clients (passwordless) | `resend` (magic link) | Recommended — no passwords to manage |
| Clients (password) | `credentials` | Requires password hashing (bcrypt), less secure |
| Both client methods | `resend` + `credentials` | Let user choose on login page |

## Security checklist

- Always use `session: { strategy: "jwt" }` for serverless/edge compatibility
- Never expose `token.sub` or raw JWT to the client — use `session.user.id`
- Set `NEXTAUTH_SECRET` to a strong random value (min 32 chars)
- Use `callbackUrl` parameter to redirect users back after login
- Rate-limit the magic link endpoint in production
- The Drizzle adapter handles token cleanup automatically
