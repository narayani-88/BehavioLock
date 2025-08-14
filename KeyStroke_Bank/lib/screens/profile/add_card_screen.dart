import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/settings_service.dart';

class AddCardResult {
  final String brand;
  final String numberGroup1;
  final String numberGroup2;
  final String numberGroup3;
  final String numberGroup4;
  final String holderName;
  final String month;
  final String year;
  final String type; // Debit, Credit, Forex
  final String network; // Visa or Mastercard

  AddCardResult({
    required this.brand,
    required this.numberGroup1,
    required this.numberGroup2,
    required this.numberGroup3,
    required this.numberGroup4,
    required this.holderName,
    required this.month,
    required this.year,
    required this.type,
    required this.network,
  });
}

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen>
    with SingleTickerProviderStateMixin {
  final _g1 = TextEditingController();
  final _g2 = TextEditingController();
  final _g3 = TextEditingController();
  final _g4 = TextEditingController();
  final _name = TextEditingController();

  String? _month;
  String? _year;
  String _network = 'Visa';

  final _debitFormKey = GlobalKey<FormState>();
  final _creditFormKey = GlobalKey<FormState>();
  final _forexFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _name.text = auth.currentUser?.name ?? '';
  }

  @override
  void dispose() {
    _g1.dispose();
    _g2.dispose();
    _g3.dispose();
    _g4.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final years = List<String>.generate(
      12,
      (i) => (DateTime.now().year + i).toString(),
    );
    final months = List<String>.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Card'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'DEBIT CARD'),
              Tab(text: 'CREDIT CARD'),
              Tab(text: 'FOREX CARD'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildForm(context, months, years, 'Debit', _debitFormKey),
            _buildForm(context, months, years, 'Credit', _creditFormKey),
            _buildForm(context, months, years, 'Forex', _forexFormKey),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<String> months,
    List<String> years,
    String type,
    GlobalKey<FormState> formKey,
  ) {
    final inputFmt = <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Card Number'),
            const SizedBox(height: 8),
            Row(
              children: [
                _groupField(_g1, inputFmt, onFilled: () => _focusNext(context)),
                const SizedBox(width: 12),
                _groupField(_g2, inputFmt, onFilled: () => _focusNext(context)),
                const SizedBox(width: 12),
                _groupField(_g3, inputFmt, onFilled: () => _focusNext(context)),
                const SizedBox(width: 12),
                _groupField(_g4, inputFmt),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Month',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black,
                    style: const TextStyle(color: Colors.black),
                    items: months
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ))
                        .toList(),
                    value: _month,
                    onChanged: (v) => setState(() => _month = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Year',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black,
                    style: const TextStyle(color: Colors.black),
                    items: years
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text(
                                y,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ))
                        .toList(),
                    value: _year,
                    onChanged: (v) => setState(() => _year = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Card Holder Name',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.black),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _network,
              decoration: const InputDecoration(
                labelText: 'Network',
                border: OutlineInputBorder(),
              ),
              dropdownColor: Colors.white,
              iconEnabledColor: Colors.black,
              style: const TextStyle(color: Colors.black),
              items: _networkOptions(context)
                  .map((n) => DropdownMenuItem(
                        value: n.key,
                        child: Text(n.label, style: const TextStyle(color: Colors.black)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _network = v ?? 'Visa'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(context, type),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('ADD CARD'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupField(TextEditingController c, List<TextInputFormatter> fmt,
      {VoidCallback? onFilled}) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: fmt,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
        onChanged: (v) {
          if (v.length == 4 && onFilled != null) onFilled();
        },
        validator: (v) => (v == null || v.length != 4) ? 'xxxx' : null,
      ),
    );
  }

  void _focusNext(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  void _submit(BuildContext context, String type) {
    final formKey = switch (type) {
      'Debit' => _debitFormKey,
      'Credit' => _creditFormKey,
      _ => _forexFormKey,
    };
    if (!formKey.currentState!.validate()) return;
    final brand = _inferBrand(_g1.text);
    final result = AddCardResult(
      brand: brand,
      numberGroup1: _g1.text,
      numberGroup2: _g2.text,
      numberGroup3: _g3.text,
      numberGroup4: _g4.text,
      holderName: _name.text.trim(),
      month: _month!,
      year: _year!,
      type: type,
      network: _network.isNotEmpty ? _network : brand,
    );
    Navigator.pop(context, result);
  }

  String _inferBrand(String g1) {
    if (g1.isEmpty) return 'Card';
    switch (g1[0]) {
      case '4':
        return 'Visa';
      case '5':
        return 'Mastercard';
      case '3':
        return 'Amex';
      default:
        return 'Card';
    }
  }

  // Derive network options from SettingsService toggles
  List<_Option> _networkOptions(BuildContext context) {
    final settings = context.read<SettingsService>();
    final available = settings.networks; // e.g., ['Visa','Mastercard',...]
    return available.map((n) => _Option(key: n, label: _prettyNetwork(n))).toList();
  }

  String _prettyNetwork(String code) {
    switch (code) {
      case 'Amex':
        return 'American Express (Amex)';
      default:
        return code;
    }
  }
}

class _Option {
  final String key;
  final String label;
  _Option({required this.key, required this.label});
}


