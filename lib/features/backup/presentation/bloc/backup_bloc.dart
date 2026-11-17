import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../notes/domain/services/reminder_sync_service.dart';
import '../../domain/models/backup_inspection_result.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../domain/usecases/backup_usecases.dart';

enum BackupStatus { initial, busy, success, error }

enum BackupOperation { export, import }

class BackupState extends Equatable {
  final BackupStatus status;
  final BackupOperation? operation;
  final double progress; // 0.0 – 1.0
  final String? message;
  final BackupInspectionResult? inspection; // hasil inspeksi, untuk dialog mode
  final String? error;
  final int? notesCount;
  final int? foldersCount;
  final int? tonesCount;

  const BackupState({
    this.status = BackupStatus.initial,
    this.operation,
    this.progress = 0.0,
    this.message,
    this.inspection,
    this.error,
    this.notesCount,
    this.foldersCount,
    this.tonesCount,
  });

  BackupState copyWith({
    BackupStatus? status,
    BackupOperation? operation,
    double? progress,
    String? message,
    BackupInspectionResult? inspection,
    String? error,
    int? notesCount,
    int? foldersCount,
    int? tonesCount,
    bool clearError = false,
  }) {
    return BackupState(
      status: status ?? this.status,
      operation: operation ?? this.operation,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      inspection: inspection ?? this.inspection,
      error: clearError ? null : (error ?? this.error),
      notesCount: notesCount ?? this.notesCount,
      foldersCount: foldersCount ?? this.foldersCount,
      tonesCount: tonesCount ?? this.tonesCount,
    );
  }

  @override
  List<Object?> get props => [
        status,
        operation,
        progress,
        message,
        inspection,
        error,
        notesCount,
        foldersCount,
        tonesCount,
      ];
}

abstract class BackupEvent extends Equatable {
  const BackupEvent();

  @override
  List<Object?> get props => [];
}

class BackupExportRequested extends BackupEvent {
  final String? notesDirPath;
  final String? assetsDirPath;

  const BackupExportRequested({this.notesDirPath, this.assetsDirPath});

  @override
  List<Object?> get props => [notesDirPath, assetsDirPath];
}

class BackupImportPickRequested extends BackupEvent {
  final List<int> zipBytes;
  final String tempExtractDirPath;

  const BackupImportPickRequested({
    required this.zipBytes,
    required this.tempExtractDirPath,
  });

  @override
  List<Object?> get props => [zipBytes, tempExtractDirPath];
}

class BackupImportModeSelected extends BackupEvent {
  final ImportMode mode;

  const BackupImportModeSelected(this.mode);

  @override
  List<Object?> get props => [mode];
}

class BackupImportCancelled extends BackupEvent {
  const BackupImportCancelled();

  @override
  List<Object?> get props => [];
}

class BackupReset extends BackupEvent {
  const BackupReset();

  @override
  List<Object?> get props => [];
}

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final ExportBackup _exportBackup;
  final InspectBackup _inspectBackup;
  final ImportBackup _importBackup;
  final String _notesDirPath;
  final String _assetsDirPath;
  final String _tempSafetyDirPath;

  BackupInspectionResult? _pendingInspection;

  BackupBloc({
    required this._exportBackup,
    required InspectBackup inspectBackup,
    required this._importBackup,
    required this._notesDirPath,
    required this._assetsDirPath,
    required this._tempSafetyDirPath,
  })  : _inspectBackup = inspectBackup,
        super(const BackupState()) {
    on<BackupExportRequested>(_onExportRequested);
    on<BackupImportPickRequested>(_onImportPickRequested);
    on<BackupImportModeSelected>(_onImportModeSelected);
    on<BackupImportCancelled>(_onImportCancelled);
    on<BackupReset>(_onReset);
  }

  Future<void> _onExportRequested(
    BackupExportRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(
      status: BackupStatus.busy,
      operation: BackupOperation.export,
      progress: 0.1,
      error: null,
    ));
    try {
      final bytes = await _exportBackup(
        ExportBackupParams(
          notesDirPath: event.notesDirPath ?? _notesDirPath,
          assetsDirPath: event.assetsDirPath ?? _assetsDirPath,
        ),
      );
      emit(BackupState(
        status: BackupStatus.success,
        operation: BackupOperation.export,
        progress: 1.0,
        message: 'Backup berhasil diekspor.',
        notesCount: _pendingInspection?.manifest.counts['notes'],
        foldersCount: _pendingInspection?.manifest.counts['folders'],
        tonesCount: _pendingInspection?.manifest.counts['tones'],
      ));
      // Simpan bytes untuk diambil oleh UI melalui getter.
      _lastExportBytes = bytes;
    } catch (e) {
      emit(state.copyWith(
        status: BackupStatus.error,
        error: 'Gagal mengeksport backup: $e',
      ));
    }
  }

  Uint8List? _lastExportBytes;

  Uint8List? get lastExportBytes => _lastExportBytes;

  Future<void> _onImportPickRequested(
    BackupImportPickRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(
      status: BackupStatus.busy,
      operation: BackupOperation.import,
      progress: 0.1,
      error: null,
      inspection: null,
    ));
    try {
      final inspection = await _inspectBackup(
        InspectBackupParams(
          zipBytes: event.zipBytes,
          tempExtractDirPath: event.tempExtractDirPath,
        ),
      );
      _pendingInspection = inspection;
      emit(BackupState(
        status: BackupStatus.success,
        operation: BackupOperation.import,
        progress: 1.0,
        message: 'File backup valid. Pilih mode impor.',
        inspection: inspection,
        notesCount: inspection.manifest.counts['notes'],
        foldersCount: inspection.manifest.counts['folders'],
        tonesCount: inspection.manifest.counts['tones'],
        error: null,
      ));
    } on Exception catch (e) {
      emit(state.copyWith(
        status: BackupStatus.error,
        error: _formatError(e),
      ));
    }
  }

  Future<void> _onImportModeSelected(
    BackupImportModeSelected event,
    Emitter<BackupState> emit,
  ) async {
    final inspection = _pendingInspection;
    if (inspection == null) {
      emit(state.copyWith(
        status: BackupStatus.error,
        error: 'Tidak ada hasil inspeksi yang tersedia. Silakan pilih file backup lagi.',
      ));
      return;
    }

    emit(state.copyWith(
      status: BackupStatus.busy,
      operation: BackupOperation.import,
      progress: 0.3,
      error: null,
    ));
    try {
      await _importBackup(
        ImportBackupParams(
          inspection: inspection,
          mode: event.mode,
          notesDirPath: _notesDirPath,
          assetsDirPath: _assetsDirPath,
          tempSafetyDirPath: _tempSafetyDirPath,
        ),
      );
      _pendingInspection = null;
      emit(BackupState(
        status: BackupStatus.success,
        operation: BackupOperation.import,
        progress: 1.0,
        message: 'Impor data backup berhasil selesai.',
        error: null,
      ));
    } on Exception catch (e) {
      emit(state.copyWith(
        status: BackupStatus.error,
        error: _formatError(e),
      ));
    }
  }

  void _onImportCancelled(
    BackupImportCancelled event,
    Emitter<BackupState> emit,
  ) {
    _pendingInspection = null;
    emit(const BackupState(
      status: BackupStatus.initial,
      operation: BackupOperation.import,
      error: null,
    ));
  }

  void _onReset(
    BackupReset event,
    Emitter<BackupState> emit,
  ) {
    _pendingInspection = null;
    emit(const BackupState(status: BackupStatus.initial));
  }

  String _formatError(Exception e) {
    if (e.toString().contains('DangerousPathException')) {
      return 'File ditolak: backup mengandung path berbahaya.';
    }
    if (e.toString().contains('NewerSchemaVersionException')) {
      return 'Versi skema tidak didukung: backup dibuat oleh versi aplikasi yang lebih baru.';
    }
    if (e.toString().contains('CorruptedBackupException')) {
      return 'File backup rusak: checksum atau isi file tidak cocok.';
    }
    if (e.toString().contains('InvalidBackupException')) {
      return 'Backup tidak valid.';
    }
    if (e.toString().contains('ReadOnlyDataException')) {
      return 'Mode baca saja: data tidak dapat diubah.';
    }
    return 'Gagal mengimpor backup: $e';
  }

  @override
  Future<void> close() {
    _lastExportBytes = null;
    _pendingInspection = null;
    return super.close();
  }
}
