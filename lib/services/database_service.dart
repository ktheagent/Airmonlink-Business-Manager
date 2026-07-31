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
  DatabaseService._({this._configuredDatabasePath});

  DatabaseService.forTesting({String databasePath = inMemoryDatabasePath})
    : this._(configuredDatabasePath: databasePath);

  static final DatabaseService instance = DatabaseService._();
  static const schemaVersion = 8;
  static const defaultBranchId = 1;

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
          version: schemaVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
            await db.execute('PRAGMA journal_mode = WAL');
            await db.execute('PRAGMA busy_timeout = 5000');
          },
          onCreate: (db, version) async {
            await _createBaseSchema(db);
            await _createCommercialSchema(db);
            await _seed(db);
            await _seedCommercialDefaults(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _upgradeLegacyColumns(db);
            await _createCommercialSchema(db);
            await _ensureCommercialColumns(db);
            await _seedCommercialDefaults(db);
          },
          onOpen: (db) async {
            await _upgradeLegacyColumns(db);
            await _createCommercialSchema(db);
            await _ensureCommercialColumns(db);
            await _seedCommercialDefaults(db);
          },
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

  Future<void> _createBaseSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
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
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_products_sku ON products(sku) WHERE sku <> ''",
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode) WHERE barcode <> ''",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
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
      CREATE TABLE IF NOT EXISTS sale_items (
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
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_created_at ON expenses(created_at)',
    );
  }

  Future<void> _upgradeLegacyColumns(Database db) async {
    await _createBaseSchema(db);
    final additions = <String, Map<String, String>>{
      'products': {
        'reorder_quantity': 'REAL NOT NULL DEFAULT 0',
        'preferred_supplier_id': 'INTEGER',
        'lead_time_days': 'INTEGER NOT NULL DEFAULT 0',
        'is_active': 'INTEGER NOT NULL DEFAULT 1',
      },
      'customers': {
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
        'credit_limit': 'REAL NOT NULL DEFAULT 0',
        'credit_enabled': 'INTEGER NOT NULL DEFAULT 1',
        'is_active': 'INTEGER NOT NULL DEFAULT 1',
      },
      'suppliers': {
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
        'tax_number': "TEXT NOT NULL DEFAULT ''",
        'is_active': 'INTEGER NOT NULL DEFAULT 1',
      },
      'sales': {
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
        'user_id': 'INTEGER',
        'cash_session_id': 'INTEGER',
        'status': "TEXT NOT NULL DEFAULT 'completed'",
        'amount_paid': 'REAL NOT NULL DEFAULT 0',
        'balance_due': 'REAL NOT NULL DEFAULT 0',
        'source_document_id': 'INTEGER',
        'returned_total': 'REAL NOT NULL DEFAULT 0',
      },
      'expenses': {
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
        'user_id': 'INTEGER',
        'cash_session_id': 'INTEGER',
        'recurring_expense_id': 'INTEGER',
        'payment_method': "TEXT NOT NULL DEFAULT 'Cash'",
      },
    };
    for (final table in additions.entries) {
      for (final column in table.value.entries) {
        if (!await _columnExists(db, table.key, column.key)) {
          await db.execute(
            'ALTER TABLE ${table.key} ADD COLUMN ${column.key} ${column.value}',
          );
        }
      }
    }
    await db.rawUpdate(
      "UPDATE sales SET amount_paid = CASE WHEN payment_method = 'Credit' THEN MAX(0, total - balance_due) ELSE total END WHERE amount_paid = 0",
    );
    await db.rawUpdate(
      "UPDATE sales SET balance_due = CASE WHEN payment_method = 'Credit' THEN total ELSE 0 END WHERE payment_method = 'Credit' AND balance_due = 0",
    );
  }

  Future<void> _ensureCommercialColumns(Database db) async {
    final additions = <String, Map<String, String>>{
      'documents': {
        'debt_posted': 'INTEGER NOT NULL DEFAULT 0',
      },
      'purchase_orders': {
        'received_value': 'REAL NOT NULL DEFAULT 0',
      },
      'stock_transfers': {
        'created_by': 'INTEGER',
      },
    };
    for (final table in additions.entries) {
      for (final column in table.value.entries) {
        if (!await _columnExists(db, table.key, column.key)) {
          await db.execute(
            'ALTER TABLE ${table.key} ADD COLUMN ${column.key} ${column.value}',
          );
        }
      }
    }
  }

  Future<void> _createCommercialSchema(Database db) async {
    final statements = <String>[
      '''CREATE TABLE IF NOT EXISTS branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        address TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS branch_inventory (
        branch_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        stock_qty REAL NOT NULL DEFAULT 0,
        low_stock_level REAL NOT NULL DEFAULT 5,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(branch_id, product_id),
        FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS roles (
        role_key TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 1
      )''',
      '''CREATE TABLE IF NOT EXISTS role_permissions (
        role_key TEXT NOT NULL,
        permission_key TEXT NOT NULL,
        PRIMARY KEY(role_key, permission_key),
        FOREIGN KEY(role_key) REFERENCES roles(role_key) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        pin_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        last_login_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS user_permissions (
        user_id INTEGER NOT NULL,
        permission_key TEXT NOT NULL,
        allowed INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY(user_id, permission_key),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS staff_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        branch_id INTEGER,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL DEFAULT '',
        old_values TEXT,
        new_values TEXT,
        reason TEXT NOT NULL DEFAULT '',
        device_id TEXT NOT NULL DEFAULT '',
        success INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
        FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE SET NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        customer_id INTEGER,
        document_no TEXT NOT NULL UNIQUE,
        document_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        balance_due REAL NOT NULL DEFAULT 0,
        debt_posted INTEGER NOT NULL DEFAULT 0,
        valid_until TEXT,
        due_at TEXT,
        notes TEXT NOT NULL DEFAULT '',
        terms TEXT NOT NULL DEFAULT '',
        converted_sale_id INTEGER,
        created_by INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL,
        FOREIGN KEY(converted_sale_id) REFERENCES sales(id) ON DELETE SET NULL,
        FOREIGN KEY(created_by) REFERENCES users(id) ON DELETE SET NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS document_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        tax_rate REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL,
        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS document_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        user_id INTEGER,
        cash_session_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        reference TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        po_no TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'draft',
        subtotal REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        received_value REAL NOT NULL DEFAULT 0,
        balance_due REAL NOT NULL DEFAULT 0,
        supplier_invoice_ref TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        expected_at TEXT,
        created_by INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE RESTRICT,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS purchase_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        ordered_qty REAL NOT NULL,
        received_qty REAL NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL,
        FOREIGN KEY(purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS goods_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_order_id INTEGER NOT NULL,
        receipt_no TEXT NOT NULL UNIQUE,
        branch_id INTEGER NOT NULL,
        received_by INTEGER,
        received_at TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(purchase_order_id) REFERENCES purchase_orders(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS supplier_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        purchase_order_id INTEGER,
        branch_id INTEGER NOT NULL,
        user_id INTEGER,
        cash_session_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        reference TEXT NOT NULL DEFAULT '',
        is_deposit INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS customer_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        user_id INTEGER,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        reference_type TEXT NOT NULL DEFAULT '',
        reference_id INTEGER,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS stock_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        user_id INTEGER,
        quantity_change REAL NOT NULL,
        reason TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS stock_counts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        count_no TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'draft',
        started_by INTEGER,
        approved_by INTEGER,
        started_at TEXT NOT NULL,
        approved_at TEXT,
        notes TEXT NOT NULL DEFAULT ''
      )''',
      '''CREATE TABLE IF NOT EXISTS stock_count_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_count_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        expected_qty REAL NOT NULL,
        counted_qty REAL,
        posted INTEGER NOT NULL DEFAULT 0,
        UNIQUE(stock_count_id, product_id),
        FOREIGN KEY(stock_count_id) REFERENCES stock_counts(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        return_no TEXT NOT NULL UNIQUE,
        user_id INTEGER,
        reason TEXT NOT NULL,
        refund_method TEXT NOT NULL,
        total REAL NOT NULL,
        restock INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        sale_item_id INTEGER NOT NULL,
        product_id INTEGER,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY(return_id) REFERENCES returns(id) ON DELETE CASCADE,
        FOREIGN KEY(sale_item_id) REFERENCES sale_items(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS refunds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        user_id INTEGER,
        cash_session_id INTEGER,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        reference TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(return_id) REFERENCES returns(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS cash_registers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        UNIQUE(branch_id, name),
        FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS cash_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        register_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        opening_float REAL NOT NULL DEFAULT 0,
        expected_cash REAL,
        actual_cash REAL,
        variance REAL,
        status TEXT NOT NULL DEFAULT 'open',
        opening_note TEXT NOT NULL DEFAULT '',
        closing_note TEXT NOT NULL DEFAULT '',
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        FOREIGN KEY(register_id) REFERENCES cash_registers(id) ON DELETE RESTRICT,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )''',
      '''CREATE TABLE IF NOT EXISTS cash_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cash_session_id INTEGER NOT NULL,
        user_id INTEGER,
        movement_type TEXT NOT NULL,
        amount REAL NOT NULL,
        reference_type TEXT NOT NULL DEFAULT '',
        reference_id INTEGER,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(cash_session_id) REFERENCES cash_sessions(id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS product_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_no TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        manufactured_at TEXT,
        expires_at TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(branch_id, product_id, batch_no),
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        frequency TEXT NOT NULL,
        interval_count INTEGER NOT NULL DEFAULT 1,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_due_at TEXT NOT NULL,
        reminder_days INTEGER NOT NULL DEFAULT 3,
        automatic_posting INTEGER NOT NULL DEFAULT 0,
        payee TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        last_posted_at TEXT,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        reminder_type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        due_at TEXT NOT NULL,
        reference_type TEXT NOT NULL DEFAULT '',
        reference_id INTEGER,
        dismissed_at TEXT,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS backup_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL,
        checksum TEXT NOT NULL,
        encrypted INTEGER NOT NULL DEFAULT 0,
        destination TEXT NOT NULL DEFAULT 'local',
        status TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_by INTEGER,
        created_at TEXT NOT NULL,
        error_message TEXT NOT NULL DEFAULT ''
      )''',
      '''CREATE TABLE IF NOT EXISTS update_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        current_version TEXT NOT NULL,
        available_version TEXT NOT NULL,
        download_url TEXT NOT NULL,
        checksum TEXT NOT NULL,
        status TEXT NOT NULL,
        checked_at TEXT NOT NULL,
        installed_at TEXT,
        error_message TEXT NOT NULL DEFAULT ''
      )''',
      '''CREATE TABLE IF NOT EXISTS notification_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel TEXT NOT NULL,
        recipient TEXT NOT NULL,
        document_type TEXT NOT NULL DEFAULT '',
        document_id INTEGER,
        status TEXT NOT NULL,
        error_message TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS import_jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL,
        import_type TEXT NOT NULL,
        source_path TEXT NOT NULL,
        total_rows INTEGER NOT NULL DEFAULT 0,
        imported_rows INTEGER NOT NULL DEFAULT 0,
        skipped_rows INTEGER NOT NULL DEFAULT 0,
        failed_rows INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        error_report TEXT NOT NULL DEFAULT '',
        created_by INTEGER,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS stock_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_no TEXT NOT NULL UNIQUE,
        source_branch_id INTEGER NOT NULL,
        destination_branch_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        created_by INTEGER,
        dispatched_by INTEGER,
        received_by INTEGER,
        dispatched_at TEXT,
        received_at TEXT,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        CHECK(source_branch_id <> destination_branch_id)
      )''',
      '''CREATE TABLE IF NOT EXISTS stock_transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        received_quantity REAL,
        FOREIGN KEY(transfer_id) REFERENCES stock_transfers(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE RESTRICT
      )''',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }

    final indexes = <String>[
      'CREATE INDEX IF NOT EXISTS idx_branch_inventory_product ON branch_inventory(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_documents_branch_status ON documents(branch_id, status)',
      'CREATE INDEX IF NOT EXISTS idx_purchase_orders_branch_status ON purchase_orders(branch_id, status)',
      'CREATE INDEX IF NOT EXISTS idx_customer_transactions_customer ON customer_transactions(customer_id, created_at)',
      'CREATE INDEX IF NOT EXISTS idx_batches_expiry ON product_batches(branch_id, expires_at)',
      'CREATE INDEX IF NOT EXISTS idx_recurring_next_due ON recurring_expenses(is_active, next_due_at)',
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_open_cash_session ON cash_sessions(register_id) WHERE status = 'open'",
    ];
    for (final index in indexes) {
      await db.execute(index);
    }
  }

  Future<void> _seed(Database db) async {
    final existing = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM products'),
        ) ??
        0;
    if (existing > 0) return;
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
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('settings', {
      'setting_key': 'business_phone',
      'setting_value': '',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('settings', {
      'setting_key': 'business_address',
      'setting_value': '',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _seedCommercialDefaults(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'branches',
      {
        'id': defaultBranchId,
        'name': 'Main Branch',
        'code': 'MAIN',
        'address': '',
        'phone': '',
        'email': '',
        'is_active': 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final roles = <String, String>{
      'owner': 'Owner',
      'manager': 'Manager',
      'cashier': 'Cashier',
      'accountant': 'Accountant',
      'stock_officer': 'Stock Officer',
    };
    for (final role in roles.entries) {
      await db.insert(
        'roles',
        {'role_key': role.key, 'label': role.value, 'is_system': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    final permissions = <String, Set<String>>{
      'owner': _allPermissions,
      'manager': _allPermissions.difference({'license.manage'}),
      'cashier': {
        'dashboard.view',
        'sales.process',
        'debt.view',
        'documents.manage',
      },
      'accountant': {
        'dashboard.view',
        'debt.view',
        'debt.payment',
        'expenses.view',
        'expenses.manage',
        'reports.view',
        'reports.profit',
        'documents.manage',
        'cash.manage',
        'audit.view',
      },
      'stock_officer': {
        'dashboard.view',
        'products.manage',
        'stock.adjust',
        'stock.count',
        'purchasing.manage',
        'reports.view',
        'imports.manage',
      },
    };
    for (final role in permissions.entries) {
      for (final permission in role.value) {
        await db.insert(
          'role_permissions',
          {'role_key': role.key, 'permission_key': permission},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await db.insert(
      'cash_registers',
      {'branch_id': defaultBranchId, 'name': 'Main Register', 'is_active': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.execute('''
      INSERT OR IGNORE INTO branch_inventory
        (branch_id, product_id, stock_qty, low_stock_level, updated_at)
      SELECT ?, id, stock_qty, low_stock_level, ? FROM products
    ''', [defaultBranchId, now]);
    await db.rawUpdate(
      'UPDATE customers SET branch_id = ? WHERE branch_id IS NULL OR branch_id = 0',
      [defaultBranchId],
    );
    await db.rawUpdate(
      'UPDATE suppliers SET branch_id = ? WHERE branch_id IS NULL OR branch_id = 0',
      [defaultBranchId],
    );
  }

  static const _allPermissions = <String>{
    'dashboard.view',
    'sales.process',
    'sales.discount',
    'sales.void',
    'sales.refund',
    'products.manage',
    'stock.adjust',
    'stock.count',
    'purchasing.manage',
    'debt.view',
    'debt.payment',
    'expenses.view',
    'expenses.manage',
    'reports.view',
    'reports.profit',
    'cash.manage',
    'documents.manage',
    'audit.view',
    'staff.manage',
    'branches.manage',
    'settings.manage',
    'backups.manage',
    'license.manage',
    'remote_dashboard.manage',
    'imports.manage',
    'updates.manage',
  };

  Future<List<Product>> getProducts({
    String query = '',
    int branchId = defaultBranchId,
  }) async {
    final db = await database;
    final trimmed = query.trim();
    final where = trimmed.isEmpty
        ? ''
        : 'AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ? OR p.category LIKE ?)';
    final args = <Object?>[branchId];
    if (trimmed.isNotEmpty) {
      args.addAll(List<Object?>.filled(4, '%$trimmed%'));
    }
    final rows = await db.rawQuery('''
      SELECT p.id, p.name, p.sku, p.barcode, p.category,
        p.cost_price, p.selling_price,
        COALESCE(bi.stock_qty, 0) AS stock_qty,
        COALESCE(bi.low_stock_level, p.low_stock_level) AS low_stock_level,
        p.created_at
      FROM products p
      LEFT JOIN branch_inventory bi
        ON bi.product_id = p.id AND bi.branch_id = ?
      WHERE COALESCE(p.is_active, 1) = 1 $where
      ORDER BY p.name COLLATE NOCASE ASC
    ''', args);
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<int> addProduct(
    Product product, {
    int branchId = defaultBranchId,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final map = product.toMap()..remove('id');
      final id = await txn.insert('products', map);
      await txn.insert('branch_inventory', {
        'branch_id': branchId,
        'product_id': id,
        'stock_qty': product.stockQty,
        'low_stock_level': product.lowStockLevel,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return id;
    });
  }

  Future<void> updateProduct(
    Product product, {
    int branchId = defaultBranchId,
  }) async {
    if (product.id == null) throw ArgumentError('Product ID is required.');
    final db = await database;
    await db.transaction((txn) async {
      final map = product.toMap()..remove('id');
      await txn.update(
        'products',
        map,
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await txn.insert(
        'branch_inventory',
        {
          'branch_id': branchId,
          'product_id': product.id,
          'stock_qty': product.stockQty,
          'low_stock_level': product.lowStockLevel,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> adjustStock(
    int id,
    double change, {
    int branchId = defaultBranchId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'branch_inventory',
        columns: ['stock_qty', 'low_stock_level'],
        where: 'branch_id = ? AND product_id = ?',
        whereArgs: [branchId, id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Product stock record was not found.');
      final current = (rows.first['stock_qty'] as num).toDouble();
      final next = current + change;
      if (next < 0) throw StateError('Stock cannot be reduced below zero.');
      await txn.update(
        'branch_inventory',
        {'stock_qty': next, 'updated_at': DateTime.now().toIso8601String()},
        where: 'branch_id = ? AND product_id = ?',
        whereArgs: [branchId, id],
      );
      if (branchId == defaultBranchId) {
        await txn.update(
          'products',
          {'stock_qty': next},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<List<BusinessContact>> getContacts(
    ContactType type, {
    int branchId = defaultBranchId,
  }) async {
    final db = await database;
    final table = type == ContactType.customer ? 'customers' : 'suppliers';
    final rows = await db.query(
      table,
      where: 'branch_id = ? AND COALESCE(is_active, 1) = 1',
      whereArgs: [branchId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((row) => BusinessContact.fromMap(row, type))
        .toList(growable: false);
  }

  Future<int> addContact(
    BusinessContact contact, {
    int branchId = defaultBranchId,
  }) async {
    final db = await database;
    final map = contact.toMap()
      ..remove('id')
      ..['branch_id'] = branchId;
    return db.insert(contact.table, map);
  }

  Future<void> recordContactPayment(
    BusinessContact contact,
    double amount, {
    int branchId = defaultBranchId,
    int? userId,
  }) async {
    if (contact.id == null) throw ArgumentError('Contact ID is required.');
    if (amount <= 0) throw ArgumentError('Payment must be greater than zero.');
    final db = await database;
    await db.transaction((txn) async {
      final changed = await txn.rawUpdate(
        'UPDATE ${contact.table} SET balance = MAX(0, balance - ?) WHERE id = ? AND branch_id = ?',
        [amount, contact.id, branchId],
      );
      if (changed != 1) throw StateError('Contact was not found in this branch.');
      if (contact.type == ContactType.customer) {
        await txn.insert('customer_transactions', {
          'customer_id': contact.id,
          'branch_id': branchId,
          'user_id': userId,
          'transaction_type': 'payment',
          'amount': -amount,
          'reference_type': 'manual_payment',
          'note': 'Customer account payment',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<int> addExpense(
    Expense expense, {
    int branchId = defaultBranchId,
    int? userId,
    int? cashSessionId,
    String paymentMethod = 'Cash',
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      if (paymentMethod == 'Cash' && userId != null && cashSessionId == null) {
        throw StateError('Open a cash-register session before paying cash.');
      }
      final map = expense.toMap()
        ..remove('id')
        ..addAll({
          'branch_id': branchId,
          'user_id': userId,
          'cash_session_id': cashSessionId,
          'payment_method': paymentMethod,
        });
      final id = await txn.insert('expenses', map);
      if (paymentMethod == 'Cash' && cashSessionId != null) {
        await txn.insert('cash_movements', {
          'cash_session_id': cashSessionId,
          'user_id': userId,
          'movement_type': 'expense',
          'amount': -expense.amount,
          'reference_type': 'expense',
          'reference_id': id,
          'note': expense.title,
          'created_at': expense.createdAt.toIso8601String(),
        });
      }
      return id;
    });
  }

  Future<List<Expense>> getExpenses({int branchId = defaultBranchId}) async {
    final db = await database;
    final rows = await db.query(
      'expenses',
      where: 'branch_id = ?',
      whereArgs: [branchId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Expense.fromMap).toList(growable: false);
  }

  Future<List<SaleRecord>> getSales({
    int? limit,
    int branchId = defaultBranchId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'branch_id = ?',
      whereArgs: [branchId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SaleRecord.fromMap).toList(growable: false);
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final rows = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    return rows
        .map(
          (row) => SaleItem(
            productId: row['product_id'] as int?,
            productName: row['product_name'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitPrice: (row['unit_price'] as num).toDouble(),
            costPrice: (row['cost_price'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  Future<BusinessContact?> getContactById(int id) async {
    final db = await database;
    final customerRows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (customerRows.isNotEmpty) {
      return BusinessContact.fromMap(customerRows.first, ContactType.customer);
    }
    final supplierRows = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (supplierRows.isNotEmpty) {
      return BusinessContact.fromMap(supplierRows.first, ContactType.supplier);
    }
    return null;
  }

  Future<String> createSale(
    SaleDraft draft, {
    int branchId = defaultBranchId,
    int? userId,
    int? cashSessionId,
    int? sourceDocumentId,
  }) async {
    if (draft.items.isEmpty) throw ArgumentError('The sale has no items.');
    if (draft.paymentMethod == 'Credit' && draft.customerId == null) {
      throw ArgumentError('A customer is required for a credit sale.');
    }
    if (draft.paymentMethod == 'Cash' && userId != null && cashSessionId == null) {
      throw StateError('Open a cash-register session before a cash sale.');
    }
    final db = await database;
    final now = DateTime.now();
    final invoiceNo = _number('ABM', now);

    await db.transaction((txn) async {
      for (final item in draft.items) {
        if (item.productId == null) {
          throw StateError('${item.productName} is not linked to a product.');
        }
        final rows = await txn.query(
          'branch_inventory',
          columns: ['stock_qty'],
          where: 'branch_id = ? AND product_id = ?',
          whereArgs: [branchId, item.productId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('${item.productName} is not stocked at this branch.');
        }
        final available = (rows.first['stock_qty'] as num).toDouble();
        final expired = Sqflite.firstIntValue(await txn.rawQuery(
              '''SELECT COUNT(*) FROM product_batches
                 WHERE branch_id = ? AND product_id = ? AND quantity > 0
                   AND expires_at IS NOT NULL AND expires_at < ?''',
              [branchId, item.productId, now.toIso8601String()],
            )) ??
            0;
        if (expired > 0) {
          throw StateError('${item.productName} has expired stock requiring review.');
        }
        if (available < item.quantity) {
          throw StateError(
            'Insufficient stock for ${item.productName}. Available: $available.',
          );
        }
      }

      if (draft.paymentMethod == 'Credit') {
        final customer = await txn.query(
          'customers',
          columns: ['balance', 'credit_limit', 'credit_enabled'],
          where: 'id = ? AND branch_id = ?',
          whereArgs: [draft.customerId, branchId],
          limit: 1,
        );
        if (customer.isEmpty) {
          throw StateError('Customer was not found in this branch.');
        }
        if ((customer.first['credit_enabled'] as num? ?? 1).toInt() != 1) {
          throw StateError('Credit sales are disabled for this customer.');
        }
        final currentBalance = (customer.first['balance'] as num).toDouble();
        final creditLimit = (customer.first['credit_limit'] as num? ?? 0)
            .toDouble();
        if (creditLimit > 0 && currentBalance + draft.total > creditLimit) {
          throw StateError('This sale exceeds the customer credit limit.');
        }
      }

      final isCredit = draft.paymentMethod == 'Credit';
      final saleId = await txn.insert('sales', {
        'invoice_no': invoiceNo,
        'subtotal': draft.subtotal,
        'discount': draft.discount,
        'total': draft.total,
        'payment_method': draft.paymentMethod,
        'customer_id': draft.customerId,
        'branch_id': branchId,
        'user_id': userId,
        'cash_session_id': cashSessionId,
        'status': 'completed',
        'amount_paid': isCredit ? 0 : draft.total,
        'balance_due': isCredit ? draft.total : 0,
        'source_document_id': sourceDocumentId,
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
          'UPDATE branch_inventory SET stock_qty = stock_qty - ?, updated_at = ? WHERE branch_id = ? AND product_id = ?',
          [item.quantity, now.toIso8601String(), branchId, item.productId],
        );
        if (branchId == defaultBranchId) {
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }

      if (isCredit) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ? AND branch_id = ?',
          [draft.total, draft.customerId, branchId],
        );
        await txn.insert('customer_transactions', {
          'customer_id': draft.customerId,
          'branch_id': branchId,
          'user_id': userId,
          'transaction_type': 'credit_sale',
          'amount': draft.total,
          'reference_type': 'sale',
          'reference_id': saleId,
          'note': invoiceNo,
          'created_at': now.toIso8601String(),
        });
      } else if (draft.paymentMethod == 'Cash' && cashSessionId != null) {
        await txn.insert('cash_movements', {
          'cash_session_id': cashSessionId,
          'user_id': userId,
          'movement_type': 'sale',
          'amount': draft.total,
          'reference_type': 'sale',
          'reference_id': saleId,
          'note': invoiceNo,
          'created_at': now.toIso8601String(),
        });
      }
    });
    return invoiceNo;
  }

  Future<DashboardMetrics> getDashboardMetrics({
    int branchId = defaultBranchId,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final monthStart = DateTime(now.year, now.month).toIso8601String();

    final todaySales = await db.rawQuery(
      'SELECT COALESCE(SUM(total - returned_total), 0) AS value, COUNT(*) AS count FROM sales WHERE branch_id = ? AND status = ? AND created_at >= ?',
      [branchId, 'completed', todayStart],
    );
    final productStats = await db.rawQuery('''
      SELECT COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN stock_qty <= low_stock_level THEN 1 ELSE 0 END), 0) AS low
      FROM branch_inventory WHERE branch_id = ?
    ''', [branchId]);
    final customerDebt = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS value FROM customers WHERE branch_id = ?',
      [branchId],
    );
    final monthExpenses = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS value FROM expenses WHERE branch_id = ? AND created_at >= ?',
      [branchId, monthStart],
    );
    final grossProfit = await db.rawQuery('''
      SELECT COALESCE(SUM(sale_profit), 0) AS value
      FROM (
        SELECT s.id,
          SUM((si.unit_price - si.cost_price) * si.quantity) - s.discount AS sale_profit
        FROM sales s
        INNER JOIN sale_items si ON si.sale_id = s.id
        WHERE s.branch_id = ? AND s.status = 'completed' AND s.created_at >= ?
        GROUP BY s.id
      )
    ''', [branchId, monthStart]);

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

  Future<Map<String, Object?>> integrityReport() async {
    final db = await database;
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final foreignKeys = await db.rawQuery('PRAGMA foreign_key_check');
    return {
      'integrity': integrity.isEmpty ? 'unknown' : integrity.first.values.first,
      'foreign_key_violations': foreignKeys.length,
      'schema_version': await db.getVersion(),
    };
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) await db.close();
  }

  static Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((row) => row['name'] == column);
  }

  static int _intValue(Map<String, Object?> row, String key) =>
      (row[key] as num? ?? 0).toInt();

  static double _doubleValue(Map<String, Object?> row, String key) =>
      (row[key] as num? ?? 0).toDouble();

  static String _number(String prefix, DateTime dateTime) {
    final stamp = dateTime
        .toIso8601String()
        .replaceAll(RegExp(r'[-:T.]'), '')
        .substring(0, 14);
    final suffix = dateTime.microsecondsSinceEpoch
        .remainder(1000)
        .toString()
        .padLeft(3, '0');
    return '$prefix-$stamp-$suffix';
  }
}
