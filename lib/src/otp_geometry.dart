import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme/otp_animated_theme.dart';

/// Resolved sizes and positions for one layout pass of an `OtpAnimatedField`.
///
/// Everything is centered in [size]: the row of boxes and the orbit share the
/// same center, so a box only ever travels between [rowCenter] and
/// [orbitCenter].
@immutable
class OtpGeometry {
  const OtpGeometry._({
    required this.length,
    required this.fit,
    required this.boxSize,
    required this.gap,
    required this.orbitBoxScale,
    required this.orbitRadius,
    required this.size,
  });

  /// Resolves the geometry of [length] boxes styled by [theme] inside
  /// [maxWidth]. When the natural row is wider than [maxWidth], boxes and gaps
  /// shrink proportionally.
  factory OtpGeometry.resolve({
    required int length,
    required OtpAnimatedTheme theme,
    required double maxWidth,
  }) {
    assert(length > 0, 'length must be positive');
    final naturalRowWidth = length * theme.boxSize + (length - 1) * theme.gap;
    final bounded = maxWidth.isFinite && maxWidth > 0;
    final fit = bounded && maxWidth < naturalRowWidth
        ? maxWidth / naturalRowWidth
        : 1.0;
    final boxSize = theme.boxSize * fit;
    final gap = theme.gap * fit;
    final orbitBoxSize = boxSize * theme.orbitBoxScale;

    // Keep neighbours on the orbit one and a half boxes apart, center to
    // center, so longer codes get a wider circle instead of colliding.
    final spacingRadius = length >= 3
        ? orbitBoxSize * 1.5 / (2 * math.sin(math.pi / length))
        : 0.0;
    var orbitRadius =
        theme.orbitRadius ?? math.max(boxSize * 0.83, spacingRadius);
    if (bounded) {
      final widestRadius = maxWidth / 2 - orbitBoxSize * _extentFactor;
      orbitRadius = math.max(0, math.min(orbitRadius, widestRadius));
    }

    final orbitExtent = 2 * (orbitRadius + orbitBoxSize * _extentFactor);
    final rowWidth = length * boxSize + (length - 1) * gap;
    return OtpGeometry._(
      length: length,
      fit: fit,
      boxSize: boxSize,
      gap: gap,
      orbitBoxScale: theme.orbitBoxScale,
      orbitRadius: orbitRadius,
      size: Size(
        math.max(rowWidth, orbitExtent),
        math.max(boxSize, orbitExtent),
      ),
    );
  }

  /// How far past the orbit radius the painted orbit reaches, in orbit box
  /// sizes: half a box diagonal plus room for the glow.
  static const double _extentFactor = 0.75;

  /// Number of boxes.
  final int length;

  /// Scale applied to the themed sizes so the row fits the available width.
  /// 1.0 when nothing had to shrink.
  final double fit;

  /// Side length of a box in the row.
  final double boxSize;

  /// Space between two boxes in the row.
  final double gap;

  /// Size of a box on the orbit relative to [boxSize].
  final double orbitBoxScale;

  /// Radius of the circle the box centers travel on.
  final double orbitRadius;

  /// Size of the whole field with the orbit's space reserved.
  final Size size;

  /// Width of the row of boxes.
  double get rowWidth => length * boxSize + (length - 1) * gap;

  /// Side length of a box on the orbit.
  double get orbitBoxSize => boxSize * orbitBoxScale;

  /// Radius of the thin ring that passes behind the orbiting boxes.
  double get innerRingRadius => orbitRadius + orbitBoxSize * 0.19;

  /// Radius of the dotted ring that hugs the outer corners of the boxes.
  double get outerRingRadius => orbitRadius + orbitBoxSize * 0.62;

  /// Center of the field, shared by the row and the orbit.
  Offset get center => size.center(Offset.zero);

  /// Center of box [index] while it sits in the row.
  Offset rowCenter(int index) {
    final left = (size.width - rowWidth) / 2;
    return Offset(
      left + index * (boxSize + gap) + boxSize / 2,
      size.height / 2,
    );
  }

  /// Angle of box [index] on the orbit before any rotation, in radians.
  ///
  /// The row is wrapped over the top of the circle, so the first and last
  /// boxes travel symmetric paths and digits read clockwise.
  double baseAngle(int index) {
    final step = 2 * math.pi / length;
    return -math.pi / 2 + (index - (length - 1) / 2) * step;
  }

  /// Center of box [index] on the orbit after [turns] revolutions, with the
  /// orbit shrunk to [radiusFactor] of its radius.
  Offset orbitCenter(int index, double turns, {double radiusFactor = 1}) {
    final angle = baseAngle(index) + turns * 2 * math.pi;
    return center + Offset.fromDirection(angle, orbitRadius * radiusFactor);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtpGeometry &&
        other.length == length &&
        other.fit == fit &&
        other.boxSize == boxSize &&
        other.gap == gap &&
        other.orbitBoxScale == orbitBoxScale &&
        other.orbitRadius == orbitRadius &&
        other.size == size;
  }

  @override
  int get hashCode =>
      Object.hash(length, fit, boxSize, gap, orbitBoxScale, orbitRadius, size);
}
