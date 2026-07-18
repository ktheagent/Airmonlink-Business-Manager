$path = 'lib/services/receipt_service.dart'
$content = @'
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/app_constants.dart';
import '../core/formatters.dart';
import '../models/sale.dart';

class ReceiptService {
  Future<void> printSale({
    required String invoice,
    required String businessName,
    required SaleDraft sale,
  }) async {
    final document = pw.Document();
    final printedAt =
        DateTime.now().toLocal().toString().split('.').first;
'@
Set-Content $path $content -NoNewline
