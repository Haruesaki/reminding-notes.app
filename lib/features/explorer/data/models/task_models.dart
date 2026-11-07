import '../../domain/entities/entities.dart';

class ToneRefModel extends ToneRef {
  const ToneRefModel({
    required super.id,
    required super.name,
    required super.relativePath,
    super.contentUri,
  });

  factory ToneRefModel.fromJson(Map<String, dynamic> json) {
    return ToneRefModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      relativePath: json['relativePath'] as String? ?? '',
      contentUri: json['contentUri'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relativePath': relativePath,
        if (contentUri != null) 'contentUri': contentUri,
      };
}

class DeadlineSettingsModel extends DeadlineSettings {
  const DeadlineSettingsModel({
    required super.at,
    super.remindStartDaysBefore = 3,
    super.remindTimes = const ['09:00', '15:00', '20:00'],
    super.notificationToneId,
    super.extras = const {},
  });

  static const _knownKeys = {
    'at',
    'remindStartDaysBefore',
    'remindTimes',
    'notificationToneId',
  };

  factory DeadlineSettingsModel.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) extras[k] = v;
    });

    final timesList = (json['remindTimes'] as List<dynamic>? ?? ['09:00', '15:00', '20:00'])
        .map((e) => e.toString())
        .toList();

    return DeadlineSettingsModel(
      at: json['at'] != null ? DateTime.parse(json['at'] as String) : DateTime.now(),
      remindStartDaysBefore: json['remindStartDaysBefore'] as int? ?? 3,
      remindTimes: timesList,
      notificationToneId: json['notificationToneId'] as String?,
      extras: extras,
    );
  }

  factory DeadlineSettingsModel.fromEntity(DeadlineSettings entity) {
    return DeadlineSettingsModel(
      at: entity.at,
      remindStartDaysBefore: entity.remindStartDaysBefore,
      remindTimes: entity.remindTimes,
      notificationToneId: entity.notificationToneId,
      extras: entity.extras,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'at': at.toIso8601String().replaceAll('Z', ''),
      'remindStartDaysBefore': remindStartDaysBefore,
      'remindTimes': remindTimes,
      'notificationToneId': notificationToneId,
    };
    map.addAll(extras);
    return map;
  }
}

class AlarmSettingsModel extends AlarmSettings {
  const AlarmSettingsModel({
    super.enabled = true,
    required super.at,
    super.toneId,
    super.extras = const {},
  });

  static const _knownKeys = {'enabled', 'at', 'toneId'};

  factory AlarmSettingsModel.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) extras[k] = v;
    });

    return AlarmSettingsModel(
      enabled: json['enabled'] as bool? ?? true,
      at: json['at'] != null ? DateTime.parse(json['at'] as String) : DateTime.now(),
      toneId: json['toneId'] as String?,
      extras: extras,
    );
  }

  factory AlarmSettingsModel.fromEntity(AlarmSettings entity) {
    return AlarmSettingsModel(
      enabled: entity.enabled,
      at: entity.at,
      toneId: entity.toneId,
      extras: entity.extras,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'enabled': enabled,
      'at': at.toIso8601String().replaceAll('Z', ''),
      'toneId': toneId,
    };
    map.addAll(extras);
    return map;
  }
}

class SubtaskModel extends Subtask {
  const SubtaskModel({
    required super.id,
    required super.text,
    super.done = false,
    super.extras = const {},
  });

  static const _knownKeys = {'id', 'text', 'done'};

  factory SubtaskModel.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) extras[k] = v;
    });

    return SubtaskModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      extras: extras,
    );
  }

  factory SubtaskModel.fromEntity(Subtask entity) {
    return SubtaskModel(
      id: entity.id,
      text: entity.text,
      done: entity.done,
      extras: entity.extras,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'text': text,
      'done': done,
    };
    map.addAll(extras);
    return map;
  }
}

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.text,
    super.done = false,
    super.collapsed = false,
    super.subtasks = const [],
    super.deadline,
    super.alarm,
    super.extras = const {},
  });

  static const _knownKeys = {
    'id',
    'text',
    'done',
    'collapsed',
    'subtasks',
    'deadline',
    'alarm',
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) extras[k] = v;
    });

    final subtasksList = (json['subtasks'] as List<dynamic>? ?? [])
        .map((e) => SubtaskModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return TaskModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      collapsed: json['collapsed'] as bool? ?? false,
      subtasks: subtasksList,
      deadline: json['deadline'] != null
          ? DeadlineSettingsModel.fromJson(json['deadline'] as Map<String, dynamic>)
          : null,
      alarm: json['alarm'] != null
          ? AlarmSettingsModel.fromJson(json['alarm'] as Map<String, dynamic>)
          : null,
      extras: extras,
    );
  }

  factory TaskModel.fromEntity(Task entity) {
    return TaskModel(
      id: entity.id,
      text: entity.text,
      done: entity.done,
      collapsed: entity.collapsed,
      subtasks: entity.subtasks,
      deadline: entity.deadline,
      alarm: entity.alarm,
      extras: entity.extras,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'text': text,
      'done': done,
      'collapsed': collapsed,
      'subtasks': subtasks.map((s) => SubtaskModel.fromEntity(s).toJson()).toList(),
      'deadline': deadline != null ? DeadlineSettingsModel.fromEntity(deadline!).toJson() : null,
      'alarm': alarm != null ? AlarmSettingsModel.fromEntity(alarm!).toJson() : null,
    };
    map.addAll(extras);
    return map;
  }
}
