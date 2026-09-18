/// The verification states of an `OtpAnimatedField`.
enum OtpStatus {
  /// The field accepts input and the boxes sit in a row.
  idle,

  /// The user has submitted a code. The boxes move from the row into a
  /// circular orbit while verification runs.
  verifying,

  /// Verification succeeded. The boxes collapse into a check mark badge and
  /// remain there until the app calls `OtpAnimatedController.reset`.
  success,

  /// Verification failed. The boxes return to the row and shake, then the
  /// field returns to [idle] automatically.
  error,
}
