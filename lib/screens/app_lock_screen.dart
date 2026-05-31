import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App lock screen — shown on resume when lock is enabled.
// ─────────────────────────────────────────────────────────────────────────────

class AppLockScreen extends StatefulWidget {
  /// Called after successful authentication so the parent can
  /// update session state and pop this screen.
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 4;

  String _entered = '';
  String? _errorMessage;
  bool _loading = false;

  // Shake animation controller for wrong PIN feedback.
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
    _tryBiometricOnOpen();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Authentication ────────────────────────────────

  Future<void> _tryBiometricOnOpen() async {
    final useBio = await AppLockService.useBiometric();
    final canBio = await AppLockService.canUseBiometric();
    if (useBio && canBio && mounted) {
      await _authenticateWithBiometric();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final ok = await AppLockService.authenticateWithBiometric();
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() {
        _loading = false;
        _errorMessage = 'Biometric failed — enter your PIN instead.';
      });
    }
  }

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength || _loading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entered += digit;
      _errorMessage = null;
    });
    if (_entered.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty || _loading) return;
    HapticFeedback.lightImpact();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verifyPin() async {
    setState(() => _loading = true);
    final ok = await AppLockService.verifyPin(_entered);
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _entered = '';
        _loading = false;
        _errorMessage = 'Incorrect PIN — try again.';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  void _unlock() {
    widget.onUnlocked();
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFF1A1A2E);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Branding ─────────────────────────
              const Text('🌿', style: TextStyle(fontSize: 52)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Kultivar',
                style: AppTypography.headlineLarge(context).copyWith(
                  color: AppColors.primary,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your PIN to continue',
                style: AppTypography.bodyMedium(context)
                    .copyWith(color: Colors.white54),
              ),

              const SizedBox(height: 40),

              // ── PIN dots ─────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    _shakeCtrl.isAnimating
                        ? 10 * (0.5 - _shakeAnim.value) * 2
                        : 0,
                    0,
                  ),
                  child: child,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_pinLength, (i) {
                    final filled = i < _entered.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: filled
                              ? AppColors.primary
                              : Colors.white38,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ── Error message ─────────────────────
              SizedBox(
                height: 32,
                child: _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13),
                        ),
                      )
                    : null,
              ),

              const Spacer(),

              // ── Numpad ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    _numRow(['1', '2', '3']),
                    const SizedBox(height: AppSpacing.sm),
                    _numRow(['4', '5', '6']),
                    const SizedBox(height: AppSpacing.sm),
                    _numRow(['7', '8', '9']),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _bioButton(),
                        _digitButton('0'),
                        _backspaceButton(),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numRow(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits.map(_digitButton).toList(),
      );

  Widget _digitButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined,
            color: Colors.white70, size: 24),
      ),
    );
  }

  Widget _bioButton() {
    return FutureBuilder<bool>(
      future: AppLockService.useBiometric(),
      builder: (_, snap) {
        if (snap.data != true) return const SizedBox(width: 72, height: 72);
        return GestureDetector(
          onTap: _loading ? null : _authenticateWithBiometric,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.fingerprint,
                    color: Colors.white70, size: 32),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN setup sheet — used from Settings to set or change the PIN.
// ─────────────────────────────────────────────────────────────────────────────

class PinSetupSheet extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isChange; // true = "Change PIN", false = "Set PIN"

  const PinSetupSheet({
    super.key,
    required this.onComplete,
    this.isChange = false,
  });

  @override
  State<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<PinSetupSheet>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 4;

  // Two-phase: enter new PIN then confirm.
  String _firstPin = '';
  String _entered = '';
  bool _confirming = false;
  String? _errorMessage;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entered += digit;
      _errorMessage = null;
    });
    if (_entered.length == _pinLength) {
      _handleComplete();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(
        () => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _handleComplete() async {
    if (!_confirming) {
      setState(() {
        _firstPin = _entered;
        _entered = '';
        _confirming = true;
      });
    } else {
      if (_entered == _firstPin) {
        await AppLockService.setPin(_entered);
        await AppLockService.setEnabled(true);
        if (mounted) {
          Navigator.pop(context);
          widget.onComplete();
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _firstPin = '';
          _confirming = false;
          _errorMessage = 'PINs did not match — try again.';
        });
        _shakeCtrl.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _confirming ? 'Confirm PIN' : (widget.isChange ? 'New PIN' : 'Set PIN');
    final subtitle = _confirming
        ? 'Enter the same PIN again'
        : 'Choose a 4-digit PIN';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colBorder,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),

          // Header
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.headlineMedium(context)),
                Text(subtitle,
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colTextMuted)),
              ],
            ),
          ]),

          const SizedBox(height: AppSpacing.xl),

          // Dots
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                _shakeCtrl.isAnimating
                    ? 10 * (0.5 - _shakeAnim.value) * 2
                    : 0,
                0,
              ),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_pinLength, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? AppColors.primary
                          : context.colBorder,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),

          SizedBox(
            height: 28,
            child: _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12),
                    ),
                  )
                : null,
          ),

          const SizedBox(height: AppSpacing.md),

          // Numpad
          Column(
            children: [
              _numRow(context, ['1', '2', '3']),
              const SizedBox(height: AppSpacing.sm),
              _numRow(context, ['4', '5', '6']),
              const SizedBox(height: AppSpacing.sm),
              _numRow(context, ['7', '8', '9']),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 64, height: 64),
                  _digitBtn(context, '0'),
                  _backspaceBtn(context),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Cancel
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: AppTypography.labelLarge(context)
                      .copyWith(color: context.colTextSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numRow(BuildContext context, List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits.map((d) => _digitBtn(context, d)).toList(),
      );

  Widget _digitBtn(BuildContext context, String digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colSurface3,
          border: Border.all(color: context.colBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: AppTypography.headlineMedium(context)
              .copyWith(fontSize: 22),
        ),
      ),
    );
  }

  Widget _backspaceBtn(BuildContext context) {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        child: Icon(Icons.backspace_outlined,
            color: context.colTextMuted, size: 22),
      ),
    );
  }
}
