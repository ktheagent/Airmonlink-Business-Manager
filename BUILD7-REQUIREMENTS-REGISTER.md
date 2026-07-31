# Build 7 requirements register

- **B7-01 — Staff accounts and five system roles:** SOURCE IMPLEMENTED. Evidence: `lib/commercial/services/commercial_service.dart; lib/commercial/screens/staff_access_screen.dart`. Validation: test/commercial_service_test.dart. Limitation: Flutter execution MISSING.
- **B7-02 — Service and UI permission enforcement:** SOURCE IMPLEMENTED. Evidence: `lib/commercial/models/commercial_models.dart; lib/state/app_state.dart; lib/screens/shell_screen.dart`. Validation: cashier discount regression source test. Limitation: Flutter execution MISSING.
- **B7-03 — Audit trail for sensitive operations:** SOURCE IMPLEMENTED. Evidence: `lib/commercial/services/commercial_service.dart; audit_logs`. Validation: structural/SQL audit PASS. Limitation: Filtering/export PARTIAL.
- **B7-04 — Returns and refunds:** SOURCE IMPLEMENTED. Evidence: `commercial_service.dart; commercial_suite_screen.dart; returns/refunds tables`. Validation: source review. Limitation: Live workflow MISSING.
- **B7-05 — Cash register shifts and variance:** SOURCE IMPLEMENTED. Evidence: `commercial_service.dart; cash_sessions/cash_movements`. Validation: source transaction audit. Limitation: Flutter execution MISSING.
- **B7-06 — Advanced profit reporting:** PARTIAL. Evidence: `commercial_report_service.dart; commercial_suite_screen.dart`. Validation: SQL query audit PASS. Limitation: All requested filters/charts incomplete.
- **B7-07 — Low-stock, expiry and reorder alerts:** PARTIAL. Evidence: `commercial_service.dart; product_batches; branch_inventory`. Validation: SQL/source audit. Limitation: Suggested purchasing model is basic.
