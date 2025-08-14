import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';

import '../models/bank_account_model.dart';
import 'api_service.dart';

// Extension to add firstWhereOrNull to Iterable
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

final _logger = Logger('BankAccountService');

class BankAccountService extends ChangeNotifier {
  final ApiService _apiService;
  
  List<BankAccount> _accounts = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<BankAccount> get accounts => List.unmodifiable(_accounts);
  BankAccount? get primaryAccount => _accounts.firstWhereOrNull((a) => a.isPrimary);
  bool get isLoading => _isLoading;
  String? get error => _error;

  BankAccountService({required ApiService apiService}) : _apiService = apiService;

  // Helper method to safely notify listeners
  void _safeNotifyListeners() {
    if (_isDisposed) return;
    
    // Schedule the notification for the next frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  // Initialize the service
  Future<void> initialize() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      _logger.info('Fetching accounts from API');
      
      final response = await _apiService.get('/api/accounts');
      _logger.fine('Raw accounts API response type: ${response.runtimeType}');
      _logger.fine('Raw accounts API response: $response');
      
      // Check if response is a string (error message) or Map
      if (response is String) {
        _logger.warning('API returned string instead of JSON: $response');
        // Check if it's an authentication error
        if (response.toLowerCase().contains('unauthorized') || 
            response.toLowerCase().contains('401') ||
            response.toLowerCase().contains('jwt')) {
          throw Exception('Authentication required. Please log in again.');
        }
        throw Exception(response);
      }
      
      // At this point, response should be a Map<String, dynamic>
      if (response['status'] == 'success') {
        final accountsData = response['data'];
        _logger.fine('Accounts data type: ${accountsData.runtimeType}');
        _logger.fine('Accounts data: $accountsData');
        
        if (accountsData is List) {
          _accounts = accountsData
              .whereType<Map<String, dynamic>>()
              .map((json) {
                try {
                  return BankAccount.fromMap(json);
                } catch (e) {
                  _logger.warning('Failed to parse account: $json', e);
                  return null;
                }
              })
              .whereType<BankAccount>()
              .toList();
          _logger.fine('Parsed accounts: $_accounts');
        } else {
          _logger.warning('Expected accounts data to be a list but got: ${accountsData.runtimeType}');
          _accounts = [];
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to load accounts';
        _logger.warning('Failed to load accounts: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      _error = 'Failed to load accounts: ${e.toString()}';
      _logger.severe('Error loading accounts', e);
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // Track if the service has been disposed
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Add a new bank account
  Future<bool> addAccount(BankAccount account) async {
    if (_isLoading) return false;
    
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      _logger.fine('Adding new bank account: ${account.accountNumber}');
      
      // Check for duplicate account number
      if (_accounts.any((a) => a.accountNumber == account.accountNumber)) {
        _error = 'An account with this number already exists';
        return false;
      }

      // If this is the first account, make it primary
      if (_accounts.isEmpty) {
        account = account.copyWith(isPrimary: true);
      }

      // Prepare account data with the exact field names expected by the backend
      final accountData = {
        'account_number': account.accountNumber,
        'account_holder_name': account.accountHolderName,
        'bank_name': account.bankName,
        'ifsc_code': account.ifscCode,
        'account_type': account.accountType.name.toLowerCase(), // Ensure lowercase to match enum
        'is_primary': account.isPrimary,
        'balance': account.balance,
      };
      
      _logger.fine('Sending account data with snake_case fields: $accountData');
      
      _logger.fine('Sending account data: $accountData');
      
      final response = await _apiService.post(
        '/api/accounts',
        data: accountData,
      );
      
      _logger.fine('Add account response: $response');

      // Handle response
      if (response['status'] == 'success') {
        // Get the account ID from the response and update the account
        final accountId = response['account_id'];
        if (accountId == null) {
          _logger.warning('Missing account_id in successful response');
          _error = 'Account created but could not retrieve account details';
          return false;
        }
        
        // Create a new account object with the ID from the response
        final newAccount = account.copyWith(id: accountId);
        _accounts.add(newAccount);
        _logger.info('Successfully added account: ${newAccount.accountNumber} with ID: $accountId');
        return true;
      } else {
        String errorMessage = 'Failed to add account';
        if (response['message'] != null) {
          errorMessage = response['message'].toString();
        } else if (response['error'] != null) {
          errorMessage = response['error'].toString();
        } else if (response['details'] != null) {
          errorMessage = 'Validation error: ${response['details']}';
        }
        _logger.warning('Failed to add account. Response: $response');
        _error = errorMessage;
        return false;
      }
    } catch (e) {
      _error = 'Failed to add account: ${e.toString()}';
      _logger.severe('Error adding account', e);
      return false;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // Delete a bank account
  Future<bool> deleteAccount(String accountId) async {
    if (_isLoading) return false;
    
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      _logger.fine('Deleting account with ID: $accountId');
      
      final response = await _apiService.delete('/api/accounts/$accountId');
      
      if (response['status'] == 'success') {
        _accounts.removeWhere((account) => account.id == accountId);
        _logger.info('Successfully deleted account with ID: $accountId');
        return true;
      } else {
        throw Exception(response['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      _error = 'Failed to delete account: ${e.toString()}';
      _logger.severe('Error deleting account', e);
      return false;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // Update an existing bank account
  Future<bool> updateAccount(BankAccount updatedAccount) async {
    if (_isLoading) return false;
    
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      _logger.fine('Updating account: ${updatedAccount.accountNumber}');
      
      // Prepare the request body
      final requestBody = updatedAccount.toMap();
      _logger.info('Sending request to update account: $requestBody');

      final response = await _apiService.put(
        '/api/accounts/${updatedAccount.id}',
        data: requestBody,
      );

      if (response['status'] == 'success') {
        final index = _accounts.indexWhere((a) => a.id == updatedAccount.id);
        if (index != -1) {
          _accounts[index] = BankAccount.fromMap(response['data']);
          _logger.info('Successfully updated account: ${updatedAccount.accountNumber}');
          return true;
        }
        throw Exception('Account not found in local state');
      } else {
        throw Exception(response['message'] ?? 'Failed to update account');
      }
    } catch (e) {
      _error = 'Failed to update account: ${e.toString()}';
      _logger.severe('Error updating account', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set an account as primary
  Future<bool> setPrimaryAccount(String accountId) async {
    if (_isLoading) return false;
    
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      _logger.fine('Setting account as primary: $accountId');
      
      // Find the account to set as primary
      final account = _accounts.firstWhere((a) => a.id == accountId);
      
      // Update all accounts to set isPrimary to false
      for (var acc in _accounts) {
        if (acc.id != accountId && acc.isPrimary) {
          await updateAccount(acc.copyWith(isPrimary: false));
        }
      }
      
      // Set the specified account as primary
      final result = await updateAccount(account.copyWith(isPrimary: true));
      
      if (result) {
        _logger.info('Successfully set account as primary: $accountId');
      }
      
      return result;
    } catch (e) {
      _error = 'Failed to set primary account: ${e.toString()}';
      _logger.severe('Error setting primary account', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  // Get account by ID
  BankAccount? getAccountById(String accountId) {
    try {
      return _accounts.firstWhere((account) => account.id == accountId);
    } catch (e) {
      _logger.warning('Account not found with ID: $accountId');
      return null;
    }
  }

  // Refresh account balances after transactions
  Future<void> refreshAccountBalances() async {
    try {
      _logger.info('Refreshing account balances');
      await initialize(); // Re-fetch all accounts to get updated balances
    } catch (e) {
      _logger.severe('Error refreshing account balances', e);
      // Don't rethrow - this is a background refresh
    }
  }
}
