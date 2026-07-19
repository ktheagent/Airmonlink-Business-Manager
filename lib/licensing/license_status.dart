enum LicenseState {
  trial,
  active,
  gracePeriod,
  expired,
  suspended,
  invalid,
  activationRequired,
}

class LicenseStatus {
  const LicenseStatus({
    required this.state,
    required this.plan,
    required this.message,
    required this.isRestricted,
  });

  final LicenseState state;
  final String plan;
  final String message;
  final bool isRestricted;
}
