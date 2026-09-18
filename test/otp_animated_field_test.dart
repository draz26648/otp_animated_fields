import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_animated_fields/otp_animated_fields.dart';
import 'package:otp_animated_fields/src/otp_box.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester,
    Widget field, {
    TextDirection textDirection = TextDirection.ltr,
    MediaQueryData? mediaQuery,
    double? width,
  }) {
    Widget child = Center(
      child: SizedBox(width: width, child: field),
    );
    if (mediaQuery != null) child = MediaQuery(data: mediaQuery, child: child);
    return tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
  }

  List<Offset> boxCenters(WidgetTester tester) => [
    for (final element in find.byType(OtpBox).evaluate())
      tester.getCenter(find.byWidget(element.widget)),
  ];

  group('input', () {
    testWidgets('renders one box per character', (tester) async {
      await pumpField(tester, const OtpAnimatedField(length: 6));
      expect(find.byType(OtpBox), findsNWidgets(6));
    });

    for (final direction in TextDirection.values) {
      testWidgets('shows digits left to right in ${direction.name}', (
        tester,
      ) async {
        await pumpField(
          tester,
          const OtpAnimatedField(),
          textDirection: direction,
        );
        await type(tester, '12');
        await tester.pump(const Duration(milliseconds: 300));

        final first = tester.getCenter(find.text('1'));
        final second = tester.getCenter(find.text('2'));
        expect(first.dx, lessThan(second.dx));
        expect(first.dy, second.dy);
      });
    }

    testWidgets('drops non-digits and anything past the length', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(controller: controller, autoVerify: false),
      );

      await type(tester, '1a2-3 4567');

      expect(controller.text, '1234');
    });

    testWidgets('accepts custom formatters for alphanumeric codes', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          autoVerify: false,
          keyboardType: TextInputType.visiblePassword,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
          ],
        ),
      );

      await type(tester, 'a1-B2');

      expect(controller.text, 'a1B2');
    });

    testWidgets('reports changes and completion', (tester) async {
      final changes = <String>[];
      final completions = <String>[];
      await pumpField(
        tester,
        OtpAnimatedField(
          autoVerify: false,
          onChanged: changes.add,
          onCompleted: completions.add,
        ),
      );

      await type(tester, '12');
      await type(tester, '1234');

      expect(changes, ['12', '1234']);
      expect(completions, ['1234']);
    });

    testWidgets('hides characters when obscured', (tester) async {
      await pumpField(
        tester,
        const OtpAnimatedField(obscureText: true, autoVerify: false),
      );

      await type(tester, '12');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1'), findsNothing);
      expect(find.text('•'), findsNWidgets(2));
    });

    testWidgets('clamps a programmatic value to the length', (tester) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(controller: controller, autoVerify: false),
      );

      controller.text = '123456';
      await tester.pump();

      expect(controller.text, '1234');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });

    testWidgets('ignores input when disabled', (tester) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(controller: controller, enabled: false),
      );

      await tester.tap(find.byType(OtpAnimatedField), warnIfMissed: false);
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('tapping opens the keyboard', (tester) async {
      await pumpField(tester, const OtpAnimatedField());

      await tester.tap(find.byType(OtpAnimatedField));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('settles while focused so host app tests do not hang', (
      tester,
    ) async {
      await pumpField(tester, const OtpAnimatedField(autofocus: true));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

  group('verifying with onVerify', () {
    testWidgets('submits once complete and lands on success', (tester) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      final result = Completer<bool>();
      final submitted = <String>[];
      final statuses = <OtpStatus>[];
      final verified = <String>[];
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          onVerify: (code) {
            submitted.add(code);
            return result.future;
          },
          onStatusChanged: statuses.add,
          onVerified: verified.add,
        ),
      );

      await type(tester, '1234');
      expect(submitted, ['1234']);
      expect(controller.status, OtpStatus.verifying);

      result.complete(true);
      await tester.pump();
      expect(controller.status, OtpStatus.success);
      expect(verified, isEmpty, reason: 'waits for the animation');

      await tester.pumpAndSettle();
      expect(verified, ['1234']);
      expect(statuses, [OtpStatus.verifying, OtpStatus.success]);
      expect(controller.text, '1234');
    });

    testWidgets('shakes, clears and returns to idle on failure', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      final statuses = <OtpStatus>[];
      final failed = <String>[];
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          onVerify: (code) async => false,
          onStatusChanged: statuses.add,
          onFailed: failed.add,
        ),
      );

      await type(tester, '1234');
      await tester.pumpAndSettle();

      expect(statuses, [OtpStatus.verifying, OtpStatus.error, OtpStatus.idle]);
      expect(failed, ['1234']);
      expect(controller.text, isEmpty);
    });

    testWidgets('keeps the code after a failure when clearOnError is off', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          clearOnError: false,
          onVerify: (code) async => false,
        ),
      );

      await type(tester, '1234');
      await tester.pumpAndSettle();

      expect(controller.status, OtpStatus.idle);
      expect(controller.text, '1234');
    });

    testWidgets('holds the orbit for the minimum duration', (tester) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      final verified = <String>[];
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          theme: OtpAnimatedTheme.dark().copyWith(
            successDuration: const Duration(milliseconds: 100),
          ),
          minimumVerifyingDuration: const Duration(seconds: 3),
          onVerify: (code) async => true,
          onVerified: verified.add,
        ),
      );

      await type(tester, '1234');
      await tester.pump(const Duration(milliseconds: 2900));
      await tester.pump();
      expect(verified, isEmpty);

      await tester.pumpAndSettle();
      expect(verified, ['1234']);
    });

    testWidgets('locks the input while verifying', (tester) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          onVerify: (code) => Completer<bool>().future,
        ),
      );

      await type(tester, '1234');
      await type(tester, '99');

      expect(controller.text, '1234');
    });

    testWidgets('treats a thrown error as a failure and reports it', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          onVerify: (code) async => throw StateError('offline'),
        ),
      );

      await type(tester, '1234');
      await tester.pump();

      expect(tester.takeException(), isStateError);
      expect(controller.status, OtpStatus.error);
      await tester.pumpAndSettle();
      expect(controller.status, OtpStatus.idle);
    });

    testWidgets('is safe to remove while verification is in flight', (
      tester,
    ) async {
      final result = Completer<bool>();
      await pumpField(
        tester,
        OtpAnimatedField(onVerify: (code) => result.future),
      );
      await type(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(const SizedBox());
      result.complete(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('verifying with the controller', () {
    testWidgets('waits for verify() when autoVerify is off', (tester) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      final failed = <String>[];
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          autoVerify: false,
          onFailed: failed.add,
        ),
      );

      await type(tester, '1234');
      expect(controller.status, OtpStatus.idle);

      controller.verify();
      await tester.pump();
      expect(controller.status, OtpStatus.verifying);

      controller.fail();
      await tester.pumpAndSettle();
      expect(controller.status, OtpStatus.idle);
      expect(failed, ['1234']);
    });

    testWidgets('rejects an incomplete code with a shake and keeps it', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      final statuses = <OtpStatus>[];
      final failed = <String>[];
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          autoVerify: false,
          onStatusChanged: statuses.add,
          onFailed: failed.add,
        ),
      );

      await type(tester, '12');
      controller.verify();
      await tester.pumpAndSettle();

      expect(statuses, [OtpStatus.error, OtpStatus.idle]);
      expect(failed, isEmpty, reason: 'nothing was verified');
      expect(controller.text, '12');
    });

    testWidgets('succeed() without a verifying phase still reaches success', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      final verified = <String>[];
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          autoVerify: false,
          onVerified: verified.add,
        ),
      );

      await type(tester, '1234');
      controller.succeed();
      await tester.pumpAndSettle();

      expect(verified, ['1234']);
    });

    testWidgets('reset() brings a verified field back to an empty row', (
      tester,
    ) async {
      final controller = OtpAnimatedController();
      addTearDown(controller.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(
          controller: controller,
          onVerify: (code) async => true,
        ),
      );
      await type(tester, '1234');
      await tester.pumpAndSettle();
      expect(controller.status, OtpStatus.success);

      controller.reset();
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
      final centers = boxCenters(tester);
      expect(centers.map((c) => c.dy).toSet(), hasLength(1));
      await type(tester, '5');
      expect(controller.text, '5');
    });

    testWidgets('follows a swapped controller', (tester) async {
      final first = OtpAnimatedController();
      final second = OtpAnimatedController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await pumpField(
        tester,
        OtpAnimatedField(controller: first, autoVerify: false),
      );
      await pumpField(
        tester,
        OtpAnimatedField(controller: second, autoVerify: false),
      );

      await type(tester, '42');

      expect(first.text, isEmpty);
      expect(second.text, '42');
    });
  });

  group('motion', () {
    for (final direction in TextDirection.values) {
      testWidgets('moves the row onto a circle in ${direction.name}', (
        tester,
      ) async {
        await pumpField(
          tester,
          OtpAnimatedField(onVerify: (code) => Completer<bool>().future),
          textDirection: direction,
        );
        final fieldCenter = tester.getCenter(find.byType(OtpAnimatedField));
        final row = boxCenters(tester);
        expect(row.map((c) => c.dy).toSet(), hasLength(1));
        expect(
          row.map((c) => c.dx),
          orderedEquals(row.map((c) => c.dx).toList()..sort()),
        );

        await type(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        final orbit = boxCenters(tester);
        final distances = orbit.map((c) => (c - fieldCenter).distance);
        expect(distances.first, greaterThan(0));
        for (final distance in distances) {
          expect(distance, closeTo(distances.first, 1e-6));
        }

        await tester.pump(const Duration(milliseconds: 400));
        expect(boxCenters(tester), isNot(orbit), reason: 'keeps orbiting');
      });
    }

    testWidgets('reserves the orbit height by default', (tester) async {
      await pumpField(
        tester,
        OtpAnimatedField(onVerify: (code) => Completer<bool>().future),
      );
      final idle = tester.getSize(find.byType(OtpAnimatedField));

      await type(tester, '1234');
      await tester.pump(const Duration(seconds: 1));

      expect(tester.getSize(find.byType(OtpAnimatedField)), idle);
    });

    testWidgets('grows from the row height when the orbit is not reserved', (
      tester,
    ) async {
      final theme = OtpAnimatedTheme.dark();
      await pumpField(
        tester,
        OtpAnimatedField(
          theme: theme,
          reserveOrbitSpace: false,
          onVerify: (code) => Completer<bool>().future,
        ),
      );
      expect(
        tester.getSize(find.byType(OtpAnimatedField)).height,
        theme.boxSize,
      );

      await type(tester, '1234');
      await tester.pump(const Duration(seconds: 1));

      expect(
        tester.getSize(find.byType(OtpAnimatedField)).height,
        greaterThan(theme.boxSize * 2),
      );
    });

    testWidgets('skips the flight when animations are disabled', (
      tester,
    ) async {
      await pumpField(
        tester,
        OtpAnimatedField(onVerify: (code) => Completer<bool>().future),
        mediaQuery: const MediaQueryData(disableAnimations: true),
      );
      final fieldCenter = tester.getCenter(find.byType(OtpAnimatedField));

      await type(tester, '1234');
      await tester.pump();

      final distances = boxCenters(
        tester,
      ).map((c) => (c - fieldCenter).distance);
      for (final distance in distances) {
        expect(distance, closeTo(distances.first, 1e-6));
      }
    });
  });

  group('accessibility and layout', () {
    testWidgets('labels the text field for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpField(
        tester,
        const OtpAnimatedField(
          semanticLabels: OtpSemanticLabels(field: 'رمز التحقق'),
        ),
        textDirection: TextDirection.rtl,
      );

      expect(find.bySemanticsLabel('رمز التحقق'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('announces verification progress', (tester) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final event = message as Map<dynamic, dynamic>;
            if (event['type'] == 'announce') {
              final data = event['data'] as Map<dynamic, dynamic>;
              announcements.add(data['message'] as String);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await pumpField(
        tester,
        OtpAnimatedField(onVerify: (code) async => false),
      );

      await type(tester, '1234');
      await tester.pumpAndSettle();

      expect(announcements, ['Verifying code', 'Incorrect code']);
    });

    for (final direction in TextDirection.values) {
      testWidgets('survives 2x text scale in ${direction.name}', (
        tester,
      ) async {
        await pumpField(
          tester,
          const OtpAnimatedField(length: 6, autoVerify: false),
          textDirection: direction,
          mediaQuery: const MediaQueryData(textScaler: TextScaler.linear(2)),
        );

        await type(tester, '888888');
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        final box = tester.getRect(find.byType(OtpBox).first);
        final digit = tester.getRect(find.text('8').first);
        expect(box.contains(digit.topLeft), isTrue);
        expect(box.contains(digit.bottomRight), isTrue);
      });
    }

    testWidgets('shrinks to fit a narrow parent', (tester) async {
      await pumpField(
        tester,
        const OtpAnimatedField(length: 6, autoVerify: false),
        width: 220,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(OtpAnimatedField)).width,
        lessThanOrEqualTo(220),
      );
      final boxes = find.byType(OtpBox);
      expect(
        tester.getRect(boxes.last).right - tester.getRect(boxes.first).left,
        lessThanOrEqualTo(220 + 1e-6),
      );
    });

    testWidgets('adapts to the ambient Material theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          home: const Scaffold(body: Center(child: OtpAnimatedField())),
        ),
      );
      final context = tester.element(find.byType(OtpAnimatedField));

      final theme = OtpAnimatedTheme.of(context);

      expect(theme.accentColor, Theme.of(context).colorScheme.primary);
      expect(theme.errorColor, Theme.of(context).colorScheme.error);
      expect(theme.keyboardAppearance, Brightness.light);
    });
  });
}
