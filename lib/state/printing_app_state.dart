import '../models/sale.dart';
import '../services/database_service.dart';
import '../services/receipt_service.dart';
import 'app_state.dart';

class PrintingAppState extends AppState {
  PrintingAppState() : super();

  String? lastPrintError;

  @override
  Future<String> completeSale(SaleDraft draft) async {
    final invoice = await super.completeSale(draft);
    try {
      final sale = sales.firstWhere((entry) => entry.invoiceNo == invoice);
      await ReceiptService(DatabaseService.instance).printSale(sale, settings);
      lastPrintError = null;
    } catch (error) {
      lastPrintError = error.toString();
      notifyListeners();
    }
    return invoice;
  }
}
