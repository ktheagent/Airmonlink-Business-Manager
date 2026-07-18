import 'package:flutter/widgets.dart';

import '../models/app_license.dart';
import '../services/license_service.dart';

class LicenseScope extends InheritedWidget {
  const LicenseScope({
    required this.license,
    required this.service,
    required super.child,
    super.key,
  });

  final AppLicense license;
  final LicenseService service;

  static LicenseScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LicenseScope>();
    assert(scope != null, 'No LicenseScope found.');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant LicenseScope oldWidget) =>
      license.status != oldWidget.license.status ||
      license.expiresAt != oldWidget.license.expiresAt ||
      license.licenseId != oldWidget.license.licenseId;
}
