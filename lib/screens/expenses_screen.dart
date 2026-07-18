import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/expense.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/page_header.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final total = state.expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Expenses',
            subtitle: 'Record operating costs for more realistic profit reporting.',
            actions: [
              FilledButton.icon(
                onPressed: () => _addExpense(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Record expense'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 12),
                  const Text('All recorded expenses'),
                  const Spacer(),
                  Text(
                    AppFormatters.money(total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              child: state.expenses.isEmpty
                  ? const Center(child: Text('No expenses have been recorded yet.'))
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Note')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Amount'), numeric: true),
                          ],
                          rows: state.expenses.map((expense) {
                            return DataRow(
                              cells: [
                                DataCell(Text(expense.title)),
                                DataCell(Text(expense.category)),
                                DataCell(
                                  SizedBox(
                                    width: 260,
                                    child: Text(
                                      expense.note.isEmpty ? '—' : expense.note,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                  ),
                                ),
                                DataCell(Text(AppFormatters.dateTime(expense.createdAt))),
                                DataCell(Text(AppFormatters.money(expense.amount))),
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

  Future<void> _addExpense(BuildContext context, AppState state) async {
    final title = TextEditingController();
    final category = TextEditingController(text: 'General');
    final amount = TextEditingController(text: '0.00');
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record expense'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    return parsed == null || parsed <= 0 ? 'Enter an amount above zero' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
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
            child: const Text('Save expense'),
          ),
        ],
      ),
    );

    if (submit != true || !context.mounted) return;
    try {
      await state.addExpense(
        Expense(
          id: null,
          title: title.text.trim(),
          category: category.text.trim(),
          amount: double.parse(amount.text.trim()),
          note: note.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (context.mounted) showSuccess(context, 'Expense recorded.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}
