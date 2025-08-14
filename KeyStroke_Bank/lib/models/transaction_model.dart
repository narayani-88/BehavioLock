import 'dart:io';
import 'package:flutter/material.dart';

enum TransactionType {
  transfer,
  payment,
  deposit,
  withdrawal,
}

class TransactionModel {
  final String id;
  final String accountId;
  final String? recipientAccountId;
  final double amount;
  final String description;
  final DateTime date;
  final TransactionType type;
  final String status;
  final String? reference;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.accountId,
    this.recipientAccountId,
    required this.amount,
    this.description = '',
    required this.date,
    required this.type,
    this.status = 'pending',
    this.reference,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getters for UI compatibility
  String get title => _getTitle();
  bool get isPending => status == 'pending';
  
  // For backward compatibility with existing UI code
  String? get recipient => type == TransactionType.transfer ? recipientAccountId : null;
  
  // Helper to generate a title based on transaction type
  String _getTitle() {
    switch (type) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.payment:
        return 'Payment';
    }
  }

  // Convert TransactionModel to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      if (recipientAccountId != null) 'recipient_account_id': recipientAccountId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'type': _typeToString(type),
      'status': status,
      'reference': reference,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static DateTime _parseAnyDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return DateTime.now();
    // 1) Prefer HTTP/RFC dates first to avoid DateTime.tryParse throwing internally
    if (s.contains(',') && (s.contains('GMT') || s.contains('UTC'))) {
      try {
        return HttpDate.parse(s);
      } catch (_) {}
    }
    // 2) ISO 8601
    try {
      final iso = DateTime.tryParse(s);
      if (iso != null) return iso;
    } catch (_) {}
    // 3) Fallback HTTP/RFC even if not matched by heuristic
    try {
      return HttpDate.parse(s);
    } catch (_) {}
    // 4) Final fallback
    return DateTime.now();
  }

  // Create TransactionModel from Map
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    // Normalize common fields
    final dynamic rawId = map['id'] ?? map['_id'];
    final String id = rawId?.toString() ?? '';

    final dynamic rawAccountId = map['account_id'] ?? map['accountId'];
    final String accountId = rawAccountId?.toString() ?? '';

    final dynamic rawRecipientId = map['recipient_account_id'] ?? map['recipientAccountId'];
    final String? recipientAccountId = rawRecipientId?.toString();

    // Amount can be num or String
    double amount = 0.0;
    final dynamic rawAmount = map['amount'];
    if (rawAmount is num) {
      amount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      final parsed = double.tryParse(rawAmount);
      if (parsed != null) amount = parsed;
    }

    final String description = (map['description'] ?? '').toString();

    // Determine type from either 'type' or 'transaction_type'
    final dynamic rawType = map['type'] ?? map['transaction_type'];
    final String typeStr = rawType?.toString().toLowerCase() ?? 'payment';

    final String status = (map['status'] ?? 'pending').toString();
    final String? reference = map['reference']?.toString();

    // Dates from various keys
    final DateTime date = _parseAnyDate(map['date']);
    final DateTime createdAt = _parseAnyDate(map['created_at']);
    final DateTime updatedAt = _parseAnyDate(map['updated_at']);

    return TransactionModel(
      id: id,
      accountId: accountId,
      recipientAccountId: recipientAccountId,
      amount: amount,
      description: description,
      date: date,
      type: _parseTransactionType(typeStr),
      status: status,
      reference: reference,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Convert TransactionType to string
  static String _typeToString(TransactionType type) {
    return type.toString().split('.').last;
  }

  // Helper method to parse TransactionType from string
  static TransactionType _parseTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return TransactionType.deposit;
      case 'withdrawal':
        return TransactionType.withdrawal;
      case 'transfer':
        return TransactionType.transfer;
      case 'payment':
      default:
        return TransactionType.payment;
    }
  }

  // Get icon based on transaction type
  IconData get icon {
    switch (type) {
      case TransactionType.payment:
        return Icons.payment;
      case TransactionType.deposit:
        return Icons.account_balance_wallet;
      case TransactionType.withdrawal:
        return Icons.money_off;
      case TransactionType.transfer:
        return Icons.swap_horiz;
    }
  }

  // Get color based on transaction type
  Color get color {
    if (amount < 0) {
      return Colors.red;
    }
    switch (type) {
      case TransactionType.payment:
        return Colors.purple;
      case TransactionType.deposit:
        return Colors.green;
      case TransactionType.withdrawal:
        return Colors.orange;
      case TransactionType.transfer:
        return Colors.blue;
    }
  }

  // Format amount with appropriate sign
  String get formattedAmount {
    const rupee = '₹';
    if (amount >= 0) {
      return '$rupee${amount.toStringAsFixed(2)}';
    } else {
      return '-$rupee${(-amount).toStringAsFixed(2)}';
    }
  }

  // Format date as a string
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today, ${_formatTime(date)}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday, ${_formatTime(date)}';
    } else {
      return '${_formatDate(date)}, ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12;
    final period = date.hour < 12 ? 'AM' : 'PM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
