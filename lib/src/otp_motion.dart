import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'otp_geometry.dart';

/// Groups the animations for an `OtpAnimatedField` into one [Listenable].
/// The box layout and orbit painter use it to repaint without rebuilding
/// widgets on each animation frame.
class OtpMotion {
  /// Bundles the given animations.
  OtpMotion({
    required this.morph,
    required this.orbit,
    required this.shake,
    required this.success,
  }) : repaint = Listenable.merge([morph, orbit, shake, success]);

  /// Progress from the row (0) to the orbit (1).
  final Animation<double> morph;

  /// Revolutions of the orbit, looping from 0 to 1.
  final Animation<double> orbit;

  /// Progress of the error animation.
  final Animation<double> shake;

  /// Progress of the success animation.
  final Animation<double> success;

  /// Notifies listeners whenever any animation ticks.
  final Listenable repaint;

  static const Curve _travel = Curves.easeInOutCubic;
  static const Curve _converge = Interval(0, 0.45, curve: Curves.easeInCubic);

  // The shake takes the first 60% of the error animation; the rest is a pause
  // that keeps the error color readable before the field resets.
  static const Curve _shakeWindow = Interval(0, 0.6);
  static const int _shakeSwings = 3;

  /// Progress of box [index] out of [length] from the row to the orbit.
  /// Staggers the movement so boxes leave the row one after another.
  double travel(int index, int length) {
    final delay = length > 1 ? math.min(0.08, 0.3 / (length - 1)) : 0.0;
    final window = 1 - delay * (length - 1);
    final local = (morph.value - delay * index) / window;
    return _travel.transform(local.clamp(0.0, 1.0));
  }

  /// How far the boxes have collapsed into the success badge, from 0 to 1.
  double get convergence => _converge.transform(success.value);

  /// Horizontal displacement of the row during the error shake, as a fraction
  /// of the shake amplitude. The displacement decays to zero.
  double get shakeOffset {
    final t = _shakeWindow.transform(shake.value);
    return math.sin(t * _shakeSwings * 2 * math.pi) * (1 - t);
  }
}

/// Positions the boxes of an `OtpAnimatedField` using paint-time transforms.
class OtpFlowDelegate extends FlowDelegate {
  /// Creates a delegate that repaints whenever [motion] ticks.
  OtpFlowDelegate({
    required this.geometry,
    required this.motion,
    required this.shakeAmplitude,
  }) : super(repaint: motion.repaint);

  /// Sizes and positions of the row and orbit.
  final OtpGeometry geometry;

  /// The animations that control box movement.
  final OtpMotion motion;

  /// Peak horizontal displacement of the error shake, in logical pixels.
  final double shakeAmplitude;

  @override
  Size getSize(BoxConstraints constraints) =>
      constraints.constrain(geometry.size);

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(geometry.boxSize));

  @override
  void paintChildren(FlowPaintingContext context) {
    final convergence = motion.convergence;
    final opacity = 1 - convergence;
    if (opacity <= 0) return;

    final shake = Offset(motion.shakeOffset * shakeAmplitude, 0);
    final half = geometry.boxSize / 2;
    for (var i = 0; i < context.childCount; i++) {
      final t = motion.travel(i, context.childCount);
      final onOrbit = geometry.orbitCenter(
        i,
        motion.orbit.value,
        radiusFactor: 1 - convergence,
      );
      final inRow = geometry.rowCenter(i) + shake;
      final center = inRow + (onOrbit - inRow) * t;
      final scale =
          (1 + (geometry.orbitBoxScale - 1) * t) * (1 - 0.7 * convergence);

      // Scale about the box center, then move that center into place.
      final transform = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, center.dx - half * scale)
        ..setEntry(1, 3, center.dy - half * scale);
      context.paintChild(i, transform: transform, opacity: opacity);
    }
  }

  @override
  bool shouldRelayout(OtpFlowDelegate oldDelegate) =>
      geometry != oldDelegate.geometry;

  @override
  bool shouldRepaint(OtpFlowDelegate oldDelegate) =>
      geometry != oldDelegate.geometry ||
      motion != oldDelegate.motion ||
      shakeAmplitude != oldDelegate.shakeAmplitude;
}
