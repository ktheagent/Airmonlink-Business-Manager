class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String category;
  final double amount;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int?,
        title: map['title'] as String,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
