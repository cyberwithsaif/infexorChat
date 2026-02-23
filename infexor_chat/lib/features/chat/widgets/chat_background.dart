import 'package:flutter/material.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;
  final String wallpaperPath;

  const ChatBackground({
    super.key,
    required this.child,
    required this.wallpaperPath,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Wallpaper image background
        Positioned.fill(
          child: Image.asset(
            wallpaperPath,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) =>
                Container(color: const Color(0xFFF0F2F5)),
          ),
        ),
        child,
      ],
    );
  }
}
