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
    final isDefault =
        wallpaperPath == 'assets/images/chatwallpaper.jpg' ||
        wallpaperPath.isEmpty;

    return Stack(
      children: [
        if (isDefault)
          // Solid background with subtle plus pattern drawn by CustomPainter for the default theme
          Positioned.fill(
            child: CustomPaint(
              painter: _PatternPainter(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          )
        else
          // User's custom selected wallpaper image
          Positioned.fill(
            child: Image.asset(
              wallpaperPath,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) =>
                  Container(color: Theme.of(context).scaffoldBackgroundColor),
            ),
          ),
        child,
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final bool isDark;

  _PatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = isDark ? const Color(0xFF0D1418) : const Color(0xFFFFFFFF);
    final patternColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : const Color(0xFFFF6B6B).withValues(alpha: 0.05);

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // Draw Plus Patterns
    final paint = Paint()
      ..color = patternColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const double spacing = 40.0;
    const double length = 6.0;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        // Horizontal line of the plus
        canvas.drawLine(Offset(x - length, y), Offset(x + length, y), paint);
        // Vertical line of the plus
        canvas.drawLine(Offset(x, y - length), Offset(x, y + length), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
