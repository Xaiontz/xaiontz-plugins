# CI/CD Pipeline Templates

GitHub Actions workflows for automated Pulumi deployments. Three workflows handle production, preview, and cleanup.

## Prerequisites

The following GitHub Actions secrets must be configured in the repository:

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | Service principal client ID (federated credentials for OIDC) |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

The service principal needs:
- `Contributor` on the target resource group
- `Key Vault Crypto User` on `xaiontz-shared-kv`
- `Storage Blob Data Contributor` on `xaiontzsharedfiles`
- `Contributor` on the shared PostgreSQL server resource group (for preview database creation)

---

## .github/workflows/infra.yml

Production deployment. Triggers on pushes to `main` that touch `infra/**`, or manually.

```yaml
name: Infrastructure

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - 'infra/**'

permissions:
  id-token: write
  contents: read

jobs:
  pulumi-up:
    name: Pulumi Up (prod)
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v5

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Install Pulumi CLI
        uses: pulumi/actions@v6

      - name: Install infra dependencies
        working-directory: infra
        run: npm ci

      - name: Pulumi login to Azure Blob backend
        working-directory: infra
        env:
          AZURE_STORAGE_ACCOUNT: xaiontzsharedfiles
          AZURE_KEYVAULT_AUTH_VIA_CLI: "true"
        run: pulumi login azblob://pulumi-{{REPO_NAME}}

      - name: Select Pulumi stack
        working-directory: infra
        env:
          AZURE_STORAGE_ACCOUNT: xaiontzsharedfiles
          AZURE_KEYVAULT_AUTH_VIA_CLI: "true"
        run: pulumi stack select prod

      - name: Pulumi up
        working-directory: infra
        env:
          AZURE_STORAGE_ACCOUNT: xaiontzsharedfiles
          AZURE_KEYVAULT_AUTH_VIA_CLI: "true"
        run: pulumi up --yes
```

---

## .github/workflows/infra-preview.yml

Preview deployment. Triggers on every push to any non-main branch (no path filter -- the preview environment must exist for the app to run regardless of whether infra code changed). Creates a `preview-{branch}` Pulumi stack that deploys a branch-specific Container App and database.

```yaml
name: Infrastructure Preview

on:
  push:
    branches-ignore:
      - main

permissions:
  id-token: write
  contents: read

concurrency:
  group: infra-preview-${{ github.ref_name }}
  cancel-in-progress: true

env:
  AZURE_STORAGE_ACCOUNT: xaiontzsharedfiles
  AZURE_KEYVAULT_AUTH_VIA_CLI: "true"
  PULUMI_BACKEND: azblob://pulumi-{{REPO_NAME}}
  KV_SECRETS: "azurekeyvault://xaiontz-shared-kv.vault.azure.net/keys/pulumi-{{REPO_NAME}}"

jobs:
  preview-deploy:
    name: Deploy Preview
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v5

      - name: Sanitize branch name
        id: branch
        run: |
          SLUG=$(echo "${{ github.ref_name }}" | tr '/' '-' | tr '.' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
          echo "slug=$SLUG" >> "$GITHUB_OUTPUT"
          echo "stack=preview-$SLUG" >> "$GITHUB_OUTPUT"

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Install Pulumi CLI
        uses: pulumi/actions@v6

      - name: Install infra dependencies
        working-directory: infra
        run: npm ci

      - name: Pulumi login
        working-directory: infra
        run: pulumi login ${{ env.PULUMI_BACKEND }}

      - name: Create or select preview stack
        working-directory: infra
        run: |
          pulumi stack select ${{ steps.branch.outputs.stack }} 2>/dev/null || \
          pulumi stack init ${{ steps.branch.outputs.stack }} \
            --secrets-provider="${{ env.KV_SECRETS }}" \
            --copy-config-from prod

      - name: Pulumi up
        working-directory: infra
        run: pulumi up --yes

      - name: Print preview URL
        working-directory: infra
        run: |
          FQDN=$(pulumi stack output containerAppFqdn 2>/dev/null || echo "pending")
          echo "### Preview deployed" >> "$GITHUB_STEP_SUMMARY"
          echo "URL: https://$FQDN" >> "$GITHUB_STEP_SUMMARY"
```

---

## .github/workflows/infra-preview-cleanup.yml

Cleanup workflow. Triggers when a PR is closed (merged or abandoned). Destroys the preview Pulumi stack and removes it.

```yaml
name: Infrastructure Preview Cleanup

on:
  pull_request:
    types: [closed]

permissions:
  id-token: write
  contents: read

env:
  AZURE_STORAGE_ACCOUNT: xaiontzsharedfiles
  AZURE_KEYVAULT_AUTH_VIA_CLI: "true"
  PULUMI_BACKEND: azblob://pulumi-{{REPO_NAME}}

jobs:
  preview-cleanup:
    name: Destroy Preview
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v5

      - name: Sanitize branch name
        id: branch
        run: |
          SLUG=$(echo "${{ github.head_ref }}" | tr '/' '-' | tr '.' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
          echo "slug=$SLUG" >> "$GITHUB_OUTPUT"
          echo "stack=preview-$SLUG" >> "$GITHUB_OUTPUT"

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Install Pulumi CLI
        uses: pulumi/actions@v6

      - name: Install infra dependencies
        working-directory: infra
        run: npm ci

      - name: Pulumi login
        working-directory: infra
        run: pulumi login ${{ env.PULUMI_BACKEND }}

      - name: Select preview stack
        id: select
        working-directory: infra
        continue-on-error: true
        run: pulumi stack select ${{ steps.branch.outputs.stack }}

      - name: Destroy preview resources
        if: steps.select.outcome == 'success'
        working-directory: infra
        run: pulumi destroy --yes

      - name: Remove preview stack
        if: steps.select.outcome == 'success'
        working-directory: infra
        run: pulumi stack rm ${{ steps.branch.outputs.stack }} --yes
```

The cleanup workflow uses `continue-on-error` on the stack select step so it exits gracefully if the preview stack was already removed or never created.
