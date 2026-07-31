import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/database_service.dart';
import '../models/commercial_models.dart';

class CommercialReportService {
  const CommercialReportService(this._database);

  final DatabaseService _database;

  Future<List<Map<String, Object?>>> profitByProduct({
    required StaffUser actor,
    DateTime? from,
    DateTime? to,
    bool consolidated = false,
  }) async {
    _requireReportAccess(actor, consolidated);
    final filters = <String>["s.status = 'completed'"];
    final args = <Object?>[];
    if (!consolidated) {
      filters.add('s.branch_id = ?');
      args.add(actor.branchId);
    }
    if (from != null) {
      filters.add('s.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      filters.add('s.created_at <= ?');
      args.add(to.toIso8601String());
    }
    final db = await _database.database;
    return db.rawQuery('''
      SELECT si.product_id, si.product_name,
        COALESCE(p.category, 'Uncategorized') AS category,
        SUM(si.quantity) AS quantity,
        SUM(si.unit_price * si.quantity) AS revenue,
        SUM(si.cost_price * si.quantity) AS cost_of_goods,
        SUM((si.unit_price - si.cost_price) * si.quantity) AS gross_profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      LEFT JOIN products p ON p.id = si.product_id
      WHERE ${filters.join(' AND ')}
      GROUP BY si.product_id, si.product_name, COALESCE(p.category, 'Uncategorized')
      ORDER BY gross_profit DESC, revenue DESC
    ''', args);
  }

  Future<List<Map<String, Object?>>> profitByBranch({
    required StaffUser actor,
    DateTime? from,
    DateTime? to,
  }) async {
    if (actor.role != StaffRole.owner && actor.role != StaffRole.manager) {
      throw StateError('Consolidated branch reporting is not permitted.');
    }
    final dateSql = <String>[];
    final args = <Object?>[];
    if (from != null) {
      dateSql.add('s.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      dateSql.add('s.created_at <= ?');
      args.add(to.toIso8601String());
    }
    final dateClause = dateSql.join(' AND ');
    final filter = dateSql.isEmpty ? '' : 'AND $dateClause';
    final db = await _database.database;
    return db.rawQuery('''
      SELECT b.id AS branch_id, b.name AS branch_name,
        COALESCE(SUM(s.total - s.returned_total), 0) AS revenue,
        COALESCE(SUM(s.discount), 0) AS discounts,
        COALESCE(SUM(s.returned_total), 0) AS returns,
        COALESCE(SUM(item_profit), 0) - COALESCE(SUM(s.discount), 0)
          AS gross_profit
      FROM branches b
      LEFT JOIN sales s
        ON s.branch_id = b.id AND s.status = 'completed' $filter
      LEFT JOIN (
        SELECT sale_id,
          SUM((unit_price - cost_price) * quantity) AS item_profit
        FROM sale_items GROUP BY sale_id
      ) item_totals ON item_totals.sale_id = s.id
      WHERE b.is_active = 1
      GROUP BY b.id, b.name
      ORDER BY revenue DESC
    ''', args);
  }

  Future<List<Map<String, Object?>>> debtAgeing(StaffUser actor) async {
    if (!actor.can(CommercialPermission.debtView)) {
      throw StateError('Your staff role cannot view customer debt.');
    }
    final now = DateTime.now();
    final db = await _database.database;
    final invoices = await db.rawQuery('''
      SELECT d.customer_id, c.name AS customer_name, d.balance_due, d.due_at
      FROM documents d
      INNER JOIN customers c ON c.id = d.customer_id
      WHERE d.branch_id = ? AND d.document_type = 'invoice'
        AND d.balance_due > 0 AND d.debt_posted = 1
      ORDER BY c.name, d.due_at
    ''', [actor.branchId]);
    final grouped = <int, Map<String, Object?>>{};
    for (final invoice in invoices) {
      final customerId = invoice['customer_id'] as int;
      final row = grouped.putIfAbsent(customerId, () => {
            'customer_id': customerId,
            'customer_name': invoice['customer_name'],
            'current': 0.0,
            'days_1_30': 0.0,
            'days_31_60': 0.0,
            'days_61_90': 0.0,
            'days_over_90': 0.0,
            'total': 0.0,
          });
      final balance = (invoice['balance_due'] as num? ?? 0).toDouble();
      final due = DateTime.tryParse(invoice['due_at']?.toString() ?? '');
      final overdueDays = due == null ? 0 : now.difference(due).inDays;
      final bucket = overdueDays <= 0
          ? 'current'
          : overdueDays <= 30
              ? 'days_1_30'
              : overdueDays <= 60
                  ? 'days_31_60'
                  : overdueDays <= 90
                      ? 'days_61_90'
                      : 'days_over_90';
      row[bucket] = (row[bucket] as double) + balance;
      row['total'] = (row['total'] as double) + balance;
    }
    return grouped.values.toList(growable: false)
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
  }

  Future<Uint8List> buildProfitPdf({
    required StaffUser actor,
    required String businessName,
    DateTime? from,
    DateTime? to,
    bool consolidated = false,
  }) async {
    final products = await profitByProduct(
      actor: actor,
      from: from,
      to: to,
      consolidated: consolidated,
    );
    final branches = consolidated
        ? await profitByBranch(actor: actor, from: from, to: to)
        : const <Map<String, Object?>>[];
    final revenue = products.fold<double>(
      0,
      (sum, row) => sum + (row['revenue'] as num? ?? 0).toDouble(),
    );
    final cost = products.fold<double>(
      0,
      (sum, row) => sum + (row['cost_of_goods'] as num? ?? 0).toDouble(),
    );
    final gross = products.fold<double>(
      0,
      (sum, row) => sum + (row['gross_profit'] as num? ?? 0).toDouble(),
    );
    final pdf = pw.Document(
      title: '$businessName Profit Report',
      author: 'Airmonlink Business Manager',
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              businessName.trim().isEmpty ? 'My Business' : businessName.trim(),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('ADVANCED PROFIT REPORT'),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by Airmonlink Business Manager', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        build: (_) => [
          pw.SizedBox(height: 18),
          pw.Text(
            'Period: ${_date(from)} to ${_date(to)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('Revenue', revenue),
              _metric('Cost of goods', cost),
              _metric('Gross product profit', gross),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Profit by product', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (products.isEmpty)
            pw.Text('No completed sales were recorded in this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Product', 'Category', 'Qty', 'Revenue', 'Cost', 'Gross profit'],
              data: products.map((row) => [
                    row['product_name'],
                    row['category'],
                    _quantity(row['quantity']),
                    _money(row['revenue']),
                    _money(row['cost_of_goods']),
                    _money(row['gross_profit']),
                  ]).toList(growable: false),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          if (branches.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Branch comparison', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const ['Branch', 'Revenue', 'Discounts', 'Returns', 'Gross profit'],
              data: branches.map((row) => [
                    row['branch_name'],
                    _money(row['revenue']),
                    _money(row['discounts']),
                    _money(row['returns']),
                    _money(row['gross_profit']),
                  ]).toList(growable: false),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  Future<String> exportProfitCsv({
    required StaffUser actor,
    DateTime? from,
    DateTime? to,
    bool consolidated = false,
  }) async {
    final rows = await profitByProduct(
      actor: actor,
      from: from,
      to: to,
      consolidated: consolidated,
    );
    final output = StringBuffer()
      ..writeln('Product,Category,Quantity,Revenue,Cost of goods,Gross profit');
    for (final row in rows) {
      output.writeln([
        _csv(row['product_name']?.toString() ?? ''),
        _csv(row['category']?.toString() ?? ''),
        row['quantity'],
        row['revenue'],
        row['cost_of_goods'],
        row['gross_profit'],
      ].join(','));
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Reports'),
    );
    await directory.create(recursive: true);
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final file = File(
      p.join(directory.path, 'Profit-Report-$timestamp.csv'),
    );
    await file.writeAsString(output.toString(), flush: true);
    return file.path;
  }

  static void _requireReportAccess(StaffUser actor, bool consolidated) {
    if (!actor.can(CommercialPermission.reportsProfit)) {
      throw StateError('Your staff role cannot view profit reports.');
    }
    if (consolidated &&
        actor.role != StaffRole.owner &&
        actor.role != StaffRole.manager) {
      throw StateError('Consolidated reporting is not permitted.');
    }
  }

  static pw.Widget _metric(String label, double value) => pw.Container(
        width: 150,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(_money(value), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static String _money(Object? value) =>
      'GHS ${(value as num? ?? 0).toStringAsFixed(2)}';

  static String _quantity(Object? value) {
    final number = (value as num? ?? 0).toDouble();
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);
  }

  static String _date(DateTime? value) =>
      value == null ? 'All dates' : DateFormat('dd MMM yyyy').format(value);

  static String _csv(String value) {
    final quote = String.fromCharCode(34);
    return '$quote${value.replaceAll(quote, '$quote$quote')}$quote';
  }
}
