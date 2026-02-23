import 'package:flutter/widgets.dart';

/// Centralized motion curves to ensure a consistent, Telegram-like feel globally.
class InfexorCurves {
  /// Primary curve for most elements. Fast start, very smooth long tail.
  /// Perfect for page transitions, bottom sheets.
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Signature "pop" effect used for sent messages and incoming bubbles.
  /// Bounces slightly past 1.0 before settling.
  static const Curve popEntrance = Curves.easeOutBack;

  /// Smooth acceleration/deceleration. Good for shared elements (Hero).
  static const Curve symmetric = Curves.easeInOutCubic;

  /// Snappy entry curve.
  static const Curve fastEntrance = Curves.fastOutSlowIn;
}
