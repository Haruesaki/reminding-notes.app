# Reminding (Notes & To-Do App)

Aplikasi catatan dan to-do list modern untuk Android yang beroperasi **100% lokal**, tanpa registrasi atau login akun, dan tanpa izin internet (`INTERNET` permission). Dibangun menggunakan **Flutter** dengan arsitektur bersih (*Clean Architecture + BLoC*), atomic file I/O, serta sistem cadangan (*backup/restore*) mandiri berbasis arsip ZIP.

---

## Fitur Utama

- **100% Offline & Privat**: Seluruh data disimpan langsung di penyimpanan lokal perangkat dalam format berkas JSON standar tanpa ketergantungan pada database pihak ketiga atau layanan cloud.
- **Folder Bersarang Tanpa Batas**: Pengelompokan catatan dalam hierarki folder tak terbatas dengan struktur direktori fisik yang sinkron dengan antarmuka.
- **Dua Jenis Berkas Catatan**:
  - **Page**: Editor catatan rich text (tebal, miring, garis bawah, coret, perataan teks, daftar angka/poin) dengan auto-save debounce 500 ms.
  - **List**: Checklist to-do interaktif dengan subtask hierarkis satu tingkat, aturan centang cascading, lencana batas waktu (*deadline*), nada notifikasi kustom, dan integrasi alarm jam sistem.
- **Kalender & Pengingat**: Jalur strip tanggal dinamis dengan pewarnaan deadline (< 3 hari: merah, 3–7 hari: netral, > 7 hari: hijau) dan halaman tinjauan pengingat berurutan.
- **Organisasi & Manajemen Berkas**: Drag-and-drop reorder, penanda favorit, filter tipe catatan, menu tahan-lepas (salin, pindah, bagikan teks murni `.txt`, hapus dengan opsi *Urungkan*).
- **Sistem Cadangan (Backup & Restore)**: Ekspor dan impor seluruh pohon catatan beserta aset nada dalam berkas ZIP terenkapsulasi dengan manifest verifikasi SHA-256 dan perlindungan terhadap *zip slip*.
- **Desain Adaptif & Aksesibilitas**: Skala teks hingga 1.3x tanpa overflow, transisi Shared Axis/Fade-Through 60 fps, tata letak responsif ponsel (rasio 9:16, 1220x2712) dan tablet (portrait/landscape).

---

## Struktur Proyek

Proyek ini menerapkan prinsip **Clean Architecture**:

```
lib/
├── core/                       # Infrastruktur global & modul inti
│   ├── di/                     # Dependency Injection (GetIt)
│   ├── migration/              # MigrationRunner untuk migrasi skema data
│   ├── router/                 # Navigasi & perutean (GoRouter)
│   ├── seeder/                 # Data seeder untuk demonstrasi dan testing
│   ├── theme/                  # Desain token Figma (warna, tipografi, radius, dimensi)
│   └── utils/                  # Utility (NameSanitizer, DisplayOrderSorter)
├── features/
│   ├── backup/                 # Layanan backup & restore ZIP
│   │   ├── data/services/      # BackupService (ekspor/impor di isolate terpisah)
│   │   └── domain/models/      # BackupManifest, file entry, dan model exception
│   ├── explorer/               # Lapisan persistensi berkas & penjelajah
│   │   ├── data/datasources/   # LocalStorageDataSource & NotesIndexManager
│   │   ├── data/models/        # FolderModel, PageFileModel, ListFileModel
│   │   └── domain/             # Entitas bisnis, contracts repository
│   ├── notes/                  # Logika aplikasi catatan & to-do
│   │   ├── domain/services/    # ReminderCalculator, AudioTonesRepository
│   │   └── presentation/       # BLoC, Cubit, halaman (Home, Editor, Kalender, dsb.)
│   └── settings/               # Pengaturan aplikasi & panel backup
│       └── presentation/pages/ # SettingsPage & accordion tile
└── main.dart                   # Titik masuk aplikasi
```

---

## Cara Menjalankan Aplikasi

### Prasyarat
1. **Flutter SDK** versi `>= 3.47.0` (Dart `>= 3.13.1`).
2. **Android SDK** (API 26–34 direkomendasikan).

### Langkah Menjalankan
1. **Clone repositori dan pasang dependensi:**
   ```bash
   git clone <repo_url>
   cd reminding
   flutter pub get
   ```

2. **Jalankan analisis kode statis:**
   ```bash
   flutter analyze
   ```

3. **Jalankan seluruh test suite:**
   ```bash
   flutter test
   ```

4. **Jalankan aplikasi di emulator atau perangkat fisik:**
   ```bash
   flutter run
   ```

---

## Format & Penyimpanan Data

Semua data pengguna disimpan pada direktori internal aplikasi (`notes_data/` dan `notes_assets/`):

1. **Struktur Direktori**:
   ```
   notes_data/
   ├── _folder.json              # Metadata folder root dan daftar urutan
   ├── Kuliah/
   │   ├── _folder.json          # Metadata subfolder Kuliah
   │   └── Tugas Besar.json      # Catatan bertipe List / Page
   └── Rencana Belanja.json
   notes_assets/
   └── tones/                    # Berkas audio nada kustom (.mp3/.wav/.ogg)
   ```

2. **Atomic Write**: Setiap perubahan berkas ditulis terlebih dahulu ke berkas sementara `*.tmp` lalu di-*rename* secara atomik ke target akhir untuk mencegah berkas korup jika aplikasi terhenti mendadak.
3. **Kompatibilitas Skema**: Setiap berkas JSON menyertakan atribut `schemaVersion`. Nilai atau properti yang belum dikenal (*unknown fields*) selalu dipertahankan secara utuh selama proses baca dan tulis.

---

## Cara Membuat dan Memulihkan Backup

Fitur backup memungkinkan pemindahan seluruh catatan, folder, dan nada kustom antarperangkat dengan aman.

### 1. Membuat Cadangan (Export Backup)
1. Buka aplikasi **Reminding**.
2. Ketuk ikon menu burger (garis tiga) di sebelah kiri search bar pada halaman utama untuk membuka laci samping (*Drawer*).
3. Pilih menu **Pengaturan**.
4. Pada accordion **Backup**, ketuk untuk membuka pilihan lalu pilih **Export Backup**.
5. Layanan akan mengemas seluruh direktori `notes_data/` dan `notes_assets/` ke dalam berkas arsip `.zip` di background isolate beserta berkas `manifest.json` yang memuat checksum SHA-256 setiap berkas.
6. Pilih lokasi penyimpanan yang diinginkan melalui pemilih berkas (*File Picker*).

### 2. Memulihkan Cadangan (Import Backup)
1. Buka menu **Pengaturan** > bagian **Backup**.
2. Pilih **Import Backup**, lalu pilih berkas arsip cadangan `.zip` yang valid.
3. Pilih mode pemulihan pada dialog konfirmasi:
   - **Gabungkan (Merge)**: Menambahkan isi cadangan ke dalam data yang sudah ada. Jika terdapat nama berkas atau folder yang sama, sistem otomatis menambahkan akhiran `(Impor)` atau `(Impor n)` tanpa menimpa berkas asli.
   - **Ganti Semua (Replace)**: Mengosongkan data lama dan menggantikannya sepenuhnya dengan isi cadangan secara atomik (dengan cadangan pengaman *rollback* jika proses gagal).
4. Setelah proses selesai, seluruh nada kustom didaftarkan ulang ke sistem dan seluruh jadwal pengingat (*reminder*) otomatis direkonsiliasi.

