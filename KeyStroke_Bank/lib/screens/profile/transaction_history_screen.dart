import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: Consumer<TransactionService>(
        builder: (context, txService, _) {
          final txs = txService.transactions;
          if (txs.isEmpty) {
            return const Center(child: Text('No transactions yet'));
          }
          return ListView.separated(
            itemCount: txs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = txs[index];
              final color = t.amount < 0 ? Colors.red : Colors.green;
              return ListTile(
                leading: Icon(_iconForType(t.type), color: color),
                title: Text(t.title),
                subtitle: Text(t.description),
                trailing: Text(
                  (t.amount < 0 ? '-' : '+') + t.amount.abs().toStringAsFixed(2),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.withdrawal:
        return Icons.call_made_rounded;
      case TransactionType.deposit:
        return Icons.call_received_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.payment:
        return Icons.payment_rounded;
    }
  }
}


