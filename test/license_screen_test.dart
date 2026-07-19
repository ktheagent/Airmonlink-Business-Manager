import 'package:airmonlink_business_manager/licensing/license_service.dart';
import 'package:airmonlink_business_manager/licensing/license_status.dart';
import 'package:airmonlink_business_manager/screens/license_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLicenseService extends LicenseService {
  FakeLicenseService() : super();

  @override
  Future<LicenseStatus> initialize({required String businessName}) async {
    return const LicenseStatus(
      state: LicenseState.trial,
      plan: 'trial',
      message: 'Trial access is active.',
      isRestricted: false,
    );
  }
}

void main() {
  testWidgets('license screen renders trial state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LicenseScreen(service: FakeLicenseService())),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Commercial licence control'), findsOneWidget);
    expect(find.text('Trial access is active.'), findsOneWidget);
  });
}
