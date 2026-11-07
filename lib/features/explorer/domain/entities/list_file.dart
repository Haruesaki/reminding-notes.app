import 'node_entry.dart';
import 'task.dart';

class ListFile extends FileEntry {
  final List<Task> tasks;

  const ListFile({
    required super.id,
    required super.relativePath,
    required super.title,
    required super.colorIndex,
    required super.favoritedAt,
    required super.createdAt,
    required super.updatedAt,
    super.schemaVersion = 1,
    super.extras = const {},
    this.tasks = const [],
  });

  @override
  String get type => 'list';

  ListFile copyWith({
    String? id,
    String? relativePath,
    String? title,
    int? colorIndex,
    DateTime? favoritedAt,
    bool clearFavoritedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
    Map<String, dynamic>? extras,
    List<Task>? tasks,
  }) {
    return ListFile(
      id: id ?? this.id,
      relativePath: relativePath ?? this.relativePath,
      title: title ?? this.title,
      colorIndex: colorIndex ?? this.colorIndex,
      favoritedAt: clearFavoritedAt ? null : (favoritedAt ?? this.favoritedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      extras: extras ?? this.extras,
      tasks: tasks ?? this.tasks,
    );
  }

  @override
  List<Object?> get props => [
        id,
        relativePath,
        title,
        colorIndex,
        favoritedAt,
        createdAt,
        updatedAt,
        schemaVersion,
        extras,
        tasks,
      ];
}
