/// Centralized animation durations mimicking Telegram's responsiveness.
///
/// Fast, snappy micro-interactions and smooth page transitions.
class InfexorDurations {
  /// Extremely fast micro-interactions (e.g., button press down)
  static const Duration micro = Duration(milliseconds: 90);

  /// Small UI updates (e.g., message ticks, rapid state toggles)
  static const Duration small = Duration(milliseconds: 160);

  /// Medium animations (e.g., message enter pop, typical layout shifts)
  static const Duration medium = Duration(milliseconds: 220);

  /// Page transitions and Hero flight durations
  static const Duration page = Duration(milliseconds: 280);

  /// Slower animations (avoid unless necessary for large screen changes)
  static const Duration large = Duration(milliseconds: 350);
}
