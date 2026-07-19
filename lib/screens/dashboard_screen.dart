import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final metrics = state.metrics;
    final lowStock = state.products
        .where((product) => product.isLowStock)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Executive dashboard',
          subtitle: 'Live overview for ${state.businessName}',
          actions: [
            Tooltip(
              message: 'Refresh dashboard data',
              child: OutlinedButton.icon(
                onPressed: state.refreshAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 700
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 14)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Today sales',
                    value: AppFormatters.money(metrics.todaySales),
                    icon: Icons.point_of_sale,
                    subtitle: '${metrics.todayTransactions} transactions',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Monthly gross profit',
                    value: AppFormatters.money(metrics.monthGrossProfit),
                    icon: Icons.trending_up,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Monthly expenses',
                    value: AppFormatters.money(metrics.monthExpenses),
                    icon: Icons.receipt_long,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Customer credit outstanding',
                    value: AppFormatters.money(metrics.customerDebt),
                    icon: Icons.account_balance_wallet_outlined,
                    warning: metrics.customerDebt > 0,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    title: 'Low-stock products',
                    value: '${metrics.lowStockProducts}',
                    icon: Icons.warning_amber_rounded,
                    warning: metrics.lowStockProducts > 0,
                    subtitle: '${metrics.totalProducts} products registered',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low-stock attention',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F2A5A),
                  ),
                ),
                const SizedBox(height: 14),
                if (lowStock.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'All products are above their low-stock levels.',
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Available'), numeric: true),
                        DataColumn(label: Text('Alert level'), numeric: true),
                        DataColumn(label: Text('Selling price'), numeric: true),
                      ],
                      rows: lowStock.take(10).map((product) {
                        return DataRow(
                          cells: [
                            DataCell(Text(product.name)),
                            DataCell(Text(product.category)),
                            DataCell(Text(product.stockQty.toStringAsFixed(1))),
                            DataCell(
                              Text(product.lowStockLevel.toStringAsFixed(1)),
                            ),
                            DataCell(
                              Text(AppFormatters.money(product.sellingPrice)),
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
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent sales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F2A5A),
                  ),
                ),
                const SizedBox(height: 14),
                if (state.sales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text('No sales have been recorded yet.'),
                    ),
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
                      ],
                      rows: state.sales.take(8).map((sale) {
                        return DataRow(
                          cells: [
                            DataCell(Text(sale.invoiceNo)),
                            DataCell(
                              Text(AppFormatters.dateTime(sale.createdAt)),
                            ),
                            DataCell(Text(sale.paymentMethod)),
                            DataCell(Text(AppFormatters.money(sale.total))),
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
}
