import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme/otp_animated_theme.dart';

/// The visual states of a single box.
enum OtpBoxVisual {
  /// Waiting for a character.
  empty,

  /// Holds the cursor.
  active,

  /// Holds a character.
  filled,

  /// Moving into orbit or orbiting during verification.
  orbiting,

  /// Verification failed.
  error,

  /// Verification succeeded.
  success,

  /// The field is disabled.
  disabled,
}

/// A rounded box that shows a character or blinking cursor in an
/// `OtpAnimatedField`. Cross-fades between [OtpBoxVisual] states.
class OtpBox extends StatelessWidget {
  /// Creates a box.
  const OtpBox({
    super.key,
    required this.character,
    required this.visual,
    required this.theme,
    required this.fit,
    required this.showCursor,
    required this.cursorVisible,
  });

  /// The character to show, or an empty string.
  final String character;

  /// The current visual state.
  final OtpBoxVisual visual;

  /// Colors, sizes and timings.
  final OtpAnimatedTheme theme;

  /// Scale applied to the themed sizes so the row fits the available width.
  final double fit;

  /// Whether this box holds the cursor.
  final bool showCursor;

  /// Controls cursor visibility during blinking.
  final ValueListenable<bool> cursorVisible;

  // Proportions of a box, as fractions of its side.
  static const double _characterInset = 0.14;
  static const double _cursorHeight = 0.4;

  @override
  Widget build(BuildContext context) {
    final side = theme.boxSize * fit;
    final Widget content;
    if (character.isNotEmpty) {
      final style = theme.textStyle;
      final inset = side * _characterInset;
      content = Padding(
        key: ValueKey(character),
        padding: EdgeInsets.all(inset),
        // Follows the user's text scale until the box is full, then fits
        // instead of overflowing.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            character,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 24) * fit,
              color: visual == OtpBoxVisual.disabled
                  ? style.color?.withValues(alpha: 0.4)
                  : style.color,
            ),
          ),
        ),
      );
    } else if (showCursor) {
      content = _Cursor(
        key: const ValueKey('cursor'),
        color: theme.cursorColor ?? theme.textStyle.color ?? theme.accentColor,
        height: side * _cursorHeight,
        visible: cursorVisible,
      );
    } else {
      content = const SizedBox.shrink(key: ValueKey('empty'));
    }

    return AnimatedContainer(
      duration: theme.styleDuration,
      curve: Curves.easeOut,
      alignment: Alignment.center,
      decoration: _decoration(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: content,
      ),
    );
  }

  BoxDecoration _decoration() {
    final fill = theme.fillColor;
    var border = theme.borderColor;
    var corner = fill;
    // Resting glows are the accent at zero alpha rather than transparent
    // black, so fading a glow in never drags its color through grey.
    var glow = theme.accentColor.withValues(alpha: 0);
    var glowBlur = theme.glowBlurRadius;

    switch (visual) {
      case OtpBoxVisual.empty:
      case OtpBoxVisual.filled:
        break;
      case OtpBoxVisual.active:
        border = theme.accentColor;
        glow = theme.accentColor.withValues(alpha: 0.45);
      case OtpBoxVisual.orbiting:
        border = theme.accentColor;
        corner = Color.alphaBlend(
          theme.accentColor.withValues(alpha: 0.8),
          fill,
        );
        glow = theme.accentColor.withValues(alpha: 0.25);
        glowBlur = theme.glowBlurRadius * 0.7;
      case OtpBoxVisual.error:
        border = theme.errorColor;
        glow = theme.errorColor.withValues(alpha: 0.4);
      case OtpBoxVisual.success:
        border = theme.successColor;
        glow = theme.successColor.withValues(alpha: 0.35);
      case OtpBoxVisual.disabled:
        border = theme.borderColor.withValues(alpha: theme.borderColor.a * 0.5);
    }

    return BoxDecoration(
      // A BoxDecoration ignores `color` once it has a gradient, and lerping
      // from no gradient fades the fill through transparent. So every visual
      // keeps the same gradient shape and only its colors change: the orbit's
      // lit corner is the only state where the two stops differ.
      gradient: RadialGradient(
        center: Alignment.topRight,
        radius: 1.1,
        colors: [corner, fill],
        stops: const [0, 0.7],
      ),
      borderRadius: BorderRadius.circular(theme.borderRadius * fit),
      border: Border.all(color: border, width: theme.borderWidth),
      boxShadow: [BoxShadow(color: glow, blurRadius: glowBlur)],
    );
  }
}

class _Cursor extends StatelessWidget {
  const _Cursor({
    super.key,
    required this.color,
    required this.height,
    required this.visible,
  });

  final Color color;
  final double height;
  final ValueListenable<bool> visible;

  static const double _width = 2;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, visible, child) => AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(_width / 2),
        ),
        child: SizedBox(width: _width, height: height),
      ),
    );
  }
}
