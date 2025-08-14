import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class ProfileService extends ChangeNotifier {
  static String _profileKey(String userId) => 'profile.$userId';
  static String _mpinKey(String userId) => 'mpin.$userId';

  final AuthService _auth;
  ProfileService({required AuthService authService}) : _auth = authService;

  Map<String, dynamic> _profile = {};

  Map<String, dynamic> get profile => _profile;
  String? get name => _profile['name'] as String?;
  String? get phone => _profile['phone'] as String?;
  String? get address => _profile['address'] as String?;
  String? get photoBase64 => _profile['photo'] as String?;

  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey(user.id));
    _profile = raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : {};
    notifyListeners();
  }

  Future<void> saveProfile({String? name, String? phone, String? address, String? photoBase64}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (name != null) _profile['name'] = name;
    if (phone != null) _profile['phone'] = phone;
    if (address != null) _profile['address'] = address;
    if (photoBase64 != null) _profile['photo'] = photoBase64;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(user.id), jsonEncode(_profile));
    notifyListeners();
  }

  Future<void> setMpin(String mpin) async {
    if (mpin.length != 6) {
      throw Exception('MPIN must be 6 digits');
    }
    final user = _auth.currentUser;
    if (user == null) return;
    final hash = sha256.convert(utf8.encode(mpin)).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mpinKey(user.id), hash);
  }

  Future<bool> hasMpin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mpinKey(user.id)) != null;
  }

  Future<bool> verifyMpin(String mpin) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_mpinKey(user.id));
    if (stored == null) return false;
    final hash = sha256.convert(utf8.encode(mpin)).toString();
    return stored == hash;
  }

  Future<bool> requireMpin(BuildContext context) async {
    if (!await hasMpin()) {
      // Ask user to set MPIN first
      if (context.mounted) {
        final set = await _showSetMpinDialog(context);
        if (!set) return false;
      } else {
        return false;
      }
    }
    if (context.mounted) {
      return _showVerifyMpinDialog(context);
    }
    return false;
  }

  Future<bool> _showSetMpinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set 6-digit MPIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.length == 6) {
                if (context.mounted) {
                  await setMpin(controller.text);
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showVerifyMpinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter MPIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (context.mounted) {
                final valid = await verifyMpin(controller.text);
                if (context.mounted) {
                  Navigator.pop(context, valid);
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}


