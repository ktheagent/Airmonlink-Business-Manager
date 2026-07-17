import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/contact.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/page_header.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({required this.type, super.key});

  final ContactType type;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isCustomer = type == ContactType.customer;
    final contacts = isCustomer ? state.customers : state.suppliers;
    final title = isCustomer ? 'Customers' : 'Suppliers';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: title,
            subtitle: isCustomer
                ? 'Maintain customer details and outstanding balances.'
                : 'Maintain supplier details and payable balances.',
            actions: [
              FilledButton.icon(
                onPressed: () => _addContact(context, state),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(isCustomer ? 'Add customer' : 'Add supplier'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Card(
              child: contacts.isEmpty
                  ? Center(child: Text('No ${title.toLowerCase()} have been added yet.'))
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Phone')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Balance'), numeric: true),
                            DataColumn(label: Text('Added')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: contacts.map((contact) {
                            return DataRow(
                              cells: [
                                DataCell(Text(contact.name)),
                                DataCell(Text(contact.phone.isEmpty ? '—' : contact.phone)),
                                DataCell(Text(contact.email.isEmpty ? '—' : contact.email)),
                                DataCell(Text(AppFormatters.money(contact.balance))),
                                DataCell(Text(AppFormatters.date(contact.createdAt))),
                                DataCell(
                                  contact.balance <= 0
                                      ? const Text('—')
                                      : TextButton(
                                          onPressed: () => _recordPayment(
                                            context,
                                            state,
                                            contact,
                                          ),
                                          child: const Text('Record payment'),
                                        ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordPayment(
    BuildContext context,
    AppState state,
    BusinessContact contact,
  ) async {
    final amount = TextEditingController(
      text: contact.balance.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          type == ContactType.customer
              ? 'Record payment from ${contact.name}'
              : 'Record payment to ${contact.name}',
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment amount',
                helperText: 'Outstanding: ${AppFormatters.money(contact.balance)}',
              ),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                if (parsed > contact.balance) return 'Payment exceeds the balance';
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (submit != true || !context.mounted) return;
    try {
      await state.recordContactPayment(
        contact,
        double.parse(amount.text.trim()),
      );
      if (context.mounted) showSuccess(context, 'Payment recorded successfully.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _addContact(BuildContext context, AppState state) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final balance = TextEditingController(text: '0.00');
    final formKey = GlobalKey<FormState>();

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == ContactType.customer ? 'Add customer' : 'Add supplier'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: balance,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: type == ContactType.customer
                        ? 'Opening amount owed'
                        : 'Opening amount payable',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    return parsed == null || parsed < 0 ? 'Enter a valid amount' : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (submit != true || !context.mounted) return;
    try {
      await state.addContact(
        BusinessContact(
          id: null,
          type: type,
          name: name.text.trim(),
          phone: phone.text.trim(),
          email: email.text.trim(),
          balance: double.parse(balance.text.trim()),
          createdAt: DateTime.now(),
        ),
      );
      if (context.mounted) showSuccess(context, 'Contact saved successfully.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}
