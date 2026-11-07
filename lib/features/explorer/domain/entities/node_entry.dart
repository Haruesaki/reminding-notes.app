import 'package:equatable/equatable.dart';

abstract class NodeEntry extends Equatable {
  final String id;
  final String relativePath;

  const NodeEntry({
    required this.id,
    required this.relativePath,
  });

  bool get isFolder;
  bool get isFile => !isFolder;
}

abstract class FileEntry extends NodeEntry {
  final String title;
  final int colorIndex;
  final DateTime? favoritedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final Map<String, dynamic> extras;

  const FileEntry({
    required super.id,
    required super.relativePath,
    required this.title,
    required this.colorIndex,
    required this.favoritedAt,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.extras = const {},
  });

  @override
  bool get isFolder => false;
  bool get isFavorite => favoritedAt != null;

  String get type;
}
