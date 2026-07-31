import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../services/database_service.dart';
import '../models/commercial_models.dart';

class ImportResult {
  const ImportResult({
    required this.totalRows,
    required this.importedRows,
    required this.skippedRows,
    required this.failedRows,
    required this.errors,
  });

  final int totalRows;
  final int importedRows;
  final int skippedRows;
  final int failedRows;
  final List<String> errors;
}

class ImportService {
  const ImportService(this._database);

  final DatabaseService _database;

  Future<ImportResult> importFile({
    required StaffUser actor,
    required String path,
    required String importType,
    bool updateExisting = false,
  }) async {
    if (!actor.can(CommercialPermission.importsManage)) {
      throw StateError('Your staff role cannot import data.');
    }
    final file = File(path);
    if (!await file.exists()) throw StateError('Import file was not found.');
    final rows = await _readRows(file);
    if (rows.length < 2) throw StateError('The import file contains no data rows.');
    final headers = rows.first
        .map((value) => value.trim().toLowerCase().replaceAll(' ', '_'))
        .toList();
    final dataRows = rows.skip(1).where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
    final errors = <String>[];
    var imported = 0;
    var skipped = 0;
    var failed = 0;
    final db = await _database.database;
    final jobId = await db.insert('import_jobs', {
      'branch_id': actor.branchId,
      'import_type': importType,
      'source_path': path,
      'total_rows': dataRows.length,
      'status': 'running',
      'created_by': actor.id,
      'created_at': DateTime.now().toIso8601String(),
    });
    try {
      await db.transaction((txn) async {
        for (var index = 0; index < dataRows.length; index++) {
          final line = index + 2;
          final values = <String, String>{};
          for (var column = 0; column < headers.length; column++) {
            values[headers[column]] = column < dataRows[index].length
                ? dataRows[index][column].trim()
                : '';
          }
          try {
            final changed = switch (importType) {
              'products' => await _importProduct(
                  txn,
                  branchId: actor.branchId,
                  values: values,
                  updateExisting: updateExisting,
                ),
              'customers' => await _importContact(
                  txn,
                  table: 'customers',
                  branchId: actor.branchId,
                  values: values,
                  updateExisting: updateExisting,
                ),
              'suppliers' => await _importContact(
                  txn,
                  table: 'suppliers',
                  branchId: actor.branchId,
                  values: values,
                  updateExisting: updateExisting,
                ),
              'opening_stock' => await _importOpeningStock(
                  txn,
                  branchId: actor.branchId,
                  values: values,
                ),
              _ => throw ArgumentError('Unsupported import type: $importType'),
            };
            if (changed) {
              imported++;
            } else {
              skipped++;
            }
          } catch (error) {
            failed++;
            errors.add('Row $line: $error');
          }
        }
        if (failed > 0) {
          throw _ImportValidationException(errors);
        }
      });
      await db.update(
        'import_jobs',
        {
          'imported_rows': imported,
          'skipped_rows': skipped,
          'failed_rows': failed,
          'status': 'completed',
          'error_report': '',
        },
        where: 'id = ?',
        whereArgs: [jobId],
      );
    } on _ImportValidationException {
      await db.update(
        'import_jobs',
        {
          'imported_rows': 0,
          'skipped_rows': 0,
          'failed_rows': failed,
          'status': 'failed',
          'error_report': errors.join('\n'),
        },
        where: 'id = ?',
        whereArgs: [jobId],
      );
      imported = 0;
      skipped = 0;
    } catch (error) {
      await db.update(
        'import_jobs',
        {'status': 'failed', 'error_report': '$error'},
        where: 'id = ?',
        whereArgs: [jobId],
      );
      rethrow;
    }
    return ImportResult(
      totalRows: dataRows.length,
      importedRows: imported,
      skippedRows: skipped,
      failedRows: failed,
      errors: errors,
    );
  }

  Future<List<List<String>>> _readRows(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (extension == '.xlsx') {
      final workbook = Excel.decodeBytes(await file.readAsBytes());
      if (workbook.tables.isEmpty) return const [];
      final sheet = workbook.tables.values.first;
      if (sheet == null) return const [];
      return sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();
    }
    if (extension != '.csv') {
      throw ArgumentError('Only CSV and XLSX files are supported.');
    }
    final content = await file.readAsString();
    return _parseCsv(content);
  }

  static List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        if (quoted && i + 1 < content.length && content[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static Future<bool> _importProduct(
    DatabaseExecutor db, {
    required int branchId,
    required Map<String, String> values,
    required bool updateExisting,
  }) async {
    final name = values['name'] ?? '';
    if (name.isEmpty) throw ArgumentError('Product name is required.');
    final sku = values['sku'] ?? '';
    final barcode = values['barcode'] ?? '';
    final cost = _number(values['cost_price'] ?? values['cost'] ?? '0', 'cost price');
    final price = _number(values['selling_price'] ?? values['price'] ?? '0', 'selling price');
    final stock = _number(values['stock_qty'] ?? values['quantity'] ?? '0', 'stock quantity');
    final lowStock = _number(values['low_stock_level'] ?? '5', 'low-stock level');
    if (cost < 0 || price < 0 || stock < 0 || lowStock < 0) {
      throw ArgumentError('Prices and quantities cannot be negative.');
    }
    List<Map<String, Object?>> existing = const [];
    if (sku.isNotEmpty) {
      existing = await db.query('products', where: 'sku = ?', whereArgs: [sku], limit: 1);
    }
    if (existing.isEmpty && barcode.isNotEmpty) {
      existing = await db.query('products', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    }
    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      if (!updateExisting) return false;
      final productId = existing.first['id'] as int;
      await db.update(
        'products',
        {
          'name': name,
          'sku': sku,
          'barcode': barcode,
          'category': values['category']?.isNotEmpty == true ? values['category'] : 'General',
          'cost_price': cost,
          'selling_price': price,
          'low_stock_level': lowStock,
          'is_active': 1,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
      await db.insert(
        'branch_inventory',
        {
          'branch_id': branchId,
          'product_id': productId,
          'stock_qty': stock,
          'low_stock_level': lowStock,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    }
    final productId = await db.insert('products', {
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'category': values['category']?.isNotEmpty == true ? values['category'] : 'General',
      'cost_price': cost,
      'selling_price': price,
      'stock_qty': branchId == DatabaseService.defaultBranchId ? stock : 0,
      'low_stock_level': lowStock,
      'created_at': now,
    });
    await db.insert('branch_inventory', {
      'branch_id': branchId,
      'product_id': productId,
      'stock_qty': stock,
      'low_stock_level': lowStock,
      'updated_at': now,
    });
    return true;
  }

  static Future<bool> _importContact(
    DatabaseExecutor db, {
    required String table,
    required int branchId,
    required Map<String, String> values,
    required bool updateExisting,
  }) async {
    final name = values['name'] ?? '';
    if (name.isEmpty) throw ArgumentError('Name is required.');
    final phone = values['phone'] ?? '';
    final email = values['email'] ?? '';
    final existing = await db.query(
      table,
      where: 'branch_id = ? AND ((phone <> ? AND phone = ?) OR (email <> ? AND email = ?))',
      whereArgs: [branchId, '', phone, '', email],
      limit: 1,
    );
    final balance = _number(values['balance'] ?? '0', 'opening balance');
    if (balance < 0) throw ArgumentError('Opening balance cannot be negative.');
    final data = <String, Object?>{
      'name': name,
      'phone': phone,
      'email': email,
      'balance': balance,
      'branch_id': branchId,
      'is_active': 1,
    };
    if (table == 'customers') {
      data['credit_limit'] = _number(values['credit_limit'] ?? '0', 'credit limit');
    } else {
      data['tax_number'] = values['tax_number'] ?? '';
    }
    if (existing.isNotEmpty) {
      if (!updateExisting) return false;
      await db.update(
        table,
        data,
        where: 'id = ? AND branch_id = ?',
        whereArgs: [existing.first['id'], branchId],
      );
      return true;
    }
    data['created_at'] = DateTime.now().toIso8601String();
    await db.insert(table, data);
    return true;
  }

  static Future<bool> _importOpeningStock(
    DatabaseExecutor db, {
    required int branchId,
    required Map<String, String> values,
  }) async {
    final sku = values['sku'] ?? '';
    final barcode = values['barcode'] ?? '';
    if (sku.isEmpty && barcode.isEmpty) {
      throw ArgumentError('SKU or barcode is required.');
    }
    final quantity = _number(values['quantity'] ?? values['stock_qty'] ?? '0', 'quantity');
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative.');
    final products = await db.query(
      'products',
      where: sku.isNotEmpty ? 'sku = ?' : 'barcode = ?',
      whereArgs: [sku.isNotEmpty ? sku : barcode],
      limit: 1,
    );
    if (products.isEmpty) throw StateError('Product was not found.');
    final productId = products.first['id'] as int;
    await db.insert(
      'branch_inventory',
      {
        'branch_id': branchId,
        'product_id': productId,
        'stock_qty': quantity,
        'low_stock_level': products.first['low_stock_level'],
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (branchId == DatabaseService.defaultBranchId) {
      await db.update(
        'products',
        {'stock_qty': quantity},
        where: 'id = ?',
        whereArgs: [productId],
      );
    }
    return true;
  }

  static double _number(String value, String label) {
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) throw ArgumentError('Invalid $label.');
    return parsed;
  }
}

class _ImportValidationException implements Exception {
  const _ImportValidationException(this.errors);
  final List<String> errors;
}
