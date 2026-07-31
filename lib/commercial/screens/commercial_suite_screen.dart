import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../core/formatters.dart';
import '../../models/product.dart';
import '../../state/app_state.dart';
import '../../widgets/feedback.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pdf_preview_dialog.dart';
import '../models/commercial_models.dart';

class CommercialSuiteScreen extends StatefulWidget {
  const CommercialSuiteScreen({super.key});

  @override
  State<CommercialSuiteScreen> createState() => _CommercialSuiteScreenState();
}

class _CommercialSuiteScreenState extends State<CommercialSuiteScreen> {

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = state.currentUser;
    if (user == null) return const SizedBox.shrink();
    final tabs = <_SuiteTab>[
      const _SuiteTab('Health', Icons.monitor_heart_outlined),
      if (user.can(CommercialPermission.documentsManage))
        const _SuiteTab('Documents', Icons.description_outlined),
      if (user.can(CommercialPermission.debtView))
        const _SuiteTab('Customer debt', Icons.account_balance_wallet_outlined),
      if (user.can(CommercialPermission.purchasingManage))
        const _SuiteTab('Purchasing', Icons.shopping_cart_checkout_outlined),
      if (user.can(CommercialPermission.stockAdjust) ||
          user.can(CommercialPermission.stockCount))
        const _SuiteTab('Inventory', Icons.inventory_outlined),
      if (user.can(CommercialPermission.cashManage) ||
          user.can(CommercialPermission.salesRefund))
        const _SuiteTab('Cash & returns', Icons.point_of_sale_outlined),
      if (user.can(CommercialPermission.staffManage) ||
          user.can(CommercialPermission.branchesManage))
        const _SuiteTab('Staff & branches', Icons.admin_panel_settings_outlined),
      if (user.can(CommercialPermission.backupsManage) ||
          user.can(CommercialPermission.importsManage) ||
          user.can(CommercialPermission.remoteDashboard) ||
          user.can(CommercialPermission.updatesManage))
        const _SuiteTab('Premium tools', Icons.workspace_premium_outlined),
      if (user.can(CommercialPermission.auditView))
        const _SuiteTab('Audit', Icons.manage_search_outlined),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Commercial Suite',
            subtitle:
                'Documents, purchasing, stock control, staff security and premium operations.',
          ),
          const SizedBox(height: 16),
          Card(
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final tab in tabs)
                  Tab(icon: Icon(tab.icon), text: tab.label),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in tabs) _buildTab(tab.label, state, user),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTab(String label, AppState state, StaffUser user) => switch (label) {
        'Health' => _HealthPanel(state: state, user: user),
        'Documents' => _DocumentsPanel(state: state, user: user),
        'Customer debt' => _CustomerDebtPanel(state: state, user: user),
        'Purchasing' => _PurchasingPanel(state: state, user: user),
        'Inventory' => _InventoryPanel(state: state, user: user),
        'Cash & returns' => _CashReturnsPanel(state: state, user: user),
        'Staff & branches' => _StaffBranchesPanel(state: state, user: user),
        'Premium tools' => _PremiumToolsPanel(state: state, user: user),
        'Audit' => _AuditPanel(state: state, user: user),
        _ => const SizedBox.shrink(),
      };
}

class _SuiteTab {
  const _SuiteTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    final consolidated = user.role == StaffRole.owner || user.role == StaffRole.manager;
    return FutureBuilder<BusinessHealthSnapshot>(
      future: state.commercial.businessHealth(
        actor: user,
        consolidated: consolidated,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorCard(snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final health = snapshot.data!;
        final metrics = <(String, double, IconData)>[
          ('Revenue', health.revenue, Icons.payments_outlined),
          ('Gross profit', health.grossProfit, Icons.trending_up),
          ('Expenses', health.expenses, Icons.receipt_long_outlined),
          ('Net profit', health.netProfit, Icons.account_balance_wallet_outlined),
          ('Customer debt', health.customerDebt, Icons.people_outline),
          ('Supplier debt', health.supplierDebt, Icons.local_shipping_outlined),
          ('Cash variance', health.cashVariance, Icons.warning_amber_outlined),
        ];
        return RefreshIndicator(
          onRefresh: state.refreshAll,
          child: ListView(
            children: [
              if (user.can(CommercialPermission.reportsProfit)) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportProfit(context),
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Export profit CSV'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _previewProfit(context),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Profit report'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 130,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  final item = metrics[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$3),
                          const Spacer(),
                          Text(item.$1),
                          Text(
                            AppFormatters.money(item.$2),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operational alerts',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.inventory_2_outlined),
                            label: Text('${health.lowStockCount} low-stock items'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.event_busy_outlined),
                            label: Text('${health.expiringCount} expiring batches'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.undo_outlined),
                            label: Text(
                              '${(health.refundRate * 100).toStringAsFixed(1)}% refund rate',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (final suggestion in health.suggestions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lightbulb_outline),
                          title: Text(suggestion),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _previewProfit(BuildContext context) async {
    final consolidated =
        user.role == StaffRole.owner || user.role == StaffRole.manager;
    await showDialog<void>(
      context: context,
      builder: (_) => AppPdfPreviewDialog(
        title: consolidated
            ? 'Consolidated profit report'
            : 'Branch profit report',
        fileName: 'Airmonlink-Profit-Report.pdf',
        initialPageFormat: PdfPageFormat.a4.landscape,
        pageFormats: {'A4 landscape': PdfPageFormat.a4.landscape},
        canChangeOrientation: false,
        canChangePageFormat: false,
        buildPdf: (_) => state.commercialReports.buildProfitPdf(
          actor: user,
          businessName: state.businessName,
          consolidated: consolidated,
        ),
      ),
    );
  }

  Future<void> _exportProfit(BuildContext context) async {
    try {
      final path = await state.commercialReports.exportProfitCsv(
        actor: user,
        consolidated:
            user.role == StaffRole.owner || user.role == StaffRole.manager,
      );
      if (context.mounted) showSuccess(context, 'Profit report exported: $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}

class _DocumentsPanel extends StatefulWidget {
  const _DocumentsPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  State<_DocumentsPanel> createState() => _DocumentsPanelState();
}

class _DocumentsPanelState extends State<_DocumentsPanel> {
  late Future<List<Map<String, Object?>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.state.commercial.listDocuments(widget.user);
  }

  void reload() => setState(() {
        future = widget.state.commercial.listDocuments(widget.user);
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _createDocument(context),
            icon: const Icon(Icons.add),
            label: const Text('New document'),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorCard(snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const _EmptyState(
                  icon: Icons.description_outlined,
                  message: 'No quotations or invoices yet.',
                );
              }
              return ListView.separated(
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final document = snapshot.data![index];
                  final id = document['id'] as int;
                  final type = (document['document_type'] as String)
                      .replaceAll('_', ' ');
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(type == 'invoice'
                            ? Icons.request_quote_outlined
                            : Icons.description_outlined),
                      ),
                      title: Text('${document['document_no']} • $type'),
                      subtitle: Text(
                        '${document['customer_name'] ?? 'Walk-in customer'} • '
                        '${document['status']} • ${AppFormatters.money((document['total'] as num).toDouble())}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => _documentAction(context, document, value),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'preview', child: Text('Preview / print')),
                          if (document['status'] == 'draft')
                            const PopupMenuItem(value: 'issue', child: Text('Issue document')),
                          if (document['document_type'] == 'quotation' &&
                              document['status'] != 'converted')
                            const PopupMenuItem(value: 'invoice', child: Text('Convert to invoice')),
                          if (document['converted_sale_id'] == null)
                            const PopupMenuItem(value: 'sale', child: Text('Convert to sale')),
                          if (document['document_type'] == 'invoice' &&
                              (document['balance_due'] as num? ?? 0).toDouble() > 0)
                            const PopupMenuItem(value: 'payment', child: Text('Record payment')),
                          if ('${document['customer_phone'] ?? ''}'.isNotEmpty)
                            const PopupMenuItem(value: 'whatsapp', child: Text('Send with WhatsApp')),
                          if ('${document['customer_email'] ?? ''}'.isNotEmpty)
                            const PopupMenuItem(value: 'email', child: Text('Send by email')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createDocument(BuildContext context) async {
    if (widget.state.products.isEmpty) {
      showFailure(context, 'Add a product before creating a document.');
      return;
    }
    var type = 'quotation';
    Product product = widget.state.products.first;
    int? customerId;
    final quantity = TextEditingController(text: '1');
    final discount = TextEditingController(text: '0');
    final notes = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create commercial document'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Document type'),
                  items: const [
                    DropdownMenuItem(value: 'quotation', child: Text('Quotation')),
                    DropdownMenuItem(value: 'estimate', child: Text('Estimate')),
                    DropdownMenuItem(value: 'proforma', child: Text('Pro-forma invoice')),
                    DropdownMenuItem(value: 'invoice', child: Text('Invoice')),
                    DropdownMenuItem(value: 'delivery_note', child: Text('Delivery note')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: customerId,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Walk-in customer')),
                    for (final customer in widget.state.customers)
                      DropdownMenuItem(value: customer.id, child: Text(customer.name)),
                  ],
                  onChanged: (value) => setDialogState(() => customerId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Product>(
                  initialValue: product,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: [
                    for (final item in widget.state.products)
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  ],
                  onChanged: (value) => setDialogState(() => product = value!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: quantity, decoration: const InputDecoration(labelText: 'Quantity'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: discount, decoration: const InputDecoration(labelText: 'Discount'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (created != true || !mounted) return;
    try {
      final qty = double.parse(quantity.text);
      await widget.state.createDocument(
        CommercialDocumentDraft(
          type: type,
          customerId: customerId,
          items: [
            CommercialDocumentItem(
              productId: product.id,
              description: product.name,
              quantity: qty,
              unitPrice: product.sellingPrice,
              costPrice: product.costPrice,
            ),
          ],
          discount: double.tryParse(discount.text) ?? 0,
          tax: 0,
          notes: notes.text,
          terms: 'Prices are valid until the stated date.',
          validUntil: DateTime.now().add(const Duration(days: 14)),
          dueAt: type == 'invoice' ? DateTime.now().add(const Duration(days: 30)) : null,
        ),
      );
      if (!mounted) return;
      showSuccess(context, 'Document created.');
      reload();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _documentAction(
    BuildContext context,
    Map<String, Object?> document,
    String action,
  ) async {
    final id = document['id'] as int;
    try {
      switch (action) {
        case 'preview':
          await showDialog<void>(
            context: context,
            builder: (_) => AppPdfPreviewDialog(
              title: 'Commercial document',
              buildPdf: (_) => widget.state.buildCommercialDocumentPdf(id),
              fileName: 'commercial-document-$id.pdf',
              initialPageFormat: PdfPageFormat.a4,
              pageFormats: const {'A4': PdfPageFormat.a4},
            ),
          );
          break;
        case 'issue':
          await widget.state.commercial.issueDocument(actor: widget.user, documentId: id);
          break;
        case 'invoice':
          await widget.state.commercial.convertQuotationToInvoice(actor: widget.user, quotationId: id);
          break;
        case 'sale':
          await widget.state.commercial.convertDocumentToSale(
            actor: widget.user,
            documentId: id,
            paymentMethod: 'Credit',
            cashSessionId: widget.state.currentCashSession?['id'] as int?,
          );
          break;
        case 'payment':
          final amount = await _askNumber(context, 'Payment amount');
          if (amount == null) return;
          await widget.state.commercial.recordDocumentPayment(
            actor: widget.user,
            documentId: id,
            amount: amount,
            paymentMethod: widget.state.currentCashSession == null ? 'Bank' : 'Cash',
            reference: '',
            cashSessionId: widget.state.currentCashSession?['id'] as int?,
          );
          break;
        case 'whatsapp':
          final path = await widget.state.exportCommercialDocument(id);
          await widget.state.notifications.openWhatsApp(
            phone: '${document['customer_phone']}',
            message:
                'Your ${document['document_type']} ${document['document_no']} is ready. The PDF was saved at $path.',
            documentType: '${document['document_type']}',
            documentId: id,
          );
          break;
        case 'email':
          final password = await widget.state.secureConfig.smtpPassword();
          final host = widget.state.settings['smtp_host'] ?? '';
          final username = widget.state.settings['smtp_username'] ?? '';
          if (host.isEmpty || username.isEmpty || password == null) {
            throw StateError('Configure SMTP settings before sending email.');
          }
          final path = await widget.state.exportCommercialDocument(id);
          await widget.state.notifications.sendEmail(
            host: host,
            port: int.tryParse(widget.state.settings['smtp_port'] ?? '') ?? 587,
            ssl: widget.state.settings['smtp_ssl'] == 'true',
            username: username,
            password: password,
            senderName: widget.state.settings['smtp_sender_name'] ?? widget.state.businessName,
            recipient: '${document['customer_email']}',
            subject: '${document['document_type']} ${document['document_no']}',
            body: 'Please find your document attached.',
            attachmentPath: path,
            documentType: '${document['document_type']}',
            documentId: id,
          );
          break;
      }
      if (!mounted) return;
      await widget.state.refreshAll();
      showSuccess(context, 'Document updated.');
      reload();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
}

class _CustomerDebtPanel extends StatefulWidget {
  const _CustomerDebtPanel({required this.state, required this.user});

  final AppState state;
  final StaffUser user;

  @override
  State<_CustomerDebtPanel> createState() => _CustomerDebtPanelState();
}

class _CustomerDebtPanelState extends State<_CustomerDebtPanel> {
  late Future<List<Map<String, Object?>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.state.commercial.listCustomerAccounts(widget.user);
  }

  void reload() => setState(() {
        future = widget.state.commercial.listCustomerAccounts(widget.user);
      });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _ErrorCard(snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = snapshot.data!;
          if (accounts.isEmpty) {
            return const _EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              message: 'No customer accounts are available in this branch.',
            );
          }
          return Card(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Balance'), numeric: true),
                    DataColumn(label: Text('Overdue'), numeric: true),
                    DataColumn(label: Text('Credit limit'), numeric: true),
                    DataColumn(label: Text('Credit status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: accounts.map((account) {
                    final enabled =
                        (account['credit_enabled'] as num? ?? 1).toInt() == 1;
                    final balance =
                        (account['balance'] as num? ?? 0).toDouble();
                    final overdue =
                        (account['overdue_balance'] as num? ?? 0).toDouble();
                    return DataRow(cells: [
                      DataCell(
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${account['name']}'),
                            if ('${account['phone'] ?? ''}'.isNotEmpty)
                              Text(
                                '${account['phone']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      DataCell(Text(AppFormatters.money(balance))),
                      DataCell(
                        Text(
                          AppFormatters.money(overdue),
                          style: TextStyle(
                            color: overdue > 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                            fontWeight: overdue > 0 ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          AppFormatters.money(
                            (account['credit_limit'] as num? ?? 0).toDouble(),
                          ),
                        ),
                      ),
                      DataCell(
                        Chip(
                          avatar: Icon(
                            enabled ? Icons.check_circle_outline : Icons.block,
                            size: 17,
                          ),
                          label: Text(enabled ? 'Enabled' : 'Blocked'),
                        ),
                      ),
                      DataCell(
                        Wrap(
                          spacing: 4,
                          children: [
                            if (widget.user.can(CommercialPermission.debtPayment))
                              TextButton(
                                onPressed: () => _credit(context, account),
                                child: const Text('Credit'),
                              ),
                            if (balance > 0 &&
                                widget.user.can(CommercialPermission.debtPayment))
                              TextButton(
                                onPressed: () => _payment(context, account),
                                child: const Text('Payment'),
                              ),
                            TextButton(
                              onPressed: () => _statement(context, account),
                              child: const Text('Statement'),
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }).toList(growable: false),
                ),
              ),
            ),
          );
        },
      );

  Future<void> _credit(
    BuildContext context,
    Map<String, Object?> account,
  ) async {
    final limit = TextEditingController(
      text: (account['credit_limit'] as num? ?? 0).toStringAsFixed(2),
    );
    final reason = TextEditingController();
    var enabled = (account['credit_enabled'] as num? ?? 1).toInt() == 1;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Credit settings — ${account['name']}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow credit sales'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                TextField(
                  controller: limit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Credit limit'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason or approval note',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final parsed = double.tryParse(limit.text.trim());
    if (parsed == null || parsed < 0) {
      if (context.mounted) showFailure(context, 'Enter a valid credit limit.');
      return;
    }
    try {
      await widget.state.commercial.setCustomerCredit(
        actor: widget.user,
        customerId: account['id'] as int,
        enabled: enabled,
        creditLimit: parsed,
        reason: reason.text.trim(),
      );
      await widget.state.refreshAll();
      reload();
      if (context.mounted) showSuccess(context, 'Customer credit updated.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _payment(
    BuildContext context,
    Map<String, Object?> account,
  ) async {
    final amount = TextEditingController(
      text: (account['balance'] as num? ?? 0).toStringAsFixed(2),
    );
    final reference = TextEditingController();
    var method = 'Bank';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Record payment — ${account['name']}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    helperText:
                        'Outstanding: ${AppFormatters.money((account['balance'] as num? ?? 0).toDouble())}',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  items: const ['Bank', 'Cash', 'Mobile Money', 'Card']
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => method = value ?? method),
                  decoration: const InputDecoration(labelText: 'Payment method'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(labelText: 'Reference'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final parsed = double.tryParse(amount.text.trim());
    if (parsed == null || parsed <= 0) {
      if (context.mounted) showFailure(context, 'Enter a valid payment amount.');
      return;
    }
    try {
      await widget.state.commercial.recordCustomerPayment(
        actor: widget.user,
        customerId: account['id'] as int,
        amount: parsed,
        paymentMethod: method,
        reference: reference.text.trim(),
        cashSessionId: method == 'Cash'
            ? widget.state.currentCashSession?['id'] as int?
            : null,
      );
      await widget.state.refreshAll();
      reload();
      if (context.mounted) showSuccess(context, 'Customer payment recorded.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _statement(
    BuildContext context,
    Map<String, Object?> account,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AppPdfPreviewDialog(
        title: 'Customer statement — ${account['name']}',
        fileName: 'Customer-Statement-${account['id']}.pdf',
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const {'A4': PdfPageFormat.a4},
        canChangeOrientation: false,
        canChangePageFormat: false,
        buildPdf: (_) => widget.state.commercialDocuments.buildCustomerStatementPdf(
          customerId: account['id'] as int,
          branchId: widget.user.branchId,
          settings: widget.state.settings,
        ),
      ),
    );
  }
}

class _PurchasingPanel extends StatefulWidget {
  const _PurchasingPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  State<_PurchasingPanel> createState() => _PurchasingPanelState();
}

class _PurchasingPanelState extends State<_PurchasingPanel> {
  late Future<List<Map<String, Object?>>> future;
  @override
  void initState() {
    super.initState();
    future = widget.state.commercial.listPurchaseOrders(widget.user);
  }

  void reload() => setState(() => future = widget.state.commercial.listPurchaseOrders(widget.user));

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New purchase order'),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _ErrorCard(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.isEmpty) {
                  return const _EmptyState(icon: Icons.shopping_cart_outlined, message: 'No purchase orders yet.');
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final order = snapshot.data![index];
                    return Card(
                      child: ListTile(
                        title: Text('${order['po_no']} • ${order['supplier_name']}'),
                        subtitle: Text('${order['status']} • ${AppFormatters.money((order['total'] as num).toDouble())} • Balance ${AppFormatters.money((order['balance_due'] as num).toDouble())}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _action(context, order, value),
                          itemBuilder: (_) => [
                            if (order['status'] != 'received' && order['status'] != 'cancelled')
                              const PopupMenuItem(value: 'receive', child: Text('Receive outstanding stock')),
                            const PopupMenuItem(value: 'pay', child: Text('Record supplier payment')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );

  Future<void> _create(BuildContext context) async {
    if (widget.state.suppliers.isEmpty || widget.state.products.isEmpty) {
      showFailure(context, 'Add a supplier and product first.');
      return;
    }
    final supplier = widget.state.suppliers.first;
    final product = widget.state.products.first;
    final quantity = await _askNumber(context, 'Order quantity');
    if (quantity == null) return;
    try {
      await widget.state.commercial.createPurchaseOrder(
        actor: widget.user,
        supplierId: supplier.id!,
        items: [
          {
            'product_id': product.id,
            'description': product.name,
            'quantity': quantity,
            'unit_cost': product.costPrice,
            'tax_rate': 0.0,
          },
        ],
      );
      if (mounted) {
        showSuccess(context, 'Purchase order created.');
        reload();
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _action(BuildContext context, Map<String, Object?> order, String action) async {
    try {
      final id = order['id'] as int;
      if (action == 'receive') {
        final items = await widget.state.commercial.purchaseOrderItems(actor: widget.user, purchaseOrderId: id);
        final quantities = <int, double>{};
        for (final item in items) {
          final outstanding = (item['ordered_qty'] as num).toDouble() - (item['received_qty'] as num).toDouble();
          if (outstanding > 0) quantities[item['id'] as int] = outstanding;
        }
        await widget.state.commercial.receivePurchaseOrder(
          actor: widget.user,
          purchaseOrderId: id,
          quantitiesByItemId: quantities,
        );
      } else {
        final amount = await _askNumber(context, 'Supplier payment amount');
        if (amount == null) return;
        await widget.state.commercial.recordSupplierPayment(
          actor: widget.user,
          supplierId: order['supplier_id'] as int,
          purchaseOrderId: id,
          amount: amount,
          paymentMethod: widget.state.currentCashSession == null ? 'Bank' : 'Cash',
          reference: '',
          cashSessionId: widget.state.currentCashSession?['id'] as int?,
        );
      }
      await widget.state.refreshAll();
      if (mounted) {
        showSuccess(context, 'Purchase record updated.');
        reload();
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
        future: user.can(CommercialPermission.reportsView)
            ? state.commercial.lowStockSuggestions(user)
            : Future.value(const []),
        builder: (context, snapshot) => ListView(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (user.can(CommercialPermission.stockAdjust))
                  _ActionCard(
                    icon: Icons.tune,
                    title: 'Stock adjustment',
                    subtitle: 'Record damaged, expired, missing or corrected stock.',
                    onPressed: () => _adjust(context),
                  ),
                if (user.can(CommercialPermission.stockCount))
                  _ActionCard(
                    icon: Icons.fact_check_outlined,
                    title: 'Physical stock count',
                    subtitle: 'Freeze expected quantities, count and approve discrepancies.',
                    onPressed: () => _count(context),
                  ),
                _ActionCard(
                  icon: Icons.qr_code_2,
                  title: 'Barcode labels',
                  subtitle: 'Generate printable Code 128, EAN or UPC labels.',
                  onPressed: () => _labels(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Low-stock purchasing suggestions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (snapshot.hasError) _ErrorCard(snapshot.error!),
            if (!snapshot.hasData) const Center(child: CircularProgressIndicator()),
            for (final item in snapshot.data ?? const <Map<String, Object?>>[])
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(item['name'] as String),
                  subtitle: Text('Stock ${item['stock_qty']} • Reorder level ${item['low_stock_level']}'),
                  trailing: Text('Suggested ${item['suggested_quantity']}'),
                ),
              ),
          ],
        ),
      );

  Future<void> _adjust(BuildContext context) async {
    if (state.products.isEmpty) return;
    final amount = await _askNumber(context, 'Quantity change (use negative to reduce)');
    if (amount == null) return;
    try {
      await state.commercial.adjustStock(
        actor: user,
        productId: state.products.first.id!,
        quantityChange: amount,
        reason: amount < 0 ? 'Damaged' : 'Correction',
        note: 'Commercial Suite adjustment',
      );
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Stock adjusted.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _count(BuildContext context) async {
    try {
      final id = await state.commercial.startStockCount(actor: user, notes: 'Physical count');
      final items = await state.commercial.stockCountItems(actor: user, stockCountId: id);
      for (final item in items) {
        await state.commercial.saveStockCountQuantity(
          actor: user,
          stockCountId: id,
          productId: item['product_id'] as int,
          countedQuantity: (item['expected_qty'] as num).toDouble(),
        );
      }
      await state.commercial.approveStockCount(actor: user, stockCountId: id);
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Stock count created and approved with current quantities.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _labels(BuildContext context) async {
    if (state.products.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AppPdfPreviewDialog(
        title: 'Barcode labels',
        buildPdf: (_) => state.buildBarcodeLabels(state.products.take(30).toList()),
        fileName: 'barcode-labels.pdf',
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const {'A4': PdfPageFormat.a4},
      ),
    );
  }
}

class _CashReturnsPanel extends StatefulWidget {
  const _CashReturnsPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  State<_CashReturnsPanel> createState() => _CashReturnsPanelState();
}

class _CashReturnsPanelState extends State<_CashReturnsPanel> {
  @override
  Widget build(BuildContext context) {
    final session = widget.state.currentCashSession;
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.point_of_sale, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session == null ? 'No open cash session' : 'Cash session is open', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(session == null ? 'Open a shift before accepting cash.' : 'Opening float: ${AppFormatters.money((session['opening_float'] as num).toDouble())}'),
                    ],
                  ),
                ),
                if (widget.user.can(CommercialPermission.cashManage))
                  FilledButton(
                    onPressed: session == null ? () => _open(context) : () => _close(context),
                    child: Text(session == null ? 'Open shift' : 'Close shift'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.user.can(CommercialPermission.salesRefund))
          _ActionCard(
            icon: Icons.assignment_return_outlined,
            title: 'Return and refund',
            subtitle: 'Return full or partial quantities and restore sale-linked stock.',
            onPressed: () => _return(context),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final float = await _askNumber(context, 'Opening cash float');
    if (float == null) return;
    try {
      final registers = await widget.state.commercial.listCashRegisters(widget.user);
      if (registers.isEmpty) throw StateError('No cash register is configured.');
      await widget.state.commercial.openCashSession(
        actor: widget.user,
        registerId: registers.first['id'] as int,
        openingFloat: float,
      );
      await widget.state.refreshAll();
      if (mounted) showSuccess(context, 'Cash shift opened.');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _close(BuildContext context) async {
    final actual = await _askNumber(context, 'Actual cash counted');
    if (actual == null) return;
    try {
      final result = await widget.state.commercial.closeCashSession(
        actor: widget.user,
        cashSessionId: widget.state.currentCashSession!['id'] as int,
        actualCash: actual,
        note: '',
      );
      await widget.state.refreshAll();
      if (mounted) showSuccess(context, 'Shift closed. Variance: ${AppFormatters.money(result['variance']!)}');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _return(BuildContext context) async {
    final completed = widget.state.sales;
    if (completed.isEmpty) {
      showFailure(context, 'No completed sale is available for return.');
      return;
    }
    try {
      final sale = completed.first;
      final items = await widget.state.commercial.returnableSaleItems(actor: widget.user, saleId: sale.id!);
      final item = items.cast<Map<String, Object?>>().firstWhere(
        (row) => (row['returnable_quantity'] as num).toDouble() > 0,
      );
      final quantity = await _askNumber(context, 'Return quantity');
      if (quantity == null) return;
      await widget.state.commercial.createReturn(
        actor: widget.user,
        saleId: sale.id!,
        quantitiesBySaleItemId: {item['id'] as int: quantity},
        refundMethod: widget.state.currentCashSession == null ? 'Store credit' : 'Cash',
        reason: 'Customer return',
        restock: true,
        cashSessionId: widget.state.currentCashSession?['id'] as int?,
      );
      await widget.state.refreshAll();
      if (mounted) showSuccess(context, 'Return recorded.');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
}

class _StaffBranchesPanel extends StatelessWidget {
  const _StaffBranchesPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (user.can(CommercialPermission.staffManage))
                _ActionCard(
                  icon: Icons.person_add_alt_1,
                  title: 'Add staff account',
                  subtitle: 'Assign a secure role and branch.',
                  onPressed: () => _addStaff(context),
                ),
              if (user.can(CommercialPermission.branchesManage))
                _ActionCard(
                  icon: Icons.add_business_outlined,
                  title: 'Add branch',
                  subtitle: 'Create separate inventory, staff and cash register.',
                  onPressed: () => _addBranch(context),
                ),
              if (user.can(CommercialPermission.branchesManage))
                _ActionCard(
                  icon: Icons.swap_horiz,
                  title: 'Transfer stock',
                  subtitle: 'Dispatch stock to another branch and receive it once.',
                  onPressed: () => _createTransfer(context),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Branches', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          for (final branch in state.branches)
            Card(child: ListTile(leading: const Icon(Icons.store_outlined), title: Text(branch.name), subtitle: Text('${branch.code} • ${branch.address}'))),
          if (user.can(CommercialPermission.branchesManage)) ...[
            const SizedBox(height: 16),
            Text(
              'Stock transfers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            FutureBuilder<List<Map<String, Object?>>>(
              future: state.commercial.listStockTransfers(user),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _ErrorCard(snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No branch stock transfers yet.'),
                  );
                }
                return Column(
                  children: [
                    for (final transfer in snapshot.data!)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(
                            '${transfer['transfer_no']} • ${transfer['source_branch_name']} → ${transfer['destination_branch_name']}',
                          ),
                          subtitle: Text('${transfer['status']} • ${transfer['notes'] ?? ''}'),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              if (transfer['status'] == 'draft' &&
                                  transfer['source_branch_id'] == user.branchId)
                                TextButton(
                                  onPressed: () => _transferAction(
                                    context,
                                    transfer['id'] as int,
                                    receive: false,
                                  ),
                                  child: const Text('Dispatch'),
                                ),
                              if (transfer['status'] == 'dispatched' &&
                                  transfer['destination_branch_id'] == user.branchId)
                                TextButton(
                                  onPressed: () => _transferAction(
                                    context,
                                    transfer['id'] as int,
                                    receive: true,
                                  ),
                                  child: const Text('Receive'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          if (user.can(CommercialPermission.staffManage)) ...[
            const SizedBox(height: 16),
            FutureBuilder<List<StaffUser>>(
              future: state.commercial.listStaff(user),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _ErrorCard(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Staff', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    for (final staff in snapshot.data!)
                      Card(child: ListTile(leading: const Icon(Icons.badge_outlined), title: Text(staff.name), subtitle: Text('${staff.role.label} • ${staff.username} • ${staff.isActive ? 'Active' : 'Disabled'}'))),
                  ],
                );
              },
            ),
          ],
        ],
      );

  Future<void> _createTransfer(BuildContext context) async {
    final destinations = state.branches
        .where((branch) => branch.isActive && branch.id != user.branchId)
        .toList(growable: false);
    if (destinations.isEmpty || state.products.isEmpty) {
      showFailure(context, 'Add another branch and at least one product first.');
      return;
    }
    var destinationId = destinations.first.id;
    var productId = state.products.first.id!;
    final quantity = TextEditingController(text: '1');
    final notes = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create stock transfer'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: destinationId,
                  decoration: const InputDecoration(labelText: 'Destination branch'),
                  items: destinations
                      .map((branch) => DropdownMenuItem<int>(
                            value: branch.id,
                            child: Text(branch.name),
                          ))
                      .toList(growable: false),
                  onChanged: (value) => setDialogState(
                    () => destinationId = value ?? destinationId,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: state.products
                      .where((product) => product.id != null)
                      .map((product) => DropdownMenuItem<int>(
                            value: product.id,
                            child: Text(product.name),
                          ))
                      .toList(growable: false),
                  onChanged: (value) => setDialogState(
                    () => productId = value ?? productId,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Transfer notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create draft'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final parsed = double.tryParse(quantity.text.trim());
    if (parsed == null || parsed <= 0) {
      if (context.mounted) showFailure(context, 'Enter a valid transfer quantity.');
      return;
    }
    try {
      await state.commercial.createStockTransfer(
        actor: user,
        destinationBranchId: destinationId,
        quantitiesByProductId: {productId: parsed},
        notes: notes.text.trim(),
      );
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Stock-transfer draft created.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _transferAction(
    BuildContext context,
    int transferId, {
    required bool receive,
  }) async {
    try {
      if (receive) {
        await state.commercial.receiveStockTransfer(
          actor: user,
          transferId: transferId,
        );
      } else {
        await state.commercial.dispatchStockTransfer(
          actor: user,
          transferId: transferId,
        );
      }
      await state.refreshAll();
      if (context.mounted) {
        showSuccess(
          context,
          receive ? 'Stock transfer received.' : 'Stock transfer dispatched.',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _addStaff(BuildContext context) async {
    final name = TextEditingController();
    final username = TextEditingController();
    final pin = TextEditingController();
    var role = StaffRole.cashier;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add staff account'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 10),
                TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 10),
                TextField(controller: pin, obscureText: true, decoration: const InputDecoration(labelText: 'PIN')),
                const SizedBox(height: 10),
                DropdownButtonFormField<StaffRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [for (final value in StaffRole.values) if (value != StaffRole.owner) DropdownMenuItem(value: value, child: Text(value.label))],
                  onChanged: (value) => setState(() => role = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await state.commercial.createStaff(
        actor: user,
        branchId: user.branchId,
        name: name.text,
        username: username.text,
        pin: pin.text,
        role: role,
      );
      if (context.mounted) showSuccess(context, 'Staff account created.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _addBranch(BuildContext context) async {
    final name = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add branch'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Branch name')),
              const SizedBox(height: 10),
              TextField(controller: code, decoration: const InputDecoration(labelText: 'Branch code')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.commercial.createBranch(actor: user, name: name.text, code: code.text);
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Branch created.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}

class _PremiumToolsPanel extends StatelessWidget {
  const _PremiumToolsPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (user.can(CommercialPermission.backupsManage)) ...[
                _ActionCard(icon: Icons.enhanced_encryption_outlined, title: 'Encrypted backup', subtitle: 'Create an AES-GCM protected database backup.', onPressed: () => _backup(context)),
                _ActionCard(icon: Icons.restore_outlined, title: 'Restore backup', subtitle: 'Verify, restore and roll back safely if integrity checks fail.', onPressed: () => _restore(context)),
                _ActionCard(icon: Icons.schedule_outlined, title: 'Automatic backup', subtitle: 'Store the encryption password securely and run daily catch-up backups.', onPressed: () => _automaticBackup(context)),
                _ActionCard(icon: Icons.cloud_upload_outlined, title: 'Cloud backup', subtitle: 'Upload an encrypted backup to an HTTPS WebDAV destination.', onPressed: () => _cloudBackup(context)),
              ],
              if (user.can(CommercialPermission.importsManage))
                _ActionCard(icon: Icons.upload_file_outlined, title: 'Import data', subtitle: 'Import products, customers, suppliers or opening stock from CSV/XLSX.', onPressed: () => _import(context)),
              if (user.can(CommercialPermission.remoteDashboard))
                _ActionCard(icon: Icons.phone_android_outlined, title: 'Remote owner dashboard', subtitle: 'Start a read-only, token-protected local network dashboard.', onPressed: () => _remote(context)),
              if (user.can(CommercialPermission.updatesManage))
                _ActionCard(icon: Icons.system_update_alt, title: 'Secure update check', subtitle: 'Verify release metadata and SHA-256 before download.', onPressed: () => _updates(context)),
              if (user.can(CommercialPermission.expensesManage))
                _ActionCard(icon: Icons.event_repeat_outlined, title: 'Recurring expense', subtitle: 'Schedule rent, utilities, salaries and subscriptions.', onPressed: () => _recurring(context)),
            ],
          ),
        ],
      );

  Future<void> _backup(BuildContext context) async {
    final password = await _askText(context, 'Backup password', obscure: true);
    if (password == null || password.isEmpty) return;
    try {
      final path = await state.createEncryptedBackup(password);
      if (context.mounted) showSuccess(context, 'Encrypted backup created: $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['abmbackup'],
      );
      final path = selection?.files.single.path;
      if (path == null) return;
      final password = await _askText(
        context,
        'Backup password',
        obscure: true,
      );
      if (password == null || password.isEmpty) return;
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore encrypted backup?'),
          content: const Text(
            'A safety copy of the current database will be created first. '
            'After a successful restore, the application will lock so the restored staff data can be loaded safely.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await state.restoreEncryptedBackup(path, password);
      if (context.mounted) {
        showSuccess(context, 'Backup restored. Sign in using the restored staff account.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _automaticBackup(BuildContext context) async {
    final password = await _askText(
      context,
      'Automatic-backup password',
      obscure: true,
    );
    if (password == null || password.isEmpty) return;
    try {
      await state.enableAutomaticBackup(password: password, intervalHours: 24);
      if (context.mounted) {
        showSuccess(context, 'Daily encrypted backup is enabled.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _cloudBackup(BuildContext context) async {
    final endpointText = await _askText(context, 'HTTPS WebDAV folder URL');
    if (endpointText == null || endpointText.isEmpty) return;
    final username = await _askText(context, 'WebDAV username');
    if (username == null) return;
    final password = await _askText(context, 'WebDAV password', obscure: true);
    if (password == null) return;
    final backupPassword = await _askText(
      context,
      'Encryption password for this backup',
      obscure: true,
    );
    if (backupPassword == null) return;
    try {
      final backupPath = await state.createEncryptedBackup(backupPassword);
      await state.secureConfig.saveWebDavPassword(password);
      await state.uploadWebDavBackup(
        backupPath: backupPath,
        endpoint: Uri.parse(endpointText),
        username: username,
        password: password,
      );
      if (context.mounted) showSuccess(context, 'Encrypted cloud backup uploaded.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx']);
      final path = result?.files.single.path;
      if (path == null) return;
      final type = await _chooseImportType(context);
      if (type == null) return;
      final imported = await state.imports.importFile(
        actor: user,
        path: path,
        importType: type,
      );
      await state.refreshAll();
      if (context.mounted) {
        showSuccess(
          context,
          'Imported ${imported.importedRows} rows; skipped ${imported.skippedRows}; failed ${imported.failedRows}.',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _remote(BuildContext context) async {
    try {
      final url = await state.startRemoteDashboard();
      if (context.mounted) showSuccess(context, 'Remote dashboard started at $url');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _updates(BuildContext context) async {
    final text = await _askText(context, 'HTTPS update manifest URL');
    if (text == null || text.isEmpty) return;
    try {
      final info = await state.updates.check(Uri.parse(text));
      if (context.mounted) showSuccess(context, info.isNewer ? 'Update ${info.availableVersion} is available.' : 'This installation is up to date.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _recurring(BuildContext context) async {
    final amount = await _askNumber(context, 'Recurring expense amount');
    if (amount == null) return;
    try {
      await state.commercial.createRecurringExpense(
        actor: user,
        title: 'Monthly operating expense',
        category: 'Operations',
        amount: amount,
        frequency: 'monthly',
        startDate: DateTime.now().add(const Duration(days: 30)),
        paymentMethod: 'Bank',
      );
      if (context.mounted) showSuccess(context, 'Recurring expense scheduled.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}

class _AuditPanel extends StatelessWidget {
  const _AuditPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AuditEntry>>(
        future: state.commercial.listAudit(actor: user),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _ErrorCard(snapshot.error!);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return const _EmptyState(icon: Icons.manage_search_outlined, message: 'No audit entries yet.');
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final entry = snapshot.data![index];
              return Card(
                child: ListTile(
                  leading: Icon(entry.success ? Icons.check_circle_outline : Icons.error_outline),
                  title: Text(entry.action.replaceAll('.', ' › ')),
                  subtitle: Text('${entry.userName ?? 'System'} • ${entry.branchName ?? ''} • ${entry.createdAt.toLocal()}\n${entry.reason}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onPressed});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 330,
        child: Card(
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 32),
                  const SizedBox(height: 14),
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(subtitle),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerRight, child: Icon(Icons.arrow_forward)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.error);
  final Object error;
  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(error.toString()),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 56), const SizedBox(height: 12), Text(message)],
        ),
      );
}

Future<double?> _askNumber(BuildContext context, String label) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continue')),
      ],
    ),
  );
  return value == null ? null : double.tryParse(value.trim());
}

Future<String?> _askText(BuildContext context, String label, {bool obscure = false}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(controller: controller, obscureText: obscure, autofocus: true, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continue')),
      ],
    ),
  );
}

Future<String?> _chooseImportType(BuildContext context) => showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Import data type'),
        children: [
          for (final value in const ['products', 'customers', 'suppliers', 'opening_stock'])
            SimpleDialogOption(onPressed: () => Navigator.pop(context, value), child: Text(value.replaceAll('_', ' '))),
        ],
      ),
    );
