import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_constants.dart';
import '../models/contact.dart';
import '../models/dashboard_metrics.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/sale.dart';

class DatabaseService {
  DatabaseService._({String? configuredDatabasePath})
      : _configuredDatabasePath = configuredDatabasePath;

  DatabaseService.forTesting({
    String databasePath = inMemoryDatabasePath,
  }) : this._(configuredDatabasePath: databasePath);

  static final DatabaseService instance = DatabaseService._();

  final String? _configuredDatabasePath;
  Database? _database;
  Future<Database>? _openingDatabase;
  String? _databasePath;

  Future<Database> get database {
    final existing = _database;
    if (existing != null) return Future.value(existing);

    final opening = _openingDatabase;
    if (opening != null) return opening;

    final future = _openDatabase();
    _openingDatabase = future;
    return future;
  }

  Future<Database> _openDatabase() async {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final configuredPath = _configuredDatabasePath;
      if (configuredPath != null) {
        _databasePath = configuredPath;
      } else {
        final directory = await getApplicationSupportDirectory();
        final appDirectory = Directory(
          p.join(directory.path, 'AirmonlinkBusinessManager'),
        );
        await appDirectory.create(recursive: true);
        _databasePath = p.join(appDirectory.path, AppConstants.databaseName);
      }

      final opened = await databaseFactory.openDatabase(
        _databasePath!,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
            await db.execute('PRAGMA journal_mode = WAL');
          },
          onCreate: _createSchema,
        ),
      );
      _database = opened;
      return opened;
    } finally {
      _openingDatabase = null;
    }
  }

  Future<String> get databasePath async {
    await database;
    return _databasePath!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL DEFAULT '',
        barcode TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'General',
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        stock_qty REAL NOT NULL DEFAULT 0,
        low_stock_level REAL NOT NULL DEFAULT 5,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX idx_products_sku ON products(sku) WHERE sku <> ""',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_products_barcode ON products(barcode) WHERE barcode <> ""',
    );

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL UNIQUE,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        customer_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_sales_created_at ON sales(created_at)');
    await db.execute(
      'CREATE INDEX idx_expenses_created_at ON expenses(created_at)',
    );

    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();
    final products = <Map<String, Object?>>[
      {
        'name': 'Bottled Water 500ml',
        'sku': 'WATER-500',
        'barcode': '100000000001',
        'category': 'Drinks',
        'cost_price': 2.00,
        'selling_price': 3.00,
        'stock_qty': 80.0,
        'low_stock_level': 15.0,
        'created_at': now,
      },
      {
        'name': 'Exercise Book',
        'sku': 'BOOK-001',
        'barcode': '100000000002',
        'category': 'Stationery',
        'cost_price': 5.50,
        'selling_price': 8.00,
        'stock_qty': 45.0,
        'low_stock_level': 10.0,
        'created_at': now,
      },
      {
        'name': 'Laundry Soap',
        'sku': 'SOAP-001',
        'barcode': '100000000003',
        'category': 'Household',
        'cost_price': 7.00,
        'selling_price': 10.00,
        'stock_qty': 32.0,
        'low_stock_level': 8.0,
        'created_at': now,
      },
      {
        'name': 'Rice 5kg',
        'sku': 'RICE-5KG',
        'barcode': '100000000004',
        'category': 'Food',
        'cost_price': 105.00,
        'selling_price': 125.00,
        'stock_qty': 12.0,
        'low_stock_level': 5.0,
        'created_at': now,
      },
      {
        'name': 'USB Cable',
        'sku': 'USB-CABLE',
        'barcode': '100000000005',
        'category': 'Electronics',
        'cost_price': 18.00,
        'selling_price': 30.00,
        'stock_qty': 4.0,
        'low_stock_level': 5.0,
        'created_at': now,
      },
    ];

    for (final product in products) {
      await db.insert('products', product);
    }

    await db.insert('settings', {
      'setting_key': 'business_name',
      'setting_value': 'My Business',
    });
    await db.insert('settings', {
      'setting_key': 'business_phone',
      'setting_value': '',
    });
    await db.insert('settings', {
      'setting_key': 'business_address',
      'setting_value': '',
    });
  }

  Future<List<Product>> getProducts({String query = ''}) async {
    final db = await database;
    final trimmed = query.trim();
    final rows = await db.query(
      'products',
      where: trimmed.isEmpty
          ? null
          : '(name LIKE ? OR sku LIKE ? OR barcode LIKE ? OR category LIKE ?)',
      whereArgs: trimmed.isEmpty
          ? null
          : List.filled(4, '%$trimmed%', growable: false),
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<int> addProduct(Product product) async {
    final db = await database;
    final map = product.toMap()..remove('id');
    return db.insert('products', map);
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) throw ArgumentError('Product ID is required.');
    final db = await database;
    final map = product.toMap()..remove('id');
    await db.update(
      'products',
      map,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock(int id, double change) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET stock_qty = MAX(0, stock_qty + ?) WHERE id = ?',
      [change, id],
    );
  }

  Future<List<BusinessContact>> getContacts(ContactType type) async {
    final db = await database;
    final table = type == ContactType.customer ? 'customers' : 'suppliers';
    final rows = await db.query(table, orderBy: 'name COLLATE NOCASE ASC');
    return rows
        .map((row) => BusinessContact.fromMap(row, type))
        .toList(growable: false);
  }

  Future<int> addContact(BusinessContact contact) async {
    final db = await database;
    final map = contact.toMap()..remove('id');
    return db.insert(contact.table, map);
  }

  Future<void> recordContactPayment(
    BusinessContact contact,
    double amount,
  ) async {
    if (contact.id == null) throw ArgumentError('Contact ID is required.');
    if (amount <= 0) throw ArgumentError('Payment must be greater than zero.');
    final db = await database;
    await db.rawUpdate(
      'UPDATE ${contact.table} SET balance = MAX(0, balance - ?) WHERE id = ?',
      [amount, contact.id],
    );
  }

  Future<int> addExpense(Expense expense) async {
    final db = await database;
    final map = expense.toMap()..remove('id');
    return db.insert('expenses', map);
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final rows = await db.query('expenses', orderBy: 'created_at DESC');
    return rows.map(Expense.fromMap).toList(growable: false);
  }

  Future<List<SaleRecord>> getSales({int? limit}) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SaleRecord.fromMap).toList(growable: false);
  }

  Future<String> createSale(SaleDraft draft) async {
    if (draft.items.isEmpty) throw ArgumentError('The sale has no items.');
    if (draft.paymentMethod == 'Credit' && draft.customerId == null) {
      throw ArgumentError('A customer is required for a credit sale.');
    }
    final db = await database;
    final now = DateTime.now();
    final invoiceNo = _invoiceNumber(now);

    await db.transaction((txn) async {
      for (final item in draft.items) {
        final rows = await txn.query(
          'products',
          columns: ['stock_qty'],
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('${item.productName} no longer exists.');
        }
        final available = (rows.first['stock_qty'] as num).toDouble();
        if (available < item.quantity) {
          throw StateError(
            'Insufficient stock for ${item.productName}. Available: $available.',
          );
        }
      }

      final saleId = await txn.insert('sales', {
        'invoice_no': invoiceNo,
        'subtotal': draft.subtotal,
        'discount': draft.discount,
        'total': draft.total,
        'payment_method': draft.paymentMethod,
        'customer_id': draft.customerId,
        'created_at': now.toIso8601String(),
      });

      for (final item in draft.items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'cost_price': item.costPrice,
          'total': item.total,
        });
        await txn.rawUpdate(
          'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      if (draft.paymentMethod == 'Credit') {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ?',
          [draft.total, draft.customerId],
        );
      }
    });

    return invoiceNo;
  }

  Future<DashboardMetrics> getDashboardMetrics() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final monthStart = DateTime(now.year, now.month).toIso8601String();

    final todaySales = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS value, COUNT(*) AS count FROM sales WHERE created_at >= ?',
      [todayStart],
    );
    final productStats = await db.rawQuery(
      'SELECT COUNT(*) AS total, COALESCE(SUM(CASE WHEN stock_qty <= low_stock_level THEN 1 ELSE 0 END), 0) AS low FROM products',
    );
    final customerDebt = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS value FROM customers',
    );
    final monthExpenses = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS value FROM expenses WHERE created_at >= ?',
      [monthStart],
    );
    final grossProfit = await db.rawQuery('''
      SELECT COALESCE(SUM(sale_profit), 0) AS value
      FROM (
        SELECT s.id,
          SUM((si.unit_price - si.cost_price) * si.quantity) - s.discount AS sale_profit
        FROM sales s
        INNER JOIN sale_items si ON si.sale_id = s.id
        WHERE s.created_at >= ?
        GROUP BY s.id
      )
    ''', [monthStart]);

    return DashboardMetrics(
      todaySales: _doubleValue(todaySales.first, 'value'),
      todayTransactions: _intValue(todaySales.first, 'count'),
      totalProducts: _intValue(productStats.first, 'total'),
      lowStockProducts: _intValue(productStats.first, 'low'),
      customerDebt: _doubleValue(customerDebt.first, 'value'),
      monthExpenses: _doubleValue(monthExpenses.first, 'value'),
      monthGrossProfit: _doubleValue(grossProfit.first, 'value'),
    );
  }

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return {
      for (final row in rows)
        row['setting_key'] as String: row['setting_value'] as String,
    };
  }

  Future<void> saveSettings(Map<String, String> settings) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in settings.entries) {
        await txn.insert(
          'settings',
          {'setting_key': entry.key, 'setting_value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> checkpoint() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) await db.close();
  }

  static int _intValue(Map<String, Object?> row, String key) =>
      (row[key] as num? ?? 0).toInt();

  static double _doubleValue(Map<String, Object?> row, String key) =>
      (row[key] as num? ?? 0).toDouble();

  static String _invoiceNumber(DateTime dateTime) {
    final stamp = dateTime
        .toIso8601String()
        .replaceAll(RegExp(r'[-:T.]'), '')
        .substring(0, 14);
    final suffix = dateTime.microsecondsSinceEpoch.remainder(1000).toString().padLeft(3, '0');
    return 'ABM-$stamp-$suffix';
  }
}
