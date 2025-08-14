import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/bank_account_model.dart';
import '../../../services/bank_account_service.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  bool _isLoading = false;
  late final BankAccountService _bankAccountService;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _bankAccountService = context.read<BankAccountService>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only load accounts if we haven't already
    if (_isLoading) {
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    try {
      await _bankAccountService.initialize();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load accounts: $error')),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankAccountService = Provider.of<BankAccountService>(context);
    final accounts = bankAccountService.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Accounts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
              ? const Center(
                  child: Text('No accounts found. Add a new account to get started.'),
                )
              : ListView.builder(
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return _buildAccountCard(account, bankAccountService);
                  },
                ),
    );
  }

  Widget _buildAccountCard(BankAccount account, BankAccountService service) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withAlpha(20), // Equivalent to 0.1 opacity with 50 alpha
          child: Icon(
            Icons.account_balance,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          '${account.bankName} ••••${account.accountNumber.substring(account.accountNumber.length - 4)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.accountHolderName),
            Text(
              '${account.accountType.toString().split('.').last} • ${account.ifscCode}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (account.isPrimary)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(51), // Equivalent to 0.2 opacity
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteAccount(context, account),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, BankAccount account) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    // Get a local reference to the ScaffoldMessenger before any async gaps
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Delete Account'),
          content: Text(
              'Are you sure you want to delete the account ending in ${account.accountNumber.substring(account.accountNumber.length - 4)}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (shouldDelete != true) {
        return;
      }

      final success = await _bankAccountService.deleteAccount(account.id);
      
      if (!mounted) return;
      
      if (success) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
          // Refresh the accounts list
          await _loadAccounts();
        }
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_bankAccountService.error ?? 'Failed to delete account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
