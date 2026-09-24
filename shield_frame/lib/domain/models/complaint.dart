class Complaint {
  final String id;
  final String type;
  final String title;
  final String description;
  final List<String> evidenceIds;
  final String generatedText;
  final String targetPoliceStation;
  final String status;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.evidenceIds,
    required this.generatedText,
    required this.targetPoliceStation,
    required this.status,
    required this.createdAt,
  });
}\n