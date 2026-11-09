import 'package:flutter/material.dart';

/// Motion tokens from the design doc. Only `transform` and `opacity` animate; nothing animates on keyboard actions;
/// reduced motion turns movement into short fades (see [Motion.reduced]).
abstract final class Motion {
  /// Entering things, press feedback.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Things already on screen that move or morph.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Bottom sheets and drawers.
  static const Curve easeDrawer = Cubic(0.32, 0.72, 0, 1);

  static const Duration press = Duration(milliseconds: 110);
  static const Duration pressRelease = Duration(milliseconds: 170);
  static const Duration enter = Duration(milliseconds: 220);
  static const Duration exit = Duration(milliseconds: 140);
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration fade = Duration(milliseconds: 160);

  /// The system "remove animations" / reduce motion setting.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  /// Zero when the user asked for less motion, otherwise [d].
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;

  /// A critically damped spring for things that settle; add [bounce] (0.1-0.3) only when a gesture carried momentum.
  static SpringDescription spring({double bounce = 0, Duration duration = const Duration(milliseconds: 400)}) =>
      SpringDescription.withDurationAndBounce(duration: duration, bounce: bounce);
}
