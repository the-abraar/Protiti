import 'dart:convert';
import 'package:http/http.dart' as http;

/// A service to interact with the TypeSafe AI Jev model (System One).
class JevService {
  final String _apiKey;
  static const String _baseUrl = 'https://api.typesafe.ai/v1/systemone';

  JevService(this._apiKey);

  /// Analyzes the given [context] using the Jev model and answers the [questions].
  ///
  /// The [questions] should be a map where the key is a stable business ID
  /// and the value defines the primitive type (`Choice`, `Score`, or `Noul`).
  Future<Map<String, dynamic>> analyzeState({
    required String context,
    required Map<String, dynamic> questions,
    String model = 'jev-latest',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'state': context,
          'model': model,
          'questions': questions,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to analyze state with Jev: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network or parsing error during Jev API call: $e');
    }
  }

  /// Convenience method to classify harassment type for the GD-Automator.
  Future<String?> classifyHarassment(String evidenceContext) async {
    final questions = {
      'harassment_type': {
        'type': 'Choice',
        'options': [
          'cyberbullying',
          'impersonation',
          'extortion',
          'threat',
          'unclear',
        ],
        'prompt': 'Classify the primary type of harassment described.',
      },
    };

    final result = await analyzeState(
      context: evidenceContext,
      questions: questions,
    );

    // Assuming the response structure maps question keys to their Choice result
    if (result['answers'] != null &&
        result['answers']['harassment_type'] != null) {
      return result['answers']['harassment_type']['choice'] as String?;
    }
    return null;
  }

  /// Convenience method to determine if immediate legal support is needed.
  Future<bool> requiresImmediateLegalSupport(String incidentContext) async {
    final questions = {
      'requires_legal': {
        'type': 'Noul',
        'prompt': 'Does this incident require immediate legal intervention?',
      },
    };

    final result = await analyzeState(
      context: incidentContext,
      questions: questions,
    );

    if (result['answers'] != null &&
        result['answers']['requires_legal'] != null) {
      final prob =
          result['answers']['requires_legal']['probability'] as double?;
      return (prob ?? 0.0) > 0.6; // True if probability > 60%
    }
    return false;
  }

  /// Convenience method to score the severity of an incident.
  Future<int> scoreSeverity(String incidentContext) async {
    final questions = {
      'severity_score': {
        'type': 'Score',
        'rubric':
            'Score the severity of the threat from 1 (lowest) to 10 (highest).',
      },
    };

    final result = await analyzeState(
      context: incidentContext,
      questions: questions,
    );

    if (result['answers'] != null &&
        result['answers']['severity_score'] != null) {
      return (result['answers']['severity_score']['score'] as num?)?.toInt() ??
          1;
    }
    return 1;
  }
}
