import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _stationController.dispose();
    super.dispose();
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
                  color: AppTheme.tealLight,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Legal GD & Complaint Generator',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Draft formal General Diary (GD) complaints formatted under Bangladesh Police & Cyber Tribunal standards.',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Formal GD Complaint packaged and ready for export.',
                    ),
                    backgroundColor: AppTheme.deepAmethyst,
                  ),
                );
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
                        backgroundColor: AppTheme.deepAmethyst,
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
                      decoration: const InputDecoration(
                        labelText:
                            'Jurisdiction Thana / Police Station (e.g. Dhanmondi, Gulshan)',
                        prefixIcon: Icon(Icons.local_police_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText:
                            'Allegation Title (e.g., Cyber Extortion / Stalking)',
                        prefixIcon: Icon(Icons.report_problem_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
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
                title: const Text('Attach Verified Evidence'),
                subtitle: const Text('Link cryptographic items from vault'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.tealLight,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '3 vault evidence items selected (WhatsApp Screenshots, Call Recordings with SHA-256 hashes)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.teal,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Select Additional Evidence'),
                    ),
                  ],
                ),
                isActive: _currentStep >= 1,
                state: _currentStep > 1
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('Legal Review & Police Format'),
                subtitle: const Text('Standard General Diary (GD) layout'),
                content: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.warmGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'General Diary Format (সাধারণ ডায়েরি):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warmGold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'To: The Officer-in-Charge (OC)\n'
                        'Subject: Application for lodging General Diary regarding cyber harassment and extortion.\n\n'
                        'I, the undersigned, hereby report that I have been subjected to continuous cyber stalking and extortion. Attached hereto are cryptographic forensic exhibits bearing integrity verification hashes.',
                        style: TextStyle(fontSize: 12, height: 1.4),
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
                color: AppTheme.tealLight,
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
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Topic / Note Title',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Note Content...',
                alignLabelWithHint: true,
              ),
              maxLines: null,
              expands: true,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal),
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
