import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/card_service.dart';
import 'add_card_screen.dart';

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
    final cards = cardService.cards
        .map((c) => _CardData(
              type: c.type,
              network: c.network,
              digits: c.last4,
              holder: c.holder,
              month: c.month,
              year: c.year,
            ))
        .toList();

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
          for (final c in cards) _GlassCard(data: c),
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

class _CardData {
  final String type; // Debit, Credit, Forex
  final String network; // Visa, Mastercard
  final String digits; // last 4
  final String holder;
  final String month;
  final String year; // yy
  const _CardData({
    required this.type,
    required this.network,
    required this.digits,
    required this.holder,
    required this.month,
    required this.year,
  });
}

class _GlassCard extends StatelessWidget {
  final _CardData data;
  const _GlassCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final gradient = data.network == 'Visa'
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
                '${data.network.toUpperCase()} • ${data.type.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '5128 6701 0095 ${data.digits}',
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            data.holder.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip('VALID', '${data.month}/${data.year}'),
              const Spacer(),
              _DeleteButton(data: data),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
    child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final _CardData data;
  const _DeleteButton({required this.data});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.white),
      onPressed: () async {
        // Capture service before async gap
        final service = context.read<CardService>();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove card?'),
            content: Text('Delete ${data.network} •••• ${data.digits}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        );
        if (confirmed != true) return;
        if (!context.mounted) return;
        // Find card by matching ends/holder/type; in real backend we'd use id.
        final matches = service.cards.where(
          (c) => c.last4 == data.digits && c.holder == data.holder && c.network == data.network,
        );
        if (matches.isEmpty) return;
        await service.removeCard(matches.first.id);
      },
    );
  }
}


