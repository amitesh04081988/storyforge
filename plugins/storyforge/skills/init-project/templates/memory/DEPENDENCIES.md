# Dependency map
<!-- The impact scripts read the table below. Keep one row per area, one line per row.
     Area       unique name, used in "Depends on" (no commas or pipes)
     Kind       module | integration | data | config | job | ui
     Paths      comma-separated globs this area owns, for example src/orders/**
     Depends on comma-separated Area names this area needs to work, or -
     Tests      where this area is covered: paths or test names, or - (a gap worth filling)
     Notes      runtime links the code does not show: events, queues, shared tables, HTTP calls
     Starter rows are examples. Replace them with the project's real areas. Rows whose Area starts
     with "_" or "<" are ignored. -->

| Area | Kind | Paths | Depends on | Tests | Notes |
|------|------|-------|------------|-------|-------|
| _example-orders | module | src/orders/** | _example-db, _example-auth | tests/orders/** | emits OrderPlaced event |
| _example-db | data | src/db/**, migrations/** | - | tests/db/** | shared by every module |
| _example-auth | module | src/auth/** | _example-db | tests/auth/** | session cookie format is a contract |
