enum LicenseKind { trial, perpetual, subscription }

enum LicenseStatus { uninitialized, trial, active, expired, invalid }

class AppLicense {
  const AppLicense({
    required this.status,
    required this.kind,
    required this.installationId,
    this.licenseId,
    this.customerName,
    this.companyName,
    this.edition = 'Professional',
    this.devicesAllowed = 1,
    this.devicesActivated = 1,
    this.issuedAt,
    this.expiresAt,
    this.updatesIncludedUntil,
    this.lastValidUseAt,
  });

  final LicenseStatus status;
  final LicenseKind kind;
  final String installationId;
  final String? licenseId;
  final String? customerName;
  final String? companyName;
  final String edition;
  final int devicesAllowed;
  final int devicesActivated;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? updatesIncludedUntil;
  final DateTime? lastValidUseAt;

  bool get isActive => status == LicenseStatus.active || status == LicenseStatus.trial;
  bool get canWrite => isActive && !(expiresAt?.isBefore(DateTime.now()) ?? false);
  int get daysRemaining {
    final end = expiresAt;
    if (end == null) return -1;
    final days = end.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  AppLicense copyWith({
    LicenseStatus? status,
    DateTime? lastValidUseAt,
  }) =>
      AppLicense(
        status: status ?? this.status,
        kind: kind,
        installationId: installationId,
        licenseId: licenseId,
        customerName: customerName,
        companyName: companyName,
        edition: edition,
        devicesAllowed: devicesAllowed,
        devicesActivated: devicesActivated,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        updatesIncludedUntil: updatesIncludedUntil,
        lastValidUseAt: lastValidUseAt ?? this.lastValidUseAt,
      );

  Map<String, Object?> toJson() => {
        'status': status.name,
        'kind': kind.name,
        'installationId': installationId,
        'licenseId': licenseId,
        'customerName': customerName,
        'companyName': companyName,
        'edition': edition,
        'devicesAllowed': devicesAllowed,
        'devicesActivated': devicesActivated,
        'issuedAt': issuedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'updatesIncludedUntil': updatesIncludedUntil?.toIso8601String(),
        'lastValidUseAt': lastValidUseAt?.toIso8601String(),
      };

  factory AppLicense.fromJson(Map<String, dynamic> json) => AppLicense(
        status: LicenseStatus.values.byName(json['status'] as String),
        kind: LicenseKind.values.byName(json['kind'] as String),
        installationId: json['installationId'] as String,
        licenseId: json['licenseId'] as String?,
        customerName: json['customerName'] as String?,
        companyName: json['companyName'] as String?,
        edition: json['edition'] as String? ?? 'Professional',
        devicesAllowed: json['devicesAllowed'] as int? ?? 1,
        devicesActivated: json['devicesActivated'] as int? ?? 1,
        issuedAt: _date(json['issuedAt']),
        expiresAt: _date(json['expiresAt']),
        updatesIncludedUntil: _date(json['updatesIncludedUntil']),
        lastValidUseAt: _date(json['lastValidUseAt']),
      );

  static DateTime? _date(dynamic value) => value is String ? DateTime.tryParse(value) : null;
}
