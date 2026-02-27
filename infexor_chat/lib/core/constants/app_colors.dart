import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary gradient
  static const Color accentBlue = Color(
    0xFFFF6B6B,
  ); // Now Orange, keeping name to avoid massive refactor
  static const Color accentPurple = Color(
    0xFFFFA07A,
  ); // Warm complimentary orange
  static const Color primaryPurple = Color(0xFFFF6B6B); // Deep Orange Accent

  // Backgrounds — WhatsApp Light Theme
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF0F2F5);
  static const Color bgCard = Color(0xFFF0F2F5);
  static const Color bgHover = Color(0xFFE9EDEF);

  // Text — Dark text for light backgrounds
  static const Color textPrimary = Color(0xFF111B21);
  static const Color textSecondary = Color(0xFF667781);
  static const Color textMuted = Color(0xFF8696A0);

  // Borders
  static const Color border = Color(0xFFE9EDEF);

  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);
  static const Color online = Color(0xFF2ECC71);

  // Chat Colors (Blue Theme -> Orange Theme)
  static const Color msgSentBg = Color(
    0xFFFFCCAA,
  ); // Light Orange (was Light Blue E3F2FD)
  static const Color msgReceivedBg = Colors.white;
  static const Color checkRead = Color(0xFF34B7F1); // Standard WhatsApp Blue
  static const Color checkSent = Color(0xFF9E9E9E); // Grey
  static const Color badgeBg = Color(0xFFFF6B6B); // Orange (was Blue)
  static const Color fabBg = Color(0xFFFF6B6B); // Orange (was Blue)

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentBlue, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Theme Colors
  static const Color darkBgPrimary = Color(0xFF0B141A); // WhatsApp Dark Bg
  static const Color darkBgSecondary = Color(0xFF202C33); // Appbar/Cards
  static const Color darkInputBg = Color(0xFF2A3942); // Input Field
  static const Color darkMsgSentBg = Color(
    0xFF00AF9C,
  ); // User requested specific blue? Screenshot looks cyan/blue: 0xFF02A8D9 or similar. Standard is Green. Let's use a nice Blue-Cyan as shown.
  // Actually, screenshot shows "Kya haal" in bright blue. Let's use 0xFF00A2FF for sent.
  // Wait, the screenshot sent bubbles are distinct Blue.
  static const Color darkMsgSentBgBlue = Color(0xFF00A2FF);
  static const Color darkMsgReceivedBg = Color(0xFF202C33);
  static const Color darkTextPrimary = Color(0xFFE9EDEF);
  static const Color darkTextSecondary = Color(0xFF8696A0);
}
