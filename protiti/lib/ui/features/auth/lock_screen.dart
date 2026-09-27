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
import '../../../data/services/threat_detection_service.dart';
import '../../../data/services/camouflage_service.dart';
import '../../../data/services/alibi_service.dart';
import '../../../data/services/disguise_settings_service.dart';
import '../../../data/services/background_sos_service.dart';
import 'thermal_decoy_screen.dart';

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
  bool _isCompromised = false;
  int _crashTapCount = 0;
  bool _isBiometricLocked = false;

  // Calculator disguise state
  String _calcDisplay = '0';
  double? _firstOperand;
  String? _operator;
  bool _shouldResetCalcDisplay = false;

  @override
  void initState() {
    super.initState();
    _scanThreats();
    _checkBiometricStatus();
    _applyLaunchDisguisePreference();
    // Fire-and-forget: requests location/mic permissions and starts the
    // hardware-button/shake/geofence SOS service once they're granted.
    // Safe to call on every lock screen load — it no-ops if already running.
    BackgroundSosService.ensureStarted();
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

  Future<void> _checkBiometricStatus() async {
    final locked = await _authService.isBiometricHardLocked();
    if (mounted) {
      setState(() => _isBiometricLocked = locked);
    }
  }

  Future<void> _scanThreats() async {
    final compromised = await ThreatDetectionService.isDeviceCompromised();
    if (mounted) {
      setState(() => _isCompromised = compromised);
    }
  }

  void _onNumberTap(String number) {
    if (_enteredPin.length < 4) {
      // HapticFeedback removed for tactical privacy
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
      // HapticFeedback removed for tactical privacy
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin(String pin) async {
    final status = await _authService.verifyPin(pin);
    if (!mounted) return;

    if (status == AuthStatus.lockedOut) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(AppLocalizations.of(context)!.lockoutMessage),
            backgroundColor: Colors.red,
          )
        );
        setState(() {
          _enteredPin = '';
          _errorMessage = '';
        });
      }
    } else if (status == AuthStatus.wiped) {
      await WipeService.executeNuclearWipe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.wipeMessage),
            backgroundColor: Colors.red,
          )
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } else if (status == AuthStatus.authenticatedReal) {
      _navigateToVault(isDecoy: false);
    } else if (status == AuthStatus.authenticatedDuress) {
      // Duress PIN entered: Quietly load harmless decoy vault
      _navigateToVault(isDecoy: true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _enteredPin = '';
        _errorMessage = AppLocalizations.of(context)!.incorrectPinMessage;
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
            onPressed: () async {
              setState(() {
                _isCalculatorMode = !_isCalculatorMode;
                _enteredPin = '';
                _errorMessage = '';
                _calcDisplay = '0';
              });
              if (_isCalculatorMode) {
                await CamouflageService.enableCalculatorDisguise();
              } else {
                await CamouflageService.restoreOriginalIdentity();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _isCalculatorMode
                ? _buildCalculatorBody()
                : _buildStandardLockBody(),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: GestureDetector(
              onDoubleTap: () {
                // Silently trigger the alibi. No UI feedback is given.
                // In exactly 15 seconds, a native phone call will ring.
                AlibiService.scheduleFakeCall(delaySeconds: 15);
              },
              child: Container(
                width: 50,
                height: 50,
                color: Colors.transparent, // Completely invisible trigger zone
              ),
            ),
          ),
        ],
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
          GestureDetector(
            onTap: () {
              _crashTapCount++;
              
              if (_crashTapCount >= 5) {
                SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              }
              
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _crashTapCount = 0;
                  });
                }
              });
            },
            onLongPress: () async {
              await _authService.enforcePinHardLock();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThermalDecoyScreen()),
              );
            },
            child: const Text(
              'Protiti (প্রতীতি)',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.myNotesSubtitle,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),

          if (_isCompromised)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panicRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.panicRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.panicRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.compromisedDeviceWarning,
                      style: const TextStyle(color: AppTheme.panicRed, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // PIN Indicators (4 dots)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
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
                    // Biometric Button
                    if (!_isBiometricLocked)
                      _buildActionButton(
                        icon: Icons.fingerprint_rounded,
                        onTap: _authenticateBiometric,
                        tooltip: AppLocalizations.of(context)!.biometricUnlockTooltip,
                      )
                    else
                      const SizedBox(width: 76, height: 76),
                    _buildNumberButton('0'),
                    // Backspace Button
                    _buildActionButton(
                      icon: Icons.backspace_rounded,
                      onTap: _onBackspace,
                      tooltip: AppLocalizations.of(context)!.deleteTooltip,
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      enableFeedback: false,
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
