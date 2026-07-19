import 'package:airmonlink_business_manager/models/dashboard_metrics.dart';
import 'package:airmonlink_business_manager/models/sale.dart';
import 'package:airmonlink_business_manager/services/report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  group('ReportService PDF generation', () {
    final service = ReportService();

    test(
      'summary PDF has a valid header and visible document payload',
      () async {
        final bytes = await service.buildSummaryPdf(
          pageFormat: PdfPageFormat.a4,
          businessName: 'Airmonlink Test Shop',
          metrics: const DashboardMetrics(
            todaySales: 150,
            todayTransactions: 2,
            totalProducts: 5,
            lowStockProducts: 1,
            customerDebt: 40,
            monthExpenses: 25,
            monthGrossProfit: 90,
          ),
          sales: const [],
          expenses: const [],
        );

        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(500));
      },
    );

    test('receipt PDF has a valid header and item payload', () async {
      const sale = SaleDraft(
        items: [
          SaleItem(
            productId: 1,
            productName: 'Test Product',
            quantity: 2,
            unitPrice: 12.5,
            costPrice: 7,
          ),
        ],
        discount: 1,
        paymentMethod: 'Cash',
        customerId: null,
      );

      final bytes = await service.buildReceiptPdf(
        pageFormat: PdfPageFormat.roll80,
        businessName: 'Airmonlink Test Shop',
        businessPhone: '0000000000',
        businessAddress: 'Accra, Ghana',
        invoiceNo: 'INV-TEST-1',
        sale: sale,
        soldAt: DateTime(2026, 7, 19, 10, 30),
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(500));
    });
  });
}
