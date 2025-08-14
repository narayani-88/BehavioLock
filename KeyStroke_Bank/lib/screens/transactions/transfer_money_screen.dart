import 'package:flutter/material.dart';
import '../../../models/transaction_model.dart';
import 'add_transaction_screen_fixed.dart';

class TransferMoneyScreen extends StatefulWidget {
  final String? accountId;
  final String? preselectedRecipientId;
  final String? preselectedRecipientAccountId;
  final TransactionType? initialTransactionType;

  const TransferMoneyScreen({
    super.key, 
    this.accountId,
    this.preselectedRecipientId, 
    this.preselectedRecipientAccountId,
    this.initialTransactionType,
  });

  @override
  State<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends State<TransferMoneyScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('TransferMoneyScreen: Initializing...');
    
    // Immediately redirect to Add Transaction screen with transfer type
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AddTransactionScreen(
            accountId: widget.accountId,
            initialTransactionType: widget.initialTransactionType ?? TransactionType.transfer,
            preselectedRecipientId: widget.preselectedRecipientId,
            preselectedRecipientAccountId: widget.preselectedRecipientAccountId,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // This screen should never be displayed as it redirects immediately
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
