import 'package:file_picker/file_picker.dart';
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
  final email = TextEditingController();
  final website = TextEditingController();
  final taxNumber = TextEditingController();
  final registrationNumber = TextEditingController();
  final paymentInstructions = TextEditingController();
  final documentFooter = TextEditingController();
  final logoPath = TextEditingController();
  final smtpHost = TextEditingController();
  final smtpPort = TextEditingController(text: '587');
  final smtpUsername = TextEditingController();
  final smtpSenderName = TextEditingController();
  final smtpPassword = TextEditingController();
  bool smtpSsl = false;
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final settings = AppStateScope.of(context).settings;
    businessName.text = settings['business_name'] ?? 'My Business';
    phone.text = settings['business_phone'] ?? '';
    address.text = settings['business_address'] ?? '';
    email.text = settings['business_email'] ?? '';
    website.text = settings['business_website'] ?? '';
    taxNumber.text = settings['business_tax_number'] ?? '';
    registrationNumber.text = settings['business_registration_number'] ?? '';
    paymentInstructions.text = settings['payment_instructions'] ?? '';
    documentFooter.text =
        settings['document_footer'] ?? 'Thank you for your business.';
    logoPath.text = settings['business_logo_path'] ?? '';
    smtpHost.text = settings['smtp_host'] ?? '';
    smtpPort.text = settings['smtp_port'] ?? '587';
    smtpUsername.text = settings['smtp_username'] ?? '';
    smtpSenderName.text = settings['smtp_sender_name'] ?? businessName.text;
    smtpSsl = settings['smtp_ssl'] == 'true';
    initialized = true;
  }

  @override
  void dispose() {
    for (final controller in [
      businessName,
      phone,
      address,
      email,
      website,
      taxNumber,
      registrationNumber,
      paymentInstructions,
      documentFooter,
      logoPath,
      smtpHost,
      smtpPort,
      smtpUsername,
      smtpSenderName,
      smtpPassword,
    ]) {
      controller.dispose();
    }
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
          subtitle:
              'Configure branding, professional documents and protected local records.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business identity and document branding',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _field(businessName, 'Business name'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(phone, 'Phone number')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(email, 'Email address')),
                  ],
                ),
                const SizedBox(height: 12),
                _field(address, 'Address', maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(website, 'Website')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(taxNumber, 'Tax number')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        registrationNumber,
                        'Registration number',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: logoPath,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Business logo file',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _selectLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Choose logo'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  paymentInstructions,
                  'Bank, mobile-money and payment instructions',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _field(documentFooter, 'Document footer', maxLines: 2),
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
                  'Email delivery',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(smtpHost, 'SMTP host')),
                    const SizedBox(width: 12),
                    SizedBox(width: 120, child: _field(smtpPort, 'Port')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(smtpUsername, 'SMTP username')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(smtpSenderName, 'Sender name')),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: smtpPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'SMTP password (stored securely)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: smtpSsl,
                  onChanged: (value) => setState(() => smtpSsl = value),
                  title: const Text('Use direct SSL'),
                  subtitle: const Text('Leave off for STARTTLS on port 587.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _backup(context, state),
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Create database backup'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _printerTest(context, state),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Open printer test'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppConstants.appName),
            subtitle: Text(
              'Version ${AppConstants.version}\nOffline-first premium Windows business management software.',
            ),
            isThreeLine: true,
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) => TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      );

  Future<void> _selectLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => logoPath.text = path);
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
        'business_email': email.text.trim(),
        'business_website': website.text.trim(),
        'business_tax_number': taxNumber.text.trim(),
        'business_registration_number': registrationNumber.text.trim(),
        'payment_instructions': paymentInstructions.text.trim(),
        'document_footer': documentFooter.text.trim(),
        'business_logo_path': logoPath.text.trim(),
        'smtp_host': smtpHost.text.trim(),
        'smtp_port': smtpPort.text.trim(),
        'smtp_username': smtpUsername.text.trim(),
        'smtp_sender_name': smtpSenderName.text.trim(),
        'smtp_ssl': smtpSsl.toString(),
      });
      if (smtpPassword.text.isNotEmpty) {
        await state.secureConfig.saveSmtpPassword(smtpPassword.text);
        smtpPassword.clear();
      }
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
