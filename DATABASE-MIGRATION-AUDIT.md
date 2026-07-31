# Database migration audit

## Migration path exercised

A Python SQLite fixture recreated the Build 6 schema with representative products, customers, suppliers, sales, sale items, expenses and settings. The current schema-version-8 SQL and commercial defaults were then applied sequentially.

## Results

- Final table count: **41**
- Legacy row counts preserved: **PASS**
- Main branch created: **PASS**
- Existing product stock copied to main-branch inventory: **PASS**
- Existing customers and suppliers assigned to main branch: **PASS**
- Legacy cash sale payment/balance migration: **PASS**
- Required corrective columns present: **PASS**
- SQLite integrity check: **ok**
- Foreign-key check: **zero violations**

## Required production validation

A real application upgrade on Windows, with the Flutter SQLite driver and a copy of a customer database, is still **MISSING**. GitHub CI should include fresh, Build 5 and Build 6 database fixtures.
