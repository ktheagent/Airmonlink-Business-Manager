import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureConfigService {
  const SecureConfigService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) =>
      _storage.write(key: 'abm.$key', value: value);

  Future<String?> read(String key) => _storage.read(key: 'abm.$key');

  Future<void> delete(String key) => _storage.delete(key: 'abm.$key');

  Future<void> saveSmtpPassword(String password) => write('smtp.password', password);
  Future<String?> smtpPassword() => read('smtp.password');

  Future<void> saveWebDavPassword(String password) =>
      write('webdav.password', password);
  Future<String?> webDavPassword() => read('webdav.password');

  Future<void> saveRemoteDashboardToken(String token) =>
      write('remote_dashboard.token', token);
  Future<String?> remoteDashboardToken() => read('remote_dashboard.token');

  Future<void> saveBackupPassword(String password) =>
      write('backup.password', password);
  Future<String?> backupPassword() => read('backup.password');
}
