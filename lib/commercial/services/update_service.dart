import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/database_service.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.availableVersion,
    required this.downloadUrl,
    required this.sha256,
    required this.releaseNotes,
    required this.mandatory,
  });

  final String currentVersion;
  final String availableVersion;
  final Uri downloadUrl;
  final String sha256;
  final String releaseNotes;
  final bool mandatory;

  bool get isNewer => _compareVersions(availableVersion, currentVersion) > 0;

  static int _compareVersions(String left, String right) {
    final a = left.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final b = right.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}

class UpdateService {
  const UpdateService(this._database);

  final DatabaseService _database;

  Future<UpdateInfo> check(Uri manifestUri) async {
    if (manifestUri.scheme != 'https') {
      throw ArgumentError('Update manifests must use HTTPS.');
    }
    final response = await http.get(manifestUri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Update check failed with status ${response.statusCode}.');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) throw FormatException('Invalid update manifest.');
    final package = await PackageInfo.fromPlatform();
    final info = UpdateInfo(
      currentVersion: package.version,
      availableVersion: data['version'] as String,
      downloadUrl: Uri.parse(data['download_url'] as String),
      sha256: (data['sha256'] as String).toLowerCase(),
      releaseNotes: data['release_notes'] as String? ?? '',
      mandatory: data['mandatory'] as bool? ?? false,
    );
    if (info.downloadUrl.scheme != 'https' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(info.sha256)) {
      throw FormatException('The update manifest is not secure or complete.');
    }
    final db = await _database.database;
    await db.insert('update_records', {
      'current_version': info.currentVersion,
      'available_version': info.availableVersion,
      'download_url': info.downloadUrl.toString(),
      'checksum': info.sha256,
      'status': info.isNewer ? 'available' : 'current',
      'checked_at': DateTime.now().toIso8601String(),
    });
    return info;
  }

  Future<String> download(UpdateInfo info) async {
    if (!info.isNewer) throw StateError('The installed version is already current.');
    final response = await http.get(info.downloadUrl).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw HttpException('Update download failed with status ${response.statusCode}.');
    }
    final actual = sha256.convert(response.bodyBytes).toString();
    if (actual.toLowerCase() != info.sha256.toLowerCase()) {
      throw StateError('Update checksum verification failed.');
    }
    final temporary = await getTemporaryDirectory();
    final filename = p.basename(info.downloadUrl.path).isEmpty
        ? 'Airmonlink-Business-Manager-Update.exe'
        : p.basename(info.downloadUrl.path);
    final path = p.join(temporary.path, filename);
    await File(path).writeAsBytes(response.bodyBytes, flush: true);
    return path;
  }

  Future<void> launchInstaller(String installerPath) async {
    final file = File(installerPath);
    if (!await file.exists()) throw StateError('Update installer was not found.');
    if (!Platform.isWindows) throw UnsupportedError('Automatic installation is supported on Windows only.');
    await Process.start(
      installerPath,
      const [],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
  }
}
