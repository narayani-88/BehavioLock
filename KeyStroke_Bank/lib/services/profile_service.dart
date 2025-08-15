import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'auth_service.dart';
import 'api_service.dart';

class ProfileService extends ChangeNotifier {
  final AuthService _auth;
  final ApiService _api;
  final _logger = Logger('ProfileService');

  ProfileService({
    required AuthService authService,
    required ApiService apiService,
  }) : _auth = authService,
       _api = apiService;

  Map<String, dynamic> _profile = {};
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get profile => _profile;
  String? get name => _profile['name'] as String?;
  String? get phone => _profile['phone'] as String?;
  String? get address => _profile['address'] as String?;
  String? get photoBase64 => _profile['photo'] as String?;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/api/profiles');
      _logger.fine('Profile API response: $response');

      if (response['status'] == 'success') {
        _profile = Map<String, dynamic>.from(response['data'] ?? {});
        _logger.info('Loaded profile from API');
      } else {
        throw Exception(response['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      _error = 'Failed to load profile: ${e.toString()}';
      _logger.severe('Error loading profile', e);
      // Don't rethrow - allow app to work with empty profile
      _profile = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile({
    String? name,
    String? phone,
    String? address,
    String? photoBase64,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requestData = <String, dynamic>{};
      if (name != null) requestData['name'] = name;
      if (phone != null) requestData['phone'] = phone;
      if (address != null) requestData['address'] = address;
      if (photoBase64 != null) requestData['photo'] = photoBase64;

      final response = await _api.post('/api/profiles', data: requestData);
      _logger.fine('Save profile response: $response');

      if (response['status'] == 'success') {
        // Update local profile with response data
        _profile = Map<String, dynamic>.from(response['data'] ?? {});
        _logger.info('Profile saved successfully');
      } else {
        throw Exception(response['message'] ?? 'Failed to save profile');
      }
    } catch (e) {
      _error = 'Failed to save profile: ${e.toString()}';
      _logger.severe('Error saving profile', e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setMpin(String mpin) async {
    if (mpin.length != 6) {
      throw Exception('MPIN must be 6 digits');
    }

    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(
        '/api/profiles/mpin',
        data: {'mpin': mpin},
      );
      _logger.fine('Set MPIN response: $response');

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Failed to set MPIN');
      }

      _logger.info('MPIN set successfully');
    } catch (e) {
      _error = 'Failed to set MPIN: ${e.toString()}';
      _logger.severe('Error setting MPIN', e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> hasMpin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _api.get('/api/profiles/mpin/exists');
      _logger.fine('Check MPIN exists response: $response');

      if (response['status'] == 'success') {
        return response['exists'] == true;
      }
      return false;
    } catch (e) {
      _logger.warning('Error checking MPIN existence', e);
      return false;
    }
  }

  Future<bool> verifyMpin(String mpin) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _api.post(
        '/api/profiles/mpin/verify',
        data: {'mpin': mpin},
      );
      _logger.fine('Verify MPIN response: $response');

      if (response['status'] == 'success') {
        return response['verified'] == true;
      }
      return false;
    } catch (e) {
      _logger.warning('Error verifying MPIN', e);
      return false;
    }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.length == 6) {
                if (context.mounted) {
                  try {
                    await setMpin(controller.text);
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to set MPIN: $e')),
                      );
                    }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
