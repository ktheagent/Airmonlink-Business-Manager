import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw ;
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
    final items = <_ReceiptItem>[];
    if (sale.id != null) {
      final db = await _database.database;
      final rows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [sale.id],
        orderBy: 'id ASC',
      );
      for (final row in rows) {
        items.add(
          _ReceiptItem(
            name: row['product_name'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitPrice: (row['unit_price'] as num).toDouble(),
          ),
        );
      }
    }

    final paper = settings['receipt_paper_size'] ?? '80mm';
    final format = paper == '58mm'
        ? PdfPageFormat.roll57
        : paper == 'A4'
            ? PdfPageFormat.a4
            : PdfPageFormat.roll80;
    final document = pw.Document();
    final business = settings['business_name']?.trim().isNotEmpty == true
        ? settings['business_name']!
        : 'My Business';
    document.addPage(
      pu.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              business,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _row('Invoice', sale.invoiceNo),
          _row('Date', _date(sale.createdAt)),
          _row('Payment', sale.paymentMethod),
          pw.Divider(),
          ...items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pu.CrossAxisAlignment.start,
                children: [
                  pu.Text(item.name),
                  _row(
                    '${_qty(item.quantity)} x ${_money(item.unitPrice)}',
                    _money(item.total),
                  ),
                ],
              ),
            ),
          ),
          pw.Divider(),
          _row('Subtotal', _money(sale.subtotal)),
          if (sale.discount > 0)
            _row('Discount', '-${_money(sale.discount)}'),
          _row('Total', _money(sale.total), bold: true),
          pu.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              settings['receipt_footer'] ?? 'Thank you for your business!',
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return Printing.layoutPdf(
      name: 'Receipt ${sale.invoiceNo}',
      format: format,
      onLayout: (_) => document.save(),
    );
  }

  pu.Widget _row(String left, String right, {bool bold = false}) {
    final style = pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pu.Row(
      children: [
        pw.Expanded(child: pw.Text(left, style: style)),
        pw.SizedBox(width: 8),
        pw.Text(right, style: style),
      ],
    );
  }

  String _money(double value) => 'GHS ${value.toStringAsFixed(2)}';

  String _qty(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _ReceiptItem {
  const _ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;
}
