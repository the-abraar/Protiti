class Evidence {
  final String id;
  final String type; // screenshot, link, text
  final String? filePath;
  final String? url;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Evidence({
    required this.id,
    required this.type,
    this.filePath,
    this.url,
    required this.description,
    this.metadata,
    required this.createdAt,
  });
}\n