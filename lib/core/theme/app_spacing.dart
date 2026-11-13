/// Token spasi dan radius terpusat untuk aplikasi.
/// Semua angka visual di sini supaya tidak ada magic number tersebar di widget.
class AppSpacing {
  /// Jarak default antar elemen (mendekati 8dp grid).
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  /// Tinggi search bar (44dp visual, tapi area tap diperbesar ke 48dp di widget yang memakainya).
  static const double searchBarHeight = 44.0;

  /// Margin horizontal layar.
  static const double screenMargin = 20.0;

  /// Padding dalam kartu.
  static const double cardPadding = 16.0;

  /// Jarak antar chip tanggal.
  static const double dateChipSpacing = 8.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double pill = 18.0;
  static const double circle = 22.0; // radius untuk circle 44dp
}
