import 'dart:ui';
import 'package:flutter/material.dart';

/// GPU-accelerated frosted glass effect mimicking Telegram's top/bottom bars.
/// Uses [RepaintBoundary] to ensure blur computations don't leak into scroll paths.
class GlassMorphism extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;

  const GlassMorphism({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.65,
    this.color = Colors.black,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            color: color.withValues(alpha: opacity),
            child: child,
          ),
        ),
      ),
    );
  }
}
