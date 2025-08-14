import 'dart:convert';

class CardModel {
  final String id;
  final String userId;
  final String type; // Debit, Credit, Forex
  final String network; // Visa, Mastercard
  final String last4;
  final String holder;
  final String month; // MM
  final String year; // YY
  final double balance; // Current balance on the card
  final DateTime createdAt;

  CardModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.network,
    required this.last4,
    required this.holder,
    required this.month,
    required this.year,
    this.balance = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'network': network,
      'last4': last4,
      'holder': holder,
      'month': month,
      'year': year,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static CardModel fromMap(Map<String, dynamic> map) {
    return CardModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      type: map['type'] as String,
      network: map['network'] as String,
      last4: map['last4'] as String,
      holder: map['holder'] as String,
      month: map['month'] as String,
      year: map['year'] as String,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());
  static CardModel fromJson(String source) => fromMap(jsonDecode(source) as Map<String, dynamic>);

  // Create a copy with updated balance
  CardModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? network,
    String? last4,
    String? holder,
    String? month,
    String? year,
    double? balance,
    DateTime? createdAt,
  }) {
    return CardModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      network: network ?? this.network,
      last4: last4 ?? this.last4,
      holder: holder ?? this.holder,
      month: month ?? this.month,
      year: year ?? this.year,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Check if card has sufficient balance for a transaction
  bool hasSufficientBalance(double amount) {
    return balance >= amount;
  }

  // Get formatted balance string
  String get formattedBalance => '₹${balance.toStringAsFixed(2)}';

  // Get masked card number for display
  String get maskedNumber => '•••• •••• •••• $last4';
}


