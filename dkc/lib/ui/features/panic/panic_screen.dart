import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:protiti/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/database_service.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../domain/use_cases/trigger_panic.dart';
import '../../../data/services/secure_audio_service.dart';
import '../../../data/services/flashlight_sos_service.dart';
import '../../../data/services/acoustic_deterrent_service.dart';
import '../../../data/services/background_sos_service.dart';
import '../../../data/services/native_sms_service.dart';
import '../../../data/services/silent_alert_service.dart';
import 'strobe_screen.dart';

class PanicScreen extends StatefulWidget {
  final bool isDecoy;
  final TriggerPanicUseCase? useCase;

  /// Delivery reports, (recipient, delivered); defaults to the SMS plugin's.
  final Stream<(String, bool)>? deliveries;

  const PanicScreen({
    super.key,
    this.isDecoy = false,
    this.useCase,
    this.deliveries,
  });

  /// How an SOS goes out once the screen is gone mid-countdown: silent SMS
  /// only, so nothing (Messages, a share sheet) pops up later for anyone to see.
  @visibleForTesting
  static SmsDispatcher unattendedSms = dispatchSilentSms;

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  late final AnimationController _holdController;

  late final TriggerPanicUseCase _panicUseCase;
  bool _isHolding = false;
  bool _isTriggered = false;
  bool _isDispatching = false;
  PanicResult? _lastResult;
  // Cancel window after the hold (B24), then delivery reports for the result.
  Timer? _countdown;
  int _secondsLeft = 0;
  final Map<String, bool> _delivered = {};
  StreamSubscription<(String, bool)>? _deliverySub;
  String? _lastAlert;
  final FlashlightSosService _flashlightService = FlashlightSosService();
  bool _isVisualSosActive = false;
  final AcousticDeterrentService _sirenService = AcousticDeterrentService();
  bool _isSirenActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Permissions are asked in Settings, after an explanation, never here.
    _panicUseCase =
        widget.useCase ??
        TriggerPanicUseCase(
          LocationService(),
          contactRepository: ContactRepository(DatabaseService()),
          audioService: SecureAudioService(),
          evidenceRepository: EvidenceRepository(DatabaseService()),
        );

    // Continuous pulse animation for SOS visibility
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 3-second hold to activate animation
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onHoldCompleted();
      }
    });

    if (!widget.isDecoy) {
      _deliverySub = (widget.deliveries ?? NativeSmsService.deliveries).listen((
        d,
      ) {
        if (mounted && _lastResult?.dispatch.statuses[d.$1] == SmsStatus.sent) {
          setState(() => _delivered[d.$1] = d.$2);
        }
      });
      AlertLog.summary().then((text) {
        if (mounted) setState(() => _lastAlert = text);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _sendIfLeftMidCountdown()) {
      _resetEmergency();
    }
  }

  /// She held SOS for 3 s, then the screen went away (screen off, another app,
  /// a tab change, the vault locking). That sends at once, never cancels (N2).
  /// Nothing is left on screen to show the result, so it buzzes the outcome
  /// and the SOS tab reports it the next time she opens it.
  bool _sendIfLeftMidCountdown() {
    if (!(_countdown?.isActive ?? false)) return false;
    _countdown!.cancel();
    _sendUnattended(_panicUseCase);
    return true;
  }

  static Future<void> _sendUnattended(TriggerPanicUseCase useCase) async {
    PanicResult? result;
    try {
      result = await useCase.execute(
        dim: false,
        record: false,
        sms: PanicScreen.unattendedSms,
      );
      await AlertLog.record(result);
    } catch (_) {}
    await const SosAlerts().vibrate(
      (result?.success ?? false) ? Buzz.sent : Buzz.failed,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendIfLeftMidCountdown();
    _countdown?.cancel();
    _deliverySub?.cancel();
    _flashlightService.stopVisualSos();
    _sirenService.stopSiren();
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    if (_isTriggered) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
    });
    _holdController.forward(from: 0.0);
  }

  void _onHoldEnd() {
    if (_isTriggered) return;
    if (_holdController.value < 1.0) {
      _holdController.reverse();
      setState(() {
        _isHolding = false;
      });
    }
  }

  /// The hold starts the same cancel window as the background triggers.
  void _onHoldCompleted() {
    const SosAlerts().vibrate(Buzz.armed);
    setState(() {
      _isHolding = false;
      _isTriggered = true;
      _secondsLeft = sosCancelWindow.inSeconds;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _sendNow();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendNow() async {
    _countdown?.cancel();
    setState(() {
      _secondsLeft = 0;
      _isDispatching = true;
      _delivered.clear();
    });

    // Execute offline SMS & location dispatch
    final result = await _panicUseCase.execute();

    if (mounted) {
      setState(() {
        _isDispatching = false;
        _lastResult = result;
      });
    }
  }

  void _resetEmergency() {
    HapticFeedback.selectionClick();
    _countdown?.cancel();
    setState(() {
      _isTriggered = false;
      _secondsLeft = 0;
      _lastResult = null;
      _delivered.clear();
      _holdController.reset();
    });
  }

  Future<void> _callHotline(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDecoy) {
      return _buildDecoySafetyView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_lastAlert != null) _buildLastAlert(_lastAlert!),
          // Header Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _isTriggered
                  ? AppTheme.panicRed.withValues(alpha: 0.2)
                  : AppTheme.primaryWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isTriggered
                    ? AppTheme.panicRed
                    : AppTheme.accentSoft.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isTriggered
                      ? Icons.warning_rounded
                      : Icons.offline_bolt_outlined,
                  size: 16,
                  color: _isTriggered
                      ? AppTheme.panicRed
                      : AppTheme.brandSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isTriggered
                      ? 'EMERGENCY SEQUENCE ACTIVE'
                      : 'OFFLINE SMS DISPATCH READY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isTriggered
                        ? AppTheme.panicRed
                        : AppTheme.brandSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Central SOS Hold Button with Progress Ring
          _buildHoldButton(),

          const SizedBox(height: 40),

          ElevatedButton.icon(
            icon: Icon(
              _isVisualSosActive ? Icons.flashlight_off : Icons.flashlight_on,
              color: Colors.white,
            ),
            label: Text(
              _isVisualSosActive ? 'STOP VISUAL SOS' : 'ACTIVATE VISUAL SOS',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isVisualSosActive ? Colors.red : Colors.orange,
            ),
            onPressed: () {
              setState(() {
                _isVisualSosActive = !_isVisualSosActive;
              });
              if (_isVisualSosActive) {
                _flashlightService.startVisualSos();
              } else {
                _flashlightService.stopVisualSos();
              }
            },
          ),
          const SizedBox(height: 20),

          OutlinedButton.icon(
            icon: const Icon(Icons.phone_in_talk, color: Colors.redAccent),
            label: const Text(
              'CALL 999 NOW',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              side: const BorderSide(color: Colors.redAccent, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              // Instantly trigger the native phone dialer intent
              _panicUseCase.launchEmergencyCall();
            },
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(
              _isSirenActive ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
            label: Text(
              _isSirenActive ? 'STOP SIREN ALARM' : 'TRIGGER SIREN ALARM',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSirenActive ? Colors.red : Colors.yellow[800],
            ),
            onPressed: () {
              setState(() {
                _isSirenActive = !_isSirenActive;
              });

              if (_isSirenActive) {
                _sirenService.triggerLoudSiren();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StrobeScreen()),
                ).then((_) {
                  _sirenService.stopSiren();
                  if (mounted) {
                    setState(() {
                      _isSirenActive = false;
                    });
                  }
                });
              } else {
                _sirenService.stopSiren();
              }
            },
          ),

          const SizedBox(height: 32),

          // Instructions / Status Text
          Text(
            _isTriggered
                ? (_secondsLeft > 0
                      ? 'Sending in $_secondsLeft s. Cancel if this was a mistake.'
                      : _isDispatching
                      ? 'Sending SOS...'
                      : 'SOS finished. See the result below.')
                : (_isHolding
                      ? 'Keep holding... ${(3.0 - (_holdController.value * 3.0)).toStringAsFixed(1)}s'
                      : AppLocalizations.of(context)!.panicHoldInstruction),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Texts your location to your trusted contacts by SMS. No mobile data needed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),

          const SizedBox(height: 28),

          // Dispatch Status & Results
          if (_secondsLeft > 0)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetEmergency,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendNow,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: AppTheme.panicRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Send now',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            )
          else if (_isDispatching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.panicRed),
            )
          else if (_lastResult != null)
            _buildDispatchResultCard(_lastResult!),

          const SizedBox(height: 24),

          // Quick Hotline Buttons (Bangladesh Direct Emergency Dialers)
          _buildEmergencyHotlines(),
        ],
      ),
    );
  }

  Widget _buildHoldButton() {
    return Semantics(
      button: true,
      label: 'Press and hold for 3 seconds to broadcast SOS',
      child: GestureDetector(
        onTapDown: (_) => _onHoldStart(),
        onTapUp: (_) => _onHoldEnd(),
        onTapCancel: () => _onHoldEnd(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _holdController]),
          builder: (context, child) {
            final pulseScale = _isTriggered
                ? 1.05
                : 1.0 + (_pulseController.value * 0.05);

            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer Progress Ring (Fills up during 3-second hold)
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: _holdController.value,
                    strokeWidth: 8,
                    backgroundColor: AppTheme.primaryWhite,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isTriggered
                          ? AppTheme.panicRed
                          : AppTheme.brandSecondary,
                    ),
                  ),
                ),

                // Glowing Pulsing SOS Circle
                Transform.scale(
                  scale: pulseScale,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 190,
                      minHeight: 190,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isTriggered
                              ? [AppTheme.panicRed, const Color(0xFF8B0000)]
                              : [const Color(0xFFE53935), AppTheme.panicRed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.panicRed.withValues(
                              alpha: _isTriggered ? 0.7 : 0.4,
                            ),
                            blurRadius: _isHolding ? 40 : 25,
                            spreadRadius: _isHolding ? 8 : 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isTriggered
                                ? Icons.notification_important
                                : Icons.touch_app_outlined,
                            size: 44,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isTriggered ? 'ACTIVE' : 'SOS',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          if (_isHolding)
                            Text(
                              'HOLDING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// An alert sent while the app was not on screen (shortcut, second PIN, or an
  /// in-app SOS she left mid-countdown).
  Widget _buildLastAlert(String text) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: ListTile(
      leading: const Icon(Icons.history, color: AppTheme.brandSecondary),
      title: Text(text, style: const TextStyle(fontSize: 13)),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Dismiss',
        onPressed: () {
          AlertLog.clear();
          setState(() => _lastAlert = null);
        },
      ),
    ),
  );

  static const _statusText = {
    SmsStatus.sent: 'Sent',
    SmsStatus.failed: 'Failed',
    SmsStatus.unconfirmed: 'Not confirmed: press Send in Messages',
  };

  /// The real outcome per recipient. Anything short of "all sent" puts a
  /// big Call 999 button right next to the problem.
  Widget _buildDispatchResultCard(PanicResult result) {
    final allSent = result.success;
    final String headline;
    if (result.dispatchMethod == 'no_contacts') {
      headline =
          'No SOS text sent: you have no trusted contacts yet. Add them in Settings.';
    } else if (allSent) {
      headline = 'SOS text sent to every contact.';
    } else if (result.dispatch.statuses.values.every(
      (s) => s == SmsStatus.unconfirmed,
    )) {
      headline = 'SOS text not confirmed. Check that it was sent.';
    } else {
      headline = 'SOS text failed for some or all contacts.';
    }
    final accent = allSent ? AppTheme.brandSecondary : AppTheme.panicRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allSent ? Icons.check_circle_outline : Icons.error_outline,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: accent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                onPressed: _resetEmergency,
                tooltip: AppLocalizations.of(context)!.disarmSosTooltip,
              ),
            ],
          ),
          if (!allSent) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.panicRed,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.phone_in_talk, size: 28),
                label: const Text(
                  'Call 999',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                onPressed: _panicUseCase.launchEmergencyCall,
              ),
            ),
          ],
          const Divider(height: 24),
          for (final entry in result.dispatch.statuses.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${entry.key}: ${_statusText[entry.value]}${switch (_delivered[entry.key]) {
                  true => ', delivered',
                  false => ', not delivered',
                  null => '',
                }}',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      entry.value == SmsStatus.sent &&
                          _delivered[entry.key] != false
                      ? AppTheme.textPrimary
                      : AppTheme.panicRed,
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Location sent:',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            result.locationDisplay,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              result.formattedMessage,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Only hotlines checked so far. TODO(owner): verify PCSW (01320000888)
  // and any campus or NGO numbers with the services themselves before adding them.
  Widget _buildEmergencyHotlines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.phone_in_talk, size: 16, color: AppTheme.brandSecondary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Direct Bangladesh Emergency Hotlines',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildHotlineCard(
                '999',
                'National Police / EMS',
                AppTheme.panicRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHotlineCard(
                '109',
                'Violence against women helpline',
                AppTheme.brandSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHotlineCard(String number, String label, Color accentColor) {
    return InkWell(
      onTap: () => _callHotline(number),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.call, size: 16, color: accentColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Innocent view shown after the second (duress) PIN
  Widget _buildDecoySafetyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.health_and_safety_outlined,
                color: AppTheme.brandSecondary,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'Personal Well-Being & Safety',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Emergency assistance numbers for daily living in Bangladesh.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          // Verified national numbers only; TODO(owner): verify any local
          // numbers (hospital, campus, traffic) before listing them here.
          _buildDecoyItem(
            'National Emergency Services',
            '999',
            'Public Service',
          ),
          const SizedBox(height: 10),
          _buildDecoyItem('National Helpline', '109', 'Public Service'),
        ],
      ),
    );
  }

  Widget _buildDecoyItem(String title, String phone, String category) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentSoft.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _callHotline(phone),
            icon: const Icon(
              Icons.call,
              size: 16,
              color: AppTheme.brandSecondary,
            ),
            label: Text(
              phone,
              style: const TextStyle(
                color: AppTheme.brandSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
