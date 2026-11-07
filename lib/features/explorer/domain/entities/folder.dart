import 'node_entry.dart';

class Folder extends NodeEntry {
  final String name;
  final DateTime createdAt;
  final List<String> order;
  final int schemaVersion;
  final Map<String, dynamic> extras;

  const Folder({
    required super.id,
    required super.relativePath,
    required this.name,
    required this.createdAt,
    this.order = const [],
    this.schemaVersion = 1,
    this.extras = const {},
  });

  @override
  bool get isFolder => true;

  Folder copyWith({
    String? id,
    String? relativePath,
    String? name,
    DateTime? createdAt,
    List<String>? order,
    int? schemaVersion,
    Map<String, dynamic>? extras,
  }) {
    return Folder(
      id: id ?? this.id,
      relativePath: relativePath ?? this.relativePath,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      extras: extras ?? this.extras,
    );
  }

  @override
  List<Object?> get props => [
        id,
        relativePath,
        name,
        createdAt,
        order,
        schemaVersion,
        extras,
      ];
}
