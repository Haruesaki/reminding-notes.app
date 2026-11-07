import 'package:equatable/equatable.dart';
import '../../../../explorer/domain/entities/tone_ref.dart';

enum TonesStatus { initial, loading, loaded, error }

class TonesState extends Equatable {
  final TonesStatus status;
  final List<ToneRef> tones;
  final String? playingToneId;
  final bool isPlaying;
  final String? errorMessage;

  const TonesState({
    this.status = TonesStatus.initial,
    this.tones = const [],
    this.playingToneId,
    this.isPlaying = false,
    this.errorMessage,
  });

  TonesState copyWith({
    TonesStatus? status,
    List<ToneRef>? tones,
    String? playingToneId,
    bool? isPlaying,
    String? errorMessage,
    bool clearPlaying = false,
  }) {
    return TonesState(
      status: status ?? this.status,
      tones: tones ?? this.tones,
      playingToneId: clearPlaying ? null : (playingToneId ?? this.playingToneId),
      isPlaying: clearPlaying ? false : (isPlaying ?? this.isPlaying),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tones,
        playingToneId,
        isPlaying,
        errorMessage,
      ];
}
