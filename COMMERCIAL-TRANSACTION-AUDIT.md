# Commercial transaction audit

## Corrective findings implemented

- First purchase receipt previously risked double stock on an absent branch-inventory row; insertion now starts at zero before the receipt increment.
- Supplier deposits remain deposits until receipt creates a liability.
- Invoice debt posts once and document payments reduce only the matching debt.
- Invoice-to-sale conversion excludes previously recorded payments from new cash.
- Converted documents cannot repeat stock/payment effects.
- Cash payment/refund/supplier/expense operations require an open cash session.
- Discount permission is checked in the transaction service, not only the UI.
- Customer, supplier, inventory and import updates are branch-scoped.
- Main-branch transfers synchronize the legacy product stock field used by preserved screens.

## Validation

- Static source review: PASS
- SQL query execution against migrated fixture: PASS
- Source regression tests added: PASS
- Flutter test execution: MISSING
- Live end-to-end Windows transactions: MISSING
