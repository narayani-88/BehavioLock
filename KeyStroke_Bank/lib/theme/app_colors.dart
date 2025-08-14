import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF4361EE);
  static const Color primaryLight = Color(0xFF4895EF);
  static const Color primaryDark = Color(0xFF3F37C9);
  
  // Secondary colors
  static const Color secondary = Color(0xFF4CC9F0);
  static const Color accent = Color(0xFFF72585);
  
  // Background colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFE63946);
  
  // Text colors
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textLight = Color(0xFFF8F9FA);
  
  // Border colors
  static const Color border = Color(0xFFE9ECEF);
  static const Color borderLight = Color(0xFFF1F3F5);
  
  // Status colors
  static const Color success = Color(0xFF52B788);
  static const Color warning = Color(0xFFFFD166);
  static const Color info = Color(0xFF4CC9F0);
  
  // Transaction type colors
  static const Color deposit = Color(0xFF2EC4B6);
  static const Color withdrawal = Color(0xFFFF9F1C);
  static const Color transfer = Color(0xFF7209B6);
  
  // Shimmer colors
  static const Color shimmerBase = Color(0xFFE9ECEF);
  static const Color shimmerHighlight = Color(0xFFF8F9FA);
  
  // Card shadow
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
  
  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
}
