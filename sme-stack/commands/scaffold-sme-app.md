---
name: scaffold-sme-app
description: Scaffold a new Next.js + Drizzle + Auth.js + shadcn application with multi-area auth (public site, client portal, internal tools). Creates project structure, database schema, auth config, and route protection.
---

# Scaffold SME App

Create a new full-stack application using the SME Stack recipe.

## Required inputs

Prompt the user for each before proceeding:

1. **App name** (lowercase kebab-case, e.g. `acme-portal`)
2. **Target directory** (default: `./<app-name>`)
3. **Auth providers** to configure:
   - SSO provider for employees (Microsoft Entra ID, Google Workspace, Okta, or none)
   - Client auth method (magic link via Resend, credentials, or both)
4. **Database** connection string or use local Postgres default (`postgresql://localhost:5432/<app-name>`)

## Execution

Use the `scaffold-sme-app` skill to execute the scaffolding workflow. Read the skill's SKILL.md and follow it step by step, loading reference files as directed.
