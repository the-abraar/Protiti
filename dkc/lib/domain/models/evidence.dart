import 'dart:convert';

class Evidence {
  final String id;
  final String type; // screenshot, link, text, audio, video, pdf
  final String? filePath;
  final String? url;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isDecoy;

  Evidence({
    required this.id,
    required this.type,
    this.filePath,
    this.url,
    required this.description,
    this.metadata,
    required this.createdAt,
    this.isDecoy = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'filePath': filePath,
      'url': url,
      'description': description,
      'metadata': metadata != null ? jsonEncode(metadata) : '',
      'createdAt': createdAt.toIso8601String(),
      'isDecoy': isDecoy ? 1 : 0,
    };
  }

  factory Evidence.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? meta;
    if (map['metadata'] != null && map['metadata'].toString().isNotEmpty) {
      try {
        meta = jsonDecode(map['metadata'].toString()) as Map<String, dynamic>?;
      } catch (_) {
        meta = null;
      }
    }

    return Evidence(
      id: map['id'] as String,
      type: map['type'] as String,
      filePath: map['filePath'] as String?,
      url: map['url'] as String?,
      description: map['description'] as String,
      metadata: meta,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isDecoy: (map['isDecoy'] as int? ?? 0) == 1,
    );
  }
}
