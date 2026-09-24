import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../../data/services/database_service.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../domain/models/evidence.dart';
import '../panic/panic_screen.dart';
import '../complaint/complaint_wizard_screen.dart';
import '../support/support_screen.dart';
import '../auth/lock_screen.dart';

class VaultScreen extends StatefulWidget {
  final bool isDecoy;

  const VaultScreen({super.key, this.isDecoy = false});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      VaultGridScreen(isDecoy: widget.isDecoy),
      ComplaintWizardScreen(isDecoy: widget.isDecoy),
      PanicScreen(isDecoy: widget.isDecoy),
      SupportScreen(isDecoy: widget.isDecoy),
    ];
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
              color: widget.isDecoy ? AppTheme.teal : AppTheme.warmGold,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isDecoy
                  ? 'Personal Notes & Files'
                  : 'Protiti Forensic Vault',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
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
                  ? AppTheme.teal
                  : AppTheme.deepAmethyst,
              onPressed: () => _showAddDialog(context),
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
          backgroundColor: AppTheme.cardDark,
          title: Text(
            widget.isDecoy ? 'Add Personal Document' : 'Secure New Evidence',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  final repo = EvidenceRepository(DatabaseService());
                  final newEvidence = Evidence(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: widget.isDecoy ? 'text' : 'screenshot',
                    description: text,
                    createdAt: DateTime.now(),
                    isDecoy: widget.isDecoy,
                  );
                  await repo.addEvidence(newEvidence);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class VaultGridScreen extends StatefulWidget {
  final bool isDecoy;

  const VaultGridScreen({super.key, this.isDecoy = false});

  @override
  State<VaultGridScreen> createState() => _VaultGridScreenState();
}

class _VaultGridScreenState extends State<VaultGridScreen> {
  final EvidenceRepository _evidenceRepo = EvidenceRepository(
    DatabaseService(),
  );
  late Future<List<Evidence>> _evidenceFuture;

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  void _loadEvidence() {
    setState(() {
      _evidenceFuture = _evidenceRepo.getEvidence(isDecoy: widget.isDecoy);
    });
  }

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
    if (widget.isDecoy) return AppTheme.tealLight;
    switch (type.toLowerCase()) {
      case 'audio':
        return AppTheme.crimson;
      case 'screenshot':
        return AppTheme.warmGold;
      case 'pdf':
        return AppTheme.tealLight;
      default:
        return AppTheme.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Evidence>>(
      future: _evidenceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isDecoy ? Icons.folder_open : Icons.shield_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isDecoy
                      ? 'No personal files saved yet'
                      : 'Forensic Vault is Empty',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadEvidence(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: widget.isDecoy
                    ? Colors.grey[900]
                    : AppTheme.deepAmethyst.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    Icon(
                      widget.isDecoy
                          ? Icons.visibility_off_outlined
                          : Icons.verified_user_outlined,
                      size: 18,
                      color: widget.isDecoy ? Colors.grey : AppTheme.tealLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isDecoy
                            ? 'Showing 3 innocent decoy files. Sensitive evidence is completely hidden.'
                            : 'Encrypted Forensic Storage: Real-time SHA-256 integrity hashing active.',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDecoy
                              ? Colors.grey[400]
                              : AppTheme.textPrimaryDark,
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
                    childAspectRatio: 0.82,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dateStr =
                        '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}';

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: widget.isDecoy
                              ? Colors.white10
                              : AppTheme.teal.withValues(alpha: 0.2),
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
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.type.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
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
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                if (!widget.isDecoy)
                                  const Icon(
                                    Icons.shield,
                                    size: 14,
                                    color: AppTheme.tealLight,
                                  ),
                              ],
                            ),
                          ],
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
