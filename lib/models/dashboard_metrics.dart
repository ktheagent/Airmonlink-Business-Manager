class DashboardMetrics {
  const DashboardMetrics({
    required this.todaySales,
    required this.todayTransactions,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.customerDebt,
    required this.monthExpenses,
    required this.monthGrossProfit,
  });

  final double todaySales;
  final int todayTransactions;
  final int totalProducts;
  final int lowStockProducts;
  final double customerDebt;
  final double monthExpenses;
  final double monthGrossProfit;

  static const empty = DashboardMetrics(
    todaySales: 0,
    todayTransactions: 0,
    totalProducts: 0,
    lowStockProducts: 0,
    customerDebt: 0,
    monthExpenses: 0,
    monthGrossProfit: 0,
  );
}
