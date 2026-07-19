import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class AppPdfPreviewDialog extends StatelessWidget {
  const AppPdfPreviewDialog({
    required this.title,
    required this.buildPdf,
    required this.fileName,
    required this.initialPageFormat,
    required this.pageFormats,
    this.canChangeOrientation = true,
    this.canChangePageFormat = true,
    this.dynamicLayout = true,
    this.forceCustomPrintPaper = false,
    super.key,
  });

  final String title;
  final LayoutCallback buildPdf;
  final String fileName;
  final PdfPageFormat initialPageFormat;
  final Map<String, PdfPageFormat> pageFormats;
  final bool canChangeOrientation;
  final bool canChangePageFormat;
  final bool dynamicLayout;
  final bool forceCustomPrintPaper;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1000,
        height: 760,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.print_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _print(context),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: buildPdf,
                initialPageFormat: initialPageFormat,
                pageFormats: pageFormats,
                pdfFileName: fileName,
                allowPrinting: false,
                allowSharing: false,
                canChangeOrientation: canChangeOrientation,
                canChangePageFormat: canChangePageFormat,
                canDebug: false,
                dynamicLayout: dynamicLayout,
                maxPageWidth: 760,
                onError: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'The print preview could not be generated.\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _print(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        onLayout: buildPdf,
        name: fileName,
        format: initialPageFormat,
        dynamicLayout: dynamicLayout,
        usePrinterSettings: true,
        forceCustomPrintPaper: forceCustomPrintPaper,
        windowsModernDialog: true,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printing failed: $error')),
      );
    }
  }
}
