import '../../domain/entities/entities.dart';

class PageFileModel extends PageFile {
  const PageFileModel({
    required super.id,
    required super.relativePath,
    required super.title,
    required super.colorIndex,
    required super.favoritedAt,
    required super.createdAt,
    required super.updatedAt,
    super.schemaVersion = 1,
    super.extras = const {},
    super.content = const [],
    super.plainText = '',
  });

  static const _knownKeys = {
    'schemaVersion',
    'id',
    'type',
    'title',
    'colorIndex',
    'favoritedAt',
    'createdAt',
    'updatedAt',
    'content',
    'plainText',
  };

  factory PageFileModel.fromJson(Map<String, dynamic> json, {required String relativePath}) {
    final extras = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) extras[k] = v;
    });

    return PageFileModel(
      id: json['id'] as String? ?? '',
      relativePath: relativePath,
      title: json['title'] as String? ?? '',
      colorIndex: json['colorIndex'] as int? ?? 0,
      favoritedAt: json['favoritedAt'] != null
          ? DateTime.tryParse(json['favoritedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      content: json['content'] as List<dynamic>? ?? const [],
      plainText: json['plainText'] as String? ?? '',
      extras: extras,
    );
  }

  factory PageFileModel.fromEntity(PageFile entity) {
    return PageFileModel(
      id: entity.id,
      relativePath: entity.relativePath,
      title: entity.title,
      colorIndex: entity.colorIndex,
      favoritedAt: entity.favoritedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      schemaVersion: entity.schemaVersion,
      content: entity.content,
      plainText: entity.plainText,
      extras: entity.extras,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'type': type,
      'title': title,
      'colorIndex': colorIndex,
      'favoritedAt': favoritedAt?.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'content': content,
      'plainText': plainText,
    };
    map.addAll(extras);
    return map;
  }
}
