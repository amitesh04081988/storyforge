# Stack guide

These are starting points, not rules. **The team's existing skills beat everything below.** A team strong in one language ships faster in it than in a "better" stack.

## Defaults by product type

| Product | Default | Strong alternatives | Choose the alternative when |
|---|---|---|---|
| Web app (CRUD, dashboards, SaaS) | TypeScript: Next.js + PostgreSQL + Prisma or Drizzle | Django + HTMX or React; Rails; Laravel; .NET + React | The team knows Python, Ruby, PHP, or C#; you need an admin panel fast (Django, Rails) |
| Public content or marketing site | Astro or Next.js static on Vercel or Netlify | Hugo | Mostly content and little interactivity |
| API or backend service | TypeScript (Fastify or NestJS) or Python (FastAPI) + PostgreSQL | Go, Java/Kotlin (Spring Boot), .NET | High throughput or low latency (Go); enterprise or JVM shop (Spring); Microsoft shop (.NET) |
| Realtime (chat, collaboration, live data) | WebSockets on Node or Elixir Phoenix + PostgreSQL + Redis | A managed realtime service | Small team, and realtime isn't the core value |
| Mobile | React Native (Expo) or Flutter | Native Swift and Kotlin | Heavy device APIs, top performance, or a platform-specific UX |
| Data or ML pipeline | Python + uv + PostgreSQL or DuckDB + an orchestrator (Prefect, Dagster) | Spark | Data volume beyond one machine |
| CLI tool | Go or Rust (single binary), or Python | Node | Distribution to non-developers favors a single binary |
| AI features | Whichever backend the team knows, plus the provider's official SDK | | Keep the model calls behind one internal module |

## Cross-cutting picks

- **Database:** PostgreSQL unless there's a specific reason not to. Add Redis only for caching, queues, or rate limits that you've actually measured a need for.
- **Auth:** prefer the framework's mature auth library or a managed provider over hand-rolled auth. SSO or SAML needs push toward a managed provider.
- **Background jobs:** use the stack's standard queue (BullMQ, Celery or RQ, Sidekiq, Oban) or a managed one.
- **Hosting:** match the team's ops capacity. With no ops person, choose a managed platform over Kubernetes.
- **Monorepo:** only when you have more than one deployable app sharing code. Otherwise use a single repo.

## Red flags in a proposal

- Microservices for a team of fewer than about 8 people, or before the product has users.
- More than one new technology the team has never used.
- Kubernetes without someone who will own it.
- A NoSQL database chosen only for "scale" when the data is relational.
