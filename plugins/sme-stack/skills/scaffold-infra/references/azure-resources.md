# Azure Resource Templates

Parameterized Pulumi TypeScript templates for all Azure resources. Replace `{{PLACEHOLDER}}` tokens with values derived from user inputs (see [architecture.md](architecture.md) for the naming table).

All resource files are stack-aware: they import `isProd` from `azure/stack.ts` to conditionally create resources in prod or reference them from the prod stack in preview mode.

---

## azure/stack.ts

Central module imported by every other file. Detects whether we are running in the `prod` stack or a `preview-{branch}` stack, and provides a helper to read outputs from the prod stack.

No parameters — the `StackReference` path uses the Pulumi project name from `Pulumi.yaml`.

```typescript
import * as pulumi from "@pulumi/pulumi";

const stack = pulumi.getStack();
export const isProd = stack === "prod";
export const branchName = isProd
  ? "main"
  : stack.replace("preview-", "");

export const prodRef = isProd
  ? undefined
  : new pulumi.StackReference(`${pulumi.getProject()}/prod`);

export function fromProd<T>(key: string): pulumi.Output<T> {
  return prodRef!.getOutput(key) as pulumi.Output<T>;
}
```

---

## azure/resource-group.ts

Prod creates the resource group. Preview stacks reuse it by name.

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as resources from "@pulumi/azure-native/resources";
import { isProd } from "./stack";

const rgName = "{{REPO_NAME}}-rg";

export const rg = isProd
  ? new resources.ResourceGroup("rg", { resourceGroupName: rgName })
  : undefined;

// In prod, rg!.name is an Output that carries an implicit dependency —
// every resource that uses resourceGroupName will wait for the RG.
export const resourceGroupName: pulumi.Input<string> = isProd
  ? rg!.name
  : rgName;
```

---

## azure/shared.ts

No parameters, no preview logic — these are hardcoded references to shared Xaiontz infrastructure used by all stacks.

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as authorization from "@pulumi/azure-native/authorization";

export const sharedRg = "xaiontz-shared-rg";
export const sharedPgServer = "xaiontz-shared-pg";
export const sharedAcrName = "xaiontzsharedacr";
export const sharedAcrLoginServer = `${sharedAcrName}.azurecr.io`;

const clientConfig = authorization.getClientConfigOutput();
export const sharedAcrId = pulumi.interpolate`/subscriptions/${clientConfig.subscriptionId}/resourceGroups/${sharedRg}/providers/Microsoft.ContainerRegistry/registries/${sharedAcrName}`;
```

---

## azure/database.ts

Both prod and preview create a database, but with different names. The AAD role is only created in prod (identity already exists). Grants run for every stack so the identity can access preview databases too.

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as dbforpostgresql from "@pulumi/azure-native/dbforpostgresql";
import * as command from "@pulumi/command";
import { sharedRg, sharedPgServer } from "./shared";
import { identityName, identity } from "./identity";
import { isProd, branchName } from "./stack";

const dbName = isProd ? "{{PROJECT_SLUG}}" : `{{PROJECT_SLUG}}-${branchName}`;

export const pgDatabase = new dbforpostgresql.Database("db", {
  resourceGroupName: sharedRg,
  serverName: sharedPgServer,
  databaseName: dbName,
});

export const databaseHost = `${sharedPgServer}.postgres.database.azure.com`;
export const databaseName = pgDatabase.name;

function runSql(name: string, database: string, sql: string, deps: pulumi.Resource[]) {
  return new command.local.Command(name, {
    create: [
      "az extension add --name rdbms-connect --yes",
      "$u = (az account show --query user.name -o tsv)",
      "$p = (az account get-access-token --resource https://ossrdbms-aad.database.windows.net --query accessToken --output tsv)",
      "$sqlFile = Join-Path $env:TEMP 'pulumi-sql.sql'",
      "$env:DB_SQL | Set-Content -Path $sqlFile -Encoding UTF8",
      "az postgres flexible-server execute --name $env:PG_SERVER --database-name $env:DB_NAME --admin-user $u --admin-password $p --file-path $sqlFile",
      "Remove-Item $sqlFile -ErrorAction SilentlyContinue",
    ].join("; "),
    environment: {
      PG_SERVER: sharedPgServer,
      DB_NAME: database,
      DB_SQL: sql,
    },
    interpreter: ["powershell", "-Command"],
  }, { dependsOn: deps });
}

// AAD role only needs creating once (in prod) — the identity is shared.
// Depends on identity so the managed identity exists in AAD before the SQL runs.
const createRole = isProd
  ? runSql(
      "create-aad-role",
      "postgres",
      `SELECT * FROM pgaadauth_create_principal('${identityName}', false, false);`,
      identity ? [pgDatabase, identity] : [pgDatabase],
    )
  : undefined;

// Grants run for every stack so the identity can access this database
const grantDeps = isProd ? [pgDatabase, createRole!] : [pgDatabase];
const grantPermissions = runSql(
  "grant-permissions",
  dbName,
  `GRANT ALL PRIVILEGES ON DATABASE "${dbName}" TO "${identityName}"; ALTER SCHEMA public OWNER TO "${identityName}";`,
  grantDeps,
);
```

---

## azure/storage.ts

Prod only. Preview stacks reference the storage account name from the prod stack.

```typescript
import * as storage from "@pulumi/azure-native/storage";
import { isProd, fromProd } from "./stack";
import { resourceGroupName } from "./resource-group";

const sa = isProd
  ? new storage.StorageAccount("sa", {
      resourceGroupName,
      accountName: "{{PROJECT_SLUG}}media",
      sku: { name: storage.SkuName.Standard_LRS },
      kind: storage.Kind.StorageV2,
      allowBlobPublicAccess: true,
    })
  : undefined;

if (isProd && sa) {
  new storage.BlobContainer("media", {
    resourceGroupName,
    accountName: sa.name,
    containerName: "media",
    publicAccess: storage.PublicAccess.Blob,
  });
}

export const storageAccountName = isProd
  ? sa!.name
  : fromProd<string>("storageAccountName");
```

---

## azure/identity.ts

Prod creates the managed identity. Preview stacks reference identity values from the prod stack.

```typescript
import * as managedidentity from "@pulumi/azure-native/managedidentity";
import { isProd, fromProd } from "./stack";
import { resourceGroupName } from "./resource-group";

export const identity = isProd
  ? new managedidentity.UserAssignedIdentity("identity", {
      resourceGroupName,
      resourceName: "{{PROJECT_SLUG}}-identity",
    })
  : undefined;

export const identityName = "{{PROJECT_SLUG}}-identity";

export const principalId = isProd
  ? identity!.principalId
  : fromProd<string>("principalId");

export const identityId = isProd
  ? identity!.id
  : fromProd<string>("identityId");

export const clientId = isProd
  ? identity!.clientId
  : fromProd<string>("clientId");
```

---

## azure/roles.ts

Prod only — RBAC is assigned to the shared managed identity once. Preview stacks inherit these permissions automatically.

```typescript
import * as authorization from "@pulumi/azure-native/authorization";
import { isProd } from "./stack";
import { principalId } from "./identity";
import { storageAccountName } from "./storage";
import { sharedAcrId } from "./shared";
import { communicationService } from "./email";

if (isProd) {
  // AcrPull on the shared ACR
  new authorization.RoleAssignment("acr-pull", {
    principalId: principalId,
    principalType: authorization.PrincipalType.ServicePrincipal,
    roleDefinitionId:
      "/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d",
    scope: sharedAcrId,
  });

  // Storage Blob Data Contributor on the storage account
  new authorization.RoleAssignment("storage-blob", {
    principalId: principalId,
    principalType: authorization.PrincipalType.ServicePrincipal,
    roleDefinitionId:
      "/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe",
    scope: storageAccountName.apply(
      (name) => `/subscriptions/*/resourceGroups/*/providers/Microsoft.Storage/storageAccounts/${name}`,
    ),
  });

  // Contributor on the ACS resource
  new authorization.RoleAssignment("acs-contributor", {
    principalId: principalId,
    principalType: authorization.PrincipalType.ServicePrincipal,
    roleDefinitionId:
      "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
    scope: communicationService!.id,
  });
}
```

Note: in the original non-preview-aware version, `roles.ts` exports named role assignments (e.g. `acrPullRole`) that `container-app.ts` uses in `dependsOn`. In the preview-aware version, `container-app.ts` handles this differently (see below).

---

## azure/environment.ts

Prod creates the Container Apps Environment. Preview stacks reference its ID from the prod stack.

```typescript
import * as app from "@pulumi/azure-native/app";
import { isProd, fromProd } from "./stack";
import { resourceGroupName } from "./resource-group";

const env = isProd
  ? new app.ManagedEnvironment("env", {
      resourceGroupName,
      environmentName: "{{PROJECT_SLUG}}-env",
    })
  : undefined;

export const environmentId = isProd
  ? env!.id
  : fromProd<string>("environmentId");

export const environment = env;
```

---

## azure/certificate.ts

Prod only. Creates a Cloudflare Origin CA certificate for the custom domain.

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as app from "@pulumi/azure-native/app";
import * as cloudflare from "@pulumi/cloudflare";
import * as tls from "@pulumi/tls";
import { isProd } from "./stack";
import { resourceGroupName } from "./resource-group";
import { environment } from "./environment";

let certificate: app.Certificate | undefined;

if (isProd && environment) {
  const originKey = new tls.PrivateKey("origin-key", {
    algorithm: "RSA",
    rsaBits: 2048,
  });

  const originCsr = new tls.CertRequest("origin-csr", {
    privateKeyPem: originKey.privateKeyPem,
    subject: { commonName: "{{DOMAIN}}" },
    dnsNames: ["{{DOMAIN}}", "*.{{DOMAIN}}"],
  });

  const config = new pulumi.Config();

  const originCaProvider = new cloudflare.Provider("origin-ca-provider", {
    apiUserServiceKey: config.requireSecret("originCaKey"),
  });

  const originCert = new cloudflare.OriginCaCertificate("origin-cert", {
    hostnames: ["{{DOMAIN}}", "*.{{DOMAIN}}"],
    requestType: "origin-rsa",
    requestedValidity: 5475,
    csr: originCsr.certRequestPem,
  }, { provider: originCaProvider });

  const pemBundle = pulumi
    .all([originCert.certificate, originKey.privateKeyPem])
    .apply(([cert, key]) => Buffer.from(`${key}\n${cert}`).toString("base64"));

  certificate = new app.Certificate("domain-cert", {
    resourceGroupName,
    environmentName: environment.name,
    certificateName: "{{DOMAIN_HYPHENATED}}-origin",
    properties: {
      value: pemBundle,
      password: "",
    },
  });
}

export { certificate };
```

---

## azure/email.ts

Prod only. Preview stacks reference the ACS endpoint from the prod stack.

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as communication from "@pulumi/azure-native/communication";
import { isProd, fromProd } from "./stack";
import { resourceGroupName } from "./resource-group";

let communicationService: communication.CommunicationService | undefined;

if (isProd) {
  const emailService = new communication.EmailService("acs-email", {
    emailServiceName: "{{REPO_NAME}}-acs-email",
    resourceGroupName,
    dataLocation: "uk",
    location: "Global",
  });

  const emailDomain = new communication.Domain("acs-email-domain", {
    domainName: "{{DOMAIN}}",
    emailServiceName: emailService.name,
    resourceGroupName,
    domainManagement: "CustomerManaged",
    location: "Global",
  });

  new communication.SenderUsername("acs-email-sender", {
    senderUsername: "DoNotReply",
    username: "DoNotReply",
    displayName: "{{EMAIL_SENDER_DISPLAY_NAME}}",
    domainName: emailDomain.name,
    emailServiceName: emailService.name,
    resourceGroupName,
  });

  communicationService = new communication.CommunicationService("acs", {
    communicationServiceName: "{{REPO_NAME}}-acs",
    resourceGroupName,
    dataLocation: "uk",
    location: "Global",
    linkedDomains: [emailDomain.id],
  });
}

export { communicationService };

export const acsEndpoint: pulumi.Output<string> = isProd
  ? communicationService!.hostName.apply((h) => `https://${h}`)
  : fromProd<string>("acsEndpoint");
```

---

## azure/container-app.ts

Both prod and preview create a Container App, but with key differences:

| Aspect | Prod | Preview |
|---|---|---|
| App name | `{{PROJECT_SLUG}}-app` | `{{PROJECT_SLUG}}-app-{branch}` |
| Image tag | `main-latest` | `{branch}-latest` |
| Custom domain | Yes (with TLS certificate) | No (auto-generated FQDN) |
| SERVER_URL | `https://{{DOMAIN}}` | Derived from Container App FQDN |
| dependsOn | DNS records + roles | None (resources already exist) |

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as app from "@pulumi/azure-native/app";
import { isProd, branchName } from "./stack";
import { resourceGroupName } from "./resource-group";
import { environmentId } from "./environment";
import { databaseHost, databaseName } from "./database";
import { sharedAcrLoginServer } from "./shared";
import { identityId, identityName, clientId } from "./identity";
import { storageAccountName } from "./storage";
import { acsEndpoint } from "./email";
import { certificate } from "./certificate";

const config = new pulumi.Config();
const payloadSecret = config.requireSecret("payloadSecret");
const entraAuthClientSecret = config.requireSecret("entraAuthClientSecret");

const appName = isProd
  ? "{{PROJECT_SLUG}}-app"
  : `{{PROJECT_SLUG}}-app-${branchName}`;

const imageTag = isProd ? "main-latest" : `${branchName}-latest`;
const imageName = `${sharedAcrLoginServer}/{{PROJECT_SLUG}}:${imageTag}`;

const customDomains = isProd && certificate
  ? [
      {
        name: "{{DOMAIN}}",
        certificateId: certificate.id,
        bindingType: "SniEnabled",
      },
    ]
  : undefined;

export const containerApp = new app.ContainerApp(
  "app",
  {
    resourceGroupName,
    environmentId,
    containerAppName: appName,
    identity: {
      type: app.ManagedServiceIdentityType.UserAssigned,
      userAssignedIdentities: [identityId],
    },
    configuration: {
      ingress: {
        external: true,
        targetPort: 3000,
        transport: app.IngressTransportMethod.Auto,
        customDomains,
      },
      registries: [
        {
          server: sharedAcrLoginServer,
          identity: identityId,
        },
      ],
      secrets: [
        { name: "payload-secret", value: payloadSecret },
        { name: "entra-auth-client-secret", value: entraAuthClientSecret },
      ],
    },
    template: {
      containers: [
        {
          name: "{{PROJECT_SLUG}}",
          image: imageName,
          resources: { cpu: 0.5, memory: "1Gi" },
          env: [
            { name: "DATABASE_HOST", value: databaseHost },
            { name: "DATABASE_NAME", value: databaseName },
            { name: "PAYLOAD_SECRET", secretRef: "payload-secret" },
            {
              name: "AZURE_STORAGE_ACCOUNT_NAME",
              value: storageAccountName,
            },
            { name: "AZURE_STORAGE_CONTAINER_NAME", value: "media" },
            { name: "AZURE_CLIENT_ID", value: clientId },
            { name: "AZURE_PG_USER", value: identityName },
            {
              name: "SERVER_URL",
              value: isProd ? "https://{{DOMAIN}}" : undefined,
            },
            { name: "ACS_ENDPOINT", value: acsEndpoint },
            { name: "EMAIL_FROM_ADDRESS", value: "DoNotReply@{{DOMAIN}}" },
            { name: "EMAIL_FROM_NAME", value: "{{EMAIL_SENDER_DISPLAY_NAME}}" },
            { name: "ENTRA_AUTH_CLIENT_ID", value: "" },
            { name: "ENTRA_AUTH_TENANT_ID", value: "" },
            { name: "ENTRA_AUTH_CLIENT_SECRET", secretRef: "entra-auth-client-secret" },
          ],
        },
      ],
      scale: { minReplicas: 0, maxReplicas: 1 },
    },
  },
);
```

In preview mode, `SERVER_URL` is left undefined — the application should fall back to the auto-detected host. Alternatively, set it after the Container App is created using its FQDN output.

Note: `ENTRA_AUTH_CLIENT_ID` and `ENTRA_AUTH_TENANT_ID` are left empty — the user must fill these in after creating the Entra ID app registration. They can be moved to Pulumi config secrets if preferred.

---

## index.ts (entry point)

Imports all resource files and exports stack outputs. Prod exports additional values consumed by preview stacks via `StackReference`.

```typescript
import { isProd } from "./azure/stack";
import "./azure/resource-group";
import "./azure/database";
import "./azure/storage";
import "./azure/identity";
import "./azure/environment";
import "./azure/container-app";

// Prod-only side effects (these files are no-ops in preview due to isProd guards,
// but importing them ensures Pulumi registers the resources)
import "./azure/roles";
import "./azure/certificate";
import "./azure/email";
import "./cloudflare/dns";

import { containerApp } from "./azure/container-app";
import { principalId, identityId, clientId, identityName } from "./azure/identity";
import { storageAccountName } from "./azure/storage";
import { environmentId } from "./azure/environment";
import { acsEndpoint } from "./azure/email";
import { resourceGroupName } from "./azure/resource-group";

// Stack outputs (available to all stacks)
export const containerAppFqdn = containerApp.configuration.apply(
  (c) => c?.ingress?.fqdn,
);
export const containerAppUrl = containerApp.configuration.apply(
  (c) => `https://${c?.ingress?.fqdn}`,
);

// Prod-only outputs consumed by preview stacks via StackReference
export {
  environmentId,
  identityId,
  clientId,
  principalId,
  storageAccountName,
  acsEndpoint,
  resourceGroupName,
};
export const identityNameValue = identityName;

// Prod-only custom domain output
export const customDomainUrl = isProd ? "https://{{DOMAIN}}" : undefined;
```
