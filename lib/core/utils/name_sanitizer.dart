class NameSanitizer {
  static final RegExp _forbiddenChars = RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]');
  static const int maxDiskNameLength = 80;

  /// Membersihkan nama untuk filesystem sesuai PRD 6.3:
  /// - Hapus \ / : * ? " < > | dan karakter kontrol
  /// - Ganti awalan '_' menjadi '-' agar tidak bentrok dengan _folder.json
  /// - Trim spasi dan titik di kedua ujung
  /// - Maksimum 80 karakter
  static String sanitize(String input) {
    var cleaned = input.replaceAll(_forbiddenChars, '');

    // Trim spasi dan titik di awal & akhir
    cleaned = cleaned.trim();
    while (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    while (cleaned.startsWith('.')) {
      cleaned = cleaned.substring(1).trim();
    }

    // Jika diawali '_', ganti semua awalan '_' dengan satu '-'
    if (cleaned.startsWith('_')) {
      var withoutLeadingUnder = cleaned;
      while (withoutLeadingUnder.startsWith('_')) {
        withoutLeadingUnder = withoutLeadingUnder.substring(1);
      }
      cleaned = '-$withoutLeadingUnder';
    }

    // Jika kosong setelah dibersihkan
    if (cleaned.isEmpty) {
      cleaned = 'unnamed';
    }

    // Maksimum 80 karakter
    if (cleaned.length > maxDiskNameLength) {
      cleaned = cleaned.substring(0, maxDiskNameLength).trim();
      while (cleaned.endsWith('.')) {
        cleaned = cleaned.substring(0, cleaned.length - 1).trim();
      }
    }

    return cleaned.isEmpty ? 'unnamed' : cleaned;
  }

  /// Menangani bentrok nama secara case-insensitive:
  /// Menambahkan " (2)", " (3)", dst.
  static String resolveCollision(
    String baseName,
    Iterable<String> existingNames, {
    String extension = '',
  }) {
    final lowerExisting = existingNames.map((e) => e.toLowerCase()).toSet();
    final ext = extension.isEmpty ? '' : (extension.startsWith('.') ? extension : '.$extension');

    final candidate = '$baseName$ext';
    if (!lowerExisting.contains(candidate.toLowerCase())) {
      return candidate;
    }

    int counter = 2;
    while (true) {
      final numberedCandidate = '$baseName ($counter)$ext';
      if (!lowerExisting.contains(numberedCandidate.toLowerCase())) {
        return numberedCandidate;
      }
      counter++;
    }
  }
}
