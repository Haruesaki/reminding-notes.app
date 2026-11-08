class BackupFileEntry {
  final String path;
  final String sha256;

  const BackupFileEntry({
    required this.path,
    required this.sha256,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'sha256': sha256,
      };

  factory BackupFileEntry.fromJson(Map<String, dynamic> json) {
    return BackupFileEntry(
      path: json['path'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
    );
  }
}

class BackupManifest {
  final String app;
  final int backupFormat;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final Map<String, int> counts;
  final List<BackupFileEntry> files;

  const BackupManifest({
    required this.app,
    required this.backupFormat,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.counts,
    required this.files,
  });

  Map<String, dynamic> toJson() => {
        'app': app,
        'backupFormat': backupFormat,
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'createdAt': createdAt.toIso8601String(),
        'counts': counts,
        'files': files.map((f) => f.toJson()).toList(),
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      app: json['app'] as String? ?? 'reminding',
      backupFormat: json['backupFormat'] as int? ?? 1,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      counts: (json['counts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      files: (json['files'] as List<dynamic>?)
              ?.map((e) => BackupFileEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
