import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF2D5A27);
  static const Color deepGreen = Color(0xFF1A3D18);
  static const Color lightGreen = Color(0xFFE8F5E3);
  static const Color mintBg = Color(0xFFF4F9F1);
  static const Color cardBg = Color(0xFFFAFAFA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE8F0E4);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF4CAF50);
  static const Color info = Color(0xFF2196F3);
  static const Color stemColor = Color(0xFF5C8A3C);
  static const Color potLight = Color(0xFFC8A882);
  static const Color potDark = Color(0xFFB89060);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: '.SF Pro Display',
    scaffoldBackgroundColor: mintBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
  );
}
