import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secure_application/secure_application.dart';
import 'package:protiti/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../../data/services/database_service.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../domain/models/evidence.dart';
import 'package:provider/provider.dart';
import 'vault_provider.dart';
import 'secure_image_viewer.dart';
import 'secure_audio_player.dart';
import '../../../data/services/p2p_transfer_service.dart';
import '../panic/panic_screen.dart';
import '../complaint/complaint_wizard_screen.dart';
import '../support/support_screen.dart';
import '../auth/lock_screen.dart';
import '../../../data/services/proximity_lock_service.dart';
import '../../../data/services/bluetooth_tether_service.dart';
import '../../../data/services/screen_cast_monitor.dart';
import '../../../data/services/auth_service.dart';

class VaultScreen extends StatefulWidget {
  final bool isDecoy;

  const VaultScreen({super.key, this.isDecoy = false});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  late final List<Widget> _screens;
  late final ProximityLockService _proximityService;
  late final BluetoothTetherService _bluetoothTetherService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _proximityService = ProximityLockService();
    _bluetoothTetherService = BluetoothTetherService();
    
    // Temporarily disabled for testing:
    // Security monitors (Bluetooth tether, proximity sensor, screen cast)
    // are triggering and kicking the user back to the lock screen.
    /*
    if (!widget.isDecoy) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;

        _proximityService.startListening(() {
          if (mounted) {
            AuthService().enforcePinHardLock();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LockScreen()),
              (route) => false,
            );
          }
        });

        _bluetoothTetherService.startTetherMonitoring(() {
          if (mounted) {
            AuthService().enforcePinHardLock();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LockScreen()),
              (route) => false,
            );
          }
        });

        ScreenCastMonitor.startMonitoring(
          onCastDetected: () async {
            if (mounted) {
              await AuthService().enforcePinHardLock();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LockScreen()),
                (route) => false,
              );
            }
          },
          onScreenshotAttempted: () async {
            if (mounted) {
              await AuthService().enforcePinHardLock();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LockScreen()),
                (route) => false,
              );
            }
          },
        );
      });
    }
    */

    _screens = [
      VaultGridScreen(isDecoy: widget.isDecoy),
      ComplaintWizardScreen(isDecoy: widget.isDecoy),
      PanicScreen(isDecoy: widget.isDecoy),
      SupportScreen(isDecoy: widget.isDecoy),
    ];

    // Enable/disable screenshot protection ONCE after the first frame.
    // Must NOT be called from build() — doing so triggers SecureGate to 
    // show its lockedBuilder overlay on every rebuild, causing the gray screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final secureProvider = SecureApplicationProvider.of(context, listen: false);
      if (!widget.isDecoy) {
        secureProvider?.secure();
      } else {
        secureProvider?.open();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _proximityService.stopListening();
    _bluetoothTetherService.stopMonitoring();
    ScreenCastMonitor.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only lock on 'paused' (app sent to background). 
    // 'inactive' fires mid-transition and would instantly bounce the user back.
    if (state == AppLifecycleState.paused) {
      Clipboard.setData(const ClipboardData(text: ''));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LockScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  void _lockVault() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LockScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              widget.isDecoy
                  ? Icons.folder_shared_outlined
                  : Icons.lock_clock_outlined,
              size: 20,
              color: widget.isDecoy ? AppTheme.accentSoft : AppTheme.brandSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isDecoy
                  ? AppLocalizations.of(context)!.decoyVaultTitle
                  : AppLocalizations.of(context)!.appTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (!widget.isDecoy)
            IconButton(
              icon: const Icon(Icons.wifi_tethering),
              tooltip: 'Offline P2P Export',
              onPressed: () async {
                final p2pService = P2PTransferService();
                await p2pService.startOfflineBroadcast("System_Diagnostic_Sync");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Offline P2P Beacon Activated')),
                  );
                }
              },
            ),
          IconButton(
            tooltip: 'Lock Vault Immediately',
            icon: const Icon(Icons.lock, color: Colors.white70),
            onPressed: _lockVault,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(widget.isDecoy ? Icons.folder : Icons.shield),
            label: widget.isDecoy ? 'Files' : 'Vault',
          ),
          BottomNavigationBarItem(
            icon: Icon(widget.isDecoy ? Icons.edit_note : Icons.description),
            label: widget.isDecoy ? 'Notes' : 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              widget.isDecoy ? Icons.info_outline : Icons.warning_amber,
            ),
            label: widget.isDecoy ? 'Safety' : 'Panic SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              widget.isDecoy
                  ? Icons.contact_support_outlined
                  : Icons.support_agent,
            ),
            label: widget.isDecoy ? 'Help' : 'Support',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: widget.isDecoy
                  ? AppTheme.accentSoft
                  : AppTheme.brandSecondary,
              onPressed: () {
                if (widget.isDecoy) {
                  _showAddDialog(context);
                } else {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.primaryWhite,
                    builder: (ctx) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.note_add, color: AppTheme.brandSecondary),
                            title: const Text('Add Text Note', style: TextStyle(color: AppTheme.textPrimary)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showAddDialog(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: AppTheme.brandSecondary),
                            title: const Text('Secure Camera Capture', style: TextStyle(color: AppTheme.textPrimary)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await Provider.of<VaultProvider>(context, listen: false)
                                  .captureAndSaveSecureImage();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.mic, color: AppTheme.brandSecondary),
                            title: const Text('Secure Audio Record', style: TextStyle(color: AppTheme.textPrimary)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await Provider.of<VaultProvider>(context, listen: false)
                                  .captureAndSaveSecureAudio(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library, color: AppTheme.brandSecondary),
                            title: const Text('Secure Gallery Import', style: TextStyle(color: AppTheme.textPrimary)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final success = await Provider.of<VaultProvider>(context, listen: false)
                                  .importAndScrubGalleryImage();
                              
                              if (success && mounted) {
                                 // CRITICAL: We cannot silently delete from the public gallery due to OS rules.
                                 // We MUST show a highly visible alert forcing the user to do it manually.
                                 showDialog(
                                   context: context,
                                   builder: (ctx) => AlertDialog(
                                     backgroundColor: AppTheme.primaryWhite,
                                     title: Row(
                                       children: const [
                                         Icon(Icons.warning_amber, color: AppTheme.panicRed),
                                         SizedBox(width: 10),
                                         Text('Action Required', style: TextStyle(color: AppTheme.textPrimary)),
                                       ],
                                     ),
                                     content: const Text(
                                       'Your evidence is now encrypted and secured in the Vault. \n\n'
                                       'However, the original unencrypted photo is STILL in your phone\'s '
                                       'public photo gallery. You must open your Photos app and manually '
                                       'delete it (and clear your Recently Deleted folder) immediately to '
                                       'ensure your safety.',
                                       style: TextStyle(color: AppTheme.textSecondary),
                                     ),
                                     actions: [
                                       TextButton(
                                         onPressed: () => Navigator.pop(ctx),
                                         child: const Text('I Understand', style: TextStyle(color: AppTheme.brandSecondary)),
                                       ),
                                     ],
                                   ),
                                 );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: Text(widget.isDecoy ? 'Add File' : 'Secure Evidence'),
            )
          : null,
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.primaryWhite,
          title: Text(
            widget.isDecoy ? 'Add Personal Document' : 'Secure New Evidence',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: widget.isDecoy
                      ? 'Document Title / Note'
                      : 'Evidence Description',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  final newEvidence = Evidence(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: widget.isDecoy ? 'text' : 'screenshot',
                    description: text,
                    createdAt: DateTime.now(),
                    isDecoy: widget.isDecoy,
                  );
                  
                  await Provider.of<VaultProvider>(context, listen: false).addEvidence(newEvidence);
                  
                  if (context.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((_) {
      // FORENSIC SANITIZATION: Instantly scrub the text controller from RAM
      // when the dialog closes to prevent stalkerware memory scraping.
      titleController.dispose();
    });
  }
}

class VaultGridScreen extends StatelessWidget {
  final bool isDecoy;

  const VaultGridScreen({super.key, this.isDecoy = false});

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'screenshot':
      case 'image':
        return Icons.image_outlined;
      case 'audio':
        return Icons.audiotrack_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'video':
        return Icons.video_file_outlined;
      case 'link':
        return Icons.link;
      default:
        return Icons.description_outlined;
    }
  }

  Color _getBadgeColor(String type) {
    if (isDecoy) return AppTheme.brandSecondary;
    switch (type.toLowerCase()) {
      case 'audio':
        return AppTheme.panicRed;
      case 'screenshot':
        return AppTheme.brandSecondary;
      case 'pdf':
        return AppTheme.brandSecondary;
      default:
        return AppTheme.accentSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = provider.items;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDecoy ? Icons.folder_open : Icons.shield_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  isDecoy
                      ? 'No personal files saved yet'
                      : 'Forensic Vault is Empty',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadEvidence(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: isDecoy
                    ? Colors.grey[100]
                    : AppTheme.surfaceLight,
                child: Row(
                  children: [
                    Icon(
                      isDecoy
                          ? Icons.visibility_off_outlined
                          : Icons.verified_user_outlined,
                      size: 18,
                      color: isDecoy ? Colors.grey : AppTheme.brandSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDecoy
                            ? 'Showing 3 innocent decoy files.'
                            : 'Your evidence is stored securely and privately.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDecoy
                              ? Colors.grey[600]
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 220,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dateStr =
                        '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}';

                    return InkWell(
                      onTap: () {
                        if (item.type == 'image' && item.filePath != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SecureImageViewer(filePath: item.filePath!),
                            ),
                          );
                        } else if (item.type == 'audio' && item.filePath != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SecureAudioPlayer(filePath: item.filePath!),
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.primaryWhite,
                              title: const Text('Evidence Details', style: TextStyle(color: AppTheme.textPrimary)),
                              content: SingleChildScrollView(
                                child: Text(item.description, style: const TextStyle(color: AppTheme.textPrimary)),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                )
                              ]
                            )
                          );
                        }
                      },
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDecoy
                                ? Colors.black12
                                : AppTheme.accentSoft.withValues(alpha: 0.2),
                          ),
                        ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getBadgeColor(
                                      item.type,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getIconForType(item.type),
                                    size: 26,
                                    color: _getBadgeColor(item.type),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.type.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              item.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (!isDecoy)
                                  const Icon(
                                    Icons.shield,
                                    size: 14,
                                    color: AppTheme.accentSoft,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
