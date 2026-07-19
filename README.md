# Airmonlink Business Manager

Airmonlink Business Manager is an offline-first Windows point-of-sale and small-business management application built with Flutter and SQLite.

## Release identity

- Version: `1.0.0+3`
- Reproducible CI toolchain: Flutter `3.44.0` / Dart `3.12`
- Canonical source package: `Airmonlink-Business-Manager-Full-Source-1.0.0-build3.zip`
- Flutter organization namespace: `com.airmonlink`
- Executable name: `airmonlink_business_manager.exe`

## Included features

- Responsive Windows dashboard
- Point of sale with product search and barcode-field matching
- Cash, Mobile Money, card, bank-transfer and customer-credit recording
- Discounts and optional customer selection
- Transaction-safe stock deduction
- Product, SKU, barcode, category, price and low-stock management
- Stock additions and deductions
- Customer and supplier records with opening balances and payment recording
- Expense recording
- Sales register
- Gross-profit and expense summary
- CSV sales and inventory exports
- PDF business summary with A4/Letter print preview
- 57/80 mm sales receipt preview and Windows printing after checkout
- High-contrast printer test page
- Timestamped local database backups
- Sample products for first-run demonstration
- GitHub Actions Windows compilation and installer packaging

## Local data locations

The SQLite database is placed in the Windows application-support directory. Backups and exports are written under:

```text
Documents/Airmonlink Business Manager/
├── Backups/
└── Exports/
```

## Build on Windows

Install Flutter 3.44.0 and Visual Studio with **Desktop development with C++**, then run:

```powershell
flutter pub get
./tool/bootstrap_windows.ps1
dart format lib test
flutter analyze
flutter test
flutter build windows --release
./tool/package_windows.ps1
```

The release folder is normally located at:

```text
build/windows/x64/runner/Release/
```

Do not distribute only the `.exe`; distribute the complete Release folder or the generated portable ZIP/installer.

## Build with GitHub Actions

1. Create a GitHub repository.
2. Upload this project to the repository.
3. Open **Actions**.
4. Run **Validate and Build Windows Release**.
5. Download the artifact named `Airmonlink-Business-Manager-1.0.0-build3-Windows`.

The workflow installs dependencies, formats the source, performs static analysis and tests, compiles the Windows release, and creates both portable ZIP and Inno Setup packages.

## Validation status

This source was structurally reviewed and checked with repository validation scripts in the delivery environment. The delivery environment did not contain the Flutter SDK or a Windows runner, so no claim is made that a Windows executable was compiled here. The included GitHub workflow is the authoritative compile-and-test gate.

## Commercial roadmap

The next controlled releases should add staff accounts and permissions, returns, purchase orders, detailed payment ledgers, audit history, licensing, automatic cloud backups and multi-branch synchronization.


## Open-source and commercial model

The community core is licensed under **GPL-3.0** so developers can inspect it, fork it, improve it and contribute through pull requests. The Airmonlink name and branding remain protected; unauthorized public forks must use their own product identity. Private commercial licensing, support, deployment and optional premium services can be offered separately. See `LICENSE`, `TRADEMARKS.md` and `COMMERCIAL_LICENSING.md`.
