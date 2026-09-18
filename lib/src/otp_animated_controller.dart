import 'package:flutter/widgets.dart';

import 'otp_status.dart';

/// Controls the text and the verification [status] of an `OtpAnimatedField`.
///
/// It is a [TextEditingController], so [text] and [clear] work as usual, and
/// listeners are notified for both text and status changes.
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
  /// Creates a controller, optionally pre-filled with [text].
  OtpAnimatedController({super.text});

  OtpStatus _status = OtpStatus.idle;

  /// Where the field currently is in its verification lifecycle.
  OtpStatus get status => _status;

  /// Submits the current code: [OtpStatus.idle] -> [OtpStatus.verifying].
  ///
  /// Call this from a "Verify" button when the field's `autoVerify` is off.
  /// Ignored unless the field is idle. If the code is incomplete the field
  /// shakes instead of verifying.
  void verify() {
    if (_status != OtpStatus.idle) return;
    _setStatus(OtpStatus.verifying);
  }

  /// Resolves verification as successful.
  ///
  /// Only needed when the field has no `onVerify` callback. Ignored once the
  /// field is already in [OtpStatus.success] or [OtpStatus.error].
  void succeed() {
    if (_status == OtpStatus.success || _status == OtpStatus.error) return;
    _setStatus(OtpStatus.success);
  }

  /// Resolves verification as failed.
  ///
  /// Only needed when the field has no `onVerify` callback. Ignored once the
  /// field is already in [OtpStatus.success] or [OtpStatus.error].
  void fail() {
    if (_status == OtpStatus.success || _status == OtpStatus.error) return;
    _setStatus(OtpStatus.error);
  }

  /// Returns the field to [OtpStatus.idle] from any status, e.g. after
  /// "Resend code". Clears the entered code unless [clearText] is false.
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
