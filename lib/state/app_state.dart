import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';

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
  }

  final DatabaseService _database;
  final ReportService _reports;
  late final BackupService _backups;

  bool isLoading = true;
  String? errorMessage;
  DashboardMetrics metrics = DashboardMetrics.empty;
  List<Product> products = const [];
  List<BusinessContact> customers = const [];
  List<BusinessContact> suppliers = const [];
  List<Expense> expenses = const [];
  List<SaleRecord> sales = const [];
  Map<String, String> settings = const {};

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
      await refreshAll();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    final results = await Future.wait<Object>([
      _database.getDashboardMetrics(),
      _database.getProducts(),
      _database.getContacts(ContactType.customer),
      _database.getContacts(ContactType.supplier),
      _database.getExpenses(),
      _database.getSales(),
      _database.getSettings(),
    ]);
    metrics = results[0] as DashboardMetrics;
    products = results[1] as List<Product>;
    customers = results[2] as List<BusinessContact>;
    suppliers = results[3] as List<BusinessContact>;
    expenses = results[4] as List<Expense>;
    sales = results[5] as List<SaleRecord>;
    settings = results[6] as Map<String, String>;
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    await _database.addProduct(product);
    await refreshAll();
  }

  Future<void> updateProduct(Product product) async {
    await _database.updateProduct(product);
    await refreshAll();
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id == null) return;
    await _database.deleteProduct(product.id!);
    await refreshAll();
  }

  Future<void> adjustStock(Product product, double change) async {
    if (product.id == null) return;
    await _database.adjustStock(product.id!, change);
    await refreshAll();
  }

  Future<void> addContact(BusinessContact contact) async {
    await _database.addContact(contact);
    await refreshAll();
  }

  Future<void> recordContactPayment(
    BusinessContact contact,
    double amount,
  ) async {
    await _database.recordContactPayment(contact, amount);
    await refreshAll();
  }

  Future<void> addExpense(Expense expense) async {
    await _database.addExpense(expense);
    await refreshAll();
  }

  Future<String> completeSale(SaleDraft draft) async {
    final invoice = await _database.createSale(draft);
    await refreshAll();
    return invoice;
  }

  Future<void> saveSettings(Map<String, String> values) async {
    await _database.saveSettings(values);
    await refreshAll();
  }

  Future<String> createBackup() => _backups.createBackup();

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
