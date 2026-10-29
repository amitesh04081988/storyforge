# Feature map
<!-- The sitemap of what this product does. Every agent reads this to find where a feature lives
     before it plans, tests, or changes code. Keep one row per feature, one line per row.
     Feature     unique name (no commas or pipes)
     Entry       how a user or caller reaches it: route, screen, CLI command, API endpoint, job, event
     Paths       comma-separated globs that implement it, for example src/orders/**
     Area        the DEPENDENCIES.md area that owns it, or -
     Status      live | beta | planned | deprecated
     Doc         docs/features/<name>.md, or -
     Tests       where it is covered: paths or test names, or - (a gap worth filling)
     Stories     story ids that built or changed it
     Starter rows are examples. Replace them. Rows whose Feature starts with "_" or "<" are ignored. -->

| Feature | Entry | Paths | Area | Status | Doc | Tests | Stories |
|---------|-------|-------|------|--------|-----|-------|---------|
| _example-csv-export | GET /orders/export, "Export" button | src/orders/export/** | _example-orders | live | docs/features/csv-export.md | tests/orders/export/** | 20261024-csv-export |
