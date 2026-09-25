import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/database_service.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../domain/use_cases/trigger_panic.dart';
import '../../../data/services/secure_audio_service.dart';
import '../../../data/services/flashlight_sos_service.dart';
import '../../../data/services/acoustic_deterrent_service.dart';
import 'strobe_screen.dart';

class PanicScreen extends StatefulWidget {
  final bool isDecoy;

  const PanicScreen({super.key, this.isDecoy = false});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _holdController;

  late final TriggerPanicUseCase _panicUseCase;
  bool _isHolding = false;
  bool _isTriggered = false;
  bool _isDispatching = false;
  PanicResult? _lastResult;
  final FlashlightSosService _flashlightService = FlashlightSosService();
  bool _isVisualSosActive = false;
  final AcousticDeterrentService _sirenService = AcousticDeterrentService();
  bool _isSirenActive = false;

  @override
  void initState() {
    super.initState();
    _panicUseCase = TriggerPanicUseCase(
      LocationService(),
      contactRepository: ContactRepository(DatabaseService()),
      audioService: SecureAudioService(),
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
  }

  @override
  void dispose() {
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

  Future<void> _onHoldCompleted() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _isTriggered = true;
      _isDispatching = true;
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
    setState(() {
      _isTriggered = false;
      _lastResult = null;
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
          // Header Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _isTriggered
                  ? AppTheme.crimson.withValues(alpha: 0.2)
                  : AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isTriggered
                    ? AppTheme.crimson
                    : AppTheme.teal.withValues(alpha: 0.4),
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
                  color: _isTriggered ? AppTheme.crimson : AppTheme.warmGold,
                ),
                const SizedBox(width: 8),
                Text(
                  _isTriggered
                      ? 'EMERGENCY SEQUENCE ACTIVE'
                      : 'OFFLINE SMS DISPATCH READY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isTriggered ? AppTheme.crimson : AppTheme.warmGold,
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
              color: Colors.white
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
              style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
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
              color: Colors.white
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
                ? 'Emergency SOS triggered! Broadcasted to responders.'
                : (_isHolding
                      ? 'Keep holding... ${(3.0 - (_holdController.value * 3.0)).toStringAsFixed(1)}s'
                      : 'Press & Hold for 3 seconds to broadcast SOS'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _isHolding ? AppTheme.warmGold : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dispatches GPS coordinates via offline SMS to emergency contacts without requiring mobile data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),

          const SizedBox(height: 28),

          // Dispatch Status & Results
          if (_isDispatching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.crimson),
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
                  backgroundColor: AppTheme.cardDark,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isTriggered ? AppTheme.crimson : AppTheme.warmGold,
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
                          ? [AppTheme.crimson, const Color(0xFF8B0000)]
                          : [const Color(0xFFE53935), AppTheme.crimson],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.crimson.withValues(
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
                            color: AppTheme.warmGold,
                            letterSpacing: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDispatchResultCard(PanicResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Offline SMS Dispatched Successfully',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: _resetEmergency,
                tooltip: 'Disarm SOS',
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.white12),
          Text(
            'Location Coordinates:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            result.locationDisplay,
            style: const TextStyle(fontSize: 12, color: AppTheme.warmGold),
          ),
          const SizedBox(height: 10),
          Text(
            'Recipients (${result.recipients.length}): ${result.recipients.join(", ")}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              result.formattedMessage,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[300],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyHotlines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.phone_in_talk, size: 16, color: AppTheme.tealLight),
            SizedBox(width: 8),
            Text(
              'Direct Bangladesh Emergency Hotlines',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryDark,
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
                AppTheme.crimson,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHotlineCard(
                '109',
                'GBV Toll-Free BD',
                AppTheme.tealLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildHotlineCard(
                '10921',
                'Violence Helpline',
                AppTheme.warmGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHotlineCard(
                '01320000888',
                'Cyber Police BD',
                Colors.deepPurpleAccent,
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
          color: AppTheme.cardDark,
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
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Innocent Decoy View shown when Duress PIN (9999) was entered
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
                color: AppTheme.tealLight,
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
          Text(
            'General campus, traffic, and emergency assistance numbers for daily living in Dhaka.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          _buildDecoyItem(
            'Dhaka Medical College Emergency',
            '+880255165088',
            'Medical',
          ),
          const SizedBox(height: 10),
          _buildDecoyItem(
            'National Emergency Services',
            '999',
            'Public Service',
          ),
          const SizedBox(height: 10),
          _buildDecoyItem(
            'Dhaka University Proctor Office',
            '01700000000',
            'Campus Info',
          ),
          const SizedBox(height: 10),
          _buildDecoyItem(
            'Dhaka Traffic Control Room',
            '01713398500',
            'Transit Helpline',
          ),
        ],
      ),
    );
  }

  Widget _buildDecoyItem(String title, String phone, String category) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
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
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _callHotline(phone),
            icon: const Icon(Icons.call, size: 16, color: AppTheme.tealLight),
            label: Text(
              phone,
              style: const TextStyle(color: AppTheme.tealLight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
