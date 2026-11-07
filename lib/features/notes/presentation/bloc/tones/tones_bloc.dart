import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../data/datasources/tones_local_data_source.dart';
import 'tones_event.dart';
import 'tones_state.dart';

class TonesBloc extends Bloc<TonesEvent, TonesState> {
  final TonesLocalDataSource dataSource;
  final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSub;

  TonesBloc({
    required this.dataSource,
    AudioPlayer? audioPlayer,
  })  : _audioPlayer = audioPlayer ?? AudioPlayer(),
        super(const TonesState()) {
    on<LoadTones>(_onLoadTones);
    on<AddToneEvent>(_onAddTone);
    on<DeleteToneEvent>(_onDeleteTone);
    on<PlayTonePreviewEvent>(_onPlayTonePreview);
    on<StopTonePreviewEvent>(_onStopTonePreview);

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      add(const StopTonePreviewEvent());
    });
  }

  Future<void> _onLoadTones(LoadTones event, Emitter<TonesState> emit) async {
    emit(state.copyWith(status: TonesStatus.loading));
    try {
      final tones = await dataSource.getTones();
      emit(state.copyWith(
        status: TonesStatus.loaded,
        tones: tones,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TonesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAddTone(AddToneEvent event, Emitter<TonesState> emit) async {
    try {
      final newTone = await dataSource.addTone(
        sourceFile: event.file,
        name: event.name,
      );
      final updated = List.of(state.tones)..add(newTone);
      emit(state.copyWith(
        status: TonesStatus.loaded,
        tones: updated,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TonesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteTone(DeleteToneEvent event, Emitter<TonesState> emit) async {
    try {
      if (state.playingToneId == event.toneId) {
        await _audioPlayer.stop();
      }
      await dataSource.deleteTone(event.toneId);
      final updated = state.tones.where((t) => t.id != event.toneId).toList();
      emit(state.copyWith(
        status: TonesStatus.loaded,
        tones: updated,
        clearPlaying: state.playingToneId == event.toneId,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TonesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onPlayTonePreview(
    PlayTonePreviewEvent event,
    Emitter<TonesState> emit,
  ) async {
    try {
      // Toggle stop if already playing the same tone
      if (state.isPlaying && state.playingToneId == event.tone.id) {
        await _audioPlayer.stop();
        emit(state.copyWith(clearPlaying: true));
        return;
      }

      await _audioPlayer.stop();

      final fullPath = p.join(dataSource.assetsDir.path, event.tone.relativePath);
      final file = File(fullPath);
      if (file.existsSync()) {
        await _audioPlayer.play(DeviceFileSource(fullPath));
        emit(state.copyWith(
          isPlaying: true,
          playingToneId: event.tone.id,
        ));
      } else {
        emit(state.copyWith(
          errorMessage: 'File nada tidak ditemukan di $fullPath',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isPlaying: false,
        playingToneId: null,
        errorMessage: 'Gagal memutar pratinjau nada: $e',
      ));
    }
  }

  Future<void> _onStopTonePreview(
    StopTonePreviewEvent event,
    Emitter<TonesState> emit,
  ) async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    emit(state.copyWith(clearPlaying: true));
  }

  @override
  Future<void> close() {
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
