import 'dart:convert';

import 'package:flutter_foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/app_constants.dart';
import '../models/app_license.dart';
import 'license_service.dart';

class LicenseController extends ChangeNotifier {
  LicenseController({
    LicenseService? service,
    FlutterSecureStorage? storage,
  }) : _service = service ?? LicenseService(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _trialKey = 'airmonlink.trial.state';

  final LicenseService _service;
  final FlutterSecureStorage _storage;

  AppLicense? _license;
  bool isLoading = true;
  String? errorMessage;

  AppLicense? get license => _license;
  bool get canWrite => _license?.canWrite ?? false;
  bool get isTrial => _license?.kind == LicenseKind.trial;
  bool get isUninitialized => _license?.status == LicenseStatus.uninitialized;

  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final paid = await _service.load();
      if (paid.status != LicenseStatus.uninitialized && paid.kind != LicenseKind.trial) {
        _license = paid;
      } else {
        _license = await _loadTrial() ?? paid;
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startTrial() async {
    final now = DateTime.now().toUtc();
    final id = await _service.getInstallationId();
    final trial = AppLicense(
      status: LicenseStatus.trial,
      kind: LicenseKind.trial,
      installationId: id,
      licenseId: 'TRIAL-${id.substring(0, 8)}',
      issuedAt: now,
      expiresAt: now.add(const Duration(days: AppConstants.trialDays)),
      lastValidUseAt: now,
    );
    await _storage.write(key: _trialKey, value: jsonEncode(trial.toJson()));
    _license = trial;
    notifyListeners();
  }

  Future<void> activate(String key) async {
    _license = await _service.activate(key);
    await _storage.delete(key: _trialKey);
    notifyListeners();
  }

  Future<void> importOffline(String token) async {
    _license = await _service.importOfflineLicense(token);
    await _storage.delete(key: _trialKey);
    notifyListeners();
  }

  Future<void> deactivate() async {
    await _service.deactivate();
    _license = await _loadTrial() ??
      AppLicense(
        status: LicenseStatus.uninitialized,
        kind: LicenseKind.trial,
        installationId: await _service.getInstallationId(),
      );
    notifyListeners();
  }

  Future<void> openPurchasePage() => _service.openPurchasePage();

  Future<AppLicense?> _loadTrial() async {
    final raw = await _storage.read(key: _trialKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final trial = AppLicense.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final now = DateTime.now().toUtc();
      final last = trial.lastValidUseAt?.toUtc();
      if (last != null && now.isBefore(last.subtract(const Duration$hours: 24)))) {
        return trial.copyWith(status: LicenseStatus.invalid);
      }
      final updated = trial.copyWith(lastValidUseAt: now);
      await _storage.write(key: _trialKey, value: jsonEncode(updated.toJson()));
      if (updated.expiresAt?.isBefore(now) ?? false) {
        return updated.copyWith(status: LicenseStatus.expired);
      }
      return updated;
    } catch (_) {
      await _storage.delete(key: _trialKey);
      return null;
    }
  }
}
