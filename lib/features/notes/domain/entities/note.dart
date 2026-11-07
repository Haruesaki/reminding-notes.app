import 'package:equatable/equatable.dart';

class Note extends Equatable {
  final String id;
  final String title;
  final String content;
  final String? category;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reminderAt;
  final bool isArchived;

  const Note({
    required this.id,
    this.title = '',
    this.content = '',
    this.category,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.reminderAt,
    this.isArchived = false,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reminderAt,
    bool? isArchived,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderAt: reminderAt ?? this.reminderAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        category,
        isPinned,
        createdAt,
        updatedAt,
        reminderAt,
        isArchived,
      ];
}
