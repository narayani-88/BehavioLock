import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

enum AccountType {
  savings,
  current,
  salary,
  fixedDeposit,
  recurringDeposit,
}

// Extension to add methods to AccountType enum
extension AccountTypeExtension on AccountType {
  // Convert enum to string
  String get name => toString().split('.').last;
  
  // Create enum from string
  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.toString() == 'AccountType.$value' || e.name == value,
      orElse: () => AccountType.savings, // Default to savings if not found
    );
  }
}

class BankAccount {
  final String id;
  final String userId;  // ID of the user who owns this account
  final String accountNumber;
  final String accountHolderName;
  final String email;   // Email of the account holder
  final String bankName;
  final String ifscCode;
  final AccountType accountType;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrimary;

  BankAccount({
    required this.id,
    required this.userId,
    required this.accountNumber,
    required this.accountHolderName,
    required this.email,
    required this.bankName,
    required this.ifscCode,
    required this.accountType,
    this.balance = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPrimary = false,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  // Convert BankAccount to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
      'email': email,
      'bankName': bankName,
      'ifscCode': ifscCode,
      'accountType': accountType.name,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPrimary': isPrimary,
    };
  }

  static final _logger = Logger('BankAccount');

  // Helper method to get a value from map with fallback to snake_case keys
  static dynamic _getValue(Map<String, dynamic> map, String key) {
    // Try camelCase first, then fall back to snake_case
    if (map.containsKey(key)) {
      return map[key];
    }
    
    // Convert camelCase to snake_case for fallback
    final snakeKey = key.replaceAllMapped(
      RegExp(r'([A-Z])'), 
      (match) => '_${match.group(0)?.toLowerCase() ?? ''}'
    );
    
    return map[snakeKey];
  }

  // Create BankAccount from Map
  factory BankAccount.fromMap(Map<String, dynamic> map) {
    try {
      final accountTypeStr = _getValue(map, 'accountType')?.toString().toLowerCase() ?? 'savings';
      
      // Handle different date formats (ISO string, HTTP date, or already DateTime)
      DateTime? parseDate(dynamic dateValue) {
        if (dateValue == null) return null;
        if (dateValue is DateTime) return dateValue;
        if (dateValue is String) {
          _logger.fine('Parsing date string: $dateValue');
          
          // 1) Try ISO 8601 first
          final iso = DateTime.tryParse(dateValue);
          if (iso != null) return iso;
          
          // 2) Try RFC1123/RFC7231 using HttpDate.parse (handles "Wed, 13 Aug 2025 14:06:41 GMT")
          try {
            return HttpDate.parse(dateValue);
          } catch (_) {}
          
          // 3) Try intl with common HTTP patterns (fallbacks)
          try {
            final httpFormat = DateFormat('EEE, dd MMM yyyy HH:mm:ss zzz');
            return httpFormat.parseUtc(dateValue).toLocal();
          } catch (_) {
            try {
              final clean = dateValue.replaceAll(' GMT', '').replaceAll(' UTC', '');
              final alt = DateFormat('EEE, dd MMM yyyy HH:mm:ss');
              return alt.parseUtc(clean).toLocal();
            } catch (_) {}
          }
        }
        return null;
      }
      
      return BankAccount(
        id: (map['_id']?.toString()) ?? (_getValue(map, 'id')?.toString()) ?? '',
        userId: _getValue(map, 'userId') ?? '',
        accountNumber: _getValue(map, 'accountNumber') ?? '',
        accountHolderName: _getValue(map, 'accountHolderName') ?? '',
        email: _getValue(map, 'email') ?? '',
        bankName: _getValue(map, 'bankName') ?? 'KeyStroke Bank',
        ifscCode: _getValue(map, 'ifscCode') ?? '',
        accountType: AccountTypeExtension.fromString(accountTypeStr),
        balance: (_getValue(map, 'balance') ?? 0.0).toDouble(),
        isPrimary: _getValue(map, 'isPrimary')?.toString().toLowerCase() == 'true' ||
            _getValue(map, 'isPrimary') == true,
        createdAt: parseDate(_getValue(map, 'createdAt')) ?? DateTime.now(),
        updatedAt: parseDate(_getValue(map, 'updatedAt')) ?? DateTime.now(),
      );
    } catch (e) {
      _logger.severe('Error parsing BankAccount from map', e);
      rethrow;
    }
  }

  // Convert to JSON string
  String toJson() => json.encode(toMap());

  // Create from JSON string
  factory BankAccount.fromJson(String source) =>
      BankAccount.fromMap(json.decode(source) as Map<String, dynamic>);

  // Create a copy of the BankAccount with some fields updated
  BankAccount copyWith({
    String? id,
    String? userId,
    String? accountNumber,
    String? accountHolderName,
    String? email,
    String? bankName,
    String? ifscCode,
    AccountType? accountType,
    double? balance,
    bool? isPrimary,
  }) {
    return BankAccount(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      email: email ?? this.email,
      bankName: bankName ?? this.bankName,
      ifscCode: ifscCode ?? this.ifscCode,
      accountType: accountType ?? this.accountType,
      balance: balance ?? this.balance,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BankAccount && 
           other.id == id &&
           other.accountNumber == accountNumber;
  }

  @override
  int get hashCode => id.hashCode ^ accountNumber.hashCode;
}

// List of popular Indian banks
const List<String> popularIndianBanks = [
  'State Bank of India',
  'HDFC Bank',
  'ICICI Bank',
  'Axis Bank',
  'Kotak Mahindra Bank',
  'Punjab National Bank',
  'Bank of Baroda',
  'IndusInd Bank',
  'Yes Bank',
  'IDBI Bank',
  'IDFC FIRST Bank',
  'Canara Bank',
  'Union Bank of India',
  'Bank of India',
  'Central Bank of India',
];
