import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _keyNotifications = 'settings.notifications';
  static const _keyDarkMode = 'settings.darkMode';
  static const _keyNetworks = 'settings.networks';
  static const _keyTypes = 'settings.cardTypes';

  // Canonical orders for display
  static const List<String> _allNetworks = <String>[
    'Visa', 'Mastercard', 'Amex', 'Discover', 'RuPay', 'UnionPay',
  ];
  static const List<String> _allTypes = <String>['Debit', 'Credit', 'Forex'];

  bool notifications = true;
  bool darkMode = false;
  final Set<String> _enabledNetworks = _allNetworks.toSet();
  final Set<String> _enabledTypes = _allTypes.toSet();

  List<String> get networks => _allNetworks.where(_enabledNetworks.contains).toList();
  List<String> get cardTypes => _allTypes.where(_enabledTypes.contains).toList();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    notifications = prefs.getBool(_keyNotifications) ?? notifications;
    darkMode = prefs.getBool(_keyDarkMode) ?? darkMode;
    final savedNetworks = prefs.getStringList(_keyNetworks);
    final savedTypes = prefs.getStringList(_keyTypes);
    if (savedNetworks != null && savedNetworks.isNotEmpty) {
      _enabledNetworks
        ..clear()
        ..addAll(savedNetworks);
    }
    if (savedTypes != null && savedTypes.isNotEmpty) {
      _enabledTypes
        ..clear()
        ..addAll(savedTypes);
    }
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    notifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
    notifyListeners();
  }

  Future<void> toggleNetwork(String name, bool enabled) async {
    if (enabled) {
      _enabledNetworks.add(name);
    } else {
      _enabledNetworks.remove(name);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyNetworks, _enabledNetworks.toList());
    notifyListeners();
  }

  Future<void> toggleCardType(String name, bool enabled) async {
    if (enabled) {
      _enabledTypes.add(name);
    } else {
      _enabledTypes.remove(name);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyTypes, _enabledTypes.toList());
    notifyListeners();
  }
}


