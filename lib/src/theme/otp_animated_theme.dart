import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

/// A transparent color used to hide the text field behind the boxes.
const Color otpTransparent = Color(0x00000000);

/// Appearance and animation settings for an `OtpAnimatedField`.
///
/// Choose [OtpAnimatedTheme.dark] or [OtpAnimatedTheme.light], or leave the
/// field's `theme` null to follow the surrounding Material [Theme] through
/// [OtpAnimatedTheme.of].
@immutable
class OtpAnimatedTheme {
  /// Creates a theme with custom colors and animation settings.
  const OtpAnimatedTheme({
    required this.fillColor,
    required this.borderColor,
    required this.accentColor,
    required this.ringColor,
    required this.textStyle,
    this.errorColor = const Color(0xFFFF4D4F),
    this.successColor = const Color(0xFF2ECC71),
    this.cursorColor,
    this.keyboardAppearance = Brightness.dark,
    this.boxSize = 58,
    this.gap = 12,
    this.borderRadius = 16,
    this.borderWidth = 1.5,
    this.glowBlurRadius = 18,
    this.orbitBoxScale = 0.64,
    this.orbitRadius,
    this.morphDuration = const Duration(milliseconds: 700),
    this.orbitPeriod = const Duration(milliseconds: 2600),
    this.errorDuration = const Duration(milliseconds: 900),
    this.successDuration = const Duration(milliseconds: 1000),
    this.styleDuration = const Duration(milliseconds: 220),
  }) : assert(boxSize > 0, 'boxSize must be positive'),
       assert(gap >= 0, 'gap cannot be negative'),
       assert(
         orbitBoxScale > 0 && orbitBoxScale <= 1,
         'orbitBoxScale must be in (0, 1]',
       ),
       assert(
         orbitRadius == null || orbitRadius > 0,
         'orbitRadius must be positive',
       );

  /// The dark preset, matching a near-black card.
  factory OtpAnimatedTheme.dark({Color accentColor = const Color(0xFFFF5A3C)}) {
    return OtpAnimatedTheme(
      fillColor: const Color(0xFF1F1F26),
      borderColor: const Color(0xFF34343E),
      accentColor: accentColor,
      ringColor: const Color(0x33FFFFFF),
      textStyle: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
  }

  /// The light preset, matching a white card.
  factory OtpAnimatedTheme.light({
    Color accentColor = const Color(0xFFFF5A3C),
  }) {
    return OtpAnimatedTheme(
      fillColor: const Color(0xFFF4F4F7),
      borderColor: const Color(0xFFDADAE2),
      accentColor: accentColor,
      ringColor: const Color(0x24000000),
      keyboardAppearance: Brightness.light,
      textStyle: const TextStyle(
        color: Color(0xFF16161A),
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
  }

  /// Creates a theme from the surrounding Material [Theme].
  ///
  /// Its brightness selects the preset. Its primary and error colors set the
  /// accent and error colors.
  factory OtpAnimatedTheme.of(BuildContext context) {
    final material = Theme.of(context);
    final scheme = material.colorScheme;
    final preset = material.brightness == Brightness.dark
        ? OtpAnimatedTheme.dark(accentColor: scheme.primary)
        : OtpAnimatedTheme.light(accentColor: scheme.primary);
    return preset.copyWith(errorColor: scheme.error);
  }

  /// Background of every box.
  final Color fillColor;

  /// Border of boxes that are neither focused nor in a result state.
  final Color borderColor;

  /// Border and glow of the focused box, and the color of the orbit.
  final Color accentColor;

  /// Border and glow of the boxes while the error animation plays.
  final Color errorColor;

  /// Color of the success badge and check mark.
  final Color successColor;

  /// Color of the thin inner ring the boxes orbit on.
  final Color ringColor;

  /// Style of the entered characters.
  final TextStyle textStyle;

  /// Color of the blinking cursor. Defaults to the [textStyle] color.
  final Color? cursorColor;

  /// Appearance of the iOS keyboard.
  final Brightness keyboardAppearance;

  /// Side length of a box in the row. The field shrinks boxes automatically
  /// when the row would exceed the available width.
  final double boxSize;

  /// Space between two boxes in the row.
  final double gap;

  /// Corner radius of a box.
  final double borderRadius;

  /// Border width of a box.
  final double borderWidth;

  /// Blur radius of the glow around the focused box.
  final double glowBlurRadius;

  /// Size of a box on the orbit relative to [boxSize].
  final double orbitBoxScale;

  /// Radius of the circle the box centers travel on.
  ///
  /// When null, the radius depends on [boxSize] and grows with the code length
  /// to keep the boxes apart.
  final double? orbitRadius;

  /// How long the boxes take to travel between the row and the orbit.
  final Duration morphDuration;

  /// How long one full revolution of the orbit takes.
  final Duration orbitPeriod;

  /// Length of the error animation: a shake followed by a short pause.
  final Duration errorDuration;

  /// Length of the success animation.
  final Duration successDuration;

  /// How long a box takes to cross-fade between styles, such as on focus changes.
  final Duration styleDuration;

  /// Returns a copy with the given fields replaced.
  OtpAnimatedTheme copyWith({
    Color? fillColor,
    Color? borderColor,
    Color? accentColor,
    Color? errorColor,
    Color? successColor,
    Color? ringColor,
    TextStyle? textStyle,
    Color? cursorColor,
    Brightness? keyboardAppearance,
    double? boxSize,
    double? gap,
    double? borderRadius,
    double? borderWidth,
    double? glowBlurRadius,
    double? orbitBoxScale,
    double? orbitRadius,
    Duration? morphDuration,
    Duration? orbitPeriod,
    Duration? errorDuration,
    Duration? successDuration,
    Duration? styleDuration,
  }) {
    return OtpAnimatedTheme(
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      accentColor: accentColor ?? this.accentColor,
      errorColor: errorColor ?? this.errorColor,
      successColor: successColor ?? this.successColor,
      ringColor: ringColor ?? this.ringColor,
      textStyle: textStyle ?? this.textStyle,
      cursorColor: cursorColor ?? this.cursorColor,
      keyboardAppearance: keyboardAppearance ?? this.keyboardAppearance,
      boxSize: boxSize ?? this.boxSize,
      gap: gap ?? this.gap,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      glowBlurRadius: glowBlurRadius ?? this.glowBlurRadius,
      orbitBoxScale: orbitBoxScale ?? this.orbitBoxScale,
      orbitRadius: orbitRadius ?? this.orbitRadius,
      morphDuration: morphDuration ?? this.morphDuration,
      orbitPeriod: orbitPeriod ?? this.orbitPeriod,
      errorDuration: errorDuration ?? this.errorDuration,
      successDuration: successDuration ?? this.successDuration,
      styleDuration: styleDuration ?? this.styleDuration,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OtpAnimatedTheme &&
        other.fillColor == fillColor &&
        other.borderColor == borderColor &&
        other.accentColor == accentColor &&
        other.errorColor == errorColor &&
        other.successColor == successColor &&
        other.ringColor == ringColor &&
        other.textStyle == textStyle &&
        other.cursorColor == cursorColor &&
        other.keyboardAppearance == keyboardAppearance &&
        other.boxSize == boxSize &&
        other.gap == gap &&
        other.borderRadius == borderRadius &&
        other.borderWidth == borderWidth &&
        other.glowBlurRadius == glowBlurRadius &&
        other.orbitBoxScale == orbitBoxScale &&
        other.orbitRadius == orbitRadius &&
        other.morphDuration == morphDuration &&
        other.orbitPeriod == orbitPeriod &&
        other.errorDuration == errorDuration &&
        other.successDuration == successDuration &&
        other.styleDuration == styleDuration;
  }

  @override
  int get hashCode => Object.hashAll([
    fillColor,
    borderColor,
    accentColor,
    errorColor,
    successColor,
    ringColor,
    textStyle,
    cursorColor,
    keyboardAppearance,
    boxSize,
    gap,
    borderRadius,
    borderWidth,
    glowBlurRadius,
    orbitBoxScale,
    orbitRadius,
    morphDuration,
    orbitPeriod,
    errorDuration,
    successDuration,
    styleDuration,
  ]);
}
