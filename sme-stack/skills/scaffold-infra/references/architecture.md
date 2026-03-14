# Infrastructure Architecture

Overview of the Azure + Cloudflare infrastructure provisioned by the SME Stack for each project. All resources are managed with Pulumi (TypeScript).

## Inputs

| Parameter | Example | Description |
|---|---|---|
| `REPO_NAME` | `xelante-drmiriam` | Git repo name. Base for resource group and Pulumi backend naming. |
| `PROJECT_SLUG` | `drmiriam` | Short identifier for Azure resources. No hyphens in storage account names. |
| `DOMAIN` | `drmiriam.co.uk` | Custom domain for the site, certificates, DNS, and email. |
| `AZURE_LOCATION` | `uksouth` | Azure region for all resources. |
| `EMAIL_SENDER_DISPLAY_NAME` | `Dr Miriam Website` | Display name shown on outbound emails. |

## Naming Derivation

Every resource name is deterministically derived from the three core inputs:

| Resource | Name Pattern | Example |
|---|---|---|
| Resource Group | `{{REPO_NAME}}-rg` | `xelante-drmiriam-rg` |
| Pulumi blob container | `pulumi-{{REPO_NAME}}` | `pulumi-xelante-drmiriam` |
| Key Vault encryption key | `pulumi-{{REPO_NAME}}` | `pulumi-xelante-drmiriam` |
| Pulumi project name | `{{PROJECT_SLUG}}` | `drmiriam` |
| Database (prod) | `{{PROJECT_SLUG}}` | `drmiriam` |
| Database (preview) | `{{PROJECT_SLUG}}-{branch}` | `drmiriam-feature-login` |
| Storage Account | `{{PROJECT_SLUG}}media` | `drmiriammedia` |
| Blob Container | `media` | `media` |
| Managed Identity | `{{PROJECT_SLUG}}-identity` | `drmiriam-identity` |
| Container App (prod) | `{{PROJECT_SLUG}}-app` | `drmiriam-app` |
| Container App (preview) | `{{PROJECT_SLUG}}-app-{branch}` | `drmiriam-app-feature-login` |
| Container Apps Environment | `{{PROJECT_SLUG}}-env` | `drmiriam-env` |
| Certificate | `{{DOMAIN_HYPHENATED}}-origin` | `drmiriam-co-uk-origin` |
| Email Service | `{{REPO_NAME}}-acs-email` | `xelante-drmiriam-acs-email` |
| Communication Service | `{{REPO_NAME}}-acs` | `xelante-drmiriam-acs` |
| Email Domain | `{{DOMAIN}}` | `drmiriam.co.uk` |
| Docker Compose DB | `{{PROJECT_SLUG}}` | `drmiriam` |
| Container image (prod) | `{{sharedAcrLoginServer}}/{{PROJECT_SLUG}}:main-latest` | `xaiontzsharedacr.azurecr.io/drmiriam:main-latest` |
| Container image (preview) | `{{sharedAcrLoginServer}}/{{PROJECT_SLUG}}:{branch}-latest` | `xaiontzsharedacr.azurecr.io/drmiriam:feature-login-latest` |
| SERVER_URL (prod) | `https://{{DOMAIN}}` | `https://drmiriam.co.uk` |
| SERVER_URL (preview) | Auto-generated Container App FQDN | `https://drmiriam-app-feature-login.*.azurecontainerapps.io` |
| EMAIL_FROM_ADDRESS | `DoNotReply@{{DOMAIN}}` | `DoNotReply@drmiriam.co.uk` |

`DOMAIN_HYPHENATED` is `DOMAIN` with dots replaced by hyphens (e.g. `drmiriam.co.uk` -> `drmiriam-co-uk`).

## Shared Resources (Hardcoded)

These exist once across all Xaiontz projects and are referenced but never created by per-project infra:

| Resource | Name | Purpose |
|---|---|---|
| Resource Group | `xaiontz-shared-rg` | Hosts shared PG server and ACR |
| PostgreSQL Flexible Server | `xaiontz-shared-pg` | Shared database server; each project creates its own database |
| Container Registry | `xaiontzsharedacr` | Shared ACR for all container images |
| Key Vault | `xaiontz-shared-kv` | Stores Pulumi encryption keys |
| Storage Account | `xaiontzsharedfiles` | Pulumi state backend (blob storage) |

## Resource Topology

### Prod stack (main branch)

All resources are created:

```
Resource Group
├── Storage Account + Blob Container (media)
├── Managed Identity
│   ├── Role: AcrPull on shared ACR
│   ├── Role: Storage Blob Data Contributor on storage account
│   └── Role: Contributor on Communication Service
├── Container Apps Environment
│   └── Container App (depends on identity, roles, certificate, DNS)
│       └── TLS Certificate (Cloudflare Origin CA)
├── Email Service
│   ├── Email Domain (customer-managed)
│   │   └── Sender Username
│   └── Communication Service (linked to email domain)
└── Database (on shared PG server)
    ├── AAD Role (managed identity)
    └── Grants (privileges + schema ownership)

Cloudflare DNS
├── A Record (apex → Container Apps Environment static IP, proxied)
└── TXT Record (asuid → Azure domain verification ID)
```

### Preview stacks (non-main branches)

Only branch-specific resources are created. Everything else is referenced from the prod stack via `StackReference`:

```
Database: {slug}-{branch} (on shared PG server)
└── Grants (privileges + schema ownership for existing identity)

Container App: {slug}-app-{branch} (in prod's Container Apps Environment)
├── Uses prod's Managed Identity
├── Uses prod's Storage Account
├── Uses prod's ACS endpoint
├── Image tag: {branch}-latest
├── No custom domain (auto-generated FQDN)
└── No TLS certificate
```

## Preview Deployments

The infra code is stack-aware. Every resource file imports from `azure/stack.ts` to determine whether it is running in `prod` or a `preview-{branch}` stack.

### Stack naming

| Stack | Branch | Created by |
|---|---|---|
| `prod` | `main` | `infra.yml` workflow or manual `pulumi up` |
| `preview-{branch}` | any non-main | `infra-preview.yml` workflow on every push |

Branch names are sanitised for stack names: `/` and `.` are replaced with `-`, converted to lowercase, and truncated to 30 characters.

### Stack-aware resource pattern

Each resource file uses `isProd` from `azure/stack.ts` to decide whether to create a resource or reference it from the prod stack:

```typescript
import { isProd, fromProd } from "./stack";

// Prod: create the resource
const env = isProd
  ? new app.ManagedEnvironment("env", { ... })
  : undefined;

// All stacks: export the environment ID
export const environmentId = isProd
  ? env!.id
  : fromProd<string>("environmentId");
```

### Prod stack outputs consumed by preview stacks

The `index.ts` exports additional values when running in prod so that preview stacks can reference them via `StackReference`:

| Export | Type | Used by preview for |
|---|---|---|
| `environmentId` | `Output<string>` | Deploying Container App into the shared environment |
| `identityId` | `Output<string>` | Assigning the managed identity to the Container App |
| `clientId` | `Output<string>` | `AZURE_CLIENT_ID` env var |
| `identityNameValue` | `string` | `AZURE_PG_USER` env var and DB grants |
| `acsEndpoint` | `Output<string>` | `ACS_ENDPOINT` env var |
| `resourceGroupName` | `string` | Resource group for the Container App |
| `storageAccountName` | `Output<string>` | `AZURE_STORAGE_ACCOUNT_NAME` env var |

### Preview stack config

Preview stacks are initialised with `pulumi stack init --copy-config-from prod`, which copies all encrypted config (secrets) from the prod stack. This means preview environments automatically get `payloadSecret`, `entraAuthClientSecret`, etc.

### Auto-cleanup

When a PR is closed (merged or abandoned), the `infra-preview-cleanup.yml` workflow destroys the preview stack and removes it:

```
pulumi destroy --yes
pulumi stack rm preview-{branch} --yes
```

## Pulumi State Management

- **Backend**: Azure Blob Storage at `azblob://pulumi-{{REPO_NAME}}` in the `xaiontzsharedfiles` storage account
- **Secrets provider**: Azure Key Vault at `azurekeyvault://xaiontz-shared-kv.vault.azure.net/keys/pulumi-{{REPO_NAME}}`
- **Stack names**: `prod` and `preview-{branch}`

The `infra_login.ps1` script handles blob container login, KV key creation (if missing), and stack initialisation. It accepts an optional stack name argument (default `prod`).

## Pulumi Config Secrets

These are stored encrypted in `Pulumi.prod.yaml` and must be set after scaffolding. Preview stacks inherit these via `--copy-config-from prod`.

| Config Key | Description |
|---|---|
| `azure-native:location` | Azure region (set to `{{AZURE_LOCATION}}`) |
| `{{PROJECT_SLUG}}:payloadSecret` | Payload CMS secret (generate with `openssl rand -base64 32`) |
| `{{PROJECT_SLUG}}:cloudflareZoneId` | Cloudflare zone ID for the domain |
| `cloudflare:apiToken` | Cloudflare API token with DNS edit permissions |
| `{{PROJECT_SLUG}}:originCaKey` | Cloudflare Origin CA key (API User Service Key) |
| `{{PROJECT_SLUG}}:entraAuthClientSecret` | Microsoft Entra ID client secret |

## File Structure

```
infra/
├── index.ts                  # Entry point, imports all resources, exports stack outputs
├── Pulumi.yaml               # Project config
├── Pulumi.prod.yaml          # Stack config (created by pulumi after first secret set)
├── package.json
├── tsconfig.json
├── infra_login.ps1           # Local login + stack init script (accepts optional stack name)
├── infra_up.ps1              # Wrapper to login + pulumi up
├── azure/
│   ├── stack.ts              # Stack detection: isProd, branchName, fromProd() helper
│   ├── resource-group.ts     # Resource group (prod only)
│   ├── shared.ts             # References to shared Xaiontz resources
│   ├── database.ts           # PostgreSQL database + AAD role + grants (all stacks)
│   ├── storage.ts            # Storage account + media blob container (prod only)
│   ├── identity.ts           # User-assigned managed identity (prod only)
│   ├── roles.ts              # RBAC role assignments (prod only)
│   ├── environment.ts        # Container Apps managed environment (prod only)
│   ├── certificate.ts        # Cloudflare Origin CA TLS certificate (prod only)
│   ├── email.ts              # Azure Communication Services / email (prod only)
│   └── container-app.ts      # Container App definition (all stacks, branch-aware)
├── cloudflare/
│   └── dns.ts                # DNS A record + TXT verification record (prod only)
└── local_dev/
    └── docker-compose.yml    # Local PostgreSQL for development
```
