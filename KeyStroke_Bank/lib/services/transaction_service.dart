import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';
import 'bank_account_service.dart';

class TransactionService with ChangeNotifier {
  final ApiService _apiService;
  final BankAccountService _bankAccountService;
  final _logger = Logger('TransactionService');
  
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<TransactionModel> get recentTransactions => _getRecentTransactions(limit: 3);
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  TransactionService(this._apiService, {BankAccountService? bankAccountService}) 
      : _bankAccountService = bankAccountService ?? BankAccountService(apiService: _apiService);
  
  /// Clear any error messages
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Get formatted error message for display
  String get formattedError {
    if (_error == null) return '';
    
    // Format specific error types
    if (_error!.toLowerCase().contains('insufficient funds')) {
      return '💳 $_error';
    } else if (_error!.toLowerCase().contains('network') || _error!.toLowerCase().contains('connection')) {
      return '🌐 $_error';
    } else if (_error!.toLowerCase().contains('authentication') || _error!.toLowerCase().contains('unauthorized')) {
      return '🔐 $_error';
    }
    
    return '❌ $_error';
  }
  
  // Get recent transactions
  List<TransactionModel> _getRecentTransactions({int limit = 3}) {
    if (_transactions.isEmpty) return [];
    final sorted = List<TransactionModel>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  List<TransactionModel> _parseList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(TransactionModel.fromMap)
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _parseMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// Check if an account has sufficient funds for a transaction
  Future<bool> hasSufficientFunds(String accountId, double amount, TransactionType type) async {
    try {
      // Get the account details
      final account = _bankAccountService.accounts.firstWhere(
        (acc) => acc.id == accountId,
        orElse: () => throw Exception('Account not found'),
      );
      
      // For transfers and withdrawals, check if balance is sufficient
      if (type == TransactionType.transfer || type == TransactionType.withdrawal) {
        if (account.balance < amount) {
          _logger.warning('Insufficient funds: Account ${account.accountNumber} has ${account.balance}, but transaction requires $amount');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      _logger.severe('Error checking sufficient funds', e);
      return false;
    }
  }

  /// Get the current balance of an account
  double getAccountBalance(String accountId) {
    try {
      final account = _bankAccountService.accounts.firstWhere(
        (acc) => acc.id == accountId,
        orElse: () => throw Exception('Account not found'),
      );
      return account.balance;
    } catch (e) {
      _logger.severe('Error getting account balance', e);
      return 0.0;
    }
  }

  /// Format balance for display
  String formatBalance(double balance) {
    if (balance < 0) {
      return '-\$${balance.abs().toStringAsFixed(2)}';
    }
    return '\$${balance.toStringAsFixed(2)}';
  }

  /// Check if a transaction amount is valid
  bool isValidTransactionAmount(double amount) {
    return amount > 0 && amount <= 999999999.99; // Reasonable upper limit
  }

  /// Get account details for display
  String getAccountDisplayInfo(String accountId) {
    try {
      final account = _bankAccountService.accounts.firstWhere(
        (acc) => acc.id == accountId,
        orElse: () => throw Exception('Account not found'),
      );
      return '${account.accountNumber} (${formatBalance(account.balance)})';
    } catch (e) {
      return 'Account not found';
    }
  }

  // Initialize transaction service
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get('/api/transactions');
      final list = (response is Map) ? response['data'] : response; // allow raw list
      _transactions = _parseList(list);
      _logger.fine('Initialized with ${_transactions.length} transactions');
    } catch (e, st) {
      _error = 'Failed to load transactions';
      _logger.severe('Error initializing transactions', e, st);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new transaction
  Future<bool> addTransaction(TransactionModel transaction) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check if account has sufficient funds before proceeding
      if (!await hasSufficientFunds(transaction.accountId, transaction.amount, transaction.type)) {
        final account = _bankAccountService.accounts.firstWhere(
          (acc) => acc.id == transaction.accountId,
          orElse: () => throw Exception('Account not found'),
        );
        
        _error = 'Insufficient funds. Account ${account.accountNumber} has ${account.balance.toStringAsFixed(2)}, but transaction requires ${transaction.amount.toStringAsFixed(2)}.';
        _logger.warning(_error);
        throw Exception(_error);
      }

      final data = {
        'account_id': transaction.accountId,
        'amount': transaction.amount,
        'transaction_type': transaction.type.toString().split('.').last,
        'description': transaction.description,
        'recipient_account_id': transaction.recipientAccountId,
      };
      
      _logger.fine('Adding transaction: $data');
      
      final response = await _apiService.post(
        '/api/transactions',
        data: data,
      );
      
      // ApiService.post returns a Map<String, dynamic>
      final Map<String, dynamic> resp = response;
      final status = resp['status']?.toString();
      if (status != null && status != 'success') {
        final msg = resp['message']?.toString() ?? 'Failed to add transaction';
        
        // Handle specific error cases
        if (msg.toLowerCase().contains('insufficient funds') || 
            msg.toLowerCase().contains('insufficient balance')) {
          _error = 'Insufficient funds: $msg';
        } else {
          _error = msg;
        }
        
        throw Exception(_error);
      }
      
      final map = _parseMap(resp['data']);
      if (map.isEmpty) {
        final msg = resp['message']?.toString() ?? 'Empty transaction payload from server';
        _error = msg;
        throw Exception(msg);
      }
      
      final newTransaction = TransactionModel.fromMap(map);
      _transactions.insert(0, newTransaction);
      _logger.info('Transaction added: ${newTransaction.id}');
      return true;
    } catch (e, st) {
      _error ??= 'Failed to add transaction: ${e.toString()}';
      _logger.severe('Error adding transaction', e, st);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get transactions by type
  List<TransactionModel> getTransactionsByType(TransactionType type) {
    return _transactions.where((t) => t.type == type).toList();
  }

  // Get recent transactions (last N transactions)
  List<TransactionModel> getRecentTransactions({int limit = 5}) {
    return _getRecentTransactions(limit: limit);
  }

  // Create a transfer between accounts
  Future<TransactionModel> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String description = 'Transfer',
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check if source account has sufficient funds before proceeding
      if (!await hasSufficientFunds(fromAccountId, amount, TransactionType.transfer)) {
        final account = _bankAccountService.accounts.firstWhere(
          (acc) => acc.id == fromAccountId,
          orElse: () => throw Exception('Account not found'),
        );
        
        _error = 'Insufficient funds for transfer. Account ${account.accountNumber} has ${account.balance.toStringAsFixed(2)}, but transfer requires ${amount.toStringAsFixed(2)}.';
        _logger.warning(_error);
        throw Exception(_error);
      }

      // Align with backend API: POST /api/transactions with
      // { account_id, amount, transaction_type: 'transfer', recipient_account_id, description }
      final data = {
        'account_id': fromAccountId,
        'amount': amount,
        'transaction_type': 'transfer',
        'recipient_account_id': toAccountId,
        'description': description,
      };
      
      _logger.fine('Initiating transfer: $data');
      
      final response = await _apiService.post(
        '/api/transactions',
        data: data,
      );
      
      // Handle backend errors
      final status = response['status']?.toString();
      if (status != null && status != 'success') {
        final msg = response['message']?.toString() ?? 'Transfer failed';
        
        // Handle specific error cases
        if (msg.toLowerCase().contains('insufficient funds') || 
            msg.toLowerCase().contains('insufficient balance')) {
          _error = 'Insufficient funds: $msg';
        } else {
          _error = msg;
        }
        
        throw Exception(_error);
      }
      
      final map = _parseMap(response['data']);
      if (map.isEmpty) {
        _error = 'Empty transfer payload from server';
        throw Exception(_error);
      }
      
      final newTransaction = TransactionModel.fromMap(map);
      _transactions.insert(0, newTransaction);
      
      _logger.info('Transfer completed: ${newTransaction.id}');
      return newTransaction;
    } catch (e, st) {
      _error ??= 'Transfer failed: ${e.toString()}';
      _logger.severe('Error creating transfer', e, st);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get total balance across all accounts
  double getTotalBalance() {
    if (_transactions.isEmpty) return 0.0;
    return _transactions.fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  // Get total income (positive amounts)
  double getTotalIncome() {
    if (_transactions.isEmpty) return 0.0;
    return _transactions
        .where((t) => t.amount > 0)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  // Get total expenses (negative amounts, returned as positive)
  double getTotalExpenses() {
    if (_transactions.isEmpty) return 0.0;
    return _transactions
        .where((t) => t.amount < 0)
        .fold(0.0, (sum, transaction) => sum - transaction.amount);
  }

  // Per-account aggregations (null accountId => all accounts)
  double getBalanceForAccount(String? accountId) {
    if (_transactions.isEmpty) return 0.0;
    final Iterable<TransactionModel> source = (accountId == null || accountId.isEmpty)
        ? _transactions
        : _transactions.where((t) => t.accountId == accountId);
    return source.fold(0.0, (sum, t) => sum + t.amount);
  }

  double getIncomeForAccount(String? accountId) {
    if (_transactions.isEmpty) return 0.0;
    final Iterable<TransactionModel> source = (accountId == null || accountId.isEmpty)
        ? _transactions
        : _transactions.where((t) => t.accountId == accountId);
    return source.where((t) => t.amount > 0).fold(0.0, (sum, t) => sum + t.amount);
  }

  double getExpensesForAccount(String? accountId) {
    if (_transactions.isEmpty) return 0.0;
    final Iterable<TransactionModel> source = (accountId == null || accountId.isEmpty)
        ? _transactions
        : _transactions.where((t) => t.accountId == accountId);
    return source.where((t) => t.amount < 0).fold(0.0, (sum, t) => sum - t.amount);
  }

  // Get transactions for a specific date range
  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    try {
      final response = await _apiService.get(
        '/api/transactions',
        queryParameters: {
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
        },
      );
      final list = (response is Map) ? response['data'] : response;
      return _parseList(list);
    } catch (e, st) {
      _error = 'Failed to fetch transactions';
      _logger.severe('Error fetching transactions by date range', e, st);
      rethrow;
    }
  }

  // Get transactions for a specific account
  Future<List<TransactionModel>> getTransactionsByAccount(String accountId) async {
    try {
      final response = await _apiService.get(
        '/api/transactions',
        queryParameters: {'account_id': accountId},
      );
      final list = (response is Map) ? response['data'] : response;
      return _parseList(list);
    } catch (e, st) {
      _error = 'Failed to fetch account transactions';
      _logger.severe('Error fetching account transactions', e, st);
      rethrow;
    }
  }

  // Get transaction by ID
  Future<TransactionModel?> getTransactionById(String id) async {
    try {
      final response = await _apiService.get('/transactions/$id');
      final payload = (response is Map) ? response['data'] : response;
      final map = _parseMap(payload);
      if (map.isEmpty) return null;
      return TransactionModel.fromMap(map);
    } catch (e, st) {
      _logger.warning('Transaction not found: $id', e, st);
      return null;
    }
  }
}
