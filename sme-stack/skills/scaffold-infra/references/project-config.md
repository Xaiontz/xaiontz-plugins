# Project Configuration Templates

Parameterized templates for Pulumi project files, scripts, and local development setup.

---

## Pulumi.yaml

```yaml
name: {{PROJECT_SLUG}}
runtime:
  name: nodejs
  options:
    typescript: true
description: Infrastructure for {{PROJECT_SLUG}} (Azure + Cloudflare)
```

---

## package.json

```json
{
  "name": "{{PROJECT_SLUG}}-infra",
  "version": "1.0.0",
  "description": "Infrastructure for {{PROJECT_SLUG}} (Azure + Cloudflare)",
  "main": "index.ts",
  "scripts": {
    "up": "pulumi up",
    "preview": "pulumi preview",
    "destroy": "pulumi destroy"
  },
  "dependencies": {
    "@pulumi/azure-native": "^3.14.0",
    "@pulumi/cloudflare": "^6",
    "@pulumi/command": "^1.0.0",
    "@pulumi/pulumi": "^3",
    "@pulumi/tls": "^5.3.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0"
  }
}
```

---

## tsconfig.json

No parameters — this file is static.

```json
{
  "compilerOptions": {
    "strict": true,
    "outDir": "bin",
    "target": "es2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "sourceMap": true,
    "experimentalDecorators": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true
  },
  "include": ["index.ts", "azure/**/*.ts", "cloudflare/**/*.ts"]
}
```

---

## infra_login.ps1

Accepts an optional stack name argument. Defaults to `prod`. Use `.\infra_login.ps1 preview-my-branch` to target a preview stack.

```powershell
param(
  [string]$Stack = "prod"
)

$env:AZURE_STORAGE_ACCOUNT = "xaiontzsharedfiles"
$env:AZURE_KEYVAULT_AUTH_VIA_CLI = "true"
$kvSecrets = "azurekeyvault://xaiontz-shared-kv.vault.azure.net/keys/pulumi-{{REPO_NAME}}"

# Ensure KV key exists (only create if missing)
az keyvault key show --vault-name xaiontz-shared-kv --name pulumi-{{REPO_NAME}} 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { az keyvault key create --vault-name xaiontz-shared-kv --name pulumi-{{REPO_NAME}} --kty RSA }

pulumi login azblob://pulumi-{{REPO_NAME}}
pulumi stack select $Stack 2>$null
if ($LASTEXITCODE -ne 0) {
  if ($Stack -eq "prod") {
    pulumi stack init prod --secrets-provider=$kvSecrets
  } else {
    pulumi stack init $Stack --secrets-provider=$kvSecrets --copy-config-from prod
  }
}
```

---

## infra_up.ps1

Accepts an optional stack name argument, forwarded to `infra_login.ps1`. Defaults to `prod`.

```powershell
param(
  [string]$Stack = "prod"
)

.\infra_login.ps1 -Stack $Stack
pulumi up
```

---

## local_dev/docker-compose.yml

```yaml
services:
  db:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: {{PROJECT_SLUG}}
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```
