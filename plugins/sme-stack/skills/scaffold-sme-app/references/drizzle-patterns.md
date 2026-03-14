# Drizzle ORM Patterns

Schema definition, migration workflow, and common patterns for the SME Stack.

## Database connection

```typescript
// src/db/index.ts
import { drizzle } from "drizzle-orm/postgres-js"
import postgres from "postgres"
import * as schema from "./schema"

const connectionString = process.env.DATABASE_URL!

const client = postgres(connectionString)
export const db = drizzle(client, { schema })
```

## Drizzle Kit configuration

```typescript
// drizzle.config.ts
import { defineConfig } from "drizzle-kit"

export default defineConfig({
  schema: "./src/db/schema/index.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
})
```

## Schema patterns

### Table with timestamps

```typescript
// src/db/schema/app.ts
import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core"

export const contacts = pgTable("contacts", {
  id: serial("id").primaryKey(),
  firstName: text("first_name").notNull(),
  lastName: text("last_name").notNull(),
  email: text("email").notNull(),
  message: text("message"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
})
```

### Reusable timestamp columns

```typescript
import { timestamp } from "drizzle-orm/pg-core"

export const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
}

// Usage:
export const posts = pgTable("posts", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  ...timestamps,
})
```

### Enums

```typescript
import { pgEnum } from "drizzle-orm/pg-core"

export const roleEnum = pgEnum("role", ["client", "employee", "admin"])

export const users = pgTable("users", {
  id: text("id").primaryKey(),
  role: roleEnum("role").default("client").notNull(),
  // ...
})
```

### Relations

```typescript
import { relations } from "drizzle-orm"

export const usersRelations = relations(users, ({ many }) => ({
  appointments: many(appointments),
}))

export const appointmentsRelations = relations(appointments, ({ one }) => ({
  client: one(users, {
    fields: [appointments.clientId],
    references: [users.id],
  }),
}))
```

### Indexes

```typescript
import { pgTable, text, index } from "drizzle-orm/pg-core"

export const contacts = pgTable(
  "contacts",
  {
    id: serial("id").primaryKey(),
    email: text("email").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    index("contacts_email_idx").on(table.email),
    index("contacts_created_at_idx").on(table.createdAt),
  ],
)
```

### Soft delete

```typescript
export const softDelete = {
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
}

// Query pattern — exclude soft-deleted rows
import { isNull } from "drizzle-orm"
const active = await db.select().from(posts).where(isNull(posts.deletedAt))
```

### JSON columns

```typescript
import { jsonb } from "drizzle-orm/pg-core"

export const settings = pgTable("settings", {
  id: serial("id").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id),
  preferences: jsonb("preferences").$type<{
    theme: "light" | "dark"
    notifications: boolean
  }>(),
})
```

## Barrel export

```typescript
// src/db/schema/index.ts
export * from "./auth"
export * from "./app"
```

Every table and relation must be re-exported here — Drizzle Kit reads this file to generate migrations.

## Query patterns

### Select with filter

```typescript
import { eq, and, isNull } from "drizzle-orm"

const result = await db
  .select()
  .from(contacts)
  .where(and(eq(contacts.email, "test@example.com"), isNull(contacts.deletedAt)))
```

### Insert

```typescript
const [newContact] = await db
  .insert(contacts)
  .values({ firstName: "Jane", lastName: "Doe", email: "jane@example.com" })
  .returning()
```

### Update

```typescript
await db
  .update(contacts)
  .set({ message: "Updated message", updatedAt: new Date() })
  .where(eq(contacts.id, 1))
```

### Delete

```typescript
await db.delete(contacts).where(eq(contacts.id, 1))
```

### Join

```typescript
const result = await db
  .select({
    appointment: appointments,
    clientName: users.name,
  })
  .from(appointments)
  .innerJoin(users, eq(appointments.clientId, users.id))
```

### With relations (query API)

```typescript
const usersWithAppointments = await db.query.users.findMany({
  with: {
    appointments: true,
  },
  where: eq(users.role, "client"),
})
```

## Migration workflow

### Development

```bash
# After modifying schema files:
pnpm db:generate          # Generate migration SQL from schema diff
                           # Review the generated SQL in drizzle/

pnpm db:migrate           # Apply pending migrations to database

# For rapid iteration (skips migration files, pushes schema directly):
pnpm db:push
```

### Production

- Migrations are committed to git in `drizzle/`
- Run `pnpm db:migrate` as part of deployment (before starting the app)
- Never use `db:push` in production

### Inspecting the database

```bash
pnpm db:studio            # Opens Drizzle Studio web UI at https://local.drizzle.studio
```

## Auth.js tables

Auth.js with the Drizzle adapter requires specific tables. Use the `@auth/drizzle-adapter` package's schema or define them manually:

```typescript
// src/db/schema/auth.ts
import { pgTable, text, timestamp, integer, primaryKey } from "drizzle-orm/pg-core"
import type { AdapterAccountType } from "next-auth/adapters"

export const users = pgTable("users", {
  id: text("id").primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: text("name"),
  email: text("email").unique().notNull(),
  emailVerified: timestamp("email_verified", { mode: "date", withTimezone: true }),
  image: text("image"),
  role: text("role").default("client").notNull(),
})

export const accounts = pgTable(
  "accounts",
  {
    userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    type: text("type").$type<AdapterAccountType>().notNull(),
    provider: text("provider").notNull(),
    providerAccountId: text("provider_account_id").notNull(),
    refresh_token: text("refresh_token"),
    access_token: text("access_token"),
    expires_at: integer("expires_at"),
    token_type: text("token_type"),
    scope: text("scope"),
    id_token: text("id_token"),
    session_state: text("session_state"),
  },
  (account) => [
    primaryKey({ columns: [account.provider, account.providerAccountId] }),
  ],
)

export const sessions = pgTable("sessions", {
  sessionToken: text("session_token").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  expires: timestamp("expires", { mode: "date", withTimezone: true }).notNull(),
})

export const verificationTokens = pgTable(
  "verification_tokens",
  {
    identifier: text("identifier").notNull(),
    token: text("token").notNull(),
    expires: timestamp("expires", { mode: "date", withTimezone: true }).notNull(),
  },
  (vt) => [
    primaryKey({ columns: [vt.identifier, vt.token] }),
  ],
)
```
