import '../../domain/entities/entities.dart';

class FolderModel extends Folder {
  const FolderModel({
    required super.id,
    required super.relativePath,
    required super.name,
    required super.createdAt,
    super.order = const [],
    super.schemaVersion = 1,
    super.extras = const {},
  });

  static const _knownKeys = {
    'schemaVersion',
    'id',
    'name',
    'createdAt',
    'order',
  };

  factory FolderModel.fromJson(Map<String, dynamic> json, {required String relativePath}) {
    final extras = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) extras[k] = v;
    });

    final orderList = (json['order'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return FolderModel(
      id: json['id'] as String? ?? '',
      relativePath: relativePath,
      name: json['name'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      order: orderList,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      extras: extras,
    );
  }

  factory FolderModel.fromEntity(Folder entity) {
    return FolderModel(
      id: entity.id,
      relativePath: entity.relativePath,
      name: entity.name,
      createdAt: entity.createdAt,
      order: entity.order,
      schemaVersion: entity.schemaVersion,
      extras: entity.extras,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'name': name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'order': order,
    };
    map.addAll(extras);
    return map;
  }
}
