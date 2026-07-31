# Build 8 source validation report

**Product:** Airmonlink Business Manager  
**Release:** 1.3.0+8  
**Validation date:** 2026-07-31  
**Release decision:** RELEASE REJECTED pending Flutter and Windows CI

## Baseline

The verified Build 6 source was used as the baseline. Its one-time trial, paid activation, shared licence state, offline grace, revocation persistence, Windows runner, printing, POS and SQLite data model were retained.

## Validation completed in this environment

- Source archive extraction and structure: **PASS**
- Build 8 identity scan: **PASS**
- Relative Dart import resolution: **PASS**
- Dart delimiter/string/comment structural scan: **PASS**
- App-state to commercial-service method reference scan: **PASS**
- YAML parse of `pubspec.yaml` and workflow: **PASS**
- Build 6 schema fixture to schema version 8 simulation: **PASS**
- Legacy row-count preservation: **PASS**
- Commercial table creation: **PASS — 41 tables**
- `PRAGMA integrity_check`: **PASS — ok**
- `PRAGMA foreign_key_check`: **PASS — zero violations**
- Main-branch inventory migration: **PASS**
- Branch-scoped customer/supplier migration: **PASS**
- Commercial report/debt/transfer SQL query execution: **PASS**

## Source checkpoint validator

- Deterministic checks: **17**
- Passed: **16**
- Warnings: **1** (`pubspec.lock` requires `flutter pub get`)
- Failed: **0**

See `BUILD8-SOURCE-VALIDATION.txt`.

## Regression source tests added

- Salted staff PIN hashing
- Invoice debt posted once and part payment allocation
- First purchase receipt increases stock once
- Quotation conversion deducts stock once
- Cashier discount denial
- Customer credit and branch-scoped payment
- Stock-transfer dispatch/receipt once
- Month-end recurring-expense clamping

These tests exist in source but were **not executed** because Flutter/Dart are not installed here.

## Required CI validation — MISSING

- `flutter pub get`
- regenerated `pubspec.lock`
- Dart formatting gate
- Flutter analysis
- Flutter test execution
- Windows release compilation
- Inno Setup compilation
- Portable application launch
- Installed upgrade/data-preservation test
- Real printer and USB scanner test
- Live SMTP/WebDAV/WhatsApp/update endpoint tests

## Known partial areas

- The service layer supports multi-line documents and purchase orders, but the first Build 8 UI creates one product line per new document/order.
- Recurring-expense service supports multiple frequencies; the initial UI exposes a simplified monthly creation flow.
- Branch transfer discrepancy/cancellation workflows require additional UI coverage.
- Audit filtering/export is not complete.
- Advanced report service supports date/branch inputs, but the UI does not expose every filter.
- Update downloads verify HTTPS and SHA-256; executable digital-signature verification is not implemented.
- WhatsApp uses a Web link rather than a configured WhatsApp Business API integration.

## Final status

The package is a source checkpoint for CI and corrective development. It is not a final customer installer.

**RELEASE REJECTED**
