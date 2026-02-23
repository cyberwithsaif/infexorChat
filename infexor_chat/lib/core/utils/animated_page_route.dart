import 'package:flutter/material.dart';

enum SlideDirection { right, left, up, down }

/// Reusable page route with combined slide + fade transition.
/// Drop-in replacement for MaterialPageRoute.
class AnimatedPageRoute<T> extends PageRouteBuilder<T> {
  final SlideDirection slideDirection;

  AnimatedPageRoute({
    required WidgetBuilder builder,
    this.slideDirection = SlideDirection.right,
    super.settings,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: const Duration(milliseconds: 450),
         reverseTransitionDuration: const Duration(milliseconds: 400),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final Offset begin;
           switch (slideDirection) {
             case SlideDirection.right:
               begin = const Offset(1.0, 0.0);
             case SlideDirection.left:
               begin = const Offset(-1.0, 0.0);
             case SlideDirection.up:
               begin = const Offset(0.0, 1.0);
             case SlideDirection.down:
               begin = const Offset(0.0, -1.0);
           }

           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.fastOutSlowIn,
             reverseCurve: Curves.fastOutSlowIn,
           );

           return SlideTransition(
             position: Tween<Offset>(
               begin: begin,
               end: Offset.zero,
             ).animate(curved),
             child: FadeTransition(
               opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
               child: child,
             ),
           );
         },
       );
}

/// Fade-only route for auth/splash transitions.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      );
}

/// Scale + fade route for media viewers (images, videos).
class ScaleFadePageRoute<T> extends PageRouteBuilder<T> {
  ScaleFadePageRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
          );
          return ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
}
