import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'otp_animated_controller.dart';
import 'otp_box.dart';
import 'otp_geometry.dart';
import 'otp_motion.dart';
import 'otp_orbit_painter.dart';
import 'otp_status.dart';
import 'theme/otp_animated_theme.dart';

/// Verifies [code] and resolves to whether it was accepted.
typedef OtpVerifyCallback = Future<bool> Function(String code);

/// What a screen reader says about an `OtpAnimatedField`.
///
/// The defaults are English; pass localized strings from your app's
/// localizations. An empty string silences that announcement.
@immutable
class OtpSemanticLabels {
  /// Creates a set of labels.
  const OtpSemanticLabels({
    this.field = 'One-time code',
    this.verifying = 'Verifying code',
    this.success = 'Code verified',
    this.error = 'Incorrect code',
  });

  /// Label of the text field.
  final String field;

  /// Announced when the boxes start orbiting.
  final String verifying;

  /// Announced when the success animation starts.
  final String success;

  /// Announced when the error animation starts.
  final String error;
}

/// A one-time-code input whose boxes turn into the loading indicator.
///
/// While the user types, the boxes sit in a row. Once the code is submitted
/// they shrink, fly onto a circle and orbit it until verification resolves:
/// into a check mark on success, or back to the row with a shake on failure.
///
/// Verify with a future:
///
/// ```dart
/// OtpAnimatedField(
///   length: 4,
///   onVerify: (code) => api.verifyOtp(code), // Future<bool>
///   onVerified: (code) => context.go('/home'),
/// )
/// ```
///
/// or drive it yourself, e.g. from a Bloc listener or a "Verify" button:
///
/// ```dart
/// OtpAnimatedField(controller: otp, autoVerify: false)
/// // ...
/// otp.verify();  // then otp.succeed() or otp.fail()
/// ```
///
/// The digit order is always left to right, including in RTL locales, because
/// a code reads the same way in every language.
class OtpAnimatedField extends StatefulWidget {
  /// Creates an animated one-time-code field.
  const OtpAnimatedField({
    super.key,
    this.length = 4,
    this.controller,
    this.focusNode,
    this.theme,
    this.autofocus = false,
    this.enabled = true,
    this.autoVerify = true,
    this.clearOnError = true,
    this.reserveOrbitSpace = true,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.hapticFeedback = true,
    this.minimumVerifyingDuration = const Duration(milliseconds: 1500),
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.semanticLabels = const OtpSemanticLabels(),
    this.onChanged,
    this.onCompleted,
    this.onVerify,
    this.onStatusChanged,
    this.onVerified,
    this.onFailed,
  }) : assert(length > 0, 'length must be positive'),
       assert(
         obscuringCharacter.length == 1,
         'obscuringCharacter must be a single character',
       );

  /// Number of characters in the code.
  final int length;

  /// Controls the text and the verification status. The field creates its own
  /// when null.
  final OtpAnimatedController? controller;

  /// Controls keyboard focus. The field creates its own when null.
  final FocusNode? focusNode;

  /// Colors, sizes and timings. Adapts to the ambient Material theme when
  /// null; see [OtpAnimatedTheme.of].
  final OtpAnimatedTheme? theme;

  /// Whether to focus the field as soon as it is shown.
  final bool autofocus;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether entering the last character submits the code. Turn it off to
  /// submit from a button with [OtpAnimatedController.verify].
  final bool autoVerify;

  /// Whether the code is cleared after the error animation.
  final bool clearOnError;

  /// Whether the field always takes the height of the orbit, keeping the row
  /// vertically centered in it, so nothing around it moves when verification
  /// starts. When false the field is as tall as the row and grows while the
  /// boxes travel to the orbit.
  final bool reserveOrbitSpace;

  /// Whether to hide the entered characters.
  final bool obscureText;

  /// The character shown instead of the input when [obscureText] is on.
  final String obscuringCharacter;

  /// Whether to vibrate on success and on error.
  final bool hapticFeedback;

  /// The shortest time the boxes stay in orbit, so a fast backend does not cut
  /// the animation short. Use [Duration.zero] to resolve as soon as possible.
  final Duration minimumVerifyingDuration;

  /// The keyboard to show.
  final TextInputType keyboardType;

  /// Restricts what can be entered. Defaults to digits only. The field always
  /// limits the input to [length] characters on top of these.
  final List<TextInputFormatter>? inputFormatters;

  /// What a screen reader says about the field.
  final OtpSemanticLabels semanticLabels;

  /// Called whenever the entered code changes.
  final ValueChanged<String>? onChanged;

  /// Called when the last character is entered, before verification starts.
  final ValueChanged<String>? onCompleted;

  /// Verifies the submitted code. The field orbits until the future resolves,
  /// then plays the success animation for true and the error animation for
  /// false. A thrown error counts as false and is reported to [FlutterError].
  ///
  /// When null, resolve verification with [OtpAnimatedController.succeed] or
  /// [OtpAnimatedController.fail].
  final OtpVerifyCallback? onVerify;

  /// Called whenever the controller's status changes.
  final ValueChanged<OtpStatus>? onStatusChanged;

  /// Called with the code once the success animation has finished: the moment
  /// to navigate away.
  final ValueChanged<String>? onVerified;

  /// Called with the rejected code once the error animation has finished.
  final ValueChanged<String>? onFailed;

  @override
  State<OtpAnimatedField> createState() => _OtpAnimatedFieldState();
}

class _OtpAnimatedFieldState extends State<OtpAnimatedField>
    with TickerProviderStateMixin {
  final GlobalKey<EditableTextState> _editableKey =
      GlobalKey<EditableTextState>();
  final ValueNotifier<bool> _cursorVisible = ValueNotifier<bool>(true);

  late final AnimationController _morph;
  late final AnimationController _orbit;
  late final AnimationController _shake;
  late final AnimationController _success;

  /// Runs for [OtpAnimatedField.minimumVerifyingDuration]. A ticker rather than
  /// a stopwatch so it follows `timeDilation` and the fake clock in tests.
  late final AnimationController _hold;

  late final OtpMotion _motion;
  late final TextInputFormatter _lockFormatter;

  OtpAnimatedController? _internalController;
  FocusNode? _internalFocusNode;
  Timer? _cursorTimer;

  late OtpAnimatedTheme _theme;
  bool _reduceMotion = false;

  late String _text;
  late OtpStatus _status;

  /// The status the boxes are dressed for. Trails [_status] so a result only
  /// shows once [_hold] has run out.
  OtpStatus _visual = OtpStatus.idle;

  /// Bumped on every status change so a superseded animation sequence stops
  /// at its next await.
  int _sequence = 0;
  bool _rejectedIncomplete = false;

  // initState and didUpdateWidget create the internal controller and focus
  // node whenever the widget does not provide one, so one of the two is
  // always set.
  OtpAnimatedController get _controller =>
      widget.controller ?? _internalController!;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = OtpAnimatedController();
    }
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode(debugLabel: 'OtpAnimatedField');
    }
    _morph = AnimationController(vsync: this);
    _orbit = AnimationController(vsync: this);
    _shake = AnimationController(vsync: this);
    _success = AnimationController(vsync: this);
    _hold = AnimationController(
      vsync: this,
      duration: widget.minimumVerifyingDuration,
    );
    _motion = OtpMotion(
      morph: _morph,
      orbit: _orbit,
      shake: _shake,
      success: _success,
    );
    _lockFormatter = TextInputFormatter.withFunction(
      (oldValue, newValue) =>
          _controller.status == OtpStatus.idle ? newValue : oldValue,
    );

    _text = _clamped(_controller.text);
    _status = _controller.status;
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _applyTheme();
  }

  @override
  void didUpdateWidget(OtpAnimatedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      (oldWidget.controller ?? _internalController)?.removeListener(
        _handleControllerChanged,
      );
      if (widget.controller == null) {
        _internalController ??= OtpAnimatedController();
      } else {
        _internalController?.dispose();
        _internalController = null;
      }
      _controller.addListener(_handleControllerChanged);
      _deferControllerSync();
    }
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
        _handleFocusChanged,
      );
      if (widget.focusNode == null) {
        _internalFocusNode ??= FocusNode(debugLabel: 'OtpAnimatedField');
      } else {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      _focusNode.addListener(_handleFocusChanged);
    }
    if (widget.length != oldWidget.length) _deferControllerSync();
    if (widget.theme != oldWidget.theme) _applyTheme();
    if (widget.minimumVerifyingDuration != oldWidget.minimumVerifyingDuration) {
      _hold.duration = widget.minimumVerifyingDuration;
    }
    if (widget.enabled != oldWidget.enabled) _syncCursor();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _cursorTimer?.cancel();
    _morph.dispose();
    _orbit.dispose();
    _shake.dispose();
    _success.dispose();
    _hold.dispose();
    _cursorVisible.dispose();
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _applyTheme() {
    _theme = widget.theme ?? OtpAnimatedTheme.of(context);
    _morph.duration = _reduceMotion ? Duration.zero : _theme.morphDuration;
    _orbit.duration = _theme.orbitPeriod;
    _shake.duration = _theme.errorDuration;
    _success.duration = _theme.successDuration;
  }

  String _clamped(String text) =>
      text.length > widget.length ? text.substring(0, widget.length) : text;

  /// Syncing can write to the controller, which notifies listeners that may
  /// call setState, so it cannot run while the tree is building.
  void _deferControllerSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleControllerChanged();
    });
  }

  void _handleControllerChanged() {
    final value = _controller.value;
    final text = _clamped(value.text);
    final selection = value.selection;
    final caretAtEnd =
        selection.isCollapsed && selection.baseOffset == text.length;
    if (text != value.text || !caretAtEnd) {
      // The boxes have no caret of their own, so editing always happens at
      // the end. Assigning re-enters this listener with the normalized value.
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      return;
    }

    final status = _controller.status;
    final previousStatus = _status;
    final textChanged = text != _text;
    final statusChanged = status != previousStatus;
    if (!textChanged && !statusChanged) return;
    setState(() {
      _text = text;
      _status = status;
    });

    // The callbacks below can re-enter this listener, e.g. by resetting the
    // controller, so each step re-reads the live status instead of trusting
    // what was captured above.
    if (textChanged) {
      widget.onChanged?.call(text);
      if (text.length == widget.length && _isIdle) {
        widget.onCompleted?.call(text);
        if (widget.autoVerify && _isIdle) _controller.verify();
      }
    }
    if (statusChanged && _status == status) _handleStatusChanged(status);
  }

  bool get _isIdle =>
      _status == OtpStatus.idle && _controller.status == OtpStatus.idle;

  void _handleStatusChanged(OtpStatus status) {
    if (status == OtpStatus.verifying && _text.length < widget.length) {
      // Nothing to verify yet: reject with a shake and keep what was typed.
      _rejectedIncomplete = true;
      _controller.fail();
      return;
    }
    final sequence = ++_sequence;
    widget.onStatusChanged?.call(status);
    if (sequence != _sequence) return;
    _syncCursor();
    switch (status) {
      case OtpStatus.idle:
        unawaited(_playIdle(sequence));
      case OtpStatus.verifying:
        unawaited(_playVerifying(sequence));
      case OtpStatus.success:
        unawaited(_playSuccess(sequence));
      case OtpStatus.error:
        unawaited(_playError(sequence));
    }
  }

  void _handleFocusChanged() {
    setState(() {});
    _syncCursor();
  }

  // A timer rather than a repeating animation, so a focused field does not
  // keep `pumpAndSettle` from settling in the host app's tests.
  void _syncCursor() {
    final blink =
        widget.enabled && _focusNode.hasFocus && _status == OtpStatus.idle;
    if (!blink) {
      _cursorTimer?.cancel();
      _cursorTimer = null;
      return;
    }
    _cursorVisible.value = true;
    _cursorTimer ??= Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _cursorVisible.value = !_cursorVisible.value,
    );
  }

  /// Awaits [future] and reports whether [sequence] is still the one to run.
  Future<bool> _run(TickerFuture future, int sequence) async {
    try {
      await future.orCancel;
    } on TickerCanceled {
      return false;
    }
    return mounted && sequence == _sequence;
  }

  void _setVisual(OtpStatus visual) {
    if (_visual != visual) setState(() => _visual = visual);
  }

  void _startOrbit() {
    if (!_orbit.isAnimating) _orbit.repeat();
  }

  Future<void> _playVerifying(int sequence) async {
    final code = _text;
    _setVisual(OtpStatus.verifying);
    _announce(widget.semanticLabels.verifying);
    _startOrbit();
    _hold.forward(from: 0);
    _morph.forward();

    final onVerify = widget.onVerify;
    if (onVerify == null) return;
    bool verified;
    try {
      verified = await onVerify(code);
    } catch (error, stackTrace) {
      verified = false;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'otp_animated_fields',
          context: ErrorDescription('while verifying a one-time code'),
        ),
      );
    }
    if (!mounted || sequence != _sequence) return;
    if (verified) {
      _controller.succeed();
    } else {
      _controller.fail();
    }
  }

  Future<void> _playSuccess(int sequence) async {
    if (_hold.isAnimating && !await _run(_hold.forward(), sequence)) return;
    if (_morph.value < 1) {
      // Resolved without a verifying phase: get onto the orbit first.
      _setVisual(OtpStatus.verifying);
      _startOrbit();
      if (!await _run(_morph.forward(), sequence)) return;
    }
    _setVisual(OtpStatus.success);
    _announce(widget.semanticLabels.success);
    if (widget.hapticFeedback) unawaited(HapticFeedback.lightImpact());
    if (!await _run(_success.forward(), sequence)) return;
    _orbit.stop();
    _focusNode.unfocus();
    widget.onVerified?.call(_text);
  }

  Future<void> _playError(int sequence) async {
    if (_hold.isAnimating && !await _run(_hold.forward(), sequence)) return;
    _setVisual(OtpStatus.error);
    final rejectedIncomplete = _rejectedIncomplete;
    _rejectedIncomplete = false;
    if (!rejectedIncomplete) _announce(widget.semanticLabels.error);
    if (widget.hapticFeedback) unawaited(HapticFeedback.mediumImpact());
    if (!await _run(_morph.reverse(), sequence)) return;
    _orbit.stop();
    if (!await _run(_shake.forward(from: 0), sequence)) return;

    final code = _text;
    _controller.reset(clearText: widget.clearOnError && !rejectedIncomplete);
    if (!rejectedIncomplete) widget.onFailed?.call(code);
  }

  Future<void> _playIdle(int sequence) async {
    _setVisual(OtpStatus.idle);
    _hold.stop();
    final settled = await Future.wait([
      _run(_success.reverse(), sequence),
      _run(_morph.reverse(), sequence),
    ]);
    if (settled.contains(false)) return;
    _orbit.stop();
    _shake.value = 0;
  }

  void _announce(String message) {
    if (message.isEmpty || !mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  void _requestKeyboard() {
    if (_focusNode.hasFocus) {
      _editableKey.currentState?.requestKeyboard();
    } else {
      _focusNode.requestFocus();
    }
  }

  OtpBoxVisual _boxVisual(int index) {
    if (!widget.enabled) return OtpBoxVisual.disabled;
    switch (_visual) {
      case OtpStatus.verifying:
        return OtpBoxVisual.orbiting;
      case OtpStatus.success:
        return OtpBoxVisual.success;
      case OtpStatus.error:
        return OtpBoxVisual.error;
      case OtpStatus.idle:
        final activeIndex = math.min(_text.length, widget.length - 1);
        if (_focusNode.hasFocus && index == activeIndex) {
          return OtpBoxVisual.active;
        }
        return index < _text.length ? OtpBoxVisual.filled : OtpBoxVisual.empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = OtpGeometry.resolve(
          length: widget.length,
          theme: theme,
          maxWidth: constraints.maxWidth,
        );
        final showCursor = _visual == OtpStatus.idle && _focusNode.hasFocus;

        final Widget field = SizedBox.fromSize(
          size: geometry.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: geometry.rowWidth,
                height: geometry.boxSize,
                child: Semantics(
                  label: widget.semanticLabels.field,
                  child: _buildInput(theme),
                ),
              ),
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: OtpOrbitPainter(
                        geometry: geometry,
                        motion: _motion,
                        accentColor: theme.accentColor,
                        ringColor: theme.ringColor,
                        successColor: theme.successColor,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                // The boxes mirror the input above for sighted users only.
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Flow(
                      // The glow of the outermost boxes spills past the row.
                      clipBehavior: Clip.none,
                      delegate: OtpFlowDelegate(
                        geometry: geometry,
                        motion: _motion,
                        shakeAmplitude: _reduceMotion
                            ? 0
                            : geometry.boxSize * 0.16,
                      ),
                      children: [
                        for (var i = 0; i < widget.length; i++)
                          OtpBox(
                            character: i < _text.length
                                ? (widget.obscureText
                                      ? widget.obscuringCharacter
                                      : _text[i])
                                : '',
                            visual: _boxVisual(i),
                            theme: theme,
                            fit: geometry.fit,
                            showCursor: showCursor && i == _text.length,
                            cursorVisible: _cursorVisible,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return TextFieldTapRegion(
          child: IgnorePointer(
            ignoring: !widget.enabled,
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _requestKeyboard,
                // A code reads left to right in every locale.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: RepaintBoundary(
                    child: widget.reserveOrbitSpace
                        ? field
                        : _GrowingHeight(
                            morph: _morph,
                            geometry: geometry,
                            child: field,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The real text field: invisible, and the single source of truth for the
  /// code, so paste, SMS autofill and hardware keyboards behave natively.
  Widget _buildInput(OtpAnimatedTheme theme) {
    const transparent = otpTransparent;
    return ExcludeFocus(
      excluding: !widget.enabled,
      child: EditableText(
        key: _editableKey,
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        readOnly: !widget.enabled,
        obscureText: widget.obscureText,
        obscuringCharacter: widget.obscuringCharacter,
        keyboardType: widget.keyboardType,
        textInputAction: TextInputAction.done,
        keyboardAppearance: theme.keyboardAppearance,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          _lockFormatter,
          ...widget.inputFormatters ?? [FilteringTextInputFormatter.digitsOnly],
          LengthLimitingTextInputFormatter(widget.length),
        ],
        onSubmitted: (_) => _controller.verify(),
        style: const TextStyle(color: transparent, fontSize: 16, height: 1),
        cursorColor: transparent,
        backgroundCursorColor: transparent,
        selectionColor: transparent,
        showCursor: false,
        rendererIgnoresPointer: true,
        enableInteractiveSelection: false,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        stylusHandwritingEnabled: false,
      ),
    );
  }
}

/// Grows from the height of the row to the height of the orbit as the boxes
/// travel, keeping the field centered and unclipped throughout.
class _GrowingHeight extends StatelessWidget {
  const _GrowingHeight({
    required this.morph,
    required this.geometry,
    required this.child,
  });

  final Animation<double> morph;
  final OtpGeometry geometry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fullHeight = geometry.size.height;
    return AnimatedBuilder(
      animation: morph,
      builder: (context, child) => SizedBox(
        width: geometry.size.width,
        height:
            geometry.boxSize +
            (fullHeight - geometry.boxSize) *
                Curves.easeInOutCubic.transform(morph.value),
        child: OverflowBox(
          minHeight: fullHeight,
          maxHeight: fullHeight,
          child: child,
        ),
      ),
      child: child,
    );
  }
}
