import '../../domain/entities/note.dart';

class NoteModel extends Note {
  const NoteModel({
    required super.id,
    super.title,
    super.content,
    super.category,
    super.isPinned,
    required super.createdAt,
    required super.updatedAt,
    super.reminderAt,
    super.isArchived,
  });

  factory NoteModel.fromEntity(Note note) {
    return NoteModel(
      id: note.id,
      title: note.title,
      content: note.content,
      category: note.category,
      isPinned: note.isPinned,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      reminderAt: note.reminderAt,
      isArchived: note.isArchived,
    );
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      category: map['category'] as String?,
      isPinned: (map['is_pinned'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      reminderAt: map['reminder_at'] != null
          ? DateTime.parse(map['reminder_at'] as String)
          : null,
      isArchived: (map['is_archived'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'is_pinned': isPinned ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'reminder_at': reminderAt?.toIso8601String(),
      'is_archived': isArchived ? 1 : 0,
    };
  }
}
