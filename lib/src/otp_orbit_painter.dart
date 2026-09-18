import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/widgets.dart';

import 'otp_geometry.dart';
import 'otp_motion.dart';

/// Paints the thin inner ring and dotted outer ring behind the orbiting boxes.
/// A rotating sweep of the accent color lights the outer ring. On success,
/// paints the check mark badge that the boxes collapse into.
class OtpOrbitPainter extends CustomPainter {
  /// Creates a painter that repaints whenever [motion] ticks.
  OtpOrbitPainter({
    required this.geometry,
    required this.motion,
    required this.accentColor,
    required this.ringColor,
    required this.successColor,
  }) : super(repaint: motion.repaint);

  /// The orbit's size and position.
  final OtpGeometry geometry;

  /// The animations that control the rings and success badge.
  final OtpMotion motion;

  /// Color of the dotted outer ring.
  final Color accentColor;

  /// Color of the thin inner ring.
  final Color ringColor;

  /// Color of the success badge.
  final Color successColor;

  static const Curve _appear = Interval(0.35, 1, curve: Curves.easeOutCubic);
  static const Curve _ringsOut = Interval(0, 0.45, curve: Curves.easeInCubic);
  static const Curve _badgePop = Interval(0.3, 0.75, curve: Curves.easeOutBack);
  static const Curve _checkDraw = Interval(0.55, 1, curve: Curves.easeOutCubic);

  // Arc length between two dots of the outer ring, in logical pixels.
  static const double _dotSpacing = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final appear = _appear.transform(motion.morph.value);
    final success = motion.success.value;
    final center = size.center(Offset.zero);

    final ringsOut = _ringsOut.transform(success);
    final ringsOpacity = appear * (1 - ringsOut);
    if (ringsOpacity > 0) {
      // Grows from 60% as it appears, shrinks to 55% as success takes over.
      final scale = (0.6 + 0.4 * appear) * (1 - 0.45 * ringsOut);
      _paintRings(canvas, center, scale, ringsOpacity);
    }
    if (success > 0) _paintBadge(canvas, center, success);
  }

  void _paintRings(Canvas canvas, Offset center, double scale, double opacity) {
    final innerRadius = geometry.innerRingRadius * scale;
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ringColor.withValues(alpha: ringColor.a * opacity),
    );

    final outerRadius = geometry.outerRingRadius * scale;
    final dotCount = math.max(
      12,
      (2 * math.pi * outerRadius / _dotSpacing).round(),
    );
    final dots = [
      for (var i = 0; i < dotCount; i++)
        center + Offset.fromDirection(i * 2 * math.pi / dotCount, outerRadius),
    ];

    // The sweep runs against the boxes; its bright seam reads as a comet head.
    final sweep = SweepGradient(
      colors: [
        accentColor.withValues(alpha: 0.1 * opacity),
        accentColor.withValues(alpha: opacity),
      ],
      transform: GradientRotation(-motion.orbit.value * 2 * math.pi),
    );
    canvas.drawPoints(
      PointMode.points,
      dots,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8
        ..shader = sweep.createShader(
          Rect.fromCircle(center: center, radius: outerRadius),
        ),
    );
  }

  void _paintBadge(Canvas canvas, Offset center, double success) {
    final radius =
        geometry.innerRingRadius * 0.7 * _badgePop.transform(success);
    if (radius <= 0) return;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = successColor.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = successColor,
    );

    final drawn = _checkDraw.transform(success);
    if (drawn <= 0) return;
    final check = Path()
      ..moveTo(center.dx - radius * 0.42, center.dy + radius * 0.02)
      ..lineTo(center.dx - radius * 0.12, center.dy + radius * 0.32)
      ..lineTo(center.dx + radius * 0.45, center.dy - radius * 0.3);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, radius * 0.13)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = successColor;
    for (final metric in check.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * drawn), stroke);
    }
  }

  @override
  bool shouldRepaint(OtpOrbitPainter oldDelegate) =>
      geometry != oldDelegate.geometry ||
      motion != oldDelegate.motion ||
      accentColor != oldDelegate.accentColor ||
      ringColor != oldDelegate.ringColor ||
      successColor != oldDelegate.successColor;
}
