import 'dart:io';
import '../lib/data/services/jev_service.dart';

void main() async {
  // Replace with your actual TypeSafe AI API Key or read from env
  final apiKey = Platform.environment['JEV_API_KEY'] ?? 'YOUR_API_KEY_HERE';
  
  if (apiKey == 'YOUR_API_KEY_HERE') {
    print('Warning: Using dummy API key. Please set JEV_API_KEY env var.');
  }

  final jevService = JevService(apiKey);

  final realIncidentData = [
    '''
    I received a message on Facebook from an unknown account threatening to post
    morphed pictures of me online unless I pay them 50,000 Taka. They sent a 
    sample picture to my inbox. This has been happening since yesterday evening.
    ''',
    '''
    Someone created a fake Instagram profile using my real name and photos. 
    They are messaging my friends and asking for money, claiming I had an accident.
    ''',
    '''
    I was walking down the street and someone yelled at me from a passing car.
    '''
  ];

  print('--- Testing JEV Integration with Real Data ---');
  
  for (int i = 0; i < realIncidentData.length; i++) {
    final incident = realIncidentData[i].trim();
    print('\n[Incident ${i + 1}]');
    print('Context: $incident');
    
    try {
      final harassmentType = await jevService.classifyHarassment(incident);
      final severity = await jevService.scoreSeverity(incident);
      final needsLegal = await jevService.requiresImmediateLegalSupport(incident);
      
      print('=> Harassment Type: $harassmentType');
      print('=> Severity Score: $severity / 10');
      print('=> Needs Immediate Legal Support: $needsLegal');
    } catch (e) {
      print('=> Error processing incident: $e');
    }
  }
}
