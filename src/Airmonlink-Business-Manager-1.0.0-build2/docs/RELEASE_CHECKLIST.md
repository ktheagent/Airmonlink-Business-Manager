# Release checklist

- [ ] Increment semantic version and Flutter build number.
- [ ] Confirm application ID and executable identity remain unchanged.
- [ ] Run `dart format --output=none --set-exit-if-changed lib test`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `flutter build windows --release` on Windows.
- [ ] Launch the compiled application on a clean Windows machine.
- [ ] Add, edit and delete a product.
- [ ] Complete a sale and confirm stock deduction.
- [ ] Complete a customer credit sale and record a repayment.
- [ ] Test insufficient-stock rejection.
- [ ] Export sales CSV, inventory CSV and summary PDF.
- [ ] Create a database backup and verify that the copied SQLite file opens in a test environment.
- [ ] Build and install the Inno Setup package.
- [ ] Scan installer and release folder before distribution.
- [ ] Publish one canonical full-source ZIP and one installer per release.
