$ErrorActionPreference = 'Stop'
$p = 'lib/screens/pos_screen.dart'
$c = Get-Content $p -Raw

$old = "import 'package:flutter/material.dart';"
$new = "import 'dart:io';`n\nimport 'package:flutter/material.dart';"
if (-not $c.Contains($old)) { throw 'Missing import marker' }
$c = $c.Replace($old, $new)

$old = "      showSuccess(context, 'Sale completed. Invoice: $invoice');"
$new = @'
      showSuccess(context, 'Sale completed. Invoice: $invoice');
      try {
        await _printReceipt(invoice, state.businessName, draft);
      } catch (error) {
        if (context.mounted) {
          showFailure(context, 'Sale saved; receipt printing failed: $error');
        }
      }
'@
if (-not $c.Contains($old)) { throw 'Missing sale success marker' }
$c = $c.Replace($old, $new)

$old = '  void _scanBarcode(String value) {'
$new = @'
  Future<void> _printReceipt(
    String invoice,
    String businessName,
    SaleDraft sale,
  ) async {
    final receipt = StringBuffer()
      ..writeln(businessName)
      ..writeln('Airmonlink Business Manager')
      ..writeln('Receipt: $invoice')
      ..writeln('Payment: ${sale.paymentMethod}');
    for (final item in sale.items) {
      receipt.writeln('${item.productName} ${item.quantity.toStringAsFixed(0)} x ${AppFormatters.money(item.unitPrice)} = ${AppFormatters.money(item.total)}');
    }
    receipt
      ..writeln('Subtotal: ${AppFormatters.money(sale.subtotal)}')
      ..writeln('Discount: ${AppFormatters.money(sale.discount)}')
      ..writeln('TOTAL: ${AppFormatters.money(sale.total)}');
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$invoice-receipt.txt');
    await file.writeAsString(receipt.toString(), flush: true);
    final result = await Process.run("notepad.exe", ["/p", file.path]);
    if (result.exitCode != 0) throw StateError('Printer returned ${result.exitCode}');
  }

  void _scanBarcode(String value) {
'@
if (-not $c.Contains($old)) { throw 'Missing barcod method marker' }
$c = $c.Replace($old, $new)

Set-Content $p $c -NoNewline
