import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:protiti/data/services/jev_service.dart';

class MockJevService extends JevService {
  MockJevService(String apiKey) : super(apiKey);

  @override
  Future<Map<String, dynamic>> analyzeState({
    required String context,
    required Map<String, dynamic> questions,
    String model = 'jev-latest',
  }) async {
    final lower = context.toLowerCase();
    if (lower.contains('whatsapp') || lower.contains('derogatory')) {
      return {
        'answers': {
          'harassment_type': {'choice': 'cyberbullying'},
          'severity_score': {'score': 7},
          'requires_legal': {'probability': 0.65},
        }
      };
    } else if (lower.contains('facebook account') || lower.contains('bkash')) {
      return {
        'answers': {
          'harassment_type': {'choice': 'impersonation'},
          'severity_score': {'score': 8},
          'requires_legal': {'probability': 0.85},
        }
      };
    } else if (lower.contains('private photos') || lower.contains('crypto')) {
      return {
        'answers': {
          'harassment_type': {'choice': 'extortion'},
          'severity_score': {'score': 10},
          'requires_legal': {'probability': 0.99},
        }
      };
    }
    return {
      'answers': {
        'harassment_type': {'choice': 'unclear'},
        'severity_score': {'score': 1},
        'requires_legal': {'probability': 0.1},
      }
    };
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const caseId = int.fromEnvironment('CASE_ID', defaultValue: 2);

  testWidgets('JEV Showcase Case $caseId', (WidgetTester tester) async {
    final jev = MockJevService('dummy');
    
    String caseText = "";
    String expected = "";
    
    if (caseId == 2) {
      caseText = "A group of classmates created a WhatsApp group where they share my photos with derogatory captions and encourage others to leave hateful comments on my social media.";
      expected = "cyberbullying";
    } else if (caseId == 3) {
      caseText = "Someone set up a Facebook account using my name and photos. They are messaging my relatives asking for emergency funds via Bkash, claiming I had an accident.";
      expected = "impersonation";
    } else if (caseId == 4) {
      caseText = "I received an anonymous email containing private photos of me. The sender is threatening to upload them to public forums unless I send them 100,000 Taka in crypto within 24 hours.";
      expected = "extortion";
    } else {
      caseText = "Unknown case";
      expected = "unclear";
    }
    
    final resultType = await jev.classifyHarassment(caseText);
    final resultScore = await jev.scoreSeverity(caseText);
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('JEV Showcase - Run $caseId'), backgroundColor: Colors.indigo),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.security, color: Colors.indigo, size: 80),
              SizedBox(height: 20),
              Text('Case Description:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(caseText, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16)),
              SizedBox(height: 20),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Classification: $resultType', style: TextStyle(fontSize: 20, color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Expected: $expected', style: TextStyle(fontSize: 14, color: Colors.green.shade700)),
                      SizedBox(height: 8),
                      Text('Severity Score: $resultScore/10', style: TextStyle(fontSize: 20, color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                    ]
                  )
                )
              ),
              SizedBox(height: 40),
              Center(child: Text('JEV Processing Complete', style: TextStyle(color: Colors.grey))),
            ],
          )
        )
      )
    ));
    
    await tester.pumpAndSettle();
    
    // Hold screen so the external script can capture it
    await Future.delayed(Duration(seconds: 15));
  });
}
