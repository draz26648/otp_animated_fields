import 'package:flutter_test/flutter_test.dart';
import 'package:otp_animated_fields/otp_animated_fields.dart';

void main() {
  late OtpAnimatedController controller;
  late int notifications;

  setUp(() {
    controller = OtpAnimatedController();
    notifications = 0;
    controller.addListener(() => notifications++);
  });

  tearDown(() => controller.dispose());

  test('starts idle and empty', () {
    expect(controller.status, OtpStatus.idle);
    expect(controller.text, isEmpty);
  });

  test('can be pre-filled', () {
    final prefilled = OtpAnimatedController(text: '12');
    addTearDown(prefilled.dispose);
    expect(prefilled.text, '12');
  });

  test('verify moves idle to verifying and notifies', () {
    controller.verify();
    expect(controller.status, OtpStatus.verifying);
    expect(notifications, 1);
  });

  test('verify is ignored unless idle', () {
    controller.verify();
    controller.verify();
    expect(notifications, 1);

    controller.succeed();
    controller.verify();
    expect(controller.status, OtpStatus.success);
  });

  test('succeed and fail resolve verification', () {
    controller.verify();
    controller.succeed();
    expect(controller.status, OtpStatus.success);

    final other = OtpAnimatedController()..verify();
    addTearDown(other.dispose);
    other.fail();
    expect(other.status, OtpStatus.error);
  });

  test('succeed and fail work without a verifying phase', () {
    controller.fail();
    expect(controller.status, OtpStatus.error);

    final other = OtpAnimatedController()..succeed();
    addTearDown(other.dispose);
    expect(other.status, OtpStatus.success);
  });

  test('a result cannot be overturned without a reset', () {
    controller.succeed();
    controller.fail();
    expect(controller.status, OtpStatus.success);

    controller.reset();
    controller.fail();
    controller.succeed();
    expect(controller.status, OtpStatus.error);
  });

  test('reset returns to idle and clears the text in one notification', () {
    controller.text = '1234';
    controller.succeed();
    notifications = 0;

    controller.reset();

    expect(controller.status, OtpStatus.idle);
    expect(controller.text, isEmpty);
    expect(notifications, 1);
  });

  test('reset can keep the text', () {
    controller.text = '1234';
    controller.fail();

    controller.reset(clearText: false);

    expect(controller.status, OtpStatus.idle);
    expect(controller.text, '1234');
  });

  test('reset on a fresh controller does not notify', () {
    controller.reset();
    expect(notifications, 0);
  });
}
