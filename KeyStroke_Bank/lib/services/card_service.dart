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
    
    try {
      // Try to load from backend first
      final response = await _api.get('/cards');
      if (response != null) {
        final List<dynamic> backendCards = response is List ? response : [];
        _cards.clear();
        _cards.addAll(backendCards.map((data) => CardModel.fromMap(Map<String, dynamic>.from(data))));
        
        // Save to local storage as backup
        await _saveAll();
        notifyListeners();
        return;
      }
    } catch (e) {
      // If backend fails, fall back to local storage
      if (kDebugMode) {
        print('Failed to load cards from backend: $e');
      }
    }
    
    // Fallback to local storage
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(user.id);
    final list = prefs.getStringList(key) ?? <String>[];
    _cards
      ..clear()
      ..addAll(list.map((s) => CardModel.fromJson(s)));
    notifyListeners();
  }

  Future<CardModel> addCard({
    required String type,
    required String network,
    required String numberGroup4,
    required String holder,
    required String month,
    required String year,
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
      createdAt: DateTime.now(),
    );

    try {
      // Persist to backend
      await _api.post('/cards', data: card.toMap());
      
      // Add to local cache on success
      _cards.add(card);
      await _saveAll();
      notifyListeners();
      return card;
    } catch (e) {
      // If backend fails, still save locally for offline functionality
      _cards.add(card);
      await _saveAll();
      notifyListeners();
      
      // Log the error but don't fail the operation
      if (kDebugMode) {
        print('Backend persistence failed for card ${card.id}: $e');
      }
      
      return card;
    }
  }

  Future<void> removeCard(String id) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    try {
      // Delete from backend first
      await _api.delete('/cards/$id');
      
      // Remove from local cache on success
      _cards.removeWhere((c) => c.id == id);
      await _saveAll();
      notifyListeners();
    } catch (e) {
      // If backend fails, still remove locally for offline functionality
      _cards.removeWhere((c) => c.id == id);
      await _saveAll();
      notifyListeners();
      
      // Log the error but don't fail the operation
      if (kDebugMode) {
        print('Backend deletion failed for card $id: $e');
      }
    }
  }

  Future<void> updateCard(CardModel card) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    try {
      // Update in backend first
      await _api.put('/cards/${card.id}', data: card.toMap());
      
      // Update local cache on success
      final index = _cards.indexWhere((c) => c.id == card.id);
      if (index != -1) {
        _cards[index] = card;
        await _saveAll();
        notifyListeners();
      }
    } catch (e) {
      // If backend fails, still update locally for offline functionality
      final index = _cards.indexWhere((c) => c.id == card.id);
      if (index != -1) {
        _cards[index] = card;
        await _saveAll();
        notifyListeners();
      }
      
      // Log the error but don't fail the operation
      if (kDebugMode) {
        print('Backend update failed for card ${card.id}: $e');
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

  /// Syncs local changes with the backend
  Future<void> syncWithBackend() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Get the latest cards from backend
      final response = await _api.get('/cards');
      if (response != null) {
        final List<dynamic> backendCards = response is List ? response : [];
        final backendCardIds = backendCards.map((data) => data['id'] as String).toSet();
        
        // Find cards that exist locally but not on backend (need to be created)
        final cardsToCreate = _cards.where((card) => !backendCardIds.contains(card.id)).toList();
        
        // Create missing cards on backend
        for (final card in cardsToCreate) {
          try {
            await _api.post('/cards', data: card.toMap());
          } catch (e) {
            if (kDebugMode) {
              print('Failed to sync card ${card.id} to backend: $e');
            }
          }
        }
        
        // Reload cards from backend to ensure consistency
        await loadCards();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to sync with backend: $e');
      }
    }
  }

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
}


