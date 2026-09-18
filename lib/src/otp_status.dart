/// The verification lifecycle of an `OtpAnimatedField`.
enum OtpStatus {
  /// The field accepts input and the boxes sit in a row.
  idle,

  /// A code was submitted. The boxes leave the row and orbit a circle until
  /// verification resolves.
  verifying,

  /// Verification succeeded. The boxes collapse into a check mark badge and
  /// the field stays there until `OtpAnimatedController.reset` is called.
  success,

  /// Verification failed. The boxes fly back to the row and shake, then the
  /// field returns to [idle] on its own.
  error,
}
