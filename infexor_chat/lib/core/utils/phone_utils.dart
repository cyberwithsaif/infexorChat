/// Phone number formatting utilities for display
class PhoneUtils {
  PhoneUtils._();

  /// Format a raw phone number for display.
  /// e.g. "917007800445" → "+91 70078 00445"
  /// e.g. "7007800445"   → "+91 70078 00445"
  /// e.g. "+917007800445" → "+91 70078 00445"
  static String formatPhoneDisplay(String? raw) {
    if (raw == null || raw.isEmpty) return '';

    // Strip non-digit characters except leading +
    String digits = raw.replaceAll(RegExp(r'[^\d]'), '');

    // Handle Indian numbers (91 prefix)
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2); // 10-digit number
      return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
    }

    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }

    // For other formats, just add + prefix if missing and space-group
    if (raw.startsWith('+')) return raw;
    return '+$digits';
  }
}
