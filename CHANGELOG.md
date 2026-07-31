# Changelog

## 1.3.0+8 — 2026-07-31

### Commercial operations

- Added quotations, estimates, pro-forma invoices, invoices, delivery notes, credit notes and branded PDF output.
- Added quotation-to-invoice and quotation-to-sale conversion with duplicate-conversion protection.
- Added customer credit limits, account transactions, part payments and printable statements.
- Added purchase orders, partial/full goods receipt, supplier deposits, supplier part payments and supplier balances.
- Added stock adjustments, approval-based physical counts, product batches, expiry data and barcode-label PDFs.
- Added returns, refunds, automatic restocking controls and refund accounting.
- Added cash registers, opening/closing shifts, cash movements and expected-versus-actual variance.

### Professional control

- Added owner, manager, cashier, accountant and stock-officer roles.
- Added salted PBKDF2 staff PINs and automatic migration of legacy SHA-256 hashes after successful login.
- Added service-level permissions, staff sessions, failed-login tracking and audit records.
- Added profit, branch, debt, low-stock and business-health reporting.

### Premium services

- Added branch inventory, branch switching and dispatch/receipt stock transfers.
- Added AES-GCM encrypted backups, integrity hashes, safety backups, restore rollback and optional WebDAV upload.
- Added CSV/XLSX import services with preview validation, duplicate handling and transaction rollback.
- Added token-protected, rate-limited, read-only local owner dashboard.
- Added SMTP document delivery and WhatsApp Web links.
- Added recurring expenses with month-end and leap-year date clamping.
- Added HTTPS update manifests and SHA-256-verified installer downloads.

### Corrective transaction audit

- Prevented first purchase receipt from doubling stock.
- Preserved supplier deposits before goods receipt without prematurely reducing supplier debt.
- Prevented invoice payments from reducing unrelated customer debt.
- Prevented partly paid invoice conversion from counting previous payments twice.
- Prevented repeated quotation/invoice conversion and repeated stock effects.
- Enforced cash sessions for cash sales, customer payments, supplier payments, expenses and refunds.
- Enforced discount permissions at transaction level.
- Corrected branch-scoped imports, customer debt, stock transfers and legacy main-branch stock synchronization.

### Validation limitations

- Added source regression tests, but Flutter tests were not executable in the delivery environment.
- Added Build 8 Windows CI and packaging identity, but Windows compilation and installer testing remain GitHub Actions gates.
- Digital-signature verification for update installers remains incomplete; SHA-256 verification is implemented.


## 1.1.1+6 — 2026-07-31

- Replaced the in-memory trial timer with the live licence server `/trial/register` endpoint.
- Made trial registration idempotent: the same device always keeps its original start and expiry dates.
- Removed every trial prompt immediately after a paid licence activates.
- Replaced the incorrect business-name-based “Licensed” badge with the shared real licence state.
- Hid licence-key inputs after activation and added explicit Change licence, Validate now and Deactivate licence controls.
- Added server-response alias parsing for real expiry, device, customer and business-name fields.
- Added active, trial, grace-period, expired, suspended, revoked, deactivated and invalid states.
- Added regression tests for trial non-extension, restart persistence, paid activation replacement and UI consistency.
- Updated Windows installer, portable package and GitHub Actions artifact identity to version 1.1.1 build 6.
- Set Start Menu and desktop shortcuts to use the installed application executable icon explicitly.

## 1.0.1+4 — 2026-07-19

- Fixed SQLite partial-index SQL quoting for empty SKU values.
- Fixed receipt PDF generation by using a finite thermal-paper height.
- Resolved analyzer failures caused by unbraced single-line if statements.
- Applied Dart formatting and safe automatic fixes.

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
