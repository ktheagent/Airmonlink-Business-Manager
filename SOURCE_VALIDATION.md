# Source validation report

**Product:** Airmonlink Business Manager  
**Release:** 1.0.1+4 (build 3)  
**Validation date:** 2026-07-19

## Printing correction delivered

- Added the supported Flutter `printing` package for Windows print preview and native printer submission.
- Added explicit A4, A5 and Letter business-summary preview and printing.
- Added 57 mm and 80 mm receipt preview and printing after every completed sale.
- Added a high-contrast printer test page under Business Settings.
- Added explicit Helvetica regular, bold, italic and bold-italic PDF fonts.
- Added visible no-sales and no-expenses rows so a report cannot appear empty when the database has no records.
- Added PDF byte validation that rejects missing, undersized or invalid PDF output before saving or printing.
- Added source tests for summary and receipt PDF generation.
- Preserved the existing SQLite schema and business data model.

## Checks completed in the delivery environment

- Repository structure and required release files: **PASS**
- Dart delimiter, string and comment structural scan: **PASS**
- Relative Dart import resolution: **PASS**
- YAML parsing for workflows, Dependabot and issue forms: **PASS**
- Release naming and version consistency: **PASS**
- SQLite schema execution in an in-memory database: **PASS**
- Credential and secret-pattern scan: **PASS**
- Printing API names checked against the official `printing` 5.15.0 and `pdf` 3.13.0 documentation: **PASS**
- Dart source and test files: **29**
- Dart source and test lines: **4209**
- Repository files before manifest generation: **53**

## Validation not performed locally

The delivery environment did not contain Flutter, Dart, Visual Studio, a Windows runner, a physical printer or Inno Setup. Therefore, the following are **not claimed as locally completed**:

- `dart format`
- `flutter analyze`
- `flutter test`
- `flutter build windows --release`
- Windows application launch
- PDF preview rendering through Windows PDFium
- Physical 57 mm, 80 mm or A4 printer testing
- Inno Setup installer compilation or installation testing

The included GitHub Actions workflow performs formatting, static analysis, tests, Windows compilation, portable packaging and installer creation using Flutter 3.44.0. A release should be distributed only after that workflow succeeds and the printer test page, receipt and report are tested on the target Windows computer.

## Artifact status

This delivery is the canonical **full-source** printing-fix release. It does not contain a compiled `.exe` or installer produced in this environment.
