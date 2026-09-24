import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../vault/vault_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final AuthService _authService = AuthService();
  bool _isCalculatorMode = false;
  String _enteredPin = '';
  String _errorMessage = '';

  // Calculator disguise state
  String _calcDisplay = '0';
  double? _firstOperand;
  String? _operator;
  bool _shouldResetCalcDisplay = false;

  void _onNumberTap(String number) {
    if (_enteredPin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _errorMessage = '';
        _enteredPin += number;
      });

      if (_enteredPin.length == 4) {
        _verifyPin(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin(String pin) async {
    final status = await _authService.verifyPin(pin);
    if (!mounted) return;

    if (status == AuthStatus.authenticatedReal) {
      _navigateToVault(isDecoy: false);
    } else if (status == AuthStatus.authenticatedDuress) {
      // Duress PIN entered: Quietly load harmless decoy vault
      _navigateToVault(isDecoy: true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _enteredPin = '';
        _errorMessage = 'Incorrect PIN. Please re-enter.';
      });
    }
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
      MaterialPageRoute(builder: (context) => VaultScreen(isDecoy: isDecoy)),
    );
  }

  // --- Calculator Disguise Logic ---
  void _onCalcButtonPress(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      if (label == 'C') {
        _calcDisplay = '0';
        _firstOperand = null;
        _operator = null;
        _shouldResetCalcDisplay = false;
      } else if (label == '=') {
        // Check stealth unlock passcode
        if (_calcDisplay == AuthService.defaultRealPin) {
          _navigateToVault(isDecoy: false);
          return;
        } else if (_calcDisplay == AuthService.defaultDuressPin) {
          _navigateToVault(isDecoy: true);
          return;
        }

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
          _calcDisplay = result % 1 == 0
              ? result.toInt().toString()
              : result.toStringAsFixed(2);
          _firstOperand = null;
          _operator = null;
          _shouldResetCalcDisplay = true;
        }
      } else if (['+', '−', '×', '÷'].contains(label)) {
        _firstOperand = double.tryParse(_calcDisplay);
        _operator = label;
        _shouldResetCalcDisplay = true;
      } else {
        // Digit or dot
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
    return Scaffold(
      backgroundColor: _isCalculatorMode
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isCalculatorMode ? 'Calculator' : 'Protiti (প্রতীতি)',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isCalculatorMode
                ? 'Switch to Standard Lock'
                : 'Enable Calculator Stealth Disguise',
            icon: Icon(
              _isCalculatorMode ? Icons.lock_outline : Icons.calculate_outlined,
              color: AppTheme.warmGold,
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Shield Logo Icon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.deepAmethyst.withValues(alpha: 0.2),
              border: Border.all(color: AppTheme.deepAmethyst, width: 2),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 56,
              color: AppTheme.tealLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Forensic Vault Authentication',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter security PIN or use biometrics to access records',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),

          // PIN Indicators (4 dots)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppTheme.warmGold : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? AppTheme.warmGold : Colors.grey[600]!,
                    width: 2,
                  ),
                ),
              );
            }),
          ),

          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: AppTheme.crimson,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Numeric Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3']),
                const SizedBox(height: 16),
                _buildKeypadRow(['4', '5', '6']),
                const SizedBox(height: 16),
                _buildKeypadRow(['7', '8', '9']),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Biometric Button
                    _buildActionButton(
                      icon: Icons.fingerprint,
                      onTap: _authenticateBiometric,
                      tooltip: 'Biometric Unlock',
                    ),
                    _buildNumberButton('0'),
                    // Backspace Button
                    _buildActionButton(
                      icon: Icons.backspace_outlined,
                      onTap: _onBackspace,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const SizedBox(height: 10),
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
      onTap: () => _onNumberTap(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardDark,
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: Icon(icon, size: 28, color: Colors.grey[400]),
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
