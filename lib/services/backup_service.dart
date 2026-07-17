import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

class BackupService {
  const BackupService(this._databaseService);

  final DatabaseService _databaseService;

  Future<String> createBackup() async {
    await _databaseService.checkpoint();
    final databasePath = await _databaseService.databasePath;
    final documents = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Backups'),
    );
    await backupDirectory.create(recursive: true);

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final destination = p.join(
      backupDirectory.path,
      'airmonlink-business-manager-$timestamp.db',
    );
    await File(databasePath).copy(destination);
    return destination;
  }
}
