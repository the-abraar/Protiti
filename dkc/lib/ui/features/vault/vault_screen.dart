import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:protiti/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../../domain/models/evidence.dart';
import 'package:provider/provider.dart';
import 'vault_provider.dart';
import 'secure_image_viewer.dart';
import 'secure_audio_player.dart';
import '../panic/panic_screen.dart';
import '../complaint/complaint_wizard_screen.dart';
import '../support/support_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/lock_screen.dart';

class VaultScreen extends StatefulWidget {
  final bool isDecoy;

  const VaultScreen({super.key, this.isDecoy = false});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _screens = [
      VaultGridScreen(isDecoy: widget.isDecoy),
      ComplaintWizardScreen(isDecoy: widget.isDecoy),
      PanicScreen(isDecoy: widget.isDecoy),
      SupportScreen(isDecoy: widget.isDecoy),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  // Chrome (app bar, tabs, button) is identical in both modes: the duress
  // view must not look different from the real one (B2).
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 20, color: AppTheme.brandSecondary),
            const SizedBox(width: 8),
            Text(
              l10n.appTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.safetySettingsTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(isDecoy: widget.isDecoy)),
              );
            },
          ),
          IconButton(
            tooltip: l10n.lockVaultTooltip,
            icon: const Icon(Icons.lock),
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
          BottomNavigationBarItem(icon: const Icon(Icons.folder), label: l10n.navFiles),
          BottomNavigationBarItem(icon: const Icon(Icons.edit_note), label: l10n.navNotes),
          BottomNavigationBarItem(
            icon: const Icon(Icons.health_and_safety_outlined),
            label: l10n.navSafety,
          ),
          BottomNavigationBarItem(icon: const Icon(Icons.help_outline), label: l10n.navHelp),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.brandSecondary,
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
                            title: Text(AppLocalizations.of(context)!.addTextNote, style: const TextStyle(color: AppTheme.textPrimary)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showAddDialog(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: AppTheme.brandSecondary),
                            title: Text(AppLocalizations.of(context)!.secureCameraCapture, style: const TextStyle(color: AppTheme.textPrimary)),
                            onTap: () async {
                              final vault = Provider.of<VaultProvider>(context, listen: false);
                              Navigator.pop(ctx);
                              await vault.captureAndSaveSecureImage();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.mic, color: AppTheme.brandSecondary),
                            title: Text(AppLocalizations.of(context)!.secureAudioRecord, style: const TextStyle(color: AppTheme.textPrimary)),
                            onTap: () async {
                              final vault = Provider.of<VaultProvider>(context, listen: false);
                              Navigator.pop(ctx);
                              await vault.captureAndSaveSecureAudio(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library, color: AppTheme.brandSecondary),
                            title: Text(AppLocalizations.of(context)!.secureGalleryImport, style: const TextStyle(color: AppTheme.textPrimary)),
                            onTap: () async {
                              final vault = Provider.of<VaultProvider>(context, listen: false);
                              Navigator.pop(ctx);
                              final success = await vault.importAndScrubGalleryImage();

                              if (success && context.mounted) {
                                 // CRITICAL: We cannot silently delete from the public gallery due to OS rules.
                                 // We MUST show a highly visible alert forcing the user to do it manually.
                                 showDialog(
                                   context: context,
                                   builder: (ctx) => AlertDialog(
                                     backgroundColor: AppTheme.primaryWhite,
                                     title: Row(
                                       children: [
                                         const Icon(Icons.warning_amber, color: AppTheme.panicRed),
                                         const SizedBox(width: 10),
                                         Text(AppLocalizations.of(context)!.actionRequiredTitle, style: const TextStyle(color: AppTheme.textPrimary)),
                                       ],
                                     ),
                                     content: Text(
                                       AppLocalizations.of(context)!.galleryDeleteWarning,
                                       style: const TextStyle(color: AppTheme.textSecondary),
                                     ),
                                     actions: [
                                       TextButton(
                                         onPressed: () => Navigator.pop(ctx),
                                         child: Text(AppLocalizations.of(context)!.iUnderstand, style: const TextStyle(color: AppTheme.brandSecondary)),
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
              label: Text(l10n.addFileFab),
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
            widget.isDecoy
                ? AppLocalizations.of(context)!.addPersonalDocument
                : AppLocalizations.of(context)!.secureNewEvidence,
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
                      ? AppLocalizations.of(context)!.documentTitleLabel
                      : AppLocalizations.of(context)!.evidenceDescriptionLabel,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
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

                  final vault = Provider.of<VaultProvider>(context, listen: false);
                  await vault.addEvidence(newEvidence);

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.save),
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
    switch (type.toLowerCase()) {
      case 'audio':
        return AppTheme.panicRed;
      case 'screenshot':
      case 'pdf':
        return AppTheme.brandSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _confirmDelete(BuildContext context, Evidence item) async {
    final vault = Provider.of<VaultProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteItemTitle),
        content: Text(l10n.deleteItemBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteTooltip, style: const TextStyle(color: AppTheme.panicRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) await vault.deleteEvidence(item);
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
                const Icon(Icons.folder_open, size: 64, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  provider.loadFailed
                      ? AppLocalizations.of(context)!.storageErrorMessage
                      : AppLocalizations.of(context)!.noPersonalFilesYet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadEvidence(),
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
                        title: Text(AppLocalizations.of(context)!.evidenceDetailsTitle, style: const TextStyle(color: AppTheme.textPrimary)),
                        content: SingleChildScrollView(
                          child: Text(item.description, style: const TextStyle(color: AppTheme.textPrimary)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(AppLocalizations.of(context)!.close),
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
                    side: BorderSide(color: AppTheme.accentSoft.withValues(alpha: 0.2)),
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
                                color: _getBadgeColor(item.type).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getIconForType(item.type),
                                size: 26,
                                color: _getBadgeColor(item.type),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                              tooltip: AppLocalizations.of(context)!.deleteTooltip,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _confirmDelete(context, item),
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
        );
      },
    );
  }
}
