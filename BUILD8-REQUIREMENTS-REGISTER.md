# Build 8 requirements register

- **B8-01 — Commercial documents and conversion:** SOURCE IMPLEMENTED. Evidence: `documents/document_items; commercial_service.dart; commercial_document_service.dart`. Validation: conversion regression source test. Limitation: Initial creation UI is single-line.
- **B8-02 — Purchase orders and supplier accounts:** SOURCE IMPLEMENTED. Evidence: `purchase_orders; goods_receipts; supplier_payments`. Validation: receipt regression source test. Limitation: Initial creation UI is single-line.
- **B8-03 — Customer debt and statements:** SOURCE IMPLEMENTED. Evidence: `customer_transactions; commercial_suite_screen.dart`. Validation: branch/credit regression source test. Limitation: Ageing UI PARTIAL.
- **B8-04 — Stock adjustment/counting/barcode labels:** SOURCE IMPLEMENTED. Evidence: `stock_adjustments; stock_counts; commercial_document_service.dart`. Validation: source/SQL audit. Limitation: Physical printer/scanner MISSING.
- **B8-05 — Multi-branch and stock transfer:** SOURCE IMPLEMENTED. Evidence: `branches; branch_inventory; stock_transfers`. Validation: transfer regression source test. Limitation: Discrepancy/cancellation UI PARTIAL.
- **B8-06 — Encrypted local/WebDAV backup and restore:** SOURCE IMPLEMENTED. Evidence: `backup_service.dart; secure_config_service.dart`. Validation: source structural audit. Limitation: Live restore/WebDAV MISSING.
- **B8-07 — Remote owner dashboard:** SOURCE IMPLEMENTED. Evidence: `remote_dashboard_service.dart`. Validation: source structural audit. Limitation: Live network test MISSING.
- **B8-08 — WhatsApp/email documents:** PARTIAL. Evidence: `notification_service.dart; settings_screen.dart`. Validation: source structural audit. Limitation: WhatsApp Business API not implemented.
- **B8-09 — Recurring expenses/reminders:** SOURCE IMPLEMENTED. Evidence: `recurring_expenses; app_state.dart`. Validation: month-end regression source test. Limitation: UI simplified.
- **B8-10 — CSV/XLSX data import:** SOURCE IMPLEMENTED. Evidence: `import_service.dart; import_jobs`. Validation: source structural audit. Limitation: Flutter execution MISSING.
- **B8-11 — Automatic software updates:** PARTIAL. Evidence: `update_service.dart; update_records`. Validation: SHA-256 source logic review. Limitation: Digital signature verification INCOMPLETE.
- **B8-12 — Business health dashboard:** PARTIAL. Evidence: `commercial_service.dart; commercial_suite_screen.dart`. Validation: SQL query audit PASS. Limitation: Full trend/chart set incomplete.
