# Changelog

## 1.0.0+3 — 2026-07-19

- Replaced the incomplete PDF-only export path with actual Windows print preview and printing through `printing` 5.15.0.
- Added an automatic 57/80 mm receipt preview after every completed sale.
- Added A4, A5 and Letter business-summary preview and printing.
- Added a high-contrast printer test page under Business Settings.
- Added explicit Helvetica font families, visible empty-state rows and PDF byte validation to prevent blank documents.
- Added PDF-generation tests for both reports and receipts.
- Preserved the existing database schema and all business records.

## 1.0.0+2 — 2026-07-17

- Corrected the GitHub Actions workflow to use released `actions/checkout@v6`.
- Updated artifact upload to `actions/upload-artifact@v7`.
- Preserved Flutter 3.44.0 and the Windows application functionality from build 1.
- No database schema or user-facing feature changes.

## 1.0.0+1 — 2026-07-16

- Created the first canonical Airmonlink Business Manager source release.
- Added SQLite product, contact, sale, sale-item, expense and settings storage.
- Added transaction-safe POS checkout, stock deduction and customer credit sales.
- Added outstanding customer and supplier balance payment recording.
- Added dashboard, inventory, customer, supplier, expense, reporting and settings modules.
- Added CSV, PDF and database-backup exports.
- Added Flutter tests and GitHub Actions Windows release packaging.
