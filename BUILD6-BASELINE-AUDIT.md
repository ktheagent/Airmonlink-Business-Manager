# Build 6 baseline audit

## Verified baseline

- Identity: Airmonlink Business Manager 1.1.1+6
- Baseline archive: `Airmonlink-Business-Manager-1.1.1-build6-Full-Source.zip`
- Existing SQLite business tables: products, customers, suppliers, sales, sale_items, expenses and settings
- Windows runner: present
- Licence controller, licence screen and status badge: present
- Existing regression tests: present

## Functions preserved by Build 8 source

- POS and transaction-safe stock deduction
- Products, contacts, expenses and reports
- Receipt generation, printing and reprinting
- Barcode search and keyboard/HID scanner path
- Business settings and application branding
- Build 6 trial/activation/deactivation/grace/revocation logic

## Baseline defects avoided

Build 8 uses additive schema migration. It does not delete the original tables, reset the database, replace the licence controller or move the application data into the installer directory.
