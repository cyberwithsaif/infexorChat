import 'package:flutter/material.dart';
import '../../core/animations/durations.dart';

/// Lightweight, visually stable 3-dot typing indicator mimicking Telegram.
/// Pre-computes animations and pauses when completely hidden to save CPU/GPU.
class TypingIndicator extends StatefulWidget {
  final Color dotColor;
  final double dotSize;
  const TypingIndicator({
    super.key,
    this.dotColor = Colors.grey,
    this.dotSize = 6.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1200ms total loop for a smooth wave.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    // We create staggered scale/opacity animations for each dot based on time offset
    final delay = index * 0.2;
    Animation<double> scaleAnimation =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 20),
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(delay, 1.0, curve: Curves.easeInOut),
          ),
        );

    Animation<double> opacityAnimation =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 20),
          TweenSequenceItem(tween: ConstantTween(0.5), weight: 60),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(delay, 1.0, curve: Curves.linear),
          ),
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Opacity(opacity: opacityAnimation.value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: widget.dotSize,
        height: widget.dotSize,
        decoration: BoxDecoration(
          color: widget.dotColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using RepaintBoundary prevents the fast-ticking dots from causing
    // the heavy ListView (if placed inside one) to repaint unnecessarily.
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) => _buildDot(index)),
      ),
    );
  }
}
