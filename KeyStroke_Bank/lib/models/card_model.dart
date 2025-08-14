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
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());
  static CardModel fromJson(String source) => fromMap(jsonDecode(source) as Map<String, dynamic>);
}


