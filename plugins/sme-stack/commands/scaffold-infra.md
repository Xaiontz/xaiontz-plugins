---
name: scaffold-infra
description: Scaffold Azure + Cloudflare infrastructure (Pulumi TypeScript) for an SME Stack application. Creates resource group, database, storage, container app, email, DNS, TLS certificates, CI/CD pipeline, and local dev setup.
---

# Scaffold Infrastructure

Create Pulumi infrastructure-as-code for deploying an SME Stack application to Azure with Cloudflare DNS.

## Required inputs

Prompt the user for each before proceeding:

1. **Repo name** (e.g. `xelante-drmiriam`) — used for resource group and Pulumi backend naming
2. **Project slug** (short identifier, e.g. `drmiriam`) — used for Azure resource names; no hyphens for storage account compatibility
3. **Domain** (e.g. `drmiriam.co.uk`) — custom domain for the site
4. **Azure location** (default: `uksouth`) — Azure region
5. **Email sender display name** (e.g. `Dr Miriam Website`) — shown on outbound emails

## Execution

Use the `scaffold-infra` skill to execute the scaffolding workflow. Read the skill's SKILL.md and follow it step by step, loading reference files as directed.
