import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:otp_animated_fields/otp_animated_fields.dart';
import 'package:otp_animated_fields/src/otp_geometry.dart';

void main() {
  final theme = OtpAnimatedTheme.dark();

  OtpGeometry resolve({int length = 4, double maxWidth = double.infinity}) =>
      OtpGeometry.resolve(length: length, theme: theme, maxWidth: maxWidth);

  test('keeps the themed sizes when there is room', () {
    final geometry = resolve(maxWidth: 400);
    expect(geometry.fit, 1);
    expect(geometry.boxSize, theme.boxSize);
    expect(geometry.rowWidth, 4 * theme.boxSize + 3 * theme.gap);
  });

  test('shrinks boxes and gaps proportionally to fit a narrow width', () {
    final geometry = resolve(length: 6, maxWidth: 240);
    expect(geometry.fit, lessThan(1));
    expect(geometry.rowWidth, closeTo(240, 1e-9));
    expect(
      geometry.gap / geometry.boxSize,
      closeTo(theme.gap / theme.boxSize, 1e-9),
    );
    expect(geometry.size.width, lessThanOrEqualTo(240 + 1e-9));
  });

  test('centers the row horizontally and vertically', () {
    final geometry = resolve();
    final first = geometry.rowCenter(0);
    final last = geometry.rowCenter(3);
    expect(first.dx + last.dx, closeTo(geometry.size.width, 1e-9));
    expect(first.dy, geometry.size.height / 2);
    expect(last.dy, geometry.size.height / 2);
  });

  test(
    'places the boxes evenly on the orbit, mirrored about the vertical axis',
    () {
      final geometry = resolve();
      for (var i = 0; i < 4; i++) {
        final distance =
            (geometry.orbitCenter(i, 0) - geometry.center).distance;
        expect(distance, closeTo(geometry.orbitRadius, 1e-9));
      }
      final first = geometry.orbitCenter(0, 0);
      final last = geometry.orbitCenter(3, 0);
      expect(first.dx + last.dx, closeTo(geometry.size.width, 1e-9));
      expect(first.dy, closeTo(last.dy, 1e-9));
    },
  );

  test('orders the boxes clockwise', () {
    final geometry = resolve();
    for (var i = 0; i < 3; i++) {
      final step = geometry.baseAngle(i + 1) - geometry.baseAngle(i);
      expect(step, closeTo(math.pi / 2, 1e-9));
    }
  });

  test('a full turn brings a box back to where it started', () {
    final geometry = resolve();
    final start = geometry.orbitCenter(1, 0);
    final end = geometry.orbitCenter(1, 1);
    expect((end - start).distance, closeTo(0, 1e-9));
  });

  test('widens the orbit for longer codes so neighbours never touch', () {
    expect(resolve(length: 8).orbitRadius, greaterThan(resolve().orbitRadius));

    for (final length in [3, 4, 5, 6, 8]) {
      final geometry = resolve(length: length);
      final neighbours =
          (geometry.orbitCenter(0, 0) - geometry.orbitCenter(1, 0)).distance;
      // The boxes stay upright, so they clear each other at any angle once
      // their centers are a box diagonal apart.
      expect(
        neighbours,
        greaterThanOrEqualTo(geometry.orbitBoxSize * math.sqrt2),
        reason: 'length $length',
      );
    }
  });

  test('honours an explicit orbit radius', () {
    final geometry = OtpGeometry.resolve(
      length: 4,
      theme: theme.copyWith(orbitRadius: 90),
      maxWidth: double.infinity,
    );
    expect(geometry.orbitRadius, 90);
  });

  test('reserves enough space for the orbit and its rings', () {
    final geometry = resolve();
    expect(
      geometry.size.height,
      greaterThanOrEqualTo(2 * geometry.outerRingRadius),
    );
    expect(geometry.innerRingRadius, lessThan(geometry.outerRingRadius));
  });

  test('handles a single box', () {
    final geometry = resolve(length: 1);
    expect(geometry.rowWidth, theme.boxSize);
    expect(geometry.orbitRadius, greaterThan(0));
  });

  test('equal inputs resolve to equal geometries', () {
    expect(resolve(maxWidth: 300), resolve(maxWidth: 300));
    expect(resolve(maxWidth: 300), isNot(resolve(maxWidth: 200)));
  });
}
