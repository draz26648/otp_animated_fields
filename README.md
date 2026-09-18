# otp_animated_fields

A Flutter input for one-time codes (OTP). When the user submits a code, the
boxes shrink and move from the row into a circular orbit while verification
runs. They collapse into a check mark on success, or return to the row and
shake on failure.

<p align="center">
  <img
    src="https://raw.githubusercontent.com/draz26648/otp_animated_fields/main/doc/demo.gif"
    alt="A user enters a 4-digit code. The boxes move into a circular orbit during verification, then collapse into a green check mark."
    width="320"
  />
</p>

## Features

- The boxes animate continuously from input to loading to result, so you
  don't need a separate spinner.
- Return a `Future<bool>` from `onVerify`, or control verification yourself
  with a controller. The controller also works with Bloc or a Verify button.
- A real text field handles paste, hardware keyboards and backspace, with a
  `oneTimeCode` hint for SMS autofill. The widget doesn't need a `Material`
  ancestor.
- Use the dark or light preset, or let the field follow your app's `Theme`.
- Boxes shrink to fit narrow screens. The orbit widens for longer codes to
  keep 6 or 8 boxes apart.
- Digits stay left to right in RTL locales and follow the user's text scale.
  The field announces status changes to screen readers and respects reduced
  motion preferences.
- The boxes move through transforms applied during painting, without widget
  rebuilds on each animation frame.

## Installation

```bash
flutter pub add otp_animated_fields
```

The package requires Flutter 3.35 or newer.

## Usage

```dart
import 'package:otp_animated_fields/otp_animated_fields.dart';

OtpAnimatedField(
  length: 4,
  autofocus: true,
  onVerify: (code) => authRepository.verifyOtp(code), // Future<bool>
  onVerified: (code) => Navigator.of(context).pushReplacementNamed('/home'),
)
```

Entering the last digit submits the code. Return `true` from `onVerify` to
play the success animation, or `false` to play the error animation. By default,
the field clears a rejected code after the animation and accepts another
attempt. A thrown error also triggers the error animation and is reported to
`FlutterError`.

The boxes orbit while verification runs, subject to `minimumVerifyingDuration`
described below. `onVerified` runs after the success animation finishes, so you
can navigate there without cutting off the animation.

### Driving it yourself

Omit `onVerify` to manage the result through the controller. Use this when
another part of your app receives the result, such as a `BlocListener`:

```dart
final otp = OtpAnimatedController();

OtpAnimatedField(
  controller: otp,
  onCompleted: (code) => context.read<OtpCubit>().verify(code),
)

// BlocListener:
switch (state) {
  case OtpVerified(): otp.succeed();
  case OtpRejected(): otp.fail();
}
```

### Verify button

```dart
OtpAnimatedField(controller: otp, autoVerify: false, onVerify: verify)

FilledButton(onPressed: otp.verify, child: const Text('Verify'))
```

Calling `verify()` on an incomplete code shakes the field and keeps the digits
already entered. After resending a code, call `otp.reset()` to return to an
empty row from any state.

| Controller | Effect |
| ---------- | ------ |
| `text`, `clear()` | Read, set or clear the code through the inherited `TextEditingController` API. |
| `status` | Read the current state: `idle`, `verifying`, `success` or `error`. |
| `verify()` | Submit the code and move the boxes into orbit. |
| `succeed()` | Resolve verification and collapse the boxes into a check mark. |
| `fail()` | Return the boxes to the row, shake, then return to `idle`. |
| `reset()` | Reset from any state to an empty row. Pass `clearText: false` to keep the code. |

## Theming

If you omit `theme`, the field follows the surrounding Material theme. Its
brightness selects the preset, `colorScheme.primary` sets the accent, and
`colorScheme.error` sets the error color. You can also choose a preset and
adjust it:

```dart
OtpAnimatedField(
  theme: OtpAnimatedTheme.dark(accentColor: const Color(0xFFFF5A3C)).copyWith(
    boxSize: 64,
    borderRadius: 20,
    orbitPeriod: const Duration(seconds: 2),
    textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
  ),
)
```

Use `OtpAnimatedTheme` to adjust colors, box size and spacing, corner radius,
glow, orbit radius, the size of orbiting boxes, and animation durations.

## Layout

By default, the field reserves the orbit's full height and centers the row
within it. This keeps nearby content in place when verification starts. Set
`reserveOrbitSpace: false` to start at the row's height and let the field grow
as the boxes move into orbit.

`minimumVerifyingDuration` defaults to 1.5 seconds. It keeps the loading
animation visible when the backend responds quickly. Set it to `Duration.zero`
to show the result as soon as possible.

## Other options

| Parameter | Purpose |
| --------- | ------- |
| `obscureText`, `obscuringCharacter` | Hide the entered digits and choose the character shown in their place. |
| `keyboardType`, `inputFormatters` | Configure input for alphanumeric codes. The default accepts digits only. |
| `clearOnError` | Set to `false` to keep a rejected code instead of clearing it. |
| `enabled`, `focusNode`, `autofocus` | Control whether the field accepts input, manage focus, or focus it when it appears. |
| `hapticFeedback` | Enable vibration on success and error. |
| `semanticLabels` | Supply a localized screen reader label and status announcements. |
| `onChanged`, `onCompleted`, `onFailed` | Respond to edits, a complete code, or a failed attempt after the error animation. |
| `onStatusChanged` | Update surrounding content when the status changes, such as a "Verifying..." title. |

## Testing your app

The cursor uses a timer to blink, so `pumpAndSettle()` can settle while the
field is focused. The repeating orbit animation keeps it from settling during
verification. Resolve verification first, or advance the test with
`pump(duration)`.

## Example

The app in `example/` shows a full verification card with a theme toggle.
Its simulated backend accepts `1234` and rejects every other code.

```bash
cd example && flutter run
```

## Contributing

Report bugs or contribute a pull request on
[github.com/draz26648/otp_animated_fields](https://github.com/draz26648/otp_animated_fields/issues).

## License

[MIT](LICENSE)
