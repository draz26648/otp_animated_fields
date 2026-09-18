## 0.1.0

* Initial release.
* `OtpAnimatedField`: a one-time-code input whose boxes fly from the row onto
  a circle and orbit it while the code is verified, then collapse into a check
  mark or shake back into the row.
* `OtpAnimatedController`: text plus `verify()`, `succeed()`, `fail()` and
  `reset()` for driving verification manually.
* `OtpAnimatedTheme`: dark and light presets, or derived from the ambient
  Material theme.
