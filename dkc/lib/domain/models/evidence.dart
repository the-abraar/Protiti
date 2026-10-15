import 'dart:convert';

class Evidence {
  final String id;
  final String type; // image, text or audio
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

  /// Metadata for an item saved now. [sha256] is of the original bytes (or a
  /// note's UTF-8 text) before any processing; [capturedAt] is this phone's
  /// clock, which whoever holds the phone can change.
  static Map<String, dynamic> captureMetadata({
    required String source,
    required String sha256,
    required DateTime capturedAt,
  }) => {
    'capture_source': source,
    'sha256': sha256,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };

  /// camera, gallery, screenshot, note or audio; null for rows saved before
  /// Oct 2026 that did not record it.
  String? get captureSource =>
      metadata?['capture_source'] as String? ??
      (metadata?['source'] == 'gallery_import' ? 'gallery' : null);

  /// SHA-256 of the original. Null for older rows: they stored a hash of the
  /// ciphertext, which proves nothing, under a different key.
  String? get sha256 => metadata?['sha256'] as String?;

  String? get platform => metadata?['platform'] as String?;

  /// When it was saved, by this phone's clock, in UTC.
  DateTime get capturedAt =>
      DateTime.tryParse(
        metadata?['captured_at'] ?? metadata?['capture_device_timestamp'] ?? '',
      )?.toUtc() ??
      createdAt.toUtc();

  /// The same item with her description, platform and link. Empty values clear them.
  Evidence withDetails({
    required String description,
    required String platform,
    required String url,
  }) => Evidence(
    id: id,
    type: type,
    filePath: filePath,
    url: url.isEmpty ? null : url,
    description: description,
    metadata: {...?metadata}
      ..remove('platform')
      ..addAll({if (platform.isNotEmpty) 'platform': platform}),
    createdAt: createdAt,
    isDecoy: isDecoy,
  );

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
