import 'node_entry.dart';

class PageFile extends FileEntry {
  final List<dynamic> content;
  final String plainText;

  const PageFile({
    required super.id,
    required super.relativePath,
    required super.title,
    required super.colorIndex,
    required super.favoritedAt,
    required super.createdAt,
    required super.updatedAt,
    super.schemaVersion = 1,
    super.extras = const {},
    this.content = const [],
    this.plainText = '',
  });

  @override
  String get type => 'page';

  PageFile copyWith({
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
    List<dynamic>? content,
    String? plainText,
  }) {
    return PageFile(
      id: id ?? this.id,
      relativePath: relativePath ?? this.relativePath,
      title: title ?? this.title,
      colorIndex: colorIndex ?? this.colorIndex,
      favoritedAt: clearFavoritedAt ? null : (favoritedAt ?? this.favoritedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      extras: extras ?? this.extras,
      content: content ?? this.content,
      plainText: plainText ?? this.plainText,
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
        content,
        plainText,
      ];
}
