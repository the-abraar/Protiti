import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../domain/models/evidence.dart';
import 'database_service.dart';
import '../repositories/evidence_repository.dart';

class DecoyGeneratorService {
  final EvidenceRepository _repository;
  DecoyGeneratorService(this._repository);

  /// Silently fetches real, benign content from public APIs to make the 
  /// decoy vault look like an actively used, legitimate application.
  Future<void> seedDynamicDecoys() async {
    try {
      // Fetch a random educational/benign summary (e.g., standard physics or history)
      final response = await http.get(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/random/summary'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final dynamicDecoy = Evidence(
          id: const Uuid().v4(),
          type: 'text',
          description: '${data['title']}\n\n${data['extract']}',
          // Randomize the timestamp to look organic (sometime in the last 72 hours)
          createdAt: DateTime.now().subtract(Duration(hours: 12 + (DateTime.now().second))),
          isDecoy: true,
        );
        
        await _repository.addEvidence(dynamicDecoy);
      }
    } catch (e) {
      // Gracefully ignore failures; we don't want to alert the user of networking errors in the decoy state
    }
  }
}
