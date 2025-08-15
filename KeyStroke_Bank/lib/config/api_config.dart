import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // For web, try multiple possible URLs
      // You can change this to your specific network IP if needed
      return 'http://localhost:5000'; // Default for web
    } else {
      // For mobile platforms
      if (Platform.isAndroid) {
        // Check if running on emulator or physical device
        // For now, default to emulator URL - change to localhost:5000 for physical device
        return 'http://10.0.2.2:5000';
      } else if (Platform.isIOS) {
        return 'http://localhost:5000';
      } else {
        return 'http://localhost:5000';
      }
    }
  }
  
  static String get webBaseUrl => 'http://localhost:5000';
  
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
}
