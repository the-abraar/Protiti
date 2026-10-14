import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:printing/printing.dart';
import '../../../domain/models/complaint.dart';
import '../../../domain/use_cases/generate_complaint.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/secure_store.dart';
import '../../core/theme/app_theme.dart';
import '../vault/vault_provider.dart';

class ComplaintWizardScreen extends StatefulWidget {
  final bool isDecoy;

  const ComplaintWizardScreen({super.key, this.isDecoy = false});

  @override
  State<ComplaintWizardScreen> createState() => _ComplaintWizardScreenState();
}

class _ComplaintWizardScreenState extends State<ComplaintWizardScreen> {
  int _currentStep = 0;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _stationController = TextEditingController();
  final _storage = secureStore;
  // Everything is attached unless she unticks it.
  final Set<String> _excludedIds = {};

  @override
  void initState() {
    super.initState();
    _loadSecureDraft();

    // Auto-save listeners
    _titleController.addListener(_saveSecureDraft);
    _descController.addListener(_saveSecureDraft);
    _stationController.addListener(_saveSecureDraft);
  }

  Future<void> _loadSecureDraft() async {
    if (widget.isDecoy) {
      _titleController.text =
          await _storage.read(key: StoreKeys.notesDraftTitle) ?? '';
      _descController.text = await _storage.read(key: StoreKeys.notesDraftBody) ?? '';
      return;
    }

    _titleController.text = await _storage.read(key: StoreKeys.draftTitle) ?? '';
    _descController.text = await _storage.read(key: StoreKeys.draftDescription) ?? '';
    _stationController.text =
        await _storage.read(key: StoreKeys.draftStation) ?? '';
  }

  Timer? _debounce;

  void _saveSecureDraft() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (widget.isDecoy) {
        _storage.write(key: StoreKeys.notesDraftTitle, value: _titleController.text);
        _storage.write(key: StoreKeys.notesDraftBody, value: _descController.text);
      } else {
        _storage.write(key: StoreKeys.draftTitle, value: _titleController.text);
        _storage.write(key: StoreKeys.draftDescription, value: _descController.text);
        _storage.write(key: StoreKeys.draftStation, value: _stationController.text);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _stationController.dispose();
    super.dispose();
  }

  Future<void> _generateAndExportPDF() async {
    final useCase = GenerateComplaintUseCase();
    final vaultEvidence = Provider.of<VaultProvider>(context, listen: false)
        .items
        .where((e) => !_excludedIds.contains(e.id))
        .toList();

    final result = await useCase.execute(
      vaultEvidence,
      {
        'title': _titleController.text,
        'description': _descController.text,
        'station': _stationController.text,
      },
    );

    if (!mounted) return;

    // Persist the dossier so it survives app termination and shows up in
    // any future "My Complaints" history view.
    try {
      final repository = ComplaintRepository(DatabaseService(isDecoy: false));
      await repository.saveComplaint(
        Complaint(
          id: result.dossierId,
          type: 'GD',
          title: _titleController.text,
          description: _descController.text,
          evidenceIds: vaultEvidence.map((e) => e.id).toList(),
          generatedText: result.generatedText,
          targetPoliceStation: _stationController.text,
          status: 'GENERATED',
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      // Export can still proceed even if the local history save fails.
    }

    // The PDF never touches disk here. The share sheet writes its own copy,
    // which TempFiles.sweep removes when she comes back to the app.
    try {
      await Printing.sharePdf(
        bytes: result.pdfBytes,
        filename: '${result.dossierId}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDecoy) {
      return _buildDecoyNotesDraftView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.gavel_outlined,
                  color: AppTheme.brandSecondary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Legal GD & Complaint Generator',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Draft a General Diary (GD) complaint to print or share. Not reviewed by a lawyer.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          Stepper(
            physics: const ClampingScrollPhysics(),
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() {
                  _currentStep += 1;
                });
              } else {
                _generateAndExportPDF();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep -= 1;
                });
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandSecondary,
                      ),
                      onPressed: details.onStepContinue,
                      child: Text(
                        _currentStep == 2 ? 'Generate & Export GD' : 'Continue',
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Incident & Thana Details'),
                subtitle: const Text(
                  'Designate Police Station and incident scope',
                ),
                content: Column(
                  children: [
                    TextField(
                      controller: _stationController,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: const InputDecoration(
                        labelText:
                            'Jurisdiction Thana / Police Station (e.g. Dhanmondi, Gulshan)',
                        prefixIcon: Icon(Icons.local_police_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: const InputDecoration(
                        labelText:
                            'Allegation Title (e.g., Cyber Extortion / Stalking)',
                        prefixIcon: Icon(Icons.report_problem_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'Chronological Description of Incident',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                  ],
                ),
                isActive: _currentStep >= 0,
                state: _currentStep > 0
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('Choose Evidence'),
                subtitle: const Text('Choose which items go into the PDF'),
                content: Consumer<VaultProvider>(
                  builder: (context, vaultProvider, _) {
                    final items = vaultProvider.items;
                    final chosen = items.where((e) => !_excludedIds.contains(e.id)).length;
                    final summary = items.isEmpty
                        ? 'No evidence yet. Save items in the Files tab, then come back to choose them.'
                        : '$chosen of ${items.length} item${items.length == 1 ? '' : 's'} will go into the PDF. '
                              'Untick anything you do not want to include.';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryWhite,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accentSoft.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                items.isEmpty
                                    ? Icons.info_outline
                                    : Icons.check_circle,
                                color: AppTheme.brandSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  summary,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final item in items)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: !_excludedIds.contains(item.id),
                            title: Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(item.type),
                            onChanged: (include) => setState(() {
                              if (include == true) {
                                _excludedIds.remove(item.id);
                              } else {
                                _excludedIds.add(item.id);
                              }
                            }),
                          ),
                      ],
                    );
                  },
                ),
                isActive: _currentStep >= 1,
                state: _currentStep > 1
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('Review the draft'),
                subtitle: const Text('Standard General Diary (GD) layout'),
                content: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.brandSecondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General Diary Format (সাধারণ ডায়েরি):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.brandSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'To: The Officer-in-Charge (OC)\n'
                        'Subject: Application for lodging General Diary regarding cyber harassment and extortion.\n\n'
                        'I, the undersigned, hereby report the following incident. The items I chose are listed with the '
                        'SHA-256 fingerprint of each original file, which anyone with the same file can recompute.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This makes an offline PDF draft. It is NOT sent to gd.police.gov.bd or any government '
                                'system (no public API exists for that). Present the PDF to the Duty Officer at your '
                                'Thana, or contact the PCSW helpline ($pcswPhone).',
                                style: TextStyle(fontSize: 11, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 2,
                state: StepState.indexed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecoyNotesDraftView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.note_alt_outlined,
                color: AppTheme.brandSecondary,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Personal Study Notes & Outlines',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Draft class essays, personal reminders, or travel itineraries.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(
              labelText: 'Topic / Note Title',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _descController,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Note Content...',
                alignLabelWithHint: true,
              ),
              maxLines: null,
              expands: true,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentSoft),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Personal note saved.')),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Note'),
          ),
        ],
      ),
    );
  }
}
