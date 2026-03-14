# SME Stack

Scaffold and develop Next.js + Drizzle + Auth.js + shadcn applications with multi-area auth (public site, client portal, internal tools).

## Installation

Copy to your local plugins directory for global availability:

```bash
cp -r .cursor/plugins/sme-stack ~/.cursor/plugins/local/sme-stack
```

Or keep it in your repository's `.cursor/plugins/` for project-scoped use.

## Components

### Skills

| Skill | Description |
|:------|:------------|
| `scaffold-sme-app` | Scaffold a new full-stack application with route groups, database schema, auth config, and route protection |

### Rules

| Rule | Description |
|:-----|:------------|
| `drizzle` | Drizzle ORM conventions for schema, queries, and migrations |
| `auth` | Auth.js session handling, role-based access, and security patterns |
| `project-structure` | Route group boundaries, file placement, and naming conventions |

### Commands

| Command | Description |
|:--------|:------------|
| `scaffold-sme-app` | Create a new SME Stack application interactively |

## Typical flow

1. Use `/scaffold-sme-app` with an app name and auth preferences.
2. The agent scaffolds the project following the skill workflow.
3. Rules activate automatically during ongoing development to enforce conventions.

## Tech stack

- **Next.js 15** (App Router)
- **Drizzle ORM** + PostgreSQL
- **Auth.js v5** (NextAuth) with multi-provider support
- **Tailwind CSS v4** + **shadcn/ui**
- **pnpm** package manager

## License

MIT
