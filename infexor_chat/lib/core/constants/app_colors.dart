import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary gradient
  static const Color accentBlue = Color(0xFF2563EB); // Primary Blue
  static const Color accentPurple = Color(0xFF1E40AF); // Secondary Blue
  static const Color primaryPurple = Color(0xFF2563EB); // Primary Blue

  // Backgrounds — Light Theme
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF1F5F9);
  static const Color bgCard = Color(0xFFF1F5F9);
  static const Color bgHover = Color(0xFFE2E8F0);

  // Text — Dark text for light backgrounds
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Borders
  static const Color border = Color(0xFFE2E8F0);

  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);
  static const Color online = Color(0xFF2ECC71);

  // Chat Colors
  static const Color msgSentBg = Color(0xFF2563EB); // Primary Blue sender bubble
  static const Color msgReceivedBg = Color(0xFFE2E8F0); // Slate receiver bubble
  static const Color checkRead = Color(0xFF60A5FA); // Accent Blue
  static const Color checkSent = Color(0xFF9E9E9E); // Grey
  static const Color badgeBg = Color(0xFF2563EB); // Primary Blue
  static const Color fabBg = Color(0xFF2563EB); // Primary Blue

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentBlue, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Theme Colors
  static const Color darkBgPrimary = Color(0xFF0B141A);
  static const Color darkBgSecondary = Color(0xFF202C33);
  static const Color darkInputBg = Color(0xFF2A3942);
  static const Color darkMsgSentBg = Color(0xFF1E40AF); // Secondary Blue
  static const Color darkMsgSentBgBlue = Color(0xFF2563EB); // Primary Blue
  static const Color darkMsgReceivedBg = Color(0xFF202C33);
  static const Color darkTextPrimary = Color(0xFFE9EDEF);
  static const Color darkTextSecondary = Color(0xFF8696A0);
}
