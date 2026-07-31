import 'dart:convert';

enum StaffRole { owner, manager, cashier, accountant, stockOfficer }

extension StaffRoleLabel on StaffRole {
  String get databaseValue => switch (this) {
    StaffRole.owner => 'owner',
    StaffRole.manager => 'manager',
    StaffRole.cashier => 'cashier',
    StaffRole.accountant => 'accountant',
    StaffRole.stockOfficer => 'stock_officer',
  };

  String get label => switch (this) {
    StaffRole.owner => 'Owner',
    StaffRole.manager => 'Manager',
    StaffRole.cashier => 'Cashier',
    StaffRole.accountant => 'Accountant',
    StaffRole.stockOfficer => 'Stock Officer',
  };

  static StaffRole parse(String value) => switch (value) {
    'manager' => StaffRole.manager,
    'cashier' => StaffRole.cashier,
    'accountant' => StaffRole.accountant,
    'stock_officer' => StaffRole.stockOfficer,
    _ => StaffRole.owner,
  };
}

abstract final class CommercialPermission {
  static const dashboardView = 'dashboard.view';
  static const salesProcess = 'sales.process';
  static const salesDiscount = 'sales.discount';
  static const salesVoid = 'sales.void';
  static const salesRefund = 'sales.refund';
  static const productsManage = 'products.manage';
  static const stockAdjust = 'stock.adjust';
  static const stockCount = 'stock.count';
  static const purchasingManage = 'purchasing.manage';
  static const debtView = 'debt.view';
  static const debtPayment = 'debt.payment';
  static const expensesView = 'expenses.view';
  static const expensesManage = 'expenses.manage';
  static const reportsView = 'reports.view';
  static const reportsProfit = 'reports.profit';
  static const cashManage = 'cash.manage';
  static const documentsManage = 'documents.manage';
  static const auditView = 'audit.view';
  static const staffManage = 'staff.manage';
  static const branchesManage = 'branches.manage';
  static const settingsManage = 'settings.manage';
  static const backupsManage = 'backups.manage';
  static const licenseManage = 'license.manage';
  static const remoteDashboard = 'remote_dashboard.manage';
  static const importsManage = 'imports.manage';
  static const updatesManage = 'updates.manage';

  static const all = <String>{
    dashboardView,
    salesProcess,
    salesDiscount,
    salesVoid,
    salesRefund,
    productsManage,
    stockAdjust,
    stockCount,
    purchasingManage,
    debtView,
    debtPayment,
    expensesView,
    expensesManage,
    reportsView,
    reportsProfit,
    cashManage,
    documentsManage,
    auditView,
    staffManage,
    branchesManage,
    settingsManage,
    backupsManage,
    licenseManage,
    remoteDashboard,
    importsManage,
    updatesManage,
  };
}

class BranchRecord {
  const BranchRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.phone,
    required this.email,
    required this.isActive,
  });

  final int id;
  final String name;
  final String code;
  final String address;
  final String phone;
  final String email;
  final bool isActive;

  factory BranchRecord.fromMap(Map<String, Object?> map) => BranchRecord(
    id: map['id'] as int,
    name: map['name'] as String,
    code: map['code'] as String? ?? '',
    address: map['address'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    email: map['email'] as String? ?? '',
    isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
  );
}

class StaffUser {
  const StaffUser({
    required this.id,
    required this.branchId,
    required this.name,
    required this.username,
    required this.role,
    required this.permissions,
    required this.isActive,
    this.lastLoginAt,
  });

  final int id;
  final int branchId;
  final String name;
  final String username;
  final StaffRole role;
  final Set<String> permissions;
  final bool isActive;
  final DateTime? lastLoginAt;

  bool can(String permission) =>
      role == StaffRole.owner || permissions.contains(permission);

  StaffUser copyWith({int? branchId}) => StaffUser(
    id: id,
    branchId: branchId ?? this.branchId,
    name: name,
    username: username,
    role: role,
    permissions: permissions,
    isActive: isActive,
    lastLoginAt: lastLoginAt,
  );

  factory StaffUser.fromMap(
    Map<String, Object?> map, {
    Set<String> permissions = const {},
  }) => StaffUser(
    id: map['id'] as int,
    branchId: (map['branch_id'] as num? ?? 1).toInt(),
    name: map['name'] as String,
    username: map['username'] as String,
    role: StaffRoleLabel.parse(map['role'] as String? ?? 'owner'),
    permissions: permissions,
    isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
    lastLoginAt: map['last_login_at'] == null
        ? null
        : DateTime.tryParse(map['last_login_at'] as String),
  );
}

class CommercialDocumentItem {
  const CommercialDocumentItem({
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    this.taxRate = 0,
  });

  final int? productId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double taxRate;

  double get lineSubtotal => quantity * unitPrice;
  double get taxAmount => lineSubtotal * taxRate / 100;
  double get total => lineSubtotal + taxAmount;

  Map<String, Object?> toMap() => {
    'product_id': productId,
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    'cost_price': costPrice,
    'tax_rate': taxRate,
    'line_total': total,
  };
}

class CommercialDocumentDraft {
  const CommercialDocumentDraft({
    required this.type,
    required this.customerId,
    required this.items,
    required this.discount,
    required this.tax,
    required this.notes,
    required this.terms,
    this.validUntil,
    this.dueAt,
  });

  final String type;
  final int? customerId;
  final List<CommercialDocumentItem> items;
  final double discount;
  final double tax;
  final String notes;
  final String terms;
  final DateTime? validUntil;
  final DateTime? dueAt;

  double get subtotal => items.fold(0, (sum, item) => sum + item.lineSubtotal);
  double get total =>
      (subtotal + tax - discount).clamp(0, double.infinity).toDouble();
}

class BusinessHealthSnapshot {
  const BusinessHealthSnapshot({
    required this.revenue,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.customerDebt,
    required this.supplierDebt,
    required this.lowStockCount,
    required this.expiringCount,
    required this.refundRate,
    required this.cashVariance,
    required this.suggestions,
  });

  final double revenue;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double customerDebt;
  final double supplierDebt;
  final int lowStockCount;
  final int expiringCount;
  final double refundRate;
  final double cashVariance;
  final List<String> suggestions;
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.createdAt,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.success,
    this.userName,
    this.branchName,
    this.oldValues,
    this.newValues,
  });

  final int id;
  final DateTime createdAt;
  final String action;
  final String entityType;
  final String entityId;
  final String reason;
  final bool success;
  final String? userName;
  final String? branchName;
  final Map<String, Object?>? oldValues;
  final Map<String, Object?>? newValues;

  static Map<String, Object?>? decodeMap(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final decoded = jsonDecode(value);
    return decoded is Map<String, Object?> ? decoded : null;
  }

  factory AuditEntry.fromMap(Map<String, Object?> map) => AuditEntry(
    id: map['id'] as int,
    createdAt: DateTime.parse(map['created_at'] as String),
    action: map['action'] as String,
    entityType: map['entity_type'] as String,
    entityId: map['entity_id'] as String? ?? '',
    reason: map['reason'] as String? ?? '',
    success: (map['success'] as num? ?? 1).toInt() == 1,
    userName: map['user_name'] as String?,
    branchName: map['branch_name'] as String?,
    oldValues: decodeMap(map['old_values']),
    newValues: decodeMap(map['new_values']),
  );
}
