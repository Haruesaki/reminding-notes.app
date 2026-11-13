import 'package:equatable/equatable.dart';
import '../../../../explorer/domain/entities/tone_ref.dart';

abstract class TonesEvent extends Equatable {
  const TonesEvent();

  @override
  List<Object?> get props => [];
}

class LoadTones extends TonesEvent {
  const LoadTones();
}

class AddToneEvent extends TonesEvent {
  final String filePath;
  final String name;

  const AddToneEvent({required this.filePath, required this.name});

  @override
  List<Object?> get props => [filePath, name];
}

class DeleteToneEvent extends TonesEvent {
  final String toneId;

  const DeleteToneEvent(this.toneId);

  @override
  List<Object?> get props => [toneId];
}

class PlayTonePreviewEvent extends TonesEvent {
  final ToneRef tone;

  const PlayTonePreviewEvent(this.tone);

  @override
  List<Object?> get props => [tone];
}

class StopTonePreviewEvent extends TonesEvent {
  const StopTonePreviewEvent();
}
