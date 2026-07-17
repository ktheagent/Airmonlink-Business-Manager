import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../models/dashboard_metrics.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/sale.dart';

class ReportService {
  Future<String> exportSalesCsv(List<SaleRecord> sales) async {
    final rows = <List<String>>[
      ['Invoice', 'Date', 'Payment Method', 'Subtotal', 'Discount', 'Total'],
      ...sales.map(
        (sale) => [
          sale.invoiceNo,
          sale.createdAt.toIso8601String(),
          sale.paymentMethod,
          sale.subtotal.toStringAsFixed(2),
          sale.discount.toStringAsFixed(2),
          sale.total.toStringAsFixed(2),
        ],
      ),
    ];

    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    final path = await _exportPath('sales', 'csv');
    await File(path).writeAsString('\ufeff$csv', encoding: utf8, flush: true);
    return path;
  }

  Future<String> exportInventoryCsv(List<Product> products) async {
    final rows = <List<String>>[
      [
        'Product',
        'SKU',
        'Barcode',
        'Category',
        'Cost Price',
        'Selling Price',
        'Stock',
        'Low Stock Level',
      ],
      ...products.map(
        (product) => [
          product.name,
          product.sku,
          product.barcode,
          product.category,
          product.costPrice.toStringAsFixed(2),
          product.sellingPrice.toStringAsFixed(2),
          product.stockQty.toStringAsFixed(2),
          product.lowStockLevel.toStringAsFixed(2),
        ],
      ),
    ];

    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    final path = await _exportPath('inventory', 'csv');
    await File(path).writeAsString('\ufeff$csv', encoding: utf8, flush: true);
    return path;
  }

  Future<String> exportSummaryPdf({
    required String businessName,
    required DashboardMetrics metrics,
    required List<SaleRecord> sales,
    required List<Expense> expenses,
  }) async {
    final document = pw.Document(
      title: '$businessName Business Summary',
      author: 'Airmonlink Business Manager',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey300),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                businessName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(AppFormatters.date(DateTime.now())),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 18),
          pw.Text(
            'Business Summary',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricBox('Today Sales', _pdfMoney(metrics.todaySales)),
              _metricBox('Today Transactions', '${metrics.todayTransactions}'),
              _metricBox('Monthly Gross Profit', _pdfMoney(metrics.monthGrossProfit)),
              _metricBox('Monthly Expenses', _pdfMoney(metrics.monthExpenses)),
              _metricBox('Customer Credit', _pdfMoney(metrics.customerDebt)),
              _metricBox('Products', '${metrics.totalProducts}'),
              _metricBox('Low Stock', '${metrics.lowStockProducts}'),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Recent Sales',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Invoice', 'Date', 'Payment', 'Total'],
            data: sales.take(25).map((sale) {
              return [
                sale.invoiceNo,
                AppFormatters.dateTime(sale.createdAt),
                sale.paymentMethod,
                _pdfMoney(sale.total),
              ];
            }).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Recent Expenses',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Description', 'Category', 'Date', 'Amount'],
            data: expenses.take(25).map((expense) {
              return [
                expense.title,
                expense.category,
                AppFormatters.dateTime(expense.createdAt),
                _pdfMoney(expense.amount),
              ];
            }).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    final path = await _exportPath('business-summary', 'pdf');
    await File(path).writeAsBytes(await document.save(), flush: true);
    return path;
  }

  static pw.Widget _metricBox(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<String> _exportPath(String prefix, String extension) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Exports'),
    );
    await directory.create(recursive: true);
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return p.join(directory.path, '$prefix-$timestamp.$extension');
  }

  static String _csvCell(String value) {
    final safeValue = RegExp(r'^[=+\-@]').hasMatch(value) ? "'$value" : value;
    return '"' + safeValue.replaceAll('"', '""') + '"';
  }

  static String _pdfMoney(num value) => 'GHS ${value.toStringAsFixed(2)}';
}
