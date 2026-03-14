# UI Conventions

Tailwind CSS v4, shadcn/ui setup, and theming patterns for the SME Stack.

## Tailwind v4 setup

Tailwind v4 uses CSS-first configuration. After `create-next-app` with `--tailwind`, the setup is:

```css
/* src/app/globals.css */
@import "tailwindcss";
```

No `tailwind.config.js` is needed for most projects. If custom configuration is required (plugins, custom screens), use `@theme` in CSS:

```css
@import "tailwindcss";

@theme {
  --font-sans: "Inter", sans-serif;
  --font-heading: "Cal Sans", sans-serif;
}
```

## shadcn/ui initialization

```bash
pnpm dlx shadcn@latest init
```

Select these options:
- Style: **Default**
- Base color: choose based on brand
- CSS variables: **Yes**
- `tailwind.config.ts` location: default
- Components directory: `src/components/ui`
- Utils directory: `src/lib/utils`

### Installing components

```bash
pnpm dlx shadcn@latest add button card input label form separator
pnpm dlx shadcn@latest add dialog dropdown-menu sheet avatar badge
pnpm dlx shadcn@latest add table tabs select checkbox textarea
```

Install components as needed — don't install everything upfront.

## CSS variable theming

shadcn/ui uses CSS variables for theming. Define them in `globals.css`:

```css
@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --card: 222.2 84% 4.9%;
    --card-foreground: 210 40% 98%;
    --popover: 222.2 84% 4.9%;
    --popover-foreground: 210 40% 98%;
    --primary: 210 40% 98%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 212.7 26.8% 83.9%;
  }
}
```

Customize HSL values to match the brand. All shadcn components inherit from these variables automatically.

## CSS variable reference

| Variable | Purpose |
|---|---|
| `--background` / `--foreground` | Page background and body text |
| `--primary` / `--primary-foreground` | Buttons, links, emphasis |
| `--secondary` / `--secondary-foreground` | Secondary actions |
| `--muted` / `--muted-foreground` | Disabled states, subtle text |
| `--accent` / `--accent-foreground` | Hover highlights |
| `--destructive` / `--destructive-foreground` | Delete, error actions |
| `--card` / `--card-foreground` | Card backgrounds |
| `--popover` / `--popover-foreground` | Dropdowns, tooltips |
| `--border` | Borders |
| `--input` | Form input borders |
| `--ring` | Focus ring color |
| `--radius` | Base border radius |

## Dark mode

Use the `class` strategy. Add `dark` class to `<html>` to toggle:

```typescript
// Minimal theme toggle
"use client"

import { useEffect, useState } from "react"

export function ThemeToggle() {
  const [dark, setDark] = useState(false)

  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark)
  }, [dark])

  return (
    <button onClick={() => setDark(!dark)}>
      {dark ? "Light" : "Dark"}
    </button>
  )
}
```

For production, use `next-themes` for system preference detection and persistence:

```bash
pnpm add next-themes
```

## Typography

Import fonts via `next/font` in the root layout:

```typescript
import { Inter } from "next/font/google"

const inter = Inter({ subsets: ["latin"], variable: "--font-sans" })

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans antialiased">{children}</body>
    </html>
  )
}
```

For heading fonts, add a second font and use `--font-heading` CSS variable.

## Layout patterns

### Public area layout

```typescript
// src/app/(public)/layout.tsx
import { SiteNav } from "@/components/public/SiteNav"
import { SiteFooter } from "@/components/public/SiteFooter"

export default function PublicLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <SiteNav />
      <main className="min-h-screen">{children}</main>
      <SiteFooter />
    </>
  )
}
```

### Portal area layout

```typescript
// src/app/(portal)/layout.tsx
import { auth } from "@/auth"
import { redirect } from "next/navigation"
import { PortalSidebar } from "@/components/portal/PortalSidebar"
import { UserMenu } from "@/components/shared/UserMenu"

export default async function PortalLayout({ children }: { children: React.ReactNode }) {
  const session = await auth()
  if (!session) redirect("/login")

  return (
    <div className="flex min-h-screen">
      <PortalSidebar />
      <div className="flex-1">
        <header className="border-b px-6 py-3 flex justify-end">
          <UserMenu user={session.user} />
        </header>
        <main className="p-6">{children}</main>
      </div>
    </div>
  )
}
```

### Internal area layout

Same pattern as portal but with admin-style navigation, breadcrumbs, and employee-only session check.

## Component conventions

- Use `cn()` from `@/lib/utils` for conditional classes: `cn("base-class", conditional && "extra-class")`
- Prefer shadcn components over custom implementations
- Keep component files focused — one component per file
- Use Tailwind utility classes directly; avoid creating CSS files for components
- For complex, reusable patterns, compose shadcn primitives into higher-level components in `components/shared/`
