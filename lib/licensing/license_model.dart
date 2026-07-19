class LicenseModel {
  const LicenseModel({
    required this.licenseId,
    required this.customer,
    required this.plan,
    required this.status,
    required this.issuedAt,
    required this.expiryAt,
    required this.deviceLimit,
    required this.activatedDevice,
    required this.offlineGraceDeadline,
    required this.signature,
    required this.token,
  });

  final String licenseId;
  final String customer;
  final String plan;
  final String status;
  final DateTime issuedAt;
  final DateTime expiryAt;
  final int deviceLimit;
  final String activatedDevice;
  final DateTime offlineGraceDeadline;
  final String signature;
  final String token;

  factory LicenseModel.fromJson(Map<String, dynamic> json) {
    return LicenseModel(
      licenseId: json['licenseId']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      plan: json['plan']?.toString() ?? 'trial',
      status: json['status']?.toString() ?? 'trial',
      issuedAt: DateTime.parse(
        json['issuedDate']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      expiryAt: DateTime.parse(
        json['expiryDate']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      deviceLimit: int.tryParse(json['deviceLimit']?.toString() ?? '1') ?? 1,
      activatedDevice: json['activatedDevice']?.toString() ?? '',
      offlineGraceDeadline: DateTime.parse(
        json['offlineGraceDeadline']?.toString() ??
            DateTime.now().toIso8601String(),
      ),
      signature: json['signature']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }
}
