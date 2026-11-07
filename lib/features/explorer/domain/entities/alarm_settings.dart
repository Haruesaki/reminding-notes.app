import 'package:equatable/equatable.dart';

class AlarmSettings extends Equatable {
  final bool enabled;
  final DateTime at;
  final String? toneId;
  final Map<String, dynamic> extras;

  const AlarmSettings({
    this.enabled = true,
    required this.at,
    this.toneId,
    this.extras = const {},
  });

  AlarmSettings copyWith({
    bool? enabled,
    DateTime? at,
    String? toneId,
    Map<String, dynamic>? extras,
  }) {
    return AlarmSettings(
      enabled: enabled ?? this.enabled,
      at: at ?? this.at,
      toneId: toneId ?? this.toneId,
      extras: extras ?? this.extras,
    );
  }

  @override
  List<Object?> get props => [enabled, at, toneId, extras];
}
