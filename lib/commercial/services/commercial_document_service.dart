import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/database_service.dart';

class CommercialDocumentService {
  const CommercialDocumentService(this._database);

  final DatabaseService _database;

  Future<Uint8List> buildDocumentPdf({
    required int documentId,
    required Map<String, String> settings,
  }) async {
    final db = await _database.database;
    final documents = await db.rawQuery('''
      SELECT d.*, c.name AS customer_name, c.phone AS customer_phone,
        c.email AS customer_email, b.name AS branch_name, b.address AS branch_address
      FROM documents d
      LEFT JOIN customers c ON c.id = d.customer_id
      INNER JOIN branches b ON b.id = d.branch_id
      WHERE d.id = ?
    ''', [documentId]);
    if (documents.isEmpty) throw StateError('Document was not found.');
    final document = documents.first;
    final items = await db.query(
      'document_items',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'id',
    );
    final pdf = pw.Document(
      title: '${document['document_type']} ${document['document_no']}',
      author: 'Airmonlink Business Manager',
    );
    final businessName = _setting(settings, 'business_name', 'My Business');
    final logoPath = settings['business_logo_path'] ?? '';
    pw.MemoryImage? logo;
    if (logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) logo = pw.MemoryImage(await file.readAsBytes());
    }
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 72, height: 72, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(settings['business_address'] ?? ''),
                    pw.Text(settings['business_phone'] ?? ''),
                    pw.Text(settings['business_email'] ?? ''),
                    if ((settings['business_tax_number'] ?? '').isNotEmpty)
                      pw.Text('Tax No: ${settings['business_tax_number']}'),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _documentTitle(document['document_type'] as String),
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('${document['document_no']}'),
                  pw.Text(_date(document['created_at'])),
                  pw.Text('Status: ${document['status']}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('${document['customer_name'] ?? 'Cash customer'}'),
                      if ('${document['customer_phone'] ?? ''}'.isNotEmpty)
                        pw.Text('${document['customer_phone']}'),
                      if ('${document['customer_email'] ?? ''}'.isNotEmpty)
                        pw.Text('${document['customer_email']}'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Branch', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('${document['branch_name']}'),
                      pw.Text('${document['branch_address'] ?? ''}'),
                      if (document['due_at'] != null) pw.Text('Due: ${_date(document['due_at'])}'),
                      if (document['valid_until'] != null)
                        pw.Text('Valid until: ${_date(document['valid_until'])}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const ['Description', 'Qty', 'Unit price', 'Tax', 'Total'],
            data: items.map((item) => [
              item['description'],
              _qty(item['quantity']),
              _money(item['unit_price']),
              '${(item['tax_rate'] as num? ?? 0).toStringAsFixed(1)}%',
              _money(item['line_total']),
            ]).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(children: [
                _totalRow('Subtotal', document['subtotal']),
                _totalRow('Discount', document['discount']),
                _totalRow('Tax', document['tax']),
                pw.Divider(),
                _totalRow('Total', document['total'], bold: true),
                if ((document['amount_paid'] as num? ?? 0).toDouble() > 0)
                  _totalRow('Paid', document['amount_paid']),
                if ((document['balance_due'] as num? ?? 0).toDouble() > 0)
                  _totalRow('Balance', document['balance_due'], bold: true),
              ]),
            ),
          ),
          if ('${document['notes'] ?? ''}'.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('${document['notes']}'),
          ],
          if ('${document['terms'] ?? ''}'.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Terms and conditions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('${document['terms']}'),
          ],
          if ((settings['payment_instructions'] ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Payment instructions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(settings['payment_instructions']!),
          ],
          pw.SizedBox(height: 28),
          pw.Row(children: [
            pw.Expanded(child: pw.Divider()),
            pw.SizedBox(width: 24),
            pw.Expanded(child: pw.Divider()),
          ]),
          pw.Row(children: [
            pw.Expanded(child: pw.Text('Customer signature', textAlign: pw.TextAlign.center)),
            pw.SizedBox(width: 24),
            pw.Expanded(child: pw.Text('Authorized signature', textAlign: pw.TextAlign.center)),
          ]),
          pw.SizedBox(height: 18),
          pw.Center(child: pw.Text(settings['document_footer'] ?? 'Thank you for your business.')),
        ],
      ),
    );
    return pdf.save();
  }

  Future<String> exportDocumentPdf({
    required int documentId,
    required Map<String, String> settings,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'documents',
      columns: ['document_no'],
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Document was not found.');
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Documents'),
    );
    await directory.create(recursive: true);
    final path = p.join(directory.path, '${rows.first['document_no']}.pdf');
    await File(path).writeAsBytes(
      await buildDocumentPdf(documentId: documentId, settings: settings),
      flush: true,
    );
    return path;
  }

  Future<Uint8List> buildCustomerStatementPdf({
    required int customerId,
    required int branchId,
    required Map<String, String> settings,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _database.database;
    final customers = await db.rawQuery('''
      SELECT c.*, b.name AS branch_name, b.address AS branch_address
      FROM customers c
      INNER JOIN branches b ON b.id = c.branch_id
      WHERE c.id = ? AND c.branch_id = ? AND COALESCE(c.is_active, 1) = 1
    ''', [customerId, branchId]);
    if (customers.isEmpty) throw StateError('Customer was not found.');
    final customer = customers.first;
    final where = <String>['customer_id = ?', 'branch_id = ?'];
    final args = <Object?>[customerId, branchId];
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('created_at <= ?');
      args.add(to.toIso8601String());
    }
    final transactions = await db.query(
      'customer_transactions',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at ASC, id ASC',
    );
    var running = 0.0;
    final rows = <List<String>>[];
    for (final transaction in transactions) {
      final amount = (transaction['amount'] as num? ?? 0).toDouble();
      running += amount;
      rows.add([
        _date(transaction['created_at']),
        '${transaction['transaction_type']}'.replaceAll('_', ' '),
        '${transaction['note'] ?? ''}',
        amount >= 0 ? _money(amount) : '',
        amount < 0 ? _money(amount.abs()) : '',
        _money(running),
      ]);
    }
    final pdf = pw.Document(
      title: 'Customer statement - ${customer['name']}',
      author: 'Airmonlink Business Manager',
    );
    final businessName = _setting(settings, 'business_name', 'My Business');
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              businessName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('CUSTOMER STATEMENT'),
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
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${customer['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('${customer['phone'] ?? ''}'),
                      pw.Text('${customer['email'] ?? ''}'),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('${customer['branch_name']}'),
                    if ('${customer['branch_address'] ?? ''}'.isNotEmpty)
                      pw.Text('${customer['branch_address']}'),
                    pw.Text('Statement date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
                    pw.Text('Outstanding: ${_money(customer['balance'])}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          if (rows.isEmpty)
            pw.Text('No account transactions were recorded in this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Type', 'Reference', 'Charge', 'Payment', 'Running balance'],
              data: rows,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
            ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Amount due: ${_money(customer['balance'])}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if ((settings['payment_instructions'] ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Payment instructions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(settings['payment_instructions']!),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  Future<String> exportCustomerStatement({
    required int customerId,
    required int branchId,
    required Map<String, String> settings,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'customers',
      columns: ['name'],
      where: 'id = ? AND branch_id = ?',
      whereArgs: [customerId, branchId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Customer was not found.');
    final safeName = '${rows.first['name']}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Statements'),
    );
    await directory.create(recursive: true);
    final path = p.join(
      directory.path,
      'Customer-Statement-${safeName.isEmpty ? customerId : safeName}.pdf',
    );
    await File(path).writeAsBytes(
      await buildCustomerStatementPdf(
        customerId: customerId,
        branchId: branchId,
        settings: settings,
      ),
      flush: true,
    );
    return path;
  }

  Future<Uint8List> buildBarcodeLabels({
    required List<Map<String, Object?>> products,
    int labelsPerProduct = 1,
  }) async {
    if (products.isEmpty) throw ArgumentError('Select at least one product.');
    if (labelsPerProduct < 1 || labelsPerProduct > 500) {
      throw ArgumentError('Label quantity must be between 1 and 500.');
    }
    final pdf = pw.Document(title: 'Product barcode labels');
    final widgets = <pw.Widget>[];
    for (final product in products) {
      final barcode = '${product['barcode'] ?? ''}'.trim();
      if (barcode.isEmpty) continue;
      for (var i = 0; i < labelsPerProduct; i++) {
        widgets.add(
          pw.Container(
            width: 62 * PdfPageFormat.mm,
            height: 31 * PdfPageFormat.mm,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  '${product['name']}',
                  maxLines: 1,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 3),
                pw.BarcodeWidget(
                  barcode: _barcodeType(barcode),
                  data: barcode,
                  width: 52 * PdfPageFormat.mm,
                  height: 13 * PdfPageFormat.mm,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 7),
                ),
                pw.Text(
                  'GHS ${(product['selling_price'] as num? ?? 0).toStringAsFixed(2)}  •  ${product['sku'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (widgets.isEmpty) throw StateError('Selected products do not have barcodes.');
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (_) => [pw.Wrap(spacing: 4, runSpacing: 4, children: widgets)],
      ),
    );
    return pdf.save();
  }

  static pw.Barcode _barcodeType(String value) {
    if (RegExp(r'^\d{13}$').hasMatch(value)) return pw.Barcode.ean13();
    if (RegExp(r'^\d{12}$').hasMatch(value)) return pw.Barcode.upcA();
    return pw.Barcode.code128();
  }

  static pw.Widget _totalRow(String label, Object? value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
            pw.Text(_money(value), style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
          ],
        ),
      );

  static String _setting(Map<String, String> settings, String key, String fallback) =>
      settings[key]?.trim().isNotEmpty == true ? settings[key]!.trim() : fallback;

  static String _documentTitle(String type) => switch (type) {
    'quotation' => 'QUOTATION',
    'estimate' => 'ESTIMATE',
    'proforma' => 'PRO-FORMA INVOICE',
    'invoice' => 'INVOICE',
    'delivery_note' => 'DELIVERY NOTE',
    'credit_note' => 'CREDIT NOTE',
    _ => type.replaceAll('_', ' ').toUpperCase(),
  };

  static String _date(Object? value) {
    if (value == null) return '';
    final date = DateTime.tryParse('$value');
    return date == null ? '$value' : DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  static String _money(Object? value) =>
      'GHS ${(value as num? ?? 0).toStringAsFixed(2)}';

  static String _qty(Object? value) {
    final number = (value as num? ?? 0).toDouble();
    return number == number.roundToDouble() ? number.toInt().toString() : number.toStringAsFixed(2);
  }
}
