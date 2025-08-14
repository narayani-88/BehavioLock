import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class CardService extends ChangeNotifier {
  // ignore: unused_field
  final ApiService _api; // reserved for future backend calls (kept for upcoming integration)
  final AuthService _auth;
  final List<CardModel> _cards = [];
  bool _initialized = false;

  CardService({required ApiService apiService, required AuthService authService})
      : _api = apiService,
        _auth = authService;

  List<CardModel> get cards => List.unmodifiable(_cards);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await loadCards();
  }

  Future<void> loadCards() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Since there's no backend, load directly from local storage
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(user.id);
    final list = prefs.getStringList(key) ?? <String>[];
    
    _cards.clear();
    for (final jsonString in list) {
      try {
        final card = CardModel.fromJson(jsonString);
        _cards.add(card);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to parse card from JSON: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<CardModel> addCard({
    required String type,
    required String network,
    required String numberGroup4,
    required String holder,
    required String month,
    required String year,
    double initialBalance = 0.0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final card = CardModel(
      id: const Uuid().v4(),
      userId: user.id,
      type: type,
      network: network,
      last4: numberGroup4,
      holder: holder,
      month: month,
      year: year.substring(2),
      balance: initialBalance,
      createdAt: DateTime.now(),
    );

    // Since there's no backend, save directly to local storage
    _cards.add(card);
    await _saveAll();
    notifyListeners();
    
    if (kDebugMode) {
      print('Card saved locally: ${card.id}');
    }
    
    return card;
  }

  Future<void> removeCard(String id) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    // Since there's no backend, remove directly from local storage
    _cards.removeWhere((c) => c.id == id);
    await _saveAll();
    notifyListeners();
    
    if (kDebugMode) {
      print('Card removed locally: $id');
    }
  }

  Future<void> updateCard(CardModel card) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    // Since there's no backend, update directly in local storage
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index != -1) {
      _cards[index] = card;
      await _saveAll();
      notifyListeners();
      
      if (kDebugMode) {
        print('Card updated locally: ${card.id}');
      }
    }
  }

  Future<void> _saveAll() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(user.id);
    await prefs.setStringList(key, _cards.map((c) => c.toJson()).toList());
  }

  String _prefsKey(String userId) => 'cards.$userId';



  /// Gets a card by ID
  CardModel? getCardById(String id) {
    try {
      return _cards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Gets cards by type
  List<CardModel> getCardsByType(String type) {
    return _cards.where((card) => card.type.toLowerCase() == type.toLowerCase()).toList();
  }

  /// Gets cards by network
  List<CardModel> getCardsByNetwork(String network) {
    return _cards.where((card) => card.network.toLowerCase() == network.toLowerCase()).toList();
  }

  /// Add money to card balance
  Future<bool> addBalance(String cardId, double amount) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final index = _cards.indexWhere((card) => card.id == cardId);
    if (index == -1) throw Exception('Card not found');

    if (amount <= 0) throw Exception('Amount must be positive');

    final updatedCard = _cards[index].copyWith(balance: _cards[index].balance + amount);
    _cards[index] = updatedCard;
    await _saveAll();
    notifyListeners();

    if (kDebugMode) {
      print('Added ₹${amount.toStringAsFixed(2)} to card $cardId. New balance: ${updatedCard.formattedBalance}');
    }

    return true;
  }

  /// Withdraw money from card balance
  Future<bool> withdrawFromCard(String cardId, double amount) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final index = _cards.indexWhere((card) => card.id == cardId);
    if (index == -1) throw Exception('Card not found');

    if (amount <= 0) throw Exception('Amount must be positive');

    final card = _cards[index];
    if (!card.hasSufficientBalance(amount)) {
      throw Exception('Insufficient balance. Available: ${card.formattedBalance}, Required: ₹${amount.toStringAsFixed(2)}');
    }

    final updatedCard = card.copyWith(balance: card.balance - amount);
    _cards[index] = updatedCard;
    await _saveAll();
    notifyListeners();

    if (kDebugMode) {
      print('Withdrew ₹${amount.toStringAsFixed(2)} from card $cardId. New balance: ${updatedCard.formattedBalance}');
    }

    return true;
  }

  /// Get total balance across all cards
  double getTotalCardBalance() {
    return _cards.fold(0.0, (sum, card) => sum + card.balance);
  }

  /// Get cards with sufficient balance for a transaction
  List<CardModel> getCardsWithSufficientBalance(double amount) {
    return _cards.where((card) => card.hasSufficientBalance(amount)).toList();
  }
}


