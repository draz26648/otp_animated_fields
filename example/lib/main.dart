import 'package:flutter/material.dart';
import 'package:otp_animated_fields/otp_animated_fields.dart';

void main() => runApp(const ExampleApp());

/// The code the simulated backend accepts.
const _validCode = '1234';
const _accent = Color(0xFFFF5A3C);

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.dark;

  void _toggleTheme() => setState(
    () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTP Animated Fields',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
        scaffoldBackgroundColor: const Color(0xFFE9E9EF),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF08080B),
      ),
      home: VerifyScreen(onToggleTheme: _toggleTheme),
    );
  }
}

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final OtpAnimatedController _otp = OtpAnimatedController();
  OtpStatus _status = OtpStatus.idle;
  bool _autoVerify = true;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  /// Simulates a network request to verify the code.
  Future<bool> _verify(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    return code == _validCode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VerifyCard(
                    isDark: isDark,
                    status: _status,
                    onToggleTheme: widget.onToggleTheme,
                    onResend: _otp.reset,
                    field: OtpAnimatedField(
                      controller: _otp,
                      autofocus: true,
                      autoVerify: _autoVerify,
                      theme: isDark
                          ? OtpAnimatedTheme.dark(accentColor: _accent)
                          : OtpAnimatedTheme.light(accentColor: _accent),
                      onVerify: _verify,
                      onStatusChanged: (status) =>
                          setState(() => _status = status),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DemoControls(
                    autoVerify: _autoVerify,
                    canVerify: _status == OtpStatus.idle,
                    onAutoVerifyChanged: (value) =>
                        setState(() => _autoVerify = value),
                    onVerify: _otp.verify,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifyCard extends StatelessWidget {
  const _VerifyCard({
    required this.isDark,
    required this.status,
    required this.onToggleTheme,
    required this.onResend,
    required this.field,
  });

  final bool isDark;
  final OtpStatus status;
  final VoidCallback onToggleTheme;
  final VoidCallback onResend;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF8A8A96) : const Color(0xFF6B6B78);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151A) : Colors.white,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: isDark ? const Color(0xFF222229) : const Color(0xFFE2E2EA),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton.filledTonal(
                    onPressed: onToggleTheme,
                    tooltip: isDark ? 'Use light theme' : 'Use dark theme',
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Header(status: status, muted: muted),
            const SizedBox(height: 12),
            field,
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Didn't receive the code?",
                  style: TextStyle(color: muted),
                ),
                TextButton(
                  onPressed: onResend,
                  child: const Text(
                    'Resend',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.muted});

  final OtpStatus status;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (status) {
      OtpStatus.idle => (
        "Let's verify your number",
        "We've sent a 4-digit code to your phone. It'll auto-verify once "
            'entered.',
      ),
      OtpStatus.verifying => (
        'Verifying...',
        'Processing security authentication',
      ),
      OtpStatus.success => ("You're in!", 'Your number has been verified.'),
      OtpStatus.error => (
        "That code didn't match",
        'Check the message and try again.',
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(status),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DemoControls extends StatelessWidget {
  const _DemoControls({
    required this.autoVerify,
    required this.canVerify,
    required this.onAutoVerifyChanged,
    required this.onVerify,
  });

  final bool autoVerify;
  final bool canVerify;
  final ValueChanged<bool> onAutoVerifyChanged;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text(
        //   'Demo: $_validCode is accepted, anything else is rejected.',
        //   textAlign: TextAlign.center,
        //   style: Theme.of(context).textTheme.bodySmall,
        // ),
        // SwitchListTile.adaptive(
        //   value: autoVerify,
        //   onChanged: onAutoVerifyChanged,
        //   title: const Text('Verify automatically'),
        //   subtitle: const Text('Turn off to submit with the button'),
        // ),
        // if (!autoVerify)
        //   FilledButton(
        //     onPressed: canVerify ? onVerify : null,
        //     child: const Text('Verify'),
        //   ),
      ],
    );
  }
}
