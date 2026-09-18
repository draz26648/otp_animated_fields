## 0.1.0

* Initial release.
* `OtpAnimatedField` displays a one-time-code input. Its boxes move into a
  circular orbit during verification, then collapse into a check mark on
  success or return to the row and shake on failure.
* `OtpAnimatedController` manages the input text and lets you control
  verification with `verify()`, `succeed()`, `fail()` and `reset()`.
* `OtpAnimatedTheme` provides dark and light presets and can follow the
  surrounding Material theme.
