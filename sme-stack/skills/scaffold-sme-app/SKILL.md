---
name: scaffold-sme-app
description: Scaffold a new Next.js + Drizzle + Auth.js + shadcn application with multi-area auth. Use when creating a new full-stack project that needs a public website, client portal, and internal tools area with separate auth flows.
---

# Scaffold SME App

Step-by-step workflow to scaffold a production-ready Next.js application with Drizzle ORM, Auth.js, and shadcn/ui.

Read [references/stack-decisions.md](references/stack-decisions.md) before starting to understand why each technology was chosen — this context helps make consistent decisions when the recipe doesn't cover an edge case.

## Inputs

Before starting, confirm these with the user:

- `APP_NAME`: lowercase kebab-case (e.g. `acme-portal`)
- `TARGET_DIR`: where to create the project (default `./$APP_NAME`)
- `SSO_PROVIDER`: employee SSO provider or `none`
- `CLIENT_AUTH`: `magic-link`, `credentials`, or `both`
- `DATABASE_URL`: Postgres connection string (default `postgresql://localhost:5432/$APP_NAME`)

## Workflow

### 1. Initialize project

```bash
pnpm create next-app@latest $APP_NAME --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --turbopack
cd $APP_NAME
```

### 2. Install core dependencies

```bash
pnpm add drizzle-orm postgres
pnpm add -D drizzle-kit @types/node
pnpm add next-auth@beta @auth/drizzle-adapter
pnpm add sharp
```

If `CLIENT_AUTH` includes magic link:
```bash
pnpm add resend
```

### 3. Set up Drizzle ORM

Read [references/drizzle-patterns.md](references/drizzle-patterns.md) for schema conventions and migration workflow.

- Create `src/db/index.ts` — database connection singleton
- Create `src/db/schema/` — schema directory with table definitions
- Create `drizzle.config.ts` — Drizzle Kit configuration
- Create Auth.js required tables (users, accounts, sessions, verification tokens)
- Add scripts to `package.json`:
  ```json
  "db:generate": "drizzle-kit generate",
  "db:migrate": "drizzle-kit migrate",
  "db:push": "drizzle-kit push",
  "db:studio": "drizzle-kit studio"
  ```

### 4. Set up Auth.js

Read [references/auth-patterns.md](references/auth-patterns.md) for multi-provider setup and role-based access.

- Create `src/auth.ts` — Auth.js configuration with Drizzle adapter
- Configure providers based on user inputs (`SSO_PROVIDER`, `CLIENT_AUTH`)
- Add JWT callback for role tagging based on auth provider
- Create `src/app/api/auth/[...nextauth]/route.ts` — Auth.js route handler
- Augment session types in `src/types/next-auth.d.ts`

### 5. Create route group structure

Read [references/project-structure.md](references/project-structure.md) for full directory layout and conventions.

Create three route groups with separate layouts:

- `src/app/(public)/` — public website, no auth required
  - `layout.tsx` — public layout with marketing nav/footer
  - `page.tsx` — homepage
- `src/app/(portal)/` — client portal, requires authenticated client
  - `layout.tsx` — portal layout with client navigation
  - `dashboard/page.tsx` — client dashboard
- `src/app/(internal)/` — employee tools, requires SSO-authenticated employee
  - `layout.tsx` — internal layout with admin navigation
  - `dashboard/page.tsx` — employee dashboard

### 6. Add route protection middleware

Create `src/middleware.ts`:
- `/portal/*` routes require any authenticated session
- `/internal/*` routes require `role === "employee"`
- All other routes are public

### 7. Install and configure shadcn/ui

Read [references/ui-conventions.md](references/ui-conventions.md) for theming conventions.

```bash
pnpm dlx shadcn@latest init
```

Install commonly needed components:
```bash
pnpm dlx shadcn@latest add button card input label form separator
```

Set up CSS variable theming in `src/app/globals.css` with light and dark mode.

### 8. Create initial DB schema

Beyond Auth.js tables, create an example app table to demonstrate the pattern:
- `src/db/schema/auth.ts` — Auth.js tables (users, accounts, sessions, verificationTokens)
- `src/db/schema/app.ts` — App-specific tables (example: contacts table)
- `src/db/schema/index.ts` — barrel export of all schema

### 9. Generate initial migration

```bash
pnpm db:generate
```

Review the generated SQL in `drizzle/` before applying.

### 10. Create environment template

Create `.env.example` with all required variables:
```env
DATABASE_URL=postgresql://localhost:5432/$APP_NAME

NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=  # generate with: openssl rand -base64 32

# SSO provider (if applicable)
AUTH_MICROSOFT_ENTRA_ID_ID=
AUTH_MICROSOFT_ENTRA_ID_SECRET=
AUTH_MICROSOFT_ENTRA_ID_TENANT_ID=

# Email provider (if applicable)
RESEND_API_KEY=
EMAIL_FROM=noreply@example.com
```

Omit provider-specific variables that don't apply based on user inputs.

### 11. Create project README

Generate a README.md with:
- Project name and description
- Prerequisites (Node.js, pnpm, Postgres)
- Setup steps (clone, install, env, migrate, run)
- Project structure overview
- Available scripts

## Post-scaffold

After scaffolding, confirm:
- `pnpm dev` starts without errors
- `pnpm build` completes successfully
- Database migration applies cleanly

Inform the user about the plugin's development rules (`drizzle.mdc`, `auth.mdc`, `project-structure.mdc`) that will guide ongoing development.
