import 'package:flutter/material.dart';

/// Reusable verified blue-tick badge widget.
/// Shows a blue checkmark icon next to verified user names.
class VerifiedBadge extends StatelessWidget {
  final double size;

  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(Icons.verified, color: const Color(0xFF1DA1F2), size: size),
    );
  }
}
