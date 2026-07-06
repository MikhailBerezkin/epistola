class MediaAsset {
  final String id;
  final String provider;
  final String path;
  final String type;

  final String? ownerType;
  final String? ownerId;

  final String? mimeType;
  final int? sizeBytes;

  final int? width;
  final int? height;
  final int? durationMs;

  final int version;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? downloadUrl;

  const MediaAsset({
    required this.id,
    required this.provider,
    required this.path,
    required this.type,
    this.ownerType,
    this.ownerId,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
    this.downloadUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider,
      'path': path,
      'type': type,
      'ownerType': ownerType,
      'ownerId': ownerId,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'width': width,
      'height': height,
      'durationMs': durationMs,
      'version': version,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'downloadUrl': downloadUrl,
    };
  }

  factory MediaAsset.fromMap(Map<String, dynamic> map) {
    return MediaAsset(
      id: map['id'] ?? '',
      provider: map['provider'] ?? '',
      path: map['path'] ?? '',
      type: map['type'] ?? '',
      ownerType: map['ownerType'],
      ownerId: map['ownerId'],
      mimeType: map['mimeType'],
      sizeBytes: map['sizeBytes'],
      width: map['width'],
      height: map['height'],
      durationMs: map['durationMs'],
      version: map['version'] ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
      downloadUrl: map['downloadUrl'],
    );
  }

  MediaAsset copyWith({
    String? id,
    String? provider,
    String? path,
    String? type,
    String? ownerType,
    String? ownerId,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
    int? durationMs,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? downloadUrl,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      path: path ?? this.path,
      type: type ?? this.type,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}
