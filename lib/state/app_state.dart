import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';

import '../commercial/models/commercial_models.dart';
import '../commercial/services/commercial_document_service.dart';
import '../commercial/services/commercial_report_service.dart';
import '../commercial/services/commercial_service.dart';
import '../commercial/services/import_service.dart';
import '../commercial/services/notification_service.dart';
import '../commercial/services/remote_dashboard_service.dart';
import '../commercial/services/secure_config_service.dart';
import '../commercial/services/security_service.dart';
import '../commercial/services/update_service.dart';
import '../models/contact.dart';
import '../models/dashboard_metrics.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/report_service.dart';

class AppState extends ChangeNotifier {
  AppState({DatabaseService? databaseService})
    : _database = databaseService ?? DatabaseService.instance,
      _reports = ReportService() {
    _backups = BackupService(_database);
    commercial = CommercialService(_database);
    commercialDocuments = CommercialDocumentService(_database);
    commercialReports = CommercialReportService(_database);
    imports = ImportService(_database);
    notifications = NotificationService(_database);
    updates = UpdateService(_database);
    remoteDashboard = RemoteDashboardService(_database);
  }

  final DatabaseService _database;
  final ReportService _reports;
  late final BackupService _backups;
  late final CommercialService commercial;
  late final CommercialDocumentService commercialDocuments;
  late final CommercialReportService commercialReports;
  late final ImportService imports;
  late final NotificationService notifications;
  late final UpdateService updates;
  late final RemoteDashboardService remoteDashboard;
  final SecureConfigService secureConfig = const SecureConfigService();
  final SecurityService security = const SecurityService();

  bool isLoading = true;
  String? errorMessage;
  bool requiresOwnerSetup = false;
  StaffUser? currentUser;
  List<BranchRecord> branches = const [];
  Map<String, Object?>? currentCashSession;
  DashboardMetrics metrics = DashboardMetrics.empty;
  List<Product> products = const [];
  List<BusinessContact> customers = const [];
  List<BusinessContact> suppliers = const [];
  List<Expense> expenses = const [];
  List<SaleRecord> sales = const [];
  Map<String, String> settings = const {};
  Timer? _operationsTimer;

  int get activeBranchId =>
      currentUser?.branchId ?? DatabaseService.defaultBranchId;

  bool can(String permission) => currentUser?.can(permission) ?? false;

  String get businessName =>
      settings['business_name']?.trim().isNotEmpty == true
      ? settings['business_name']!
      : 'My Business';
  String get businessPhone => settings['business_phone']?.trim() ?? '';
  String get businessAddress => settings['business_address']?.trim() ?? '';

  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      requiresOwnerSetup = !await commercial.hasStaffUsers();
      branches = await commercial.listBranches();
      await refreshAll();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createInitialOwner({
    required String name,
    required String username,
    required String pin,
  }) async {
    currentUser = await commercial.createInitialOwner(
      name: name,
      username: username,
      pin: pin,
    );
    requiresOwnerSetup = false;
    branches = await commercial.listBranches();
    await refreshAll();
    await _startScheduledOperations();
  }

  Future<void> login({required String username, required String pin}) async {
    currentUser = await commercial.login(username: username, pin: pin);
    branches = await commercial.listBranches();
    await refreshAll();
    await _startScheduledOperations();
  }

  Future<void> switchBranch(int branchId) async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in before changing branch.');
    if (user.role != StaffRole.owner && user.role != StaffRole.manager) {
      throw StateError('Only owners and managers can change branch context.');
    }
    if (currentCashSession != null) {
      throw StateError('Close the current cash shift before changing branch.');
    }
    if (!branches.any((branch) => branch.id == branchId && branch.isActive)) {
      throw StateError('The selected branch is not active.');
    }
    currentUser = user.copyWith(branchId: branchId);
    await refreshAll();
    await commercial.logAudit(
      actor: currentUser!,
      action: 'branch.context_switched',
      entityType: 'branch',
      entityId: '$branchId',
    );
  }

  Future<void> lock() async {
    final user = currentUser;
    _operationsTimer?.cancel();
    _operationsTimer = null;
    currentUser = null;
    currentCashSession = null;
    await remoteDashboard.stop();
    if (user != null) await commercial.endStaffSession(user);
    notifyListeners();
  }

  Future<void> _startScheduledOperations() async {
    _operationsTimer?.cancel();
    await _runScheduledOperations();
    _operationsTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_runScheduledOperations());
    });
  }

  Future<void> _runScheduledOperations() async {
    final actor = currentUser;
    if (actor == null) return;
    try {
      if (actor.can(CommercialPermission.expensesManage)) {
        await commercial.processDueRecurringExpenses(actor: actor);
      }
      if (actor.can(CommercialPermission.backupsManage) &&
          settings['automatic_backup_enabled'] == 'true') {
        final hours = int.tryParse(settings['automatic_backup_hours'] ?? '') ?? 24;
        final db = await _database.database;
        final rows = await db.query(
          'backup_records',
          columns: ['created_at'],
          where: 'status = ? AND encrypted = 1',
          whereArgs: ['completed'],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        final last = rows.isEmpty
            ? null
            : DateTime.tryParse(rows.first['created_at'] as String);
        final due = last == null ||
            DateTime.now().difference(last).inHours >= hours.clamp(1, 24 * 30);
        if (due) {
          final password = await secureConfig.backupPassword();
          if (password != null && password.length >= 8) {
            await _backups.createEncryptedBackup(
              password: password,
              createdBy: actor.id,
            );
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Scheduled operation failed: $error\n$stackTrace');
    }
  }

  Future<void> enableAutomaticBackup({
    required String password,
    int intervalHours = 24,
  }) async {
    _require(CommercialPermission.backupsManage);
    if (password.length < 8) {
      throw ArgumentError('Backup password must contain at least eight characters.');
    }
    await secureConfig.saveBackupPassword(password);
    await _database.saveSettings({
      ...settings,
      'automatic_backup_enabled': 'true',
      'automatic_backup_hours': intervalHours.clamp(1, 24 * 30).toString(),
    });
    await refreshAll();
    await _runScheduledOperations();
  }

  Future<void> disableAutomaticBackup() async {
    _require(CommercialPermission.backupsManage);
    await secureConfig.delete('backup.password');
    await _database.saveSettings({
      ...settings,
      'automatic_backup_enabled': 'false',
    });
    await refreshAll();
  }

  Future<void> refreshAll() async {
    final branchId = activeBranchId;
    final results = await Future.wait<Object>([
      _database.getDashboardMetrics(branchId: branchId),
      _database.getProducts(branchId: branchId),
      _database.getContacts(ContactType.customer, branchId: branchId),
      _database.getContacts(ContactType.supplier, branchId: branchId),
      _database.getExpenses(branchId: branchId),
      _database.getSales(branchId: branchId),
      _database.getSettings(),
    ]);
    metrics = results[0] as DashboardMetrics;
    products = results[1] as List<Product>;
    customers = results[2] as List<BusinessContact>;
    suppliers = results[3] as List<BusinessContact>;
    expenses = results[4] as List<Expense>;
    sales = results[5] as List<SaleRecord>;
    settings = results[6] as Map<String, String>;
    final user = currentUser;
    currentCashSession = user == null
        ? null
        : await commercial.currentCashSession(user);
    notifyListeners();
  }

  void _require(String permission) {
    final user = currentUser;
    if (user == null) throw StateError('Sign in before continuing.');
    if (!user.can(permission)) {
      throw StateError('Your staff role does not permit this action.');
    }
  }

  Future<void> addProduct(Product product) async {
    _require(CommercialPermission.productsManage);
    await _database.addProduct(product, branchId: activeBranchId);
    await commercial.logAudit(
      actor: currentUser!,
      action: 'product.created',
      entityType: 'product',
      entityId: product.sku,
      newValues: product.toMap(),
    );
    await refreshAll();
  }

  Future<void> updateProduct(Product product) async {
    _require(CommercialPermission.productsManage);
    await _database.updateProduct(product, branchId: activeBranchId);
    await commercial.logAudit(
      actor: currentUser!,
      action: 'product.updated',
      entityType: 'product',
      entityId: '${product.id}',
      newValues: product.toMap(),
    );
    await refreshAll();
  }

  Future<void> deleteProduct(Product product) async {
    _require(CommercialPermission.productsManage);
    if (product.id == null) return;
    await _database.deleteProduct(product.id!);
    await commercial.logAudit(
      actor: currentUser!,
      action: 'product.disabled',
      entityType: 'product',
      entityId: '${product.id}',
      oldValues: product.toMap(),
    );
    await refreshAll();
  }

  Future<void> adjustStock(Product product, double change) async {
    _require(CommercialPermission.stockAdjust);
    if (product.id == null) return;
    await commercial.adjustStock(
      actor: currentUser!,
      productId: product.id!,
      quantityChange: change,
      reason: 'Correction',
      note: 'Quick adjustment from product screen',
    );
    await refreshAll();
  }

  Future<void> addContact(BusinessContact contact) async {
    final permission = contact.type == ContactType.customer
        ? CommercialPermission.debtView
        : CommercialPermission.purchasingManage;
    _require(permission);
    await _database.addContact(contact, branchId: activeBranchId);
    await commercial.logAudit(
      actor: currentUser!,
      action: '${contact.type.name}.created',
      entityType: contact.type.name,
      entityId: contact.name,
      newValues: contact.toMap(),
    );
    await refreshAll();
  }

  Future<void> recordContactPayment(
    BusinessContact contact,
    double amount,
  ) async {
    _require(
      contact.type == ContactType.customer
          ? CommercialPermission.debtPayment
          : CommercialPermission.purchasingManage,
    );
    if (contact.id == null) throw ArgumentError('Contact ID is required.');
    if (contact.type == ContactType.customer) {
      await commercial.recordCustomerPayment(
        actor: currentUser!,
        customerId: contact.id!,
        amount: amount,
        paymentMethod: 'Bank',
        reference: 'Customer account payment',
      );
    } else {
      await commercial.recordSupplierPayment(
        actor: currentUser!,
        supplierId: contact.id!,
        amount: amount,
        paymentMethod: 'Bank',
        reference: 'Supplier account payment',
      );
    }
    await refreshAll();
  }

  Future<void> addExpense(Expense expense) async {
    _require(CommercialPermission.expensesManage);
    await _database.addExpense(
      expense,
      branchId: activeBranchId,
      userId: currentUser!.id,
      cashSessionId: currentCashSession?['id'] as int?,
      paymentMethod: 'Cash',
    );
    await commercial.logAudit(
      actor: currentUser!,
      action: 'expense.created',
      entityType: 'expense',
      entityId: expense.title,
      newValues: expense.toMap(),
    );
    await refreshAll();
  }

  Future<String> completeSale(SaleDraft draft) async {
    _require(CommercialPermission.salesProcess);
    if (draft.discount > 0) _require(CommercialPermission.salesDiscount);
    final invoice = await _database.createSale(
      draft,
      branchId: activeBranchId,
      userId: currentUser!.id,
      cashSessionId: draft.paymentMethod == 'Cash'
          ? currentCashSession?['id'] as int?
          : null,
    );
    await commercial.logAudit(
      actor: currentUser!,
      action: 'sale.completed',
      entityType: 'sale',
      entityId: invoice,
      newValues: {
        'total': draft.total,
        'discount': draft.discount,
        'payment_method': draft.paymentMethod,
      },
    );
    await refreshAll();
    return invoice;
  }

  Future<void> saveSettings(Map<String, String> values) async {
    _require(CommercialPermission.settingsManage);
    await _database.saveSettings(values);
    await commercial.logAudit(
      actor: currentUser!,
      action: 'settings.updated',
      entityType: 'settings',
      entityId: 'business',
      newValues: values,
    );
    await refreshAll();
  }

  Future<String> createBackup() {
    _require(CommercialPermission.backupsManage);
    return _backups.createBackup();
  }

  Future<String> createEncryptedBackup(String password) async {
    _require(CommercialPermission.backupsManage);
    final path = await _backups.createEncryptedBackup(
      password: password,
      createdBy: currentUser!.id,
    );
    await commercial.logAudit(
      actor: currentUser!,
      action: 'backup.created',
      entityType: 'backup',
      entityId: path,
    );
    return path;
  }

  Future<void> uploadWebDavBackup({
    required String backupPath,
    required Uri endpoint,
    required String username,
    required String password,
  }) async {
    _require(CommercialPermission.backupsManage);
    await _backups.uploadWebDav(
      backupPath: backupPath,
      endpoint: endpoint,
      username: username,
      password: password,
    );
    await commercial.logAudit(
      actor: currentUser!,
      action: 'backup.cloud_uploaded',
      entityType: 'backup',
      entityId: backupPath,
      newValues: {'endpoint': endpoint.host},
    );
  }

  Future<void> restoreEncryptedBackup(String path, String password) async {
    _require(CommercialPermission.backupsManage);
    final actor = currentUser!;
    _operationsTimer?.cancel();
    _operationsTimer = null;
    await remoteDashboard.stop();
    await _backups.restoreEncryptedBackup(backupPath: path, password: password);
    try {
      await commercial.logAudit(
        actor: actor,
        action: 'backup.restored',
        entityType: 'backup',
        entityId: path,
      );
    } catch (error) {
      debugPrint('The restore completed, but its audit entry could not be linked: $error');
    }
    currentUser = null;
    currentCashSession = null;
    await initialize();
  }

  Future<BusinessHealthSnapshot> businessHealth({bool consolidated = false}) {
    return commercial.businessHealth(
      actor: currentUser!,
      consolidated: consolidated,
    );
  }

  Future<int> createDocument(CommercialDocumentDraft draft) async {
    final id = await commercial.createDocument(actor: currentUser!, draft: draft);
    await refreshAll();
    return id;
  }

  Future<String> exportCommercialDocument(int documentId) =>
      commercialDocuments.exportDocumentPdf(
        documentId: documentId,
        settings: settings,
      );

  Future<Uint8List> buildCommercialDocumentPdf(int documentId) =>
      commercialDocuments.buildDocumentPdf(
        documentId: documentId,
        settings: settings,
      );

  Future<Uint8List> buildBarcodeLabels(
    List<Product> selected, {
    int labelsPerProduct = 1,
  }) => commercialDocuments.buildBarcodeLabels(
    products: selected.map((product) => product.toMap()).toList(),
    labelsPerProduct: labelsPerProduct,
  );

  Future<String> startRemoteDashboard() async {
    _require(CommercialPermission.remoteDashboard);
    var token = await secureConfig.remoteDashboardToken();
    if (token == null || token.length < 24) {
      token = security.randomToken();
      await secureConfig.saveRemoteDashboardToken(token);
    }
    final uri = await remoteDashboard.start(token: token);
    await commercial.logAudit(
      actor: currentUser!,
      action: 'remote_dashboard.started',
      entityType: 'remote_dashboard',
      entityId: '${uri.port}',
    );
    return uri.toString();
  }

  Future<void> stopRemoteDashboard() async {
    await remoteDashboard.stop();
    final actor = currentUser;
    if (actor != null) {
      await commercial.logAudit(
        actor: actor,
        action: 'remote_dashboard.stopped',
        entityType: 'remote_dashboard',
        entityId: '',
      );
    }
    notifyListeners();
  }

  Future<String> exportSalesCsv() => _reports.exportSalesCsv(sales);
  Future<String> exportInventoryCsv() => _reports.exportInventoryCsv(products);

  Future<Uint8List> buildSummaryPdf(PdfPageFormat format) {
    return _reports.buildSummaryPdf(
      pageFormat: format,
      businessName: businessName,
      metrics: metrics,
      sales: sales,
      expenses: expenses,
    );
  }

  Future<Uint8List> buildReceiptPdf({
    required PdfPageFormat format,
    required String invoiceNo,
    required SaleDraft sale,
    required DateTime soldAt,
    String? customerName,
  }) {
    return _reports.buildReceiptPdf(
      pageFormat: format,
      businessName: businessName,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
      invoiceNo: invoiceNo,
      sale: sale,
      soldAt: soldAt,
      customerName: customerName,
    );
  }

  Future<Uint8List> buildReceiptPdfForSavedSale(
    SaleRecord sale, {
    PdfPageFormat? format,
  }) async {
    final items = await _database.getSaleItems(sale.id!);
    final customer = sale.customerId != null
        ? await _database.getContactById(sale.customerId!)
        : null;
    return _reports.buildReceiptPdf(
      pageFormat: format ?? PdfPageFormat.roll80,
      businessName: businessName,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
      invoiceNo: sale.invoiceNo,
      sale: SaleDraft(
        items: items,
        discount: sale.discount,
        paymentMethod: sale.paymentMethod,
        customerId: sale.customerId,
      ),
      soldAt: sale.createdAt,
      customerName: customer?.name,
    );
  }

  Future<void> reprintReceipt(SaleRecord sale) async {
    final bytes = await buildReceiptPdfForSavedSale(sale);
    final documents = await _reports.exportReceiptPdf(
      businessName: businessName,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
      invoiceNo: sale.invoiceNo,
      sale: SaleDraft(
        items: await _database.getSaleItems(sale.id!),
        discount: sale.discount,
        paymentMethod: sale.paymentMethod,
        customerId: sale.customerId,
      ),
      soldAt: sale.createdAt,
      customerName:
          (sale.customerId != null
                  ? await _database.getContactById(sale.customerId!)
                  : null)
              ?.name,
    );
    await File(documents).writeAsBytes(bytes, flush: true);
  }

  Future<String> exportReceiptPdfForSavedSale(SaleRecord sale) async {
    final items = await _database.getSaleItems(sale.id!);
    final customer = sale.customerId != null
        ? await _database.getContactById(sale.customerId!)
        : null;
    return _reports.exportReceiptPdf(
      businessName: businessName,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
      invoiceNo: sale.invoiceNo,
      sale: SaleDraft(
        items: items,
        discount: sale.discount,
        paymentMethod: sale.paymentMethod,
        customerId: sale.customerId,
      ),
      soldAt: sale.createdAt,
      customerName: customer?.name,
    );
  }

  Future<Uint8List> buildPrinterTestPdf(PdfPageFormat format) {
    return _reports.buildPrinterTestPdf(
      pageFormat: format,
      businessName: businessName,
    );
  }

  Future<String> exportSummaryPdf() => _reports.exportSummaryPdf(
    businessName: businessName,
    metrics: metrics,
    sales: sales,
    expenses: expenses,
  );

  Future<String> exportReceiptPdf({
    required String invoiceNo,
    required SaleDraft sale,
    required DateTime soldAt,
    String? customerName,
  }) {
    return _reports.exportReceiptPdf(
      businessName: businessName,
      businessPhone: businessPhone,
      businessAddress: businessAddress,
      invoiceNo: invoiceNo,
      sale: sale,
      soldAt: soldAt,
      customerName: customerName,
    );
  }

  @override
  void dispose() {
    _operationsTimer?.cancel();
    unawaited(remoteDashboard.stop());
    super.dispose();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState super.notifier,
    required super.child,
    super.key,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in the widget tree.');
    return scope!.notifier!;
  }
}
