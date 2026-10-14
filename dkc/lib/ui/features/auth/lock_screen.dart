import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/services/auth_service.dart';
import '../vault/vault_screen.dart';
import '../vault/vault_provider.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../data/services/database_service.dart';
import 'package:provider/provider.dart';
import '../../../data/services/wipe_service.dart';
import '../../../data/services/background_sos_service.dart';
import 'pin_setup_screen.dart';

/// The app's only face: a working calculator. Typing a code and then "="
/// unlocks; holding "=" asks for a fingerprint if she turned that on.
/// The first launch on an install shows code setup instead; after a wipe it
/// never does again, so whoever typed the wipe code only ever sees a calculator.
class LockScreen extends StatefulWidget {
  final AuthService? authService;

  const LockScreen({super.key, this.authService});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _biometricEnabled = false;
  bool _needsSetup = false;

  static const _maxDigits = 10;
  static const _error = 'Error';

  String _display = '0';
  double? _accumulator;
  String? _operator;
  bool _startNewNumber = false;
  // Keys exactly as typed since the last operator, so codes starting with 0 work.
  String _typedDigits = '';

  @override
  void initState() {
    super.initState();
    _checkSetup();
    _checkBiometricStatus();
    // Starts the power-button/shake SOS service only if she turned it on in
    // Settings; never asks for a permission here (B17).
    BackgroundSosService.startIfEnabled();
  }

  Future<void> _checkSetup() async {
    try {
      final done = await _authService.isSetupComplete() || await WipeService.hasWiped();
      if (mounted) setState(() => _needsSetup = !done);
    } catch (_) {
      // Fail closed: storage is unreadable, so stay a plain calculator.
    }
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final enabled = await _authService.isBiometricEnabled();
      if (mounted) setState(() => _biometricEnabled = enabled);
    } catch (_) {}
  }

  /// A miss or a lockout shows nothing at all: it just stays a calculator.
  Future<void> _verifyPin(String pin) async {
    AuthStatus status;
    try {
      status = await _authService.verifyPin(pin);
    } catch (_) {
      status = AuthStatus.failed;
    }
    if (!mounted) return;
    switch (status) {
      case AuthStatus.authenticatedReal:
        _navigateToVault(isDecoy: false);
      case AuthStatus.authenticatedDuress:
        _navigateToVault(isDecoy: true);
      case AuthStatus.wiped:
        await _wipe();
      case AuthStatus.lockedOut:
      case AuthStatus.failed:
        break;
    }
  }

  Future<void> _wipe() async {
    try {
      await WipeService.executeNuclearWipe();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LockScreen()),
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

  /// Up to 9 significant digits, no trailing zeros, like a pocket calculator.
  static String _format(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e10) return value.toInt().toString();
    final parts = value.toStringAsPrecision(9).split('e');
    final mantissa = parts[0].contains('.') ? parts[0].replaceFirst(RegExp(r'\.?0+$'), '') : parts[0];
    return parts.length == 2 ? '${mantissa}e${parts[1]}' : mantissa;
  }

  /// Null means "Error": division by zero or a result too large to show.
  static double? _apply(double a, String op, double b) {
    final result = switch (op) {
      '+' => a + b,
      '−' => a - b,
      '×' => a * b,
      _ => b == 0 ? double.nan : a / b,
    };
    return result.isFinite ? result : null;
  }

  double get _value => double.tryParse(_display) ?? 0;

  void _showResult(double? result) {
    _display = result == null ? _error : _format(result);
    _startNewNumber = true;
  }

  void _clear() {
    _display = '0';
    _accumulator = null;
    _operator = null;
    _startNewNumber = false;
    _typedDigits = '';
  }

  void _onCalcButtonPress(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      final isError = _display == _error;
      switch (label) {
        case 'C':
          _clear();
        case '%' || '±' when isError:
          break;
        case '%':
          _showResult(_value / 100);
          _typedDigits = '';
        case '±':
          if (_display != '0') {
            _display = _display.startsWith('-') ? _display.substring(1) : '-$_display';
          }
          _typedDigits = '';
        case '=':
          // A bare 4-10 digit entry may be a code: checked like any PIN entry.
          if (_operator == null && RegExp(r'^\d{4,10}$').hasMatch(_typedDigits)) {
            _verifyPin(_typedDigits);
          }
          _typedDigits = '';
          if (_operator != null && _accumulator != null) {
            _showResult(_apply(_accumulator!, _operator!, _value));
            _accumulator = null;
            _operator = null;
          }
        case '+' || '−' || '×' || '÷':
          if (isError) break;
          // Chaining: 2 + 3 + works out 5 before taking the next number.
          if (_operator != null && _accumulator != null && !_startNewNumber) {
            final result = _apply(_accumulator!, _operator!, _value);
            _showResult(result);
            if (result == null) {
              _accumulator = null;
              _operator = null;
              break;
            }
          }
          _accumulator = _value;
          _operator = label;
          _startNewNumber = true;
          _typedDigits = '';
        default:
          _onDigit(label);
      }
    });
  }

  void _onDigit(String label) {
    _typedDigits += label;
    if (_startNewNumber || _display == _error) {
      _display = label == '.' ? '0.' : label;
      _startNewNumber = false;
    } else if (label == '.') {
      if (!_display.contains('.')) _display += '.';
    } else if (_display == '0') {
      _display = label;
    } else if (_display.replaceAll(RegExp(r'[-.]'), '').length < _maxDigits) {
      _display += label;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsSetup) {
      return PinSetupScreen(
        authService: _authService,
        onDone: () => setState(() => _needsSetup = false),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildCalculatorBody()),
      ),
    );
  }

  Widget _buildCalculatorBody() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _display,
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
                maxLines: 1,
              ),
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
                // Only when she opted in; otherwise a long press is an ordinary press.
                onLongPress: label == '=' && _biometricEnabled ? _authenticateBiometric : null,
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
