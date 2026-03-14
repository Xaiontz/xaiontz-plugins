# Stack Decisions

Rationale behind each technology choice in the SME Stack. Read this before scaffolding to understand the "why" — it helps make consistent decisions when the recipe doesn't cover an edge case.

## Next.js 15 (App Router)

The dominant React meta-framework. Widest LLM training data coverage of any React framework. App Router provides:
- Server Components by default (better performance, direct DB access)
- Route groups for multi-area architecture without URL nesting
- Middleware for auth enforcement at the edge
- Built-in image optimization, fonts, metadata API

## Drizzle ORM over Prisma

| Concern | Drizzle | Prisma |
|---|---|---|
| Schema language | TypeScript (no separate DSL) | `.prisma` file (separate language) |
| Code generation step | None — schema changes take effect immediately | `prisma generate` required after every schema change |
| Query API | SQL-adjacent — LLMs transfer SQL knowledge directly | Prisma-specific nesting syntax |
| Runtime weight | Pure JavaScript, no binary engine | Rust binary engine (cold start, platform-specific) |
| AI agent reliability | Higher — no codegen step to forget, no DSL to context-switch | Lower — agents forget `generate`, mix up nesting |

Drizzle's SQL-adjacent API means an LLM that knows SQL (all of them) can write Drizzle intuitively. Prisma's query API (`findMany`, `include`, `some`/`every`/`none`) is a unique grammar that must be learned specifically.

**Exception**: If MS SQL Server is required, use Prisma — Drizzle has no MSSQL adapter.

## Drizzle ORM over Payload CMS

Payload wraps Drizzle internally (`@payloadcms/drizzle`). Using Drizzle directly eliminates:
- Admin panel overhead (unused when AI agents manage content in code)
- Import map generation after component changes
- 9+ `@payloadcms/*` packages in the dependency tree
- Payload's schema ownership (naming conventions, `_status`, `_rels`, `payload_locked_documents`)
- Build-time overhead from admin panel compilation

Payload is worth considering when a non-technical user needs a web UI for content editing. For AI-agent-driven development, it adds friction without proportional benefit.

## Auth.js (NextAuth v5) over custom auth

- 80+ built-in providers (Entra ID, Google, GitHub, Okta, etc.)
- First-class Drizzle adapter — auth tables managed alongside app tables
- JWT + session strategies with middleware integration
- Magic link / email auth via Resend provider
- Session type augmentation for TypeScript
- Multi-provider support in a single config (SSO for employees + credentials/magic link for clients)

Building custom auth means reinventing session management, CSRF protection, token rotation, and provider-specific OAuth flows.

## Tailwind CSS v4 + shadcn/ui

- Tailwind v4: CSS-first configuration, no `tailwind.config.js`, faster builds
- shadcn/ui: Copy-paste components (not a dependency), full control, CSS variable theming
- Both extremely well-represented in LLM training data
- CSS variable theming enables multi-brand support without code changes

## PostgreSQL

- Most capable open-source relational database
- Native JSON/JSONB, full-text search, GIS, array types
- Drizzle has first-class Postgres support (`drizzle-orm/pg-core`)
- Azure, AWS, GCP all offer managed Postgres
- Excellent tooling ecosystem (pgAdmin, Drizzle Studio, DBeaver)

## pnpm over npm/yarn

- Strict dependency resolution (no phantom dependencies)
- Efficient disk usage via content-addressable storage
- Native workspace support for monorepos
- Fastest install times of the three
