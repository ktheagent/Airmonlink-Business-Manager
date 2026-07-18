import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_constants.dart';
import '../models/app_license.dart';

class LicenseException implements Exception {
  const LicenseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LicenseService {
  LicenseService({
    FlutterSecureStorage? storage,
    http.Client? client,
  }) : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  static const _licenseKey = 'airmonlink.license.token';
  static const _installationKey = 'airmonlink.installation.id';

  final FlutterSecureStorage _storage;
  final http.Client _client;

  Future<String> getInstallationId() async {
    final existing = await _storage.read(key: _installationKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final value = base64Url.encode(bytes).replaceAll('=', '');
    await _storage.write(key: _installationKey, value: value);
    return value;
  }

  Future<AppLicense> load() async {
    final installationId = await getInstallationId();
    final token = await _storage.read(key: _licenseKey);
    if (token == null || token.isEmpty) {
      return AppLicense(
        status: LicenseStatus.uninitialized,
        kind: LicenseKind.trial,
        installationId: installationId,
      );
    }
    try {
      final license = await _verifyToken(token);
      if (license.installationId != installationId) {
        throw const LicenseException('This license belongs to another installation.');
      }
      final now = DateTime.now().toUtc();
      final lastValid = license.lastValidUseAt?.toUtc();
      if (lastValid != null && now.isBefore(lastValid.subtract(const Duration(hours: 24)))) {
        return license.copyWith(status: LicenseStatus.invalid);
      }
      final updated = license.copyWith(lastValidUseAt: now);
      await _storeLicense(updated);
      if (updated.expiresAt?.isBefore(now) ?? false) {
        return updated.copyWith(status: LicenseStatus.expired);
      }
      return updated;
    } catch (_) {
      return AppLicense(
        status: LicenseStatus.invalid,
        kind: LicenseKind.trial,
        installationId: installationId,
      );
    }
  }

  Futur<AppLicense> startTrial() async {
    final current = await load();
    if (current.status != LicenseStatus.uninitialized) return current;
    final now = DateTime.now().toUtc();
    final license = AppLicense(
      status: LicenseStatus.trial,
      kind: LicenseKind.trial,
      installationId: current.installationId,
      licenseId: 'TRIAL-${current.installationId.substring(0, 8).toUpperCase()}',
      issuedAt: now,
      expiresAt: now.add(const Duration(days: AppConstants.trialDays)),
      lastValidUseAt: now,
    );
    await _storeLicense(license);
    return license;
  }

  Future<AppLicense> activate(String licenseKey) async {
    final installationId = await getInstallationId();
    final uri = Uri.parse('${AppConstants.licensingApiUrl}/api/v1/activate');
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'license_key': licenseKey.trim(),
        'installation_id': installationId,
        'app_version': AppConstants.version,
      }),
    );
    if (response.statusCode != 200) {
      throw LicenseException('Activation failed (${response.statusCode}).');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const LicenseException('The licensing server did not return a signed token.');
    }
    final license = await _verifyToken(token);
    if (license.installationId != installationId) {
      throw const LicenseException('The activation token does not match this installation.');
    }
    await _storage.write(key: _licenseKey, value: token);
    return license;
  }

  Future<AppLicense> importOfflineLicense(String token) async {
    final license = await _verifyToken(token.trim());
    final installationId = await getInstallationId();
    if (license.installationId != installationId) {
      throw const LicenseException('The offline license does not belong to this computer.');
    }
    await _storage.write(key: _licenseKey, value: token.trim());
    return license;
  }

  Future<void> deactivate() async {
    final license = await load();
    final licenseId = license.licenseId;
    if (licenseId != null) {
      try {
        await _client.post(
          Uri.parse('${AppConstants.licensingApiUrl}/api/v1/deactivate'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'license_id': licenseId,
            'installation_id': license.installationId,
          }),
        );
      } catch (_) {}
    }
    await _storage.delete(key: _licenseKey);
  }

  Future<void> openPurchasePage() async {
    final uri = Uri.parse(AppConstants.purchaseUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const LicenseException('Could not open the purchase page.');
    }
  }

  Future<AppLicense> _verifyToken(String token) async {
    final parts = token.split('.');
    if (parts.length != 2) {
      throw const LicenseException('Invalid license token format.');
    }
    final publicKeyText = AppConstants.licensePublicKeyBase64.trim();
    if (publicKeyText.isEmpty) {
      throw const LicenseException('Production license verification is not configured.');
    }
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
    final message = utf8.encode(parts[0]);
    final signatureBytes = base64Url.decode(base64Url.normalize(parts[1]));
    final publicKeyBytes = base64.decode(publicKeyText);
    if (publicKeyBytes.length != 32) {
      throw const LicenseException('The configured Ed25519 public key is invalid.');
    }
    final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    final isValid = await Ed25519().verify(message, signature: Signature(signatureBytes, publicKey: publicKey));
    if (!isValid) throw const LicenseException('The license signature is invalid.');
    final json = jsonDecode(payload) as Map<String, dynamic>;
    return AppLicense.fromJson(json);
  }

  Future<void> _storeLicense(AppLicense license) async {
    final payload = base64Url.encode(utf8.encode(jsonEncode(license.toJson()))).replaceAll('=', '');
    // Trial licenses are locally issued and are stored in protected storage.
    // Paid licenses are never re-signed by the client.
    if (license.kind == LicenseKind.trial) {
      await _storage.write(key: _licenseKey, value: '$payload.local');
    }
  }
}
