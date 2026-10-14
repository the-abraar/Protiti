import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:protiti/l10n/app_localizations.dart';
import '../../../data/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../vault/vault_screen.dart';
import '../vault/vault_provider.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../data/services/database_service.dart';
import 'package:provider/provider.dart';
import '../../../data/services/wipe_service.dart';
import '../../../data/services/disguise_settings_service.dart';
import '../../../data/services/background_sos_service.dart';
import 'pin_setup_screen.dart';

class LockScreen extends StatefulWidget {
  /// True after a wipe: open on the plain calculator with no flash of anything else.
  final bool startInCalculator;

  const LockScreen({super.key, this.startInCalculator = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final AuthService _authService = AuthService();
  late bool _isCalculatorMode = widget.startInCalculator;
  String _enteredPin = '';
  String _errorMessage = '';
  bool _biometricEnabled = false;
  bool _needsSetup = false;

  static const _maxPinLength = 10;

  // Calculator disguise state
  String _calcDisplay = '0';
  double? _firstOperand;
  String? _operator;
  bool _shouldResetCalcDisplay = false;
  // Digits exactly as typed since the last operator, so codes starting with 0 work.
  String _typedDigits = '';

  @override
  void initState() {
    super.initState();
    _checkSetup();
    _checkBiometricStatus();
    if (!widget.startInCalculator) _applyLaunchDisguisePreference();
    // Starts the power-button/shake SOS service only if she turned it on in
    // Settings; never asks for a permission here (B17).
    BackgroundSosService.startIfEnabled();
  }

  /// If the survivor has enabled "Always launch as calculator" in Settings,
  /// open straight into the disguise instead of briefly revealing the
  /// branded Protiti lock screen — important on a shared/monitored device
  /// where there's no time to remember to tap the disguise toggle.
  Future<void> _applyLaunchDisguisePreference() async {
    final alwaysCalculator =
        await DisguiseSettingsService.getAlwaysLaunchAsCalculator();
    if (alwaysCalculator && mounted) {
      setState(() => _isCalculatorMode = true);
    }
  }

  Future<void> _checkSetup() async {
    try {
      final done = await _authService.isSetupComplete();
      if (mounted) setState(() => _needsSetup = !done);
    } catch (_) {
      // Fail closed: storage is unreadable, so no code can unlock anything.
    }
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final enabled = await _authService.isBiometricEnabled();
      if (mounted) setState(() => _biometricEnabled = enabled);
    } catch (_) {}
  }

  void _onNumberTap(String number) {
    if (_enteredPin.length < _maxPinLength) {
      // HapticFeedback removed for tactical privacy
      setState(() {
        _errorMessage = '';
        _enteredPin += number;
      });
    }
  }

  void _onSubmit() {
    if (_enteredPin.length >= 4) _verifyPin(_enteredPin);
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      // HapticFeedback removed for tactical privacy
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  /// Used by both the keypad and the calculator. In the calculator a miss or
  /// a lockout shows nothing at all: it just stays a calculator.
  Future<void> _verifyPin(String pin) async {
    final silent = _isCalculatorMode;
    AuthStatus status;
    try {
      status = await _authService.verifyPin(pin);
    } catch (_) {
      status = AuthStatus.failed;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    switch (status) {
      case AuthStatus.authenticatedReal:
        _navigateToVault(isDecoy: false);
      case AuthStatus.authenticatedDuress:
        // Duress PIN entered: Quietly load harmless decoy vault
        _navigateToVault(isDecoy: true);
      case AuthStatus.wiped:
        await _wipe();
      case AuthStatus.lockedOut:
        setState(() {
          _enteredPin = '';
          _errorMessage = silent ? '' : l10n.lockoutMessage;
        });
      case AuthStatus.failed:
        if (!silent) HapticFeedback.heavyImpact();
        setState(() {
          _enteredPin = '';
          _errorMessage = silent ? '' : l10n.incorrectPinMessage;
        });
    }
  }

  Future<void> _wipe() async {
    try {
      await WipeService.executeNuclearWipe();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LockScreen(startInCalculator: true)),
      (_) => false,
    );
  }

  Future<void> _authenticateBiometric() async {
    final status = await _authService.authenticateBiometric();
    if (status == AuthStatus.authenticatedReal && mounted) {
      _navigateToVault(isDecoy: false);
    }
  }

  void _navigateToVault({required bool isDecoy}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => VaultProvider(
            EvidenceRepository(DatabaseService(isDecoy: isDecoy)),
            isDecoy: isDecoy,
          ),
          child: VaultScreen(isDecoy: isDecoy),
        ),
      ),
    );
  }

  static String _formatNumber(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  // --- Calculator Disguise Logic ---
  void _onCalcButtonPress(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      if (label == 'C') {
        _calcDisplay = '0';
        _firstOperand = null;
        _operator = null;
        _shouldResetCalcDisplay = false;
        _typedDigits = '';
      } else if (label == '%') {
        _calcDisplay = _formatNumber((double.tryParse(_calcDisplay) ?? 0) / 100);
        _shouldResetCalcDisplay = true;
        _typedDigits = '';
      } else if (label == '±') {
        if (_calcDisplay != '0') {
          _calcDisplay = _calcDisplay.startsWith('-') ? _calcDisplay.substring(1) : '-$_calcDisplay';
        }
        _typedDigits = '';
      } else if (label == '=') {
        // A bare 4-10 digit entry may be a code: checked like any PIN entry.
        if (_operator == null && RegExp(r'^\d{4,10}$').hasMatch(_typedDigits)) {
          _verifyPin(_typedDigits);
        }
        _typedDigits = '';

        // Standard arithmetic evaluation
        if (_firstOperand != null && _operator != null) {
          final secondOperand = double.tryParse(_calcDisplay) ?? 0.0;
          double result = 0.0;
          switch (_operator) {
            case '+':
              result = _firstOperand! + secondOperand;
              break;
            case '−':
              result = _firstOperand! - secondOperand;
              break;
            case '×':
              result = _firstOperand! * secondOperand;
              break;
            case '÷':
              result = secondOperand != 0
                  ? _firstOperand! / secondOperand
                  : 0.0;
              break;
          }
          _calcDisplay = _formatNumber(result);
          _firstOperand = null;
          _operator = null;
          _shouldResetCalcDisplay = true;
        }
      } else if (['+', '−', '×', '÷'].contains(label)) {
        _firstOperand = double.tryParse(_calcDisplay);
        _operator = label;
        _shouldResetCalcDisplay = true;
        _typedDigits = '';
      } else {
        // Digit or dot
        if (_typedDigits.length < _maxPinLength) _typedDigits += label;
        if (_calcDisplay == '0' || _shouldResetCalcDisplay) {
          _calcDisplay = label;
          _shouldResetCalcDisplay = false;
        } else {
          if (_calcDisplay.length < 10) {
            _calcDisplay += label;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // After a wipe the calculator stays a calculator; setup is one toggle away.
    if (_needsSetup && !_isCalculatorMode) {
      return PinSetupScreen(
        authService: _authService,
        onDone: () => setState(() => _needsSetup = false),
      );
    }
    return Scaffold(
      backgroundColor: _isCalculatorMode
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isCalculatorMode
              ? AppLocalizations.of(context)!.calculatorLabel
              : 'Protiti (প্রতীতি)',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isCalculatorMode
                ? AppLocalizations.of(context)!.switchToStandardLockTooltip
                : AppLocalizations.of(context)!.enableCalculatorDisguiseTooltip,
            icon: Icon(
              _isCalculatorMode ? Icons.lock_outline : Icons.calculate_outlined,
              color: AppTheme.brandSecondary,
            ),
            onPressed: () {
              setState(() {
                _isCalculatorMode = !_isCalculatorMode;
                _enteredPin = '';
                _errorMessage = '';
                _calcDisplay = '0';
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isCalculatorMode
            ? _buildCalculatorBody()
            : _buildStandardLockBody(),
      ),
    );
  }

  Widget _buildStandardLockBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Clean Lock Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceLight,
              border: Border.all(color: AppTheme.accentSoft.withOpacity(0.5), width: 2),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: AppTheme.brandSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Protiti (প্রতীতি)',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.myNotesSubtitle,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),

          // PIN indicators: one per digit typed, at least six.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_enteredPin.length < 6 ? 6 : _enteredPin.length, (index) {
              final isFilled = index < _enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppTheme.brandSecondary : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? AppTheme.brandSecondary : AppTheme.accentSoft,
                    width: 2,
                  ),
                ),
              );
            }),
          ),

          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: AppTheme.panicRed,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 40),

          // Numeric Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3']),
                const SizedBox(height: 20),
                _buildKeypadRow(['4', '5', '6']),
                const SizedBox(height: 20),
                _buildKeypadRow(['7', '8', '9']),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.backspace_rounded,
                      onTap: _onBackspace,
                      tooltip: AppLocalizations.of(context)!.deleteTooltip,
                    ),
                    _buildNumberButton('0'),
                    _buildActionButton(
                      icon: Icons.check_rounded,
                      onTap: _onSubmit,
                      tooltip: AppLocalizations.of(context)!.enterTooltip,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_biometricEnabled) ...[
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.fingerprint_rounded,
              onTap: _authenticateBiometric,
              tooltip: AppLocalizations.of(context)!.biometricUnlockTooltip,
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberButton(d)).toList(),
    );
  }

  Widget _buildNumberButton(String digit) {
    return InkWell(
      splashColor: AppTheme.surfaceLight,
      highlightColor: AppTheme.surfaceLight,
      enableFeedback: false,
      onTap: () => _onNumberTap(digit),
      borderRadius: BorderRadius.circular(38),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryWhite,
          border: Border.all(color: AppTheme.surfaceLight, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        enableFeedback: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: Icon(icon, size: 28, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  // --- Calculator Disguise UI ---
  Widget _buildCalculatorBody() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Text(
              _calcDisplay,
              style: const TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCalcRow(['C', '±', '%', '÷'], isTopRow: true),
                const SizedBox(height: 12),
                _buildCalcRow(['7', '8', '9', '×']),
                const SizedBox(height: 12),
                _buildCalcRow(['4', '5', '6', '−']),
                const SizedBox(height: 12),
                _buildCalcRow(['1', '2', '3', '+']),
                const SizedBox(height: 12),
                _buildCalcRow(['0', '.', '=']),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcRow(List<String> labels, {bool isTopRow = false}) {
    return Expanded(
      child: Row(
        children: labels.map((label) {
          final isOperator = ['÷', '×', '−', '+', '='].contains(label);
          final isZero = label == '0';
          return Expanded(
            flex: isZero ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOperator
                      ? Colors.orange[800]
                      : (isTopRow ? Colors.grey[700] : Colors.grey[900]),
                  foregroundColor: Colors.white,
                  shape: isZero
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        )
                      : const CircleBorder(),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                onPressed: () => _onCalcButtonPress(label),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
