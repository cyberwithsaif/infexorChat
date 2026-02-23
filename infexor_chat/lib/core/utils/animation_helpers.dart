import 'package:flutter/material.dart';

/// Wraps a child with tap scale feedback (press = 0.97, release = 1.0).
class TapScaleFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const TapScaleFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
  });

  @override
  State<TapScaleFeedback> createState() => _TapScaleFeedbackState();
}

class _TapScaleFeedbackState extends State<TapScaleFeedback> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onLongPress: widget.onLongPress,
        splashFactory: InkRipple.splashFactory,
        highlightColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        child: AnimatedScale(
          scale: _isPressed ? widget.pressedScale : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Staggered entrance animation for list items.
/// Capped at index 10 to prevent lag on long lists.
class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
        );

    final clampedIndex = widget.index.clamp(0, 10);
    final delay = Duration(milliseconds: 60 * clampedIndex);

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Entrance animation for FAB (scale from 0 to 1 with elastic curve).
class AnimatedFabEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const AnimatedFabEntrance({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 400),
  });

  @override
  State<AnimatedFabEntrance> createState() => _AnimatedFabEntranceState();
}

class _AnimatedFabEntranceState extends State<AnimatedFabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// Entrance animation for new message bubbles (slide + fade from side).
class MessageBubbleEntrance extends StatefulWidget {
  final Widget child;
  final bool isMe;

  const MessageBubbleEntrance({
    super.key,
    required this.child,
    required this.isMe,
  });

  @override
  State<MessageBubbleEntrance> createState() => _MessageBubbleEntranceState();
}

class _MessageBubbleEntranceState extends State<MessageBubbleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // Telegram-style medium duration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    // Pop effect: 0.85 -> 1.0
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    // Slight upward motion (e.g. 10px). Offset Y is relative to size,
    // so begin: (0, 0.1) creates a small shift.
    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
