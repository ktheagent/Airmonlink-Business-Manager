import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LicenseStorage {
  LicenseStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveCachedLicense(String value) async {
    await _storage.write(key: 'cached_license', value: value);
  }

  Future<String?> loadCachedLicense() async {
    return _storage.read(key: 'cached_license');
  }

  Future<void> clearCachedLicense() async {
    await _storage.delete(key: 'cached_license');
  }
}
