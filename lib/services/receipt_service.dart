import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sale.dart';
import 'database_service.dart';

class ReceiptService {
  ReceiptService(this._database);

  final DatabaseService _database;

  Future<bool> printSale(
    SaleRecord sale,
    Map<String, String> settings,
  ) async {
    final entries = <_ReceiptLine>[];
    if (sale.id != null) {
      final db = await _database.database;
      final rows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [sale.id],
        orderBy: 'id ASC',
      );
      for (final row in rows) {
        entries.add(
          _ReceiptLine(
            name: row['product_name'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitPrice: (row['unit_price'] as num).toDouble(),
          ),
        );
      }
    }

    return _print(
      name: 'Receipt ${sale.invoiceNo}',
      invoice: sale.invoiceNo,
      createdAt: sale.createdAt,
      paymentMethod: sale.paymentMethod,
      items: entries,
      subtotal: sale.subtotal,
    discount: sale.discount,
      total: sale.total,
    settings: settings,
    );
  }

  Future<bool> printTest(Map<String, String> settings) {
    final now = DateTime.now();
    return _print(
      name: 'Airmonlink test receipt',
      invoice: 'TEST-${now.millisecondsSinceEpoch}',
      createdAt: now,
      paymentMethod: 'Cash',
      items: const [
        _ReceiptLine(name: 'Test product', quantity: 2, unitPrice: 10),
      ],
      subtotal: 20,
      discount: 0,
      total: 20,
      settings: settings,
    );
  }

  Future<bool> _print({
    required String name,
    required String invoice,
    required DateTime createdAt,
    required String paymentMethod,
    required List<_ReceiptLine> items,
    required double subtotal,
    required double discount,
    required double total,
    required Map<String, String> settings,
  }) async {
    final printers = await Printing.listPrinters();
    if (printers.isEmpty) {
      throw StateError(
        'No printers are installed in Windows. Add or enable a printer and try again.',
      );
    }

    final paper = settings['receipt_paper_size'] ?? '80mm';
    final format = switch (paper) {
      '58mm' => PdfPageFormat.roll57,
      'A4' => PdfPageFormat.a4,
      _ => PdfPageFormat.roll80,
    };
    final thermal = paper != 'A4';
    final bytes = await _build(
      format: format,
      invoice: invoice,
      createdAt: createdAt,
      paymentMethod: paymentMethod,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      settings: settings,
    );

    return Printing.layoutPdf(
      name: name,
      format: format,
      dynamicLayout: false,
      usePrinterSettings: false,
      forceCustomPrintPaper: thermal,
      windowsModernDialog: true,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> _build({
    required PdfPageFormat format,
    required String invoice,
    required DateTime createdAt,
    required String paymentMethod,
    required List<_ReceiptLine> items,
    required double subtotal,
    required double discount,
    required double total,
    required Map<String, String> settings,
  }) async {
    final document = pw.Document();
    final thermal = format.width < 100 * PdfPageFormat.mm;
    final bodySize = thermal ? 9.0 : 11.0;
    final margin = thermal ? 4 * PdfPageFormat.mm : 16 * PdfPageFormat.mm;
    final business = settings['business_name']?.trim().isNotEmpty == true
        ? settings['business_name']!
        : 'My Business';

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: pw.EdgeInsets.all(margin),
        theme: pw.ThemeData.withFont(base: pu.Font.helvetica()),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              business,
              textAlign: pu.TextAlign.center,
              style: pu.TextStyle(fontSize: thermal ? 14.0 : 20.0, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (settings['business_address']?.trim().isNotEmpty == true)
            pw.Center(child: pu.Text(settings['business_address']!, style: pw.TextStyle(fontSize: bodySize))),
            if (settings['business_phone']?.trim().isNotEmpty == true)
            pw.Center(child: pw.Text(settings['business_phone']!, style: pw.TextStyle(fontSize: bodySize))),
          pw.SizedBox(height: 8),
          pw.Divider(),
          _textRow('Invoice', invoice, bodySize),
          _textRow('Date', ${writeDate(createdAt)} ${writeTime(createdAt)}', bodySize),
          _textRow('Payment', paymentMethod, bodySize),
          pw.Divider(),
          ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(item.name, style: pu.TextStyle(fontSize: bodySize, fontWeight: pu.FontWeight.bold)),
                  _textRow('${fmt(item.quantity)} x ${money(item.unitPrice)}', money(item.total), bodySize),
                ]),
              )),
          pw.Divider(),
          _textRow('Subtotal', money(subtotal), bodySize),
          if (discount > 0) _textRow('Discount', '-${money(discount)}', bodySize),
          _textRow('TOTAL', money(total), bodySize, bold: true),
          pw.SizedBox(height: 12),
          pw.Center(child: pu.Text(settings['receipt_footer'] ?? 'Thank you for your business!', textAlign: pu.TextAlign.center, style: pw.TextStyle(fontSize: bodySize))),
        ],
      ),
    );
    return document.save();
  }

  pu.Widget _textRow(String left, String right, double size, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Row(children: [
      pu.Expanded(child: pw.Text(left, style: style)),
      pw.SizedBox(width: 8),
      pu.Text(right, style: style),
    ]);
  }

  String money(double value) => 'GHS ${value.toStringAsFixed(2)}';
  String fmt(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  String writeDate(DateTime value) => '${valu.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String writeTime(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _ReceiptLine {
  const _ReceiptLine({required this.name, required this.quantity, required this.unitPrice});
  final String name;
  final double quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;
}
