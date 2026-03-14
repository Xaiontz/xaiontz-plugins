# Cloudflare DNS Template

Parameterized Pulumi TypeScript template for Cloudflare DNS records. The Cloudflare zone ID is stored in Pulumi config; the domain comes from the `{{DOMAIN}}` input.

Prod only — preview stacks skip DNS records entirely (they use auto-generated `.azurecontainerapps.io` FQDNs).

---

## cloudflare/dns.ts

```typescript
import * as cloudflare from "@pulumi/cloudflare";
import * as pulumi from "@pulumi/pulumi";
import { isProd } from "../azure/stack";
import { environment } from "../azure/environment";

export let aRecord: cloudflare.DnsRecord | undefined;
export let txtVerificationRecord: cloudflare.DnsRecord | undefined;

if (isProd && environment) {
  const config = new pulumi.Config();
  const zoneId = config.require("cloudflareZoneId");

  const verificationId = environment.customDomainConfiguration.apply(
    (c) => c?.customDomainVerificationId ?? "",
  );

  aRecord = new cloudflare.DnsRecord("apex-a", {
    zoneId: zoneId,
    name: "{{DOMAIN}}",
    type: "A",
    content: environment.staticIp,
    proxied: true,
    ttl: 1,
  });

  txtVerificationRecord = new cloudflare.DnsRecord(
    "azure-verification-txt",
    {
      zoneId: zoneId,
      name: "asuid",
      type: "TXT",
      content: verificationId,
      proxied: false,
      ttl: 1,
    },
  );
}
```

The A record points the apex domain at the Container Apps Environment static IP with Cloudflare proxying enabled. The TXT record contains the Azure custom domain verification ID required before the Container App can bind to the domain. Both are skipped in preview stacks.
