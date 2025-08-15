import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ket_stroke_bank/services/transaction_service.dart';
import 'package:ket_stroke_bank/models/transaction_model.dart';
import 'package:ket_stroke_bank/models/bank_account_model.dart';
import 'package:ket_stroke_bank/services/bank_account_service.dart';
import 'package:ket_stroke_bank/theme/app_colors.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? accountId;
  final TransactionType? initialTransactionType;

  const AddTransactionScreen({
    super.key,
    this.accountId,
    this.initialTransactionType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _recipientAccountController = TextEditingController();

  TransactionType _selectedType = TransactionType.deposit;
  String? _selectedAccountId;
  List<BankAccount> _accounts = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _transactionTypes = [
    {
      'type': TransactionType.deposit,
      'label': 'Deposit',
      'icon': Icons.arrow_downward,
    },
    {
      'type': TransactionType.withdrawal,
      'label': 'Withdrawal',
      'icon': Icons.arrow_upward,
    },
    {
      'type': TransactionType.transfer,
      'label': 'Transfer',
      'icon': Icons.swap_horiz,
    },
    {
      'type': TransactionType.payment,
      'label': 'Payment',
      'icon': Icons.payment,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Set initial transaction type if provided
    if (widget.initialTransactionType != null) {
      _selectedType = widget.initialTransactionType!;
    }
    _loadAccounts();
  }

  Color _getTransactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return AppColors.deposit;
      case TransactionType.withdrawal:
        return AppColors.withdrawal;
      case TransactionType.transfer:
        return AppColors.transfer;
      default:
        return AppColors.primary;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _recipientAccountController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accountService = Provider.of<BankAccountService>(
        context,
        listen: false,
      );
      await accountService.initialize();

      if (mounted) {
        setState(() {
          _accounts = accountService.accounts.toSet().toList();
          if (widget.accountId != null &&
              _accounts.any((a) => a.id == widget.accountId)) {
            _selectedAccountId = widget.accountId;
          } else if (_accounts.isNotEmpty) {
            _selectedAccountId = _accounts.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load accounts: $e')));
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an account')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      final now = DateTime.now();
      final transaction = TransactionModel(
        id: const Uuid().v4(),
        accountId: _selectedAccountId!,
        amount: _selectedType == TransactionType.withdrawal ? -amount : amount,
        description: _descriptionController.text,
        type: _selectedType,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      await Provider.of<TransactionService>(
        context,
        listen: false,
      ).addTransaction(transaction);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add transaction: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildAccountDropdown() {
    if (_accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          'No accounts available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final selectedAccount = _accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => _accounts.first,
    );

    return GestureDetector(
      onTap: _showAccountSelection,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(26), // ~10% opacity
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedAccount.accountHolderName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '•••• ${selectedAccount.accountNumber.substring(selectedAccount.accountNumber.length - 4)} • ${selectedAccount.bankName}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showAccountSelection() {
    if (_accounts.isEmpty) {
      return;
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Account',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Accounts list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _accounts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  final isSelected = account.id == _selectedAccountId;

                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: isSelected
                        ? AppColors.primary.withAlpha(51) // ~20% opacity
                        : theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(
                              color: AppColors.primary.withAlpha(26),
                              width: 1.5,
                            ) // ~10% opacity
                          : BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedAccountId = account.id);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withAlpha(
                                        26,
                                      ) // ~10% opacity
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.accountHolderName,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '•••• ${account.accountNumber.substring(account.accountNumber.length - 4)} • ${account.bankName}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isSelected
                                          ? AppColors.primary.withAlpha(
                                              204,
                                            ) // ~80% opacity
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom padding for better scrolling on some devices
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transaction Type
                    Text(
                      'Transaction Type',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _transactionTypes.map((type) {
                        final isSelected = _selectedType == type['type'];
                        return FilterChip(
                          label: Text(type['label']),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(
                                () => _selectedType =
                                    type['type'] as TransactionType,
                              );
                            }
                          },
                          avatar: Icon(
                            type['icon'] as IconData,
                            color: isSelected
                                ? _getTransactionTypeColor(_selectedType)
                                : null,
                          ),
                          backgroundColor: Colors.grey[200],
                          selectedColor: _getTransactionTypeColor(
                            type['type'] as TransactionType,
                          ).withAlpha(51), // ~20% opacity
                          labelStyle: TextStyle(
                            color: isSelected
                                ? _getTransactionTypeColor(_selectedType)
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Account Selection
                    Text(
                      'Account',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAccountDropdown(),
                    const SizedBox(height: 24),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: '0.00',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter transaction details',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter a description'
                          : null,
                    ),

                    // Recipient Account (for transfers)
                    if (_selectedType == TransactionType.transfer) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _recipientAccountController,
                        decoration: InputDecoration(
                          labelText: 'Recipient Account Number',
                          prefixIcon: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 22,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          filled: true,
                          fillColor: theme.cardColor,
                        ),
                        validator: (value) =>
                            (value?.isEmpty ?? true) &&
                                _selectedType == TransactionType.transfer
                            ? 'Please enter recipient account number'
                            : null,
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Submit Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          disabledBackgroundColor: AppColors.primary.withAlpha(
                            128,
                          ), // ~50% opacity
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Add Transaction',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
