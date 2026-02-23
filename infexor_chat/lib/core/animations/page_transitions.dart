import 'package:flutter/material.dart';

/// A custom page route that matches Telegram's slide-and-fade parallax transition.
///
/// Slides in from the right edge.
/// The previous page slightly darkens and slides slowly to the left.
class InfexorPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  InfexorPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // A smooth, snappy curve
          final curve = Curves.fastOutSlowIn;

          final primaryAnimation = CurvedAnimation(
            parent: animation,
            curve: curve,
            reverseCurve: curve,
          );

          final secondaryCurveAnimation = CurvedAnimation(
            parent: secondaryAnimation,
            curve: curve,
            reverseCurve: curve,
          );

          // The incoming page slides in from the right
          final primarySlide = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(primaryAnimation);

          // The outgoing page underneath slides left by 25%
          final secondarySlide = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.25, 0.0),
          ).animate(secondaryCurveAnimation);

          return SlideTransition(
            position: secondarySlide,
            child: SlideTransition(
              position: primarySlide,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  child,
                  // Dimming overlay on the outgoing screen
                  IgnorePointer(
                    child: FadeTransition(
                      opacity: Tween<double>(
                        begin: 0.0,
                        end: 0.3,
                      ).animate(secondaryCurveAnimation),
                      child: Container(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
