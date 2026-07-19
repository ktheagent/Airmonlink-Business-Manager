import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../core/app_constants.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/page_header.dart';
import '../widgets/pdf_preview_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final businessName = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final state = AppStateScope.of(context);
    businessName.text = state.settings['business_name'] ?? 'My Business';
    phone.text = state.settings['business_phone'] ?? '';
    address.text = state.settings['business_address'] ?? '';
    initialized = true;
  }

  @override
  void dispose() {
    businessName.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Business settings',
          subtitle: 'Configure business identity and protect local records.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: businessName,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _save(context, state),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Database backup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a timestamped copy of the complete local database in your Documents folder. Keep additional copies on an external drive or secure cloud storage.',
                ),
                const SizedBox(height: 16),
                Tooltip(
                  message: 'Create a database backup',
                  child: FilledButton.tonalIcon(
                    onPressed: () => _backup(context, state),
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Create database backup'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printer test',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preview and print a high-contrast test page before using receipts or reports. The preview must show text and two test bars before you send it to the printer.',
                ),
                const SizedBox(height: 16),
                Tooltip(
                  message: 'Open printer test preview',
                  child: FilledButton.tonalIcon(
                    onPressed: () => _printerTest(context, state),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Open printer test'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(AppConstants.appName),
            subtitle: const Text(
              'Version ${AppConstants.version}\nOffline-first Windows business management software.',
            ),
            isThreeLine: true,
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, AppState state) async {
    if (businessName.text.trim().isEmpty) {
      showFailure(context, 'Business name is required.');
      return;
    }
    try {
      await state.saveSettings({
        'business_name': businessName.text.trim(),
        'business_phone': phone.text.trim(),
        'business_address': address.text.trim(),
      });
      if (context.mounted) showSuccess(context, 'Business settings saved.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _backup(BuildContext context, AppState state) async {
    try {
      final path = await state.createBackup();
      if (context.mounted) showSuccess(context, 'Backup created at $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _printerTest(BuildContext context, AppState state) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AppPdfPreviewDialog(
        title: 'Printer test page',
        buildPdf: state.buildPrinterTestPdf,
        fileName: 'airmonlink-printer-test.pdf',
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const {
          'A4': PdfPageFormat.a4,
          'Letter': PdfPageFormat.letter,
        },
      ),
    );
  }
}
