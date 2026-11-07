import 'package:equatable/equatable.dart';

class DeadlineSettings extends Equatable {
  final DateTime at;
  final int remindStartDaysBefore;
  final List<String> remindTimes;
  final String? notificationToneId;
  final Map<String, dynamic> extras;

  const DeadlineSettings({
    required this.at,
    this.remindStartDaysBefore = 3,
    this.remindTimes = const ['09:00', '15:00', '20:00'],
    this.notificationToneId,
    this.extras = const {},
  });

  DeadlineSettings copyWith({
    DateTime? at,
    int? remindStartDaysBefore,
    List<String>? remindTimes,
    String? notificationToneId,
    bool clearNotificationToneId = false,
    Map<String, dynamic>? extras,
  }) {
    return DeadlineSettings(
      at: at ?? this.at,
      remindStartDaysBefore: remindStartDaysBefore ?? this.remindStartDaysBefore,
      remindTimes: remindTimes ?? this.remindTimes,
      notificationToneId: clearNotificationToneId
          ? null
          : (notificationToneId ?? this.notificationToneId),
      extras: extras ?? this.extras,
    );
  }

  @override
  List<Object?> get props => [
        at,
        remindStartDaysBefore,
        remindTimes,
        notificationToneId,
        extras,
      ];
}
