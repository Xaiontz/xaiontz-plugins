# Project Structure

Canonical directory layout for an SME Stack application. The three route groups — `(public)`, `(portal)`, `(internal)` — are the architectural core.

## Directory layout

```
$APP_NAME/
├── src/
│   ├── app/
│   │   ├── (public)/              # Public website — no auth required
│   │   │   ├── layout.tsx         # Marketing layout (nav, footer)
│   │   │   ├── page.tsx           # Homepage
│   │   │   ├── about/page.tsx
│   │   │   ├── services/page.tsx
│   │   │   └── contact/page.tsx
│   │   │
│   │   ├── (portal)/              # Client portal — authenticated clients
│   │   │   ├── layout.tsx         # Portal layout (sidebar nav, user menu)
│   │   │   ├── dashboard/page.tsx
│   │   │   ├── appointments/page.tsx
│   │   │   ├── documents/page.tsx
│   │   │   └── messages/page.tsx
│   │   │
│   │   ├── (internal)/            # Internal tools — SSO-authenticated employees
│   │   │   ├── layout.tsx         # Internal layout (admin nav, breadcrumbs)
│   │   │   ├── dashboard/page.tsx
│   │   │   ├── clients/page.tsx
│   │   │   ├── scheduling/page.tsx
│   │   │   └── reports/page.tsx
│   │   │
│   │   ├── (auth)/                # Auth pages (login, register, error)
│   │   │   ├── login/page.tsx
│   │   │   ├── register/page.tsx
│   │   │   └── error/page.tsx
│   │   │
│   │   ├── api/
│   │   │   └── auth/[...nextauth]/route.ts
│   │   │
│   │   ├── layout.tsx             # Root layout (html, body, fonts, providers)
│   │   └── globals.css            # CSS variables, Tailwind imports
│   │
│   ├── auth.ts                    # Auth.js configuration
│   ├── middleware.ts              # Route protection
│   │
│   ├── db/
│   │   ├── index.ts               # Database connection singleton
│   │   ├── schema/
│   │   │   ├── index.ts           # Barrel export of all tables
│   │   │   ├── auth.ts            # Auth.js tables (users, accounts, sessions)
│   │   │   └── app.ts             # Application-specific tables
│   │   └── seed.ts                # Optional seed script
│   │
│   ├── components/
│   │   ├── ui/                    # shadcn/ui components (auto-generated)
│   │   ├── public/                # Public-area specific components
│   │   ├── portal/                # Portal-area specific components
│   │   ├── internal/              # Internal-area specific components
│   │   └── shared/                # Cross-area shared components
│   │
│   ├── lib/
│   │   ├── utils.ts               # shadcn cn() helper
│   │   └── constants.ts           # App-wide constants
│   │
│   └── types/
│       └── next-auth.d.ts         # Auth.js session type augmentation
│
├── drizzle/                       # Generated migrations (by drizzle-kit)
├── drizzle.config.ts              # Drizzle Kit configuration
├── .env.example                   # Environment variable template
├── .env.local                     # Local environment (gitignored)
├── next.config.ts
├── tailwind.config.ts             # Only if Tailwind v4 CSS-only config isn't sufficient
├── tsconfig.json
├── package.json
└── pnpm-lock.yaml
```

## Route group conventions

### `(public)` — Public website

- No authentication required
- Marketing-oriented layout with navigation bar and footer
- Static or ISR pages where possible for performance
- SEO metadata on every page

### `(portal)` — Client portal

- Requires authenticated session (any provider)
- Sidebar navigation with user context
- Client-specific data only (filtered by session user ID)
- Protected by middleware: redirects to `/login` if unauthenticated

### `(internal)` — Employee internal tools

- Requires SSO-authenticated employee session (`role === "employee"`)
- Admin-style navigation with breadcrumbs
- Full data access (all clients, scheduling, reports)
- Protected by middleware: redirects to `/login` if unauthenticated, `/unauthorized` if wrong role

### `(auth)` — Authentication pages

- Shared login/register/error pages
- Login page shows appropriate providers based on context
- No layout chrome — clean, focused auth experience

## Naming conventions

- **Files**: kebab-case for directories, PascalCase for components (`UserMenu.tsx`), camelCase for utilities (`getSession.ts`)
- **Route segments**: kebab-case (`client-details`, not `clientDetails`)
- **Database tables**: snake_case (`contact_submissions`, not `contactSubmissions`)
- **Schema files**: Group by domain, not by table (`auth.ts` contains all auth tables, `app.ts` contains app tables)
- **Components**: Scope to area when area-specific (`components/portal/AppointmentCard.tsx`), use `shared/` when used across areas

## Shared vs area-specific code

- `components/ui/` — shadcn components, never modified per area
- `components/shared/` — custom components used in 2+ areas (e.g. `DataTable`, `StatusBadge`)
- `components/<area>/` — components used only within that area
- `lib/` — utilities and constants shared across all areas
- `db/` — database layer is shared; access control happens at the route/middleware level, not the DB layer
