import 'package:flutter/material.dart';

class ComplaintWizardScreen extends StatefulWidget {
  @override
  _ComplaintWizardScreenState createState() => _ComplaintWizardScreenState();
}

class _ComplaintWizardScreenState extends State<ComplaintWizardScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: () {
        if (_currentStep < 2) {
          setState(() {
            _currentStep += 1;
          });
        }
      },
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() {
            _currentStep -= 1;
          });
        }
      },
      steps: [
        Step(
          title: Text('Incident Details'),
          content: Column(
            children: [
              TextField(decoration: InputDecoration(labelText: 'Incident Title')),
              TextField(decoration: InputDecoration(labelText: 'Description'), maxLines: 3),
            ],
          ),
          isActive: _currentStep >= 0,
        ),
        Step(
          title: Text('Evidence'),
          content: Column(
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.upload_file),
                label: Text('Upload Evidence'),
              ),
            ],
          ),
          isActive: _currentStep >= 1,
        ),
        Step(
          title: Text('Review & Submit'),
          content: Text('Review your details before submitting to generate the formal complaint.'),
          isActive: _currentStep >= 2,
        ),
      ],
    );
  }
}
