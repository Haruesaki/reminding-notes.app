import 'package:equatable/equatable.dart';
import 'alarm_settings.dart';
import 'deadline_settings.dart';

class Subtask extends Equatable {
  final String id;
  final String text;
  final bool done;
  final Map<String, dynamic> extras;

  const Subtask({
    required this.id,
    required this.text,
    this.done = false,
    this.extras = const {},
  });

  Subtask copyWith({
    String? id,
    String? text,
    bool? done,
    Map<String, dynamic>? extras,
  }) {
    return Subtask(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
      extras: extras ?? this.extras,
    );
  }

  @override
  List<Object?> get props => [id, text, done, extras];
}

class Task extends Equatable {
  final String id;
  final String text;
  final bool done;
  final bool collapsed;
  final List<Subtask> subtasks;
  final DeadlineSettings? deadline;
  final AlarmSettings? alarm;
  final Map<String, dynamic> extras;

  const Task({
    required this.id,
    required this.text,
    this.done = false,
    this.collapsed = false,
    this.subtasks = const [],
    this.deadline,
    this.alarm,
    this.extras = const {},
  });

  Task copyWith({
    String? id,
    String? text,
    bool? done,
    bool? collapsed,
    List<Subtask>? subtasks,
    DeadlineSettings? deadline,
    bool clearDeadline = false,
    AlarmSettings? alarm,
    bool clearAlarm = false,
    Map<String, dynamic>? extras,
  }) {
    return Task(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
      collapsed: collapsed ?? this.collapsed,
      subtasks: subtasks ?? this.subtasks,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      alarm: clearAlarm ? null : (alarm ?? this.alarm),
      extras: extras ?? this.extras,
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        done,
        collapsed,
        subtasks,
        deadline,
        alarm,
        extras,
      ];
}
