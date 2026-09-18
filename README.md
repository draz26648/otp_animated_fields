# otp_animated_fields

A one-time-code (OTP) input for Flutter whose boxes become the loading
indicator. When the code is submitted, the boxes shrink, fly off the row onto a
circle and orbit it until verification resolves. Then they collapse into a check
mark, or fly back to the row and shake.

## Features

- Row to orbit to result, as one continuous animation. No spinner to swap in.
- Two ways to verify: return a `Future<bool>` from `onVerify`, or drive the
  status yourself with a controller (handy for Bloc, or a "Verify" button).
- A real text field underneath, so paste, SMS autofill (`oneTimeCode`), hardware
  keyboards and backspace all behave natively. No `Material` ancestor needed.
- Dark and light presets, or adapts to your app's `Theme` out of the box.
- Boxes shrink to fit narrow screens, and the orbit widens for longer codes so
  6 or 8 boxes never collide.
- Digits stay left to right in RTL locales, respect the user's text scale, and
  status changes are announced to screen readers. Honors "reduce motion".
- Animation runs as paint-only transforms: no widget rebuilds per frame.

## Installation

The package is not on pub.dev yet. Until it is, depend on the repository:

```yaml
dependencies:
  otp_animated_fields:
    git:
      url: https://github.com/draz26648/otp_animated_fields.git
```

Requires Flutter 3.35 or newer.

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

Entering the last digit submits the code. The boxes orbit until the future
resolves: `true` plays the success animation, `false` (or a thrown error, which
is also reported to `FlutterError`) plays the error animation, clears the code
and hands the field back to the user. `onVerified` fires when the success
animation has finished, so it is the right moment to navigate.

### Driving it yourself

Leave `onVerify` out and resolve verification through the controller. This fits
state management where the result arrives somewhere else, like a `BlocListener`:

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

Calling `verify()` on an incomplete code shakes the field and keeps what was
typed. After "Resend code", call `otp.reset()` to return to an empty row from
any state.

| Controller        | Effect                                               |
| ----------------- | ---------------------------------------------------- |
| `text`, `clear()` | It is a `TextEditingController`                      |
| `status`          | `idle`, `verifying`, `success` or `error`            |
| `verify()`        | Submit the code: row to orbit                        |
| `succeed()`       | Orbit to check mark                                  |
| `fail()`          | Orbit to row, shake, then back to `idle`             |
| `reset()`         | Anything to an empty row; `clearText: false` to keep |

## Theming

With no `theme`, the field follows the ambient Material theme: brightness picks
the preset, `colorScheme.primary` becomes the accent and `colorScheme.error` the
error color. Or pick a preset and adjust it:

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

`OtpAnimatedTheme` covers colors, box size, gap, corner radius, glow, the orbit
radius and box scale, and every duration.

## Layout

By default the field is always as tall as the orbit, with the row centered in
it, so nothing around it moves when verification starts. Set
`reserveOrbitSpace: false` for a field that is only as tall as the row and grows
while the boxes travel.

`minimumVerifyingDuration` (1.5 s by default) keeps the boxes in orbit long
enough for the animation to read when the backend answers instantly. Set it to
`Duration.zero` to resolve as soon as possible.

## Other options

| Parameter                              | Purpose                                         |
| -------------------------------------- | ----------------------------------------------- |
| `obscureText`, `obscuringCharacter`    | Hide the digits                                 |
| `keyboardType`, `inputFormatters`      | Alphanumeric codes (defaults to digits only)    |
| `clearOnError`                         | Keep the rejected code instead of clearing it   |
| `enabled`, `focusNode`, `autofocus`    | The usual                                       |
| `hapticFeedback`                       | Vibrate on success and error                    |
| `semanticLabels`                       | Localized screen reader label and announcements |
| `onChanged`, `onCompleted`, `onFailed` | Callbacks                                       |
| `onStatusChanged`                      | Swap the title to "Verifying..." and the like   |

## Testing your app

The cursor blinks on a timer rather than a repeating animation, so
`pumpAndSettle()` settles while the field is focused. It does not settle while
the field is verifying, the same as any progress indicator: resolve the
verification first, or use `pump(duration)`.

## Example

`example/` recreates a full verification card with a theme toggle. `1234` is
accepted, anything else is rejected.

```bash
cd example && flutter run
```

## Contributing

Issues and pull requests are welcome at
[github.com/draz26648/otp_animated_fields](https://github.com/draz26648/otp_animated_fields/issues).

## License

[MIT](LICENSE)
