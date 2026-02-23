import 'package:flutter/widgets.dart';

/// Bouncing scroll physics matching Telegram/iOS feel.
/// Always scrollable so the bounce happens even if content is small.
class InfexorScrollPhysics extends BouncingScrollPhysics {
  const InfexorScrollPhysics({ScrollPhysics? parent})
    : super(parent: parent ?? const AlwaysScrollableScrollPhysics());
}
