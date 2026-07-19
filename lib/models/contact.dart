enum ContactType { customer, supplier }

class BusinessContact {
  const BusinessContact({
    required this.id,
    required this.type,
    required this.name,
    required this.phone,
    required this.email,
    required this.balance,
    required this.createdAt,
  });

  final int? id;
  final ContactType type;
  final String name;
  final String phone;
  final String email;
  final double balance;
  final DateTime createdAt;

  String get table => type == ContactType.customer ? 'customers' : 'suppliers';

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'balance': balance,
    'created_at': createdAt.toIso8601String(),
  };

  factory BusinessContact.fromMap(Map<String, Object?> map, ContactType type) =>
      BusinessContact(
        id: map['id'] as int?,
        type: type,
        name: map['name'] as String,
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        balance: (map['balance'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
