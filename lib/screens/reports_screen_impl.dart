import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/sale.dart';
import '../services/database_service.dart';
import '../services/receipt_service.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/page_header.dart';
import '../widgets/stat_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final netEstimate = state.metrics.monthGrossProfit - state.metrics.monthExpenses;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Reports and exports',
          subtitle: 'Review performance, export records, and reprint receipts.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _exportInventory(context, state),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Inventory CSV'),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportSales(context, state),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Sales CSV'),
            ),
            FilledButton.icon(
              onPressed: () => _exportPdf(context, state),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Summary PDF'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950 ? 3 : 1;
            final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Monthly gross profit',
                    value: AppFormatters.money(state.metrics.monthGrossProfit),
                    icon: Icons.trending_up,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Monthly expenses',
                    value: AppFormatters.money(state.metrics.monthExpenses),
                    icon: Icons.money_off_csred_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Estimated net result',
                    value: AppFormatters.money(netEstimate),
                    icon: Icons.account_balance_outlined,
                    warning: netEstimate < 0,
                    subtitle: 'Gross profit minus recorded expenses',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales register', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (state.sales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('No sales are available for reporting.')),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Invoice')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Payment')),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('Print')),
                      ],
                      rows: state.sales.map((sale) {
                        return DataRow(
                          cells: [
                            DataCell(Text(sale.invoiceNo)),
                            DataCell(Text(AppFormatters.dateTime(sale.createdAt))),
                            DataCell(Text(sale.paymentMethod)),
                              DataCell(Text(AppFormatters.money(sale.total))),
                              DataCell(
                              IconButton(
                                tooltip: 'Print receipt',
                                  onPressed: () => _printReceipt(context, state, sale),
                                  icon: const Icon(Icons.print_outlined),
                                ),
                              ),
                            ],
                           );
                        }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _printReceipt(BuildContext context, AppState state, SaleRecord sale) async {
    try {
      final printed = await ReceiptService(DatabaseService.instance).printSale(sale, state.settings);
      if (!context.mounted) return;
      if (printed) {
        showSuccess(context, 'Receipt sent to the Windows print dialog.');
      } else {
        showFailure(context, 'Printing was cancelled.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _exportInventory(BuildContext context, AppState state) async {
    try {
      final path = await state.exportInventoryCsv();
      if (context.mounted) showSuccess(context, 'Inventory exported to $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _exportSales(BuildContext context, AppState state) async {
    try {
      final path = await state.exportSalesCsv();
      if (context.mounted) showSuccess(context, 'Sales exported to $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _exportPdf(BuildContext context, AppState state) async {
    try {
      final path = await state.exportSummaryPdf();
      if (context.mounted) showSuccess(context, 'PDF exported to $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}
