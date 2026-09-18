import 'package:flutter/widgets.dart';

import 'otp_status.dart';

/// Controls the text and the verification [status] of an `OtpAnimatedField`.
///
/// Extends [TextEditingController], so you can use [text] and [clear] as usual.
/// Notifies listeners when either the text or the status changes.
///
/// ```dart
/// final otp = OtpAnimatedController();
///
/// otp.verify();   // row -> orbit
/// otp.succeed();  // orbit -> check mark
/// otp.fail();     // orbit -> row, shake, back to idle
/// otp.reset();    // anything -> empty row
/// ```
class OtpAnimatedController extends TextEditingController {
  /// Creates a controller with optional initial [text].
  OtpAnimatedController({super.text});

  OtpStatus _status = OtpStatus.idle;

  /// The field's current verification state.
  OtpStatus get status => _status;

  /// Submits the current code: [OtpStatus.idle] -> [OtpStatus.verifying].
  ///
  /// Call this from a "Verify" button when the field's `autoVerify` is off.
  /// Has no effect unless the field is idle. If the code is incomplete, the
  /// field shakes instead of starting verification.
  void verify() {
    if (_status != OtpStatus.idle) return;
    _setStatus(OtpStatus.verifying);
  }

  /// Resolves verification as successful.
  ///
  /// Use this when the field has no `onVerify` callback. Has no effect once
  /// the field is in [OtpStatus.success] or [OtpStatus.error].
  void succeed() {
    if (_status == OtpStatus.success || _status == OtpStatus.error) return;
    _setStatus(OtpStatus.success);
  }

  /// Resolves verification as failed.
  ///
  /// Use this when the field has no `onVerify` callback. Has no effect once
  /// the field is in [OtpStatus.success] or [OtpStatus.error].
  void fail() {
    if (_status == OtpStatus.success || _status == OtpStatus.error) return;
    _setStatus(OtpStatus.error);
  }

  /// Returns the field to [OtpStatus.idle] from any status, for example after
  /// resending a code. Clears the entered code unless [clearText] is false.
  void reset({bool clearText = true}) {
    final statusChanged = _status != OtpStatus.idle;
    _status = OtpStatus.idle;
    if (clearText && text.isNotEmpty) {
      // Assigning the value notifies listeners, covering the status change too.
      value = TextEditingValue.empty;
    } else if (statusChanged) {
      notifyListeners();
    }
  }

  void _setStatus(OtpStatus next) {
    _status = next;
    notifyListeners();
  }
}
