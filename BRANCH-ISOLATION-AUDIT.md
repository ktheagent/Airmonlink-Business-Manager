# Branch isolation audit

## Controls implemented

- Branch ID on staff, customers, suppliers, sales, expenses, documents, purchase orders, debt, cash sessions, stock and transfers.
- Service methods derive branch context from the authenticated staff user.
- Owner/manager consolidated reads are explicit.
- Staff branch switching is limited to owner/manager and blocked while their cash shift is open.
- Imports are assigned to a selected authorized branch.
- Transfers separate draft, dispatch and receipt effects.

## Validation

- Migrated fixture branch defaults: PASS
- Customer debt branch query: PASS
- Profit-by-branch query: PASS
- Transfer query and stock synchronization: PASS
- Source regression test added: PASS
- Flutter execution and hostile-access test: MISSING
