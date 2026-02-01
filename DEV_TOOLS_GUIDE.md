# Development Tools Guide
**For Next.js + Supabase + Payload CMS Stack**

This guide documents recommended tools and services for full-stack development with OpenClaw VM, specifically optimized for the React/Next.js + Supabase + Payload CMS technology stack deploying to Vercel.

---

## 📋 Table of Contents

1. [Essential Tools (Pre-installed)](#essential-tools-pre-installed)
2. [Project Setup Tools](#project-setup-tools)
3. [MCP Servers](#mcp-servers)
4. [Recommended Additions](#recommended-additions)
5. [Optional Tools](#optional-tools)
6. [Quick Reference](#quick-reference)

---

## Essential Tools (Pre-installed)

These tools are automatically installed via `bootstrap/modules/12-dev-tools.sh`:

### pnpm - Package Manager
**Why:** 70% less disk space than npm, faster installs, excellent monorepo support

```bash
# Use pnpm instead of npm
pnpm install
pnpm add <package>
pnpm run dev

# Check version
pnpm --version
```

**Resources:**
- Docs: https://pnpm.io/
- Comparison: https://pnpm.io/benchmarks

---

### Biome - Unified Linter & Formatter
**Why:** 10-25x faster than ESLint + Prettier, single tool, single config

```bash
# Initialize in project
biome init

# Format code
biome format --write ./src

# Lint code
biome lint ./src

# Check everything
biome check --write ./src
```

**Migration from ESLint/Prettier:**
```bash
biome migrate eslint --write
biome migrate prettier --write
```

**Resources:**
- Docs: https://biomejs.dev/
- VS Code Extension: https://marketplace.visualstudio.com/items?itemName=biomejs.biome

---

### Doppler CLI - Secrets Management
**Why:** Centralized environment variables, auto-sync to Vercel/GitHub Actions

```bash
# Login
doppler login

# Setup project
doppler setup

# Run command with secrets
doppler run -- pnpm dev

# Sync to Vercel
doppler secrets download --no-file --format env-no-quotes | vercel env add
```

**Resources:**
- Docs: https://docs.doppler.com/
- Vercel Integration: https://www.doppler.com/integrations/vercel

---

### Bruno CLI - API Testing
**Why:** Git-friendly, offline-first, no cloud sync required

```bash
# Create collection
bru new my-api-tests

# Run collection
bru run my-api-tests
```

**Resources:**
- Docs: https://docs.usebruno.com/
- Desktop App: https://www.usebruno.com/downloads

---

### Turborepo - Monorepo Management
**Why:** Developed by Vercel, optimized for Next.js, remote caching

```bash
# Create new monorepo
npx create-turbo@latest

# Run tasks
turbo dev
turbo build
turbo lint
```

**Resources:**
- Docs: https://turbo.build/repo
- Examples: https://github.com/vercel/turbo/tree/main/examples

---

## Project Setup Tools

Install these per-project as needed:

### Testing Framework

#### Vitest (Recommended)
**Why:** Fast, modern, built for Vite/Next.js

```bash
pnpm add -D vitest @testing-library/react @testing-library/jest-dom @vitejs/plugin-react jsdom

# Or use template
npx create-next-app@latest --example with-vitest my-app
```

**vitest.config.ts:**
```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
  },
})
```

**Resources:**
- Docs: https://vitest.dev/
- Next.js Guide: https://nextjs.org/docs/app/building-your-application/testing/vitest

---

#### Playwright (E2E Testing)
**Why:** Cross-browser, auto-waiting, maintained by Microsoft

```bash
pnpm add -D @playwright/test
npx playwright install

# Or use template
npx create-next-app@latest --example with-playwright my-app
```

**playwright.config.ts:**
```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  use: {
    baseURL: 'http://localhost:3000',
  },
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
})
```

**Resources:**
- Docs: https://playwright.dev/
- Next.js Example: https://github.com/vercel/next.js/tree/canary/examples/with-playwright

---

### Error Tracking

#### Sentry
**Why:** Native Vercel integration, performance monitoring, session replay

```bash
npx @sentry/wizard@latest -i nextjs
```

**This creates:**
- `sentry.client.config.ts`
- `sentry.server.config.ts`
- `sentry.edge.config.ts`
- `instrumentation.ts` (for Next.js 15+)

**Vercel Integration:**
1. Install from Vercel Marketplace: https://vercel.com/integrations/sentry
2. Automatic source map uploads
3. Integrated billing

**Resources:**
- Docs: https://docs.sentry.io/platforms/javascript/guides/nextjs/
- Marketplace: https://vercel.com/integrations/sentry

---

### Database ORM

#### Drizzle ORM (Recommended for Supabase)
**Why:** Lightweight (7.4kb), serverless-ready, fast cold starts

```bash
pnpm add drizzle-orm postgres
pnpm add -D drizzle-kit
```

**drizzle.config.ts:**
```typescript
import type { Config } from 'drizzle-kit'

export default {
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
} satisfies Config
```

**Example schema.ts:**
```typescript
import { pgTable, serial, text, timestamp } from 'drizzle-orm/pg-core'

export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: text('title').notNull(),
  content: text('content'),
  createdAt: timestamp('created_at').defaultNow(),
})
```

**Generate migration:**
```bash
pnpm drizzle-kit generate:pg
pnpm drizzle-kit migrate
```

**Resources:**
- Docs: https://orm.drizzle.team/
- Supabase Guide: https://orm.drizzle.team/docs/guides/supabase

---

### Image Optimization

#### Cloudinary
**Why:** Auto-optimization, modern formats (WebP/AVIF), transformations

```bash
pnpm add next-cloudinary
```

**app/page.tsx:**
```typescript
import { CldImage } from 'next-cloudinary'

export default function Page() {
  return (
    <CldImage
      src="sample"
      width={500}
      height={500}
      crop="fill"
      gravity="auto"
      alt="Sample"
    />
  )
}
```

**next.config.js:**
```javascript
module.exports = {
  images: {
    loader: 'cloudinary',
    path: 'https://res.cloudinary.com/your-cloud-name/',
  },
}
```

**Resources:**
- Docs: https://next.cloudinary.dev/
- Dashboard: https://cloudinary.com/console

---

### Email Service

#### Resend
**Why:** Developer-first, React Email templates, Server Actions support

```bash
pnpm add resend @react-email/components
```

**app/api/send/route.ts:**
```typescript
import { Resend } from 'resend'
import { EmailTemplate } from '@/emails/template'

const resend = new Resend(process.env.RESEND_API_KEY)

export async function POST(request: Request) {
  const { data, error } = await resend.emails.send({
    from: 'onboarding@resend.dev',
    to: 'user@example.com',
    subject: 'Hello World',
    react: EmailTemplate({ name: 'User' }),
  })

  if (error) {
    return Response.json({ error }, { status: 500 })
  }

  return Response.json(data)
}
```

**emails/template.tsx:**
```typescript
import { Html, Button } from '@react-email/components'

export function EmailTemplate({ name }: { name: string }) {
  return (
    <Html>
      <h1>Hello {name}!</h1>
      <Button href="https://example.com">Click me</Button>
    </Html>
  )
}
```

**Resources:**
- Docs: https://resend.com/docs
- React Email: https://react.email/

---

## MCP Servers

Configure these in `~/.config/claude/mcp.json`:

### Pre-configured MCP Servers

Already configured in `deployment-tools/mcp/mcp-servers-full-stack.json`:

1. **Google Drive** - File operations and sharing
2. **Dropbox** - Cloud storage access
3. **GitHub** - Repository management
4. **Filesystem** - Local file operations
5. **PostgreSQL** - Supabase database queries
6. **Brave Search** - Web search
7. **Figma** - Design-to-code integration
8. **Stripe** - Payment integration
9. **Sentry** - Error tracking integration
10. **Sequential Thinking** - Enhanced reasoning

### Figma MCP Server

**Setup:**
```bash
# Get Figma PAT: https://www.figma.com/developers/api#access-tokens
export FIGMA_PAT="your-figma-token"

# Get file key from URL: https://www.figma.com/file/FILE_KEY/...
export FIGMA_FILE_KEY="your-file-key"
```

**Usage with Claude Code:**
- Extract design tokens (colors, spacing, typography)
- Generate React + Tailwind components
- Get structured design data

**Resources:**
- Docs: https://www.figma.com/developers/mcp
- Blog: https://www.figma.com/blog/introducing-figma-mcp-server/

---

### Stripe MCP Server

**Setup:**
```bash
# Get secret key from: https://dashboard.stripe.com/apikeys
export STRIPE_SECRET_KEY="sk_test_..."
```

**Usage with Claude Code:**
- Create customers and subscriptions
- Manage payment intents
- Query payment data
- Access Stripe docs as markdown

**Resources:**
- Docs: https://docs.stripe.com/mcp
- Dashboard: https://dashboard.stripe.com/

---

## Recommended Additions

Install these based on project needs:

### Background Jobs

#### Trigger.dev
**Why:** Serverless timeout workarounds, checkpoint-resume system

```bash
npx trigger.dev@latest init
```

**app/api/trigger/route.ts:**
```typescript
import { createAppRoute } from "@trigger.dev/nextjs"
import { client } from "@/trigger"

export const { POST, dynamic } = createAppRoute(client)
```

**jobs/example.ts:**
```typescript
import { eventTrigger } from "@trigger.dev/sdk"
import { client } from "./trigger"

client.defineJob({
  id: "example-job",
  name: "Example Job",
  version: "0.0.1",
  trigger: eventTrigger({
    name: "example.event",
  }),
  run: async (payload, io, ctx) => {
    await io.logger.info("Hello world!", { payload })

    // Long-running task
    await io.wait("wait", 60)

    return { success: true }
  },
})
```

**Resources:**
- Docs: https://trigger.dev/docs
- Vercel Guide: https://trigger.dev/docs/guides/frameworks/nextjs

---

### Component Development

#### Storybook
**Why:** Isolated component testing, visual regression, documentation

```bash
npx storybook@latest init
```

**Enable React Server Components:**
```javascript
// .storybook/main.ts
export default {
  framework: {
    name: '@storybook/nextjs',
    options: {
      builder: {
        useSWC: true,
      },
    },
  },
  features: {
    experimentalRSC: true,
  },
}
```

**Resources:**
- Docs: https://storybook.js.org/docs/get-started/nextjs
- Next.js 15: https://storybook.js.org/blog/storybook-8-3/

---

### Analytics

#### PostHog
**Why:** Product analytics, session replay, feature flags, open-source

```bash
pnpm add posthog-js posthog-node
```

**app/providers.tsx:**
```typescript
'use client'
import posthog from 'posthog-js'
import { PostHogProvider } from 'posthog-js/react'

if (typeof window !== 'undefined') {
  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY!, {
    api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST,
    capture_pageview: false,
  })
}

export function PHProvider({ children }: { children: React.ReactNode }) {
  return <PostHogProvider client={posthog}>{children}</PostHogProvider>
}
```

**Vercel Proxy Setup:**
```javascript
// next.config.js
module.exports = {
  async rewrites() {
    return [
      {
        source: '/ingest/:path*',
        destination: 'https://app.posthog.com/:path*',
      },
    ]
  },
}
```

**Resources:**
- Docs: https://posthog.com/docs/libraries/next-js
- Dashboard: https://app.posthog.com/

---

## Optional Tools

### File Uploads

#### UploadThing
**Why:** Type-safe, Next.js-optimized file uploads

```bash
pnpm add uploadthing @uploadthing/react
```

**Resources:**
- Docs: https://docs.uploadthing.com/
- Comparison vs Supabase Storage: Choose based on needs

---

### Visual Regression Testing

#### Chromatic
**Why:** Automated visual testing for Storybook

```bash
pnpm add -D chromatic
npx chromatic --project-token=<your-token>
```

**Resources:**
- Docs: https://www.chromatic.com/docs
- Storybook Integration: https://www.chromatic.com/docs/storybook

---

### Alternative Database

#### Neon
**Why:** Database branching, scales to zero, serverless Postgres

**Use Case:** Preview deployments with isolated database branches

**Resources:**
- Docs: https://neon.tech/docs
- Vercel Integration: https://vercel.com/integrations/neon

---

## Quick Reference

### Package Managers Comparison

| Feature | npm | pnpm | Advantages |
|---------|-----|------|------------|
| Disk Space | Baseline | -70% | pnpm uses hard links |
| Install Speed | Baseline | +2x faster | pnpm parallel installs |
| Monorepo | Manual | Built-in | pnpm workspace native |

**Use pnpm for:**
- Monorepos (multiple packages)
- Faster CI/CD builds
- Disk space constraints

---

### Testing Strategy

```
Unit Tests (Vitest)
└── Components, hooks, utilities
    ├── Fast feedback
    └── High coverage

Integration Tests (Vitest)
└── API routes, database queries
    ├── Test with real dependencies
    └── Use test database

E2E Tests (Playwright)
└── Critical user flows
    ├── Login, checkout, form submissions
    └── Cross-browser testing
```

---

### MCP Server Environment Variables

```bash
# Required for full MCP functionality
export GITHUB_PAT="ghp_..."
export SUPABASE_DB_URL="postgresql://..."
export FIGMA_PAT="..."
export FIGMA_FILE_KEY="..."
export STRIPE_SECRET_KEY="sk_test_..."
export SENTRY_AUTH_TOKEN="..."
export SENTRY_ORG="..."
export SENTRY_PROJECT="..."
export BRAVE_API_KEY="..." # Optional
```

---

### Deployment Checklist

**Pre-deployment:**
- [ ] All tests passing (`pnpm test`)
- [ ] Linting clean (`biome check`)
- [ ] Build succeeds (`pnpm build`)
- [ ] Environment variables set in Vercel
- [ ] Database migrations applied
- [ ] Sentry source maps configured

**Post-deployment:**
- [ ] Smoke test production URL
- [ ] Check Sentry for errors
- [ ] Verify PostHog events
- [ ] Test Stripe webhooks (if applicable)
- [ ] Monitor performance (Vercel Analytics)

---

### Useful Commands

```bash
# Development
pnpm dev                    # Start dev server
pnpm build                  # Production build
pnpm start                  # Start production server

# Testing
pnpm test                   # Run Vitest
pnpm test:e2e              # Run Playwright
pnpm test:coverage         # Coverage report

# Linting
biome check --write ./src  # Lint and format
biome ci ./src             # CI check (no writes)

# Database
pnpm drizzle-kit generate  # Generate migration
pnpm drizzle-kit migrate   # Apply migration
pnpm drizzle-kit studio    # Database GUI

# Deployment
vercel                     # Deploy to preview
vercel --prod             # Deploy to production
doppler run -- vercel     # Deploy with secrets
```

---

## Payload CMS Specific

### Development Workflow

```bash
# Generate database schema
pnpm payload generate:db-schema

# Access admin panel
http://localhost:3000/admin

# Generate TypeScript types
pnpm payload generate:types
```

### Recommended Plugins

- **payload-plugin-form-builder** - Form builder for Payload
- **payload-plugin-nested-docs** - Nested document hierarchies
- **payload-plugin-seo** - SEO meta fields
- **payload-workflow** - Publishing workflows

### Integration Tips

1. **With Drizzle:** Use Payload's `@payloadcms/db-postgres` adapter
2. **With Supabase:** Connect to same database, separate schemas
3. **With Vercel:** Deploy admin panel alongside Next.js app
4. **With Cloudinary:** Custom field for media management

---

## Resources

### Official Documentation
- Next.js: https://nextjs.org/docs
- Supabase: https://supabase.com/docs
- Payload CMS: https://payloadcms.com/docs
- Vercel: https://vercel.com/docs

### Community
- Next.js Discord: https://discord.gg/nextjs
- Supabase Discord: https://discord.supabase.com/
- Payload Slack: https://payloadcms.com/community/slack

### Learning
- Next.js Learn: https://nextjs.org/learn
- Supabase University: https://supabase.com/docs/guides
- Payload Examples: https://github.com/payloadcms/payload/tree/main/examples

---

**Last Updated:** 2026-02-01
**Stack Version:** Next.js 15+ | Supabase v2 | Payload CMS v3
