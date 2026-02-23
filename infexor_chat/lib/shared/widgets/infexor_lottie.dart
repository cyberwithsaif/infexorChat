import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Reusable wrapper for fast, memory-efficient Lottie animations.
/// Lazy loads the animation and handles platform brightness swapping if needed.
class InfexorLottieAnimation extends StatelessWidget {
  final String assetName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool repeat;
  final bool renderCache;

  const InfexorLottieAnimation({
    super.key,
    required this.assetName,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.renderCache = true,
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary ensures the continuous Lottie ticks do not trigger parent repaints.
    return RepaintBoundary(
      child: Lottie.asset(
        assetName,
        width: width,
        height: height,
        fit: fit,
        repeat: repeat,
        options: LottieOptions(enableMergePaths: true),
        // Frame reduction can be enabled if the app needs to save battery,
        // but for Telegram-level feel we generally want the highest possible frame rendering.
      ),
    );
  }
}
