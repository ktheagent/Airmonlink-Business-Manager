import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

class BackupService {
  const BackupService(this._databaseService);

  final DatabaseService _databaseService;

  Future<String> createBackup() async {
    await _databaseService.checkpoint();
    final databasePath = await _databaseService.databasePath;
    final backupDirectory = await _backupDirectory();
    final destination = p.join(
      backupDirectory.path,
      'airmonlink-business-manager-${_timestamp()}.db',
    );
    await File(databasePath).copy(destination);
    return destination;
  }

  Future<String> createEncryptedBackup({
    required String password,
    String destination = 'local',
    int? createdBy,
  }) async {
    if (password.length < 8) {
      throw ArgumentError('Backup password must contain at least eight characters.');
    }
    await _databaseService.checkpoint();
    final databasePath = await _databaseService.databasePath;
    final bytes = await File(databasePath).readAsBytes();
    final checksum = legacy_crypto.sha256.convert(bytes).toString();
    final payload = utf8.encode(jsonEncode({
      'format': 'airmonlink-business-manager-backup',
      'format_version': 1,
      'schema_version': DatabaseService.schemaVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'database_sha256': checksum,
      'database_bytes': base64Encode(bytes),
    }));

    final salt = _randomBytes(16);
    final algorithm = AesGcm.with256bits();
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    final secretBox = await algorithm.encrypt(payload, secretKey: key);
    final envelope = utf8.encode(jsonEncode({
      'magic': 'ABMENC1',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': 210000,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'cipher_text': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    }));
    final backupDirectory = await _backupDirectory();
    final path = p.join(
      backupDirectory.path,
      'airmonlink-business-manager-${_timestamp()}.abmbackup',
    );
    await File(path).writeAsBytes(envelope, flush: true);
    await _recordBackup(
      path: path,
      checksum: legacy_crypto.sha256.convert(envelope).toString(),
      encrypted: true,
      destination: destination,
      status: 'completed',
      createdBy: createdBy,
      sizeBytes: envelope.length,
    );
    return path;
  }

  Future<void> restoreEncryptedBackup({
    required String backupPath,
    required String password,
  }) async {
    final source = File(backupPath);
    if (!await source.exists()) throw StateError('Backup file was not found.');
    final envelopeBytes = await source.readAsBytes();
    final envelope = jsonDecode(utf8.decode(envelopeBytes));
    if (envelope is! Map<String, dynamic> || envelope['magic'] != 'ABMENC1') {
      throw StateError('This is not a supported Airmonlink backup.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final secretBox = SecretBox(
      base64Decode(envelope['cipher_text'] as String),
      nonce: base64Decode(envelope['nonce'] as String),
      mac: Mac(base64Decode(envelope['mac'] as String)),
    );
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: (envelope['iterations'] as num).toInt(),
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    late final List<int> clearText;
    try {
      clearText = await AesGcm.with256bits().decrypt(secretBox, secretKey: key);
    } catch (_) {
      throw StateError('Backup password is incorrect or the file is damaged.');
    }
    final payload = jsonDecode(utf8.decode(clearText));
    if (payload is! Map<String, dynamic> ||
        payload['format'] != 'airmonlink-business-manager-backup') {
      throw StateError('Backup content is invalid.');
    }
    final databaseBytes = base64Decode(payload['database_bytes'] as String);
    final expected = payload['database_sha256'] as String;
    final actual = legacy_crypto.sha256.convert(databaseBytes).toString();
    if (actual != expected) throw StateError('Backup integrity verification failed.');

    final databasePath = await _databaseService.databasePath;
    final databaseFile = File(databasePath);
    final safetyPath = '$databasePath.before-restore-${_timestamp()}';
    await _databaseService.checkpoint();
    await databaseFile.copy(safetyPath);
    await _databaseService.close();
    try {
      await _removeSidecars(databasePath);
      await databaseFile.writeAsBytes(databaseBytes, flush: true);
      final report = await _databaseService.integrityReport();
      if (report['integrity'] != 'ok' || report['foreign_key_violations'] != 0) {
        throw StateError('Restored database failed integrity verification.');
      }
    } catch (error) {
      await _databaseService.close();
      await File(safetyPath).copy(databasePath);
      await _removeSidecars(databasePath);
      await _databaseService.database;
      rethrow;
    }
  }

  Future<void> uploadWebDav({
    required String backupPath,
    required Uri endpoint,
    required String username,
    required String password,
  }) async {
    if (endpoint.scheme != 'https') {
      throw ArgumentError('WebDAV backups require an HTTPS endpoint.');
    }
    final file = File(backupPath);
    if (!await file.exists()) throw StateError('Backup file was not found.');
    final target = endpoint.replace(
      path: '${endpoint.path.endsWith('/') ? endpoint.path : '${endpoint.path}/'}${p.basename(backupPath)}',
    );
    final response = await http.put(
      target,
      headers: {
        HttpHeaders.authorizationHeader:
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
      },
      body: await file.readAsBytes(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Cloud backup failed with status ${response.statusCode}.');
    }
  }

  Future<Directory> _backupDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Backups'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _recordBackup({
    required String path,
    required String checksum,
    required bool encrypted,
    required String destination,
    required String status,
    required int? createdBy,
    required int sizeBytes,
    String errorMessage = '',
  }) async {
    final db = await _databaseService.database;
    await db.insert('backup_records', {
      'path': path,
      'checksum': checksum,
      'encrypted': encrypted ? 1 : 0,
      'destination': destination,
      'status': status,
      'size_bytes': sizeBytes,
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
      'error_message': errorMessage,
    });
  }

  static Future<void> _removeSidecars(String databasePath) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  static Uint8List _randomBytes(int count) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(count, (_) => random.nextInt(256)),
    );
  }

  static String _timestamp() => DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
}
