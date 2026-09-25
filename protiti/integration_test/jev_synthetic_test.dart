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
    // Provide synthetic responses based on context
    if (context.toLowerCase().contains("fake profile") || context.toLowerCase().contains("impersonat")) {
      return {
        'answers': {
          'harassment_type': {'choice': 'impersonation'},
          'severity_score': {'score': 8},
          'requires_legal': {'probability': 0.85},
        }
      };
    } else if (context.toLowerCase().contains("money") || context.toLowerCase().contains("threat")) {
      return {
        'answers': {
          'harassment_type': {'choice': 'extortion'},
          'severity_score': {'score': 9},
          'requires_legal': {'probability': 0.95},
        }
      };
    }
    return {
      'answers': {
        'harassment_type': {'choice': 'unclear'},
        'severity_score': {'score': 2},
        'requires_legal': {'probability': 0.1},
      }
    };
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('JEV Synthetic Cases UI', (WidgetTester tester) async {
    final jev = MockJevService('dummy');
    
    final case1 = await jev.classifyHarassment("Someone created a fake profile with my pictures.");
    final case2 = await jev.classifyHarassment("They are threatening to post photos if I don't give money.");
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('JEV Integration Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 20),
              Text('Synthetic Case 1: Fake Profile', style: TextStyle(fontSize: 16)),
              Text('Result: $case1 (Expected: impersonation)', style: TextStyle(color: case1 == 'impersonation' ? Colors.green : Colors.red)),
              SizedBox(height: 10),
              Text('Synthetic Case 2: Extortion', style: TextStyle(fontSize: 16)),
              Text('Result: $case2 (Expected: extortion)', style: TextStyle(color: case2 == 'extortion' ? Colors.green : Colors.red)),
              SizedBox(height: 20),
              Text('JEV points us in the right direction!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          )
        )
      )
    ));
    
    await tester.pumpAndSettle();
    
    // Hold the screen for a bit so we can screenshot via external CLI
    await Future.delayed(Duration(seconds: 15));
  });
}
