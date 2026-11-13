/// Status izin alarm presisi untuk ditampilkan di UI.
enum AlarmPermissionStatus {
  /// Izin telah diberikan; penjadwalan presisi akan berjalan.
  granted,
  /// Izin ditolak atau belum tersedia; gunakan penjadwalan tidak-presisi sebagai fallback.
  denied,
  /// Platform tidak mendukung izin alarm presisi (bukan Android / versi lama).
  unavailable,
}

/// Satu titik pengambilan keputusan izin alarm presisi di domain layer.
/// Domain murni: tidak mengimpor Flutter atau plugin.
abstract class AlarmPermissionService {
  /// Cek apakah aplikasi diizinkan menjadwalkan alarm presisi (Android 12+).
  /// Mengembalikan true jika izin telah diberikan.
  Future<bool> canScheduleExactAlarms();

  /// Minta izin alarm presisi kepada pengguna.
  /// Pada Android, ini membuka layar pengaturan alarm khusus aplikasi.
  /// Mengembalikan true bila izin tertera diberikan setelah dialog ditutup.
  Future<bool> requestExactAlarmsPermission();

  /// Status gabungan untuk ditampilkan di UI tab Deadline.
  Future<AlarmPermissionStatus> alarmPermissionStatus();
}
