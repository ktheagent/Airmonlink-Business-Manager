import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'device_identity_service.dart';
import 'license_api_client.dart';
import 'license_model.dart';
import 'license_status.dart';
import 'license_storage.dart';

class LicenseService {
  LicenseService({
    LicenseStorage? storage,
    LicenseApiClient? apiClient,
    DeviceIdentityService? deviceIdentityService,
    this.packageInfo,
  }) : _storage = storage ?? LicenseStorage(),
       _apiClient = apiClient ?? LicenseApiClient(),
       _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService();
  final LicenseStorage _storage;
  final LicenseApiClient _apiClient;
  final DeviceIdentityService _deviceIdentityService;
  final PackageInfo? packageInfo;

  LicenseModel? _cachedLicense;
  DateTime? _trialStartedAt;

  Future<LicenseStatus> initialize({required String businessName}) async {
    await _deviceIdentityService.getDeviceIdentifier();

    final cachedJson = await _storage.loadCachedLicense();
    if (cachedJson != null) {
      final parsed = jsonDecode(cachedJson) as Map<String, dynamic>;
      _cachedLicense = LicenseModel.fromJson(parsed);
    }

    final now = DateTime.now();
    final trialStart = _trialStartedAt ?? now;
    final trialExpiry = trialStart.add(const Duration(days: 14));
    if (_cachedLicense == null) {
      return LicenseStatus(
        state: now.isAfter(trialExpiry)
            ? LicenseState.expired
            : LicenseState.trial,
        plan: 'trial',
        message: 'Trial access is active until ${_date(trialExpiry)}.',
        isRestricted: now.isAfter(trialExpiry),
      );
    }

    final signed = _cachedLicense!;
    if (signed.status == 'active') {
      final grace = signed.offlineGraceDeadline;
      final inGrace = now.isBefore(grace) && now.isAfter(signed.expiryAt);
      return LicenseStatus(
        state: inGrace ? LicenseState.gracePeriod : LicenseState.active,
        plan: signed.plan,
        message: inGrace
            ? 'Subscription is in grace period.'
            : 'Licence is active.',
        isRestricted: false,
      );
    }

    if (signed.status == 'expired') {
      return const LicenseStatus(
        state: LicenseState.expired,
        plan: 'trial',
        message: 'The licence has expired.',
        isRestricted: true,
      );
    }

    return LicenseStatus(
      state: LicenseState.invalid,
      plan: signed.plan,
      message: 'The licence could not be verified.',
      isRestricted: true,
    );
  }

  Future<LicenseModel?> activateLicense({
    required String licenseKey,
    required String businessName,
  }) async {
    final appPackageInfo = this.packageInfo ?? await PackageInfo.fromPlatform();
    final deviceId = await _deviceIdentityService.getDeviceIdentifier();
    final response = await _apiClient.activate(
      licenseKey: licenseKey,
      deviceIdentifier: deviceId,
      appVersion: appPackageInfo.version,
      platform: Platform.operatingSystem,
      businessName: businessName,
    );
    final model = LicenseModel.fromJson(response);
    _cachedLicense = model;
    await _storage.saveCachedLicense(jsonEncode(response));
    return model;
  }

  Future<void> deactivateLicense() async {
    if (_cachedLicense == null) return;
    await _apiClient.deactivate(token: _cachedLicense!.token);
    await _storage.clearCachedLicense();
    _cachedLicense = null;
  }

  Future<LicenseModel?> validateLicense() async {
    if (_cachedLicense == null) return null;
    final deviceId = await _deviceIdentityService.getDeviceIdentifier();
    final response = await _apiClient.validate(
      token: _cachedLicense!.token,
      deviceIdentifier: deviceId,
    );
    final model = LicenseModel.fromJson(response);
    _cachedLicense = model;
    await _storage.saveCachedLicense(jsonEncode(response));
    return model;
  }

  Future<void> registerTrial() async {
    _trialStartedAt = DateTime.now();
  }

  static String _date(DateTime value) =>
      value.toLocal().toString().split('.').first;
}
