import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:protiti/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../../domain/models/evidence.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
    // The camera or photo picker she opened from here backgrounds the app;
    // locking then would drop her photo (B18).
    if (state == AppLifecycleState.paused && !context.read<VaultProvider>().pickerOpen) {
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
                            title: Text(l10n.addTextNote, style: const TextStyle(color: AppTheme.textPrimary)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showAddDialog(context);
                            },
                          ),
                          for (final (icon, label, save, fromGallery) in <(IconData, String, Future<Evidence?> Function(VaultProvider), bool)>[
                            (Icons.camera_alt, l10n.secureCameraCapture, (v) => v.addImage(ImageSource.camera, captureSource: 'camera'), false),
                            (Icons.mic, l10n.secureAudioRecord, (v) => v.captureAndSaveSecureAudio(context), false),
                            (Icons.photo_library, l10n.secureGalleryImport, (v) => v.addImage(ImageSource.gallery, captureSource: 'gallery'), true),
                            (Icons.screenshot_outlined, l10n.secureScreenshotImport, (v) => v.addImage(ImageSource.gallery, captureSource: 'screenshot'), true),
                          ])
                            ListTile(
                              leading: Icon(icon, color: AppTheme.brandSecondary),
                              title: Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
                              onTap: () {
                                Navigator.pop(ctx);
                                _capture(context, save, fromGallery: fromGallery);
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

  /// Saves the photo or recording first, so nothing is lost if she stops
  /// here, then asks for the optional description, platform and link.
  Future<void> _capture(
    BuildContext context,
    Future<Evidence?> Function(VaultProvider) save, {
    required bool fromGallery,
  }) async {
    final vault = Provider.of<VaultProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final saved = await save(vault);
    if (saved == null || !context.mounted) return;
    if (fromGallery) {
      // We cannot delete from the public gallery (OS rules), so she must be told.
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.primaryWhite,
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: AppTheme.panicRed),
              const SizedBox(width: 10),
              Text(l10n.actionRequiredTitle, style: const TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
          content: Text(l10n.galleryDeleteWarning, style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.iUnderstand, style: const TextStyle(color: AppTheme.brandSecondary)),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
    }
    final details = await showDialog<EvidenceDetails>(
      context: context,
      builder: (_) => EvidenceDetailsDialog(title: l10n.addDetailsTitle, description: saved.description, withSource: true),
    );
    if (details == null) return;
    await vault.updateDetails(
      saved,
      description: details.description.isEmpty ? saved.description : details.description,
      platform: details.platform,
      url: details.url,
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final vault = Provider.of<VaultProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final details = await showDialog<EvidenceDetails>(
      context: context,
      builder: (_) => EvidenceDetailsDialog(
        title: widget.isDecoy ? l10n.addPersonalDocument : l10n.secureNewEvidence,
        descriptionLabel: widget.isDecoy ? l10n.documentTitleLabel : l10n.evidenceDescriptionLabel,
        withSource: !widget.isDecoy,
        requireDescription: true,
      ),
    );
    if (details == null) return;
    await vault.addNote(details.description, platform: details.platform, url: details.url);
  }
}

typedef EvidenceDetails = ({String description, String platform, String url});

/// Description, and for real evidence the app or platform and the link.
/// Plain text fields so Bangla keyboards work; nothing is suggested or learned.
class EvidenceDetailsDialog extends StatefulWidget {
  final String title;
  final String? descriptionLabel;
  final String description;
  final bool withSource;
  final bool requireDescription;

  const EvidenceDetailsDialog({
    super.key,
    required this.title,
    this.descriptionLabel,
    this.description = '',
    required this.withSource,
    this.requireDescription = false,
  });

  @override
  State<EvidenceDetailsDialog> createState() => _EvidenceDetailsDialogState();
}

class _EvidenceDetailsDialogState extends State<EvidenceDetailsDialog> {
  late final _description = TextEditingController(text: widget.description);
  final _platform = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    // Drop her text from memory as soon as the dialog closes.
    _description.dispose();
    _platform.dispose();
    _url.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label, {TextInputType? type, int maxLines = 1}) => TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        minLines: 1,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppTheme.primaryWhite,
      title: Text(widget.title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_description, widget.descriptionLabel ?? l10n.evidenceDescriptionLabel,
                type: TextInputType.multiline, maxLines: 4),
            if (widget.withSource) ...[
              _field(_platform, l10n.evidencePlatformLabel),
              _field(_url, l10n.evidenceUrlLabel, type: TextInputType.url),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.requireDescription ? l10n.cancel : l10n.skip,
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _description.text.trim();
            if (widget.requireDescription && text.isEmpty) return;
            Navigator.pop<EvidenceDetails>(
                context, (description: text, platform: _platform.text.trim(), url: _url.text.trim()));
          },
          child: Text(l10n.save),
        ),
      ],
    );
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

  /// What was recorded about an item. Notes-app rows show only their text.
  void _showDetails(BuildContext context, Evidence item) {
    final l10n = AppLocalizations.of(context)!;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              SelectableText(value, style: const TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
        );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryWhite,
        title: Text(l10n.evidenceDetailsTitle, style: const TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.description, style: const TextStyle(color: AppTheme.textPrimary)),
              if (!item.isDecoy) ...[
                row(l10n.captureSourceLabel, l10n.captureSourceName(item.captureSource ?? 'other')),
                row(l10n.capturedAtLabel, DateFormat('yyyy-MM-dd HH:mm:ss').format(item.capturedAt)),
                if (item.platform != null) row(l10n.platformLabel, item.platform!),
                if (item.url != null) row(l10n.linkLabel, item.url!),
                row(l10n.sha256Label, item.sha256 ?? l10n.notRecorded),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
        ],
      ),
    );
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
                    _showDetails(context, item);
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
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                              tooltip: AppLocalizations.of(context)!.evidenceDetailsTitle,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _showDetails(context, item),
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
