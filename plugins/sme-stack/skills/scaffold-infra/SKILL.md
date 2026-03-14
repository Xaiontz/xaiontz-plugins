---
name: scaffold-infra
description: Scaffold Azure + Cloudflare infrastructure for an SME Stack application using Pulumi (TypeScript). Creates a complete infra/ directory with resource definitions, CI/CD pipelines (prod + preview branch deployments), and local dev setup.
---

# Scaffold Infrastructure

Step-by-step workflow to scaffold a Pulumi TypeScript project that provisions Azure Container Apps, PostgreSQL, Blob Storage, Azure Communication Services (email), Cloudflare DNS, and TLS certificates. Includes preview branch deployments with auto-cleanup.

Read [references/architecture.md](references/architecture.md) before starting to understand the naming conventions, resource topology, shared infrastructure assumptions, and preview deployment pattern.

## Inputs

Before starting, confirm these with the user:

- `REPO_NAME`: the git repository name, used for resource group and Pulumi backend naming (e.g. `xelante-drmiriam`)
- `PROJECT_SLUG`: short identifier for Azure resources — no hyphens allowed in storage account names (e.g. `drmiriam`)
- `DOMAIN`: custom domain for the site (e.g. `drmiriam.co.uk`)
- `AZURE_LOCATION`: Azure region (default `uksouth`)
- `EMAIL_SENDER_DISPLAY_NAME`: display name for outbound emails (e.g. `Dr Miriam Website`)

Derive `DOMAIN_HYPHENATED` by replacing dots with hyphens (e.g. `drmiriam.co.uk` -> `drmiriam-co-uk`).

## Workflow

### 1. Create directory structure

```
infra/
├── azure/
├── cloudflare/
└── local_dev/
```

### 2. Generate project configuration files

Read [references/project-config.md](references/project-config.md) for all templates.

Create these files, replacing `{{PLACEHOLDER}}` tokens with the collected inputs:

- `infra/Pulumi.yaml`
- `infra/package.json`
- `infra/tsconfig.json`
- `infra/infra_login.ps1`
- `infra/infra_up.ps1`
- `infra/local_dev/docker-compose.yml`

### 3. Generate Azure resource files

Read [references/azure-resources.md](references/azure-resources.md) for all templates.

Create each file in `infra/azure/`, replacing `{{PLACEHOLDER}}` tokens:

1. `stack.ts` — stack detection module (no replacements needed)
2. `resource-group.ts` — uses `REPO_NAME`
3. `shared.ts` — no replacements (hardcoded shared resource references)
4. `database.ts` — uses `PROJECT_SLUG`
5. `storage.ts` — uses `PROJECT_SLUG`
6. `identity.ts` — uses `PROJECT_SLUG`
7. `roles.ts` — no replacements (wires up RBAC from other modules)
8. `environment.ts` — uses `PROJECT_SLUG`
9. `certificate.ts` — uses `DOMAIN`, `DOMAIN_HYPHENATED`
10. `email.ts` — uses `REPO_NAME`, `DOMAIN`, `EMAIL_SENDER_DISPLAY_NAME`
11. `container-app.ts` — uses `PROJECT_SLUG`, `DOMAIN`, `EMAIL_SENDER_DISPLAY_NAME`

All resource files are stack-aware: they import `isProd` from `stack.ts` and conditionally create resources (prod) or reference them from the prod stack (preview). See the architecture reference for the full preview deployment pattern.

### 4. Generate Cloudflare DNS file

Read [references/cloudflare-dns.md](references/cloudflare-dns.md) for the template.

Create `infra/cloudflare/dns.ts`, replacing `{{DOMAIN}}`. This file is prod-only (guarded by `isProd`).

### 5. Generate entry point

The `infra/index.ts` template is at the bottom of [references/azure-resources.md](references/azure-resources.md). Create it, replacing `{{DOMAIN}}`.

The entry point imports all resource files and exports stack outputs. In prod, it exports additional values (`environmentId`, `identityId`, `clientId`, `storageAccountName`, `acsEndpoint`, `resourceGroupName`, `identityNameValue`) that preview stacks consume via Pulumi `StackReference`.

### 6. Generate CI/CD workflows

Read [references/ci-cd.md](references/ci-cd.md) for all three workflow templates.

Create these files, replacing `{{REPO_NAME}}`:

- `.github/workflows/infra.yml` — prod deployment (main branch, `infra/**` path filter)
- `.github/workflows/infra-preview.yml` — preview deployment (every push to non-main branches, no path filter)
- `.github/workflows/infra-preview-cleanup.yml` — preview cleanup (PR close, destroys preview stack)

### 7. Install dependencies

```bash
cd infra
pnpm install
```

### 8. Add infra to .gitignore

Ensure the project `.gitignore` includes:

```
infra/bin/
infra/node_modules/
```

### 9. Initial Pulumi login (inform user)

Tell the user to run the following from the `infra/` directory to initialise the Pulumi backend:

```powershell
.\infra_login.ps1
```

This will:
- Login to the Azure Blob Storage backend
- Create the Key Vault encryption key if it doesn't exist
- Initialise the `prod` stack

To login and target a preview stack instead:

```powershell
.\infra_login.ps1 preview-my-branch
```

### 10. Configure Pulumi secrets (inform user)

After login, the user must set these config values:

```bash
pulumi config set azure-native:location {{AZURE_LOCATION}}
pulumi config set --secret payloadSecret "$(openssl rand -base64 32)"
pulumi config set cloudflareZoneId <zone-id>
pulumi config set --secret cloudflare:apiToken <token>
pulumi config set --secret originCaKey <key>
pulumi config set --secret entraAuthClientSecret <secret>
```

And update `ENTRA_AUTH_CLIENT_ID` and `ENTRA_AUTH_TENANT_ID` in `container-app.ts` after creating the Entra ID app registration.

Preview stacks inherit config from prod via `pulumi stack init --copy-config-from prod` (handled automatically by the CI workflow).

## Post-scaffold

After scaffolding, confirm:
- `pnpm install` completes without errors in `infra/`
- All `{{PLACEHOLDER}}` tokens have been replaced (search the generated files)
- The directory structure matches [references/architecture.md](references/architecture.md)

Inform the user about:
- The `infra.mdc` rule that guides ongoing infrastructure development
- The three GitHub Actions workflows:
  - `infra.yml` — auto-deploys prod infra on `infra/**` changes to `main`
  - `infra-preview.yml` — auto-deploys preview environment on every push to non-main branches
  - `infra-preview-cleanup.yml` — auto-destroys preview environment on PR close
- The `infra_login.ps1` / `infra_up.ps1` scripts for local Pulumi operations
- The `local_dev/docker-compose.yml` for running PostgreSQL locally during development
- The preview deployment pattern: each branch gets its own database and Container App with an auto-generated FQDN
