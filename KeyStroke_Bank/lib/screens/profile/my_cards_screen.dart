import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/card_service.dart';
import '../../models/card_model.dart';
import 'add_card_screen.dart';
import 'card_withdrawal_screen.dart';
import 'add_money_to_card_screen.dart';

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CardService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardService = context.watch<CardService>();
    final cards = cardService.cards;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Cards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (cards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No cards yet')),
            ),
          for (final card in cards) _GlassCard(card: card),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onAddCard,
              icon: const Icon(Icons.add),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('ADD NEW CARD'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddCard() async {
    // Capture service before the async gap to avoid using context after await
    final cardService = context.read<CardService>();
    final result = await Navigator.push<AddCardResult>(
      context,
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );
    if (!mounted || result == null) return;
    await cardService.addCard(
          type: result.type,
          network: result.network,
          numberGroup4: result.numberGroup4,
          holder: result.holderName,
          month: result.month,
          year: result.year,
        );
  }
}



class _GlassCard extends StatelessWidget {
  final CardModel card;
  const _GlassCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final gradient = card.network == 'Visa'
        ? const LinearGradient(colors: [Color(0xFF6A5AE0), Color(0xFF6CC6FF)])
        : const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)]);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.sim_card, color: Colors.white),
              Text(
                '${card.network.toUpperCase()} • ${card.type.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            card.maskedNumber,
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            card.holder.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
                     Row(
                       children: [
                         _chip('VALID', '${card.month}/${card.year}'),
                         const Spacer(),
                         _chip('BALANCE', card.formattedBalance),
                       ],
                     ),
                     const SizedBox(height: 8),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         _AddMoneyButton(card: card),
                         const SizedBox(width: 4),
                         _WithdrawButton(card: card),
                         const SizedBox(width: 4),
                         _DeleteButton(card: card),
                       ],
                     ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10)),
        ],
      ),
    );
  }
}

class _AddMoneyButton extends StatelessWidget {
  final CardModel card;
  const _AddMoneyButton({required this.card});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddMoneyToCardScreen(card: card),
          ),
        );
      },
    );
  }
}

class _WithdrawButton extends StatelessWidget {
  final CardModel card;
  const _WithdrawButton({required this.card});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardWithdrawalScreen(card: card),
          ),
        );
      },
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final CardModel card;
  const _DeleteButton({required this.card});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.white),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () async {
        // Capture service before async gap
        final service = context.read<CardService>();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove card?'),
            content: Text('Delete ${card.network} •••• ${card.last4}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        );
        if (confirmed != true) return;
        if (!context.mounted) return;
        await service.removeCard(card.id);
      },
    );
  }
}


