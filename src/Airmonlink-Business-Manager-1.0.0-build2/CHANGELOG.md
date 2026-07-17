# Changelog

## 1.0.0+2 — 2026-07-17

- Corrected the GitHub Actions workflow to use released `actions/checkout@v6`.
- Updated artifact upload to current `actions/upload-artifact@v7`.
- Preserved Flutter 3.44.0 and the Windows application functionality from build 1.
- No database schema or user-facing feature changes.

## 1.0.0+2 — 2026-07-16

- Created the first canonical Airmonlink Business Manager source release.
- Added SQLite product, contact, sale, sale-item, expense and settings storage.
- Added transaction-safe POS checkout, stock deduction and customer credit sales.
- Added outstanding customer and supplier balance payment recording.
- Added dashboard, inventory, customer, supplier, expense, reporting and settings modules.
- Added CSV, PDF and database-backup exports.
- Added Flutter tests and GitHub Actions Windows release packaging.
