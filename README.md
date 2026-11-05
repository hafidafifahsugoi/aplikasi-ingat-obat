# 🌿💊 Ingat Obat — Personal Health & Medication Companion

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Hive](https://img.shields.io/badge/Database-Hive_NoSQL-FFCA28)
![UI/UX](https://img.shields.io/badge/UI%2FUX-Soft_Sage_Pastel_%26_Dark_Mode-5B9A8B)

**Ingat Obat** adalah aplikasi mobile berbasis **Flutter** untuk membantu pasien dan keluarga mengelola jadwal minum obat secara teratur, tenang, dan menyenangkan. Dirancang dengan pendekatan **Soft Pastel Wellness UI/UX (Sage Mint)** serta dilengkapi **Mode Gelap (Ramah Mata)**, **Kalender Kepatuhan Interaktif**, **Grafik Statistik Mingguan**, dan **Pemantau Riwayat Buka Aplikasi**.

---

## ✨ Fitur Unggulan

### 1. 🌿 Desain Aesthetic Soft Wellness & Mode Gelap (Ramah Mata)
- **Soft Sage Mint & Pastel Palette**: Warna lembut yang menenangkan dan tidak membuat mata lelah.
- **Mode Gelap (Soft Dark Mode)**: Menggunakan nuansa *Deep Pine Slate* (`#111918` & `#1B2625`) yang nyaman dilihat pada malam hari. Dapat diubah langsung lewat tombol cepat (`🌙 / ☀️`) di Beranda atau melalui menu **Profil**.

### 2. 🧭 Navigasi 4 Menu Utama (Bottom Navigation Bar)
- **💊 Tab Jadwal (Beranda)**:
  - Sapaan waktu otomatis (*Selamat Pagi/Siang/Sore/Malam*) & nama pengguna.
  - **Strip Kalender Mingguan Interaktif** dengan indikator status tiap tanggal (`✓` Sudah Minum, `⏳` Sebagian, `✖` Belum Minum).
  - **Kartu Ringkasan Harian** dengan *circular progress ring*.
  - Filter cepat: *Semua*, *Belum Diminum*, dan *Selesai*.
- **📅 Tab Kalender Bulanan**:
  - Tampilan kalender 1 bulan penuh dengan indikator kepatuhan per tanggal.
  - Klik tanggal mana saja untuk melihat daftar obat pada hari tersebut sekaligus menandai **Minum** atau **Batal** secara langsung.
- **📊 Tab Grafik & Statistik Kepatuhan**:
  - Kartu *Skor Kepatuhan Mingguan*, *Streak Hari Sempurna (100%)*, dan total dosis.
  - **Grafik Batang 7 Hari Terakhir** yang interaktif (ketuk batang grafik untuk melihat rincian obat pada hari tersebut).
  - **Rincian Kepatuhan per Obat** dengan *progress bar* masing-masing obat.
- **👤 Tab Profil**:
  - Informasi akun pengguna, saklar **Mode Gelap (Ramah Mata)**, fitur **Ubah Password**, dan **Logout**.

### 3. 🔔 Notifikasi & Riwayat Buka Aplikasi
- **Alarm & Notifikasi Harian Otomatis**: Pengingat obat terjadwal setiap hari sesuai jam yang ditentukan menggunakan `flutter_local_notifications` dan suara notifikasi.
- **Pemantau Riwayat Aplikasi Dibuka**:
  - Tombol lonceng (`🔔`) di pojok kanan atas menampilkan apakah aplikasi **Sudah Dibuka Hari Ini**, berapa kali dibuka, serta **riwayat jam aplikasi dibuka** (berguna bagi keluarga/pendamping untuk memastikan pasien sudah membuka aplikasi).
  - Menampilkan daftar status notifikasi jadwal obat hari ini beserta tombol cepat **Minum**.

### 4. ✨ Halaman Tambah & Edit Obat dengan Live Preview
- **Live Preview Card**: Pratinjau tampilan kartu obat secara *real-time* saat mengetik nama obat, memilih takaran, warna, dan ikon.
- **Chip Takaran & Aturan Pakai Cepat**: Pilihan cepat (`1 Tablet`, `1 Kapsul`, `5 ml (1 Sendok)`, `Sesudah Makan`, `Sebelum Makan`, dll.).
- **Preset Waktu Umum & Jam Kustom**: Pilihan sekali ketuk untuk jadwal *Pagi (07:00)*, *Siang (12:30)*, *Sore (17:00)*, *Malam (20:30)*, atau tambah jam kustom bebas.
- **8 Warna Pastel & 8 Ikon Bentuk Obat**: Memudahkan identifikasi visual setiap obat/vitamin.

### 5. 🔐 Autentikasi & Penyimpanan Lokal (Hive NoSQL)
- **Register, Login, Lupa Password, dan Ubah Password**.
- Seluruh data obat, riwayat minum obat (`MedicineLog`), sesi pengguna, preferensi Mode Gelap, dan riwayat buka aplikasi tersimpan secara persisten di perangkat menggunakan **Hive**.

---

## 🛠️ Struktur Proyek

```text
lib/
├── main.dart                          # Entry point & listener tema (Light/Dark Mode)
├── theme/
│   └── app_theme.dart                 # Konfigurasi palet warna Soft Sage Mint & Dark Mode
├── models/
│   ├── medicine.dart                  # Model Medicine & MedicineLog
│   ├── medicine.g.dart                # Hive TypeAdapter Medicine
│   ├── user.dart                      # Model User
│   └── user.g.dart                    # Hive TypeAdapter User
├── services/
│   ├── auth_service.dart              # Layanan autentikasi & manajemen akun
│   ├── database_service.dart          # Penyimpanan Hive (Obat, Log, Tema, Riwayat Buka App)
│   ├── notification_service.dart      # Penjadwalan alarm & notifikasi lokal
│   └── ai_assistant.dart              # Pesan motivasi, apresiasi, & tips kesehatan
├── screens/
│   ├── splash_screen.dart             # Halaman pembuka animasi
│   ├── home_screen.dart               # Navigasi utama, Tab Jadwal, & Sheet Notifikasi
│   ├── calendar_screen.dart           # Tab Kalender Bulanan interaktif
│   ├── statistics_screen.dart         # Tab Grafik & Analitik Kepatuhan
│   ├── add_edit_medicine_screen.dart  # Halaman Tambah/Edit Obat dengan Live Preview
│   ├── profile_screen.dart            # Tab Profil & pengaturan Mode Gelap
│   └── auth/
│       ├── login_screen.dart          # Halaman Masuk
│       ├── register_screen.dart       # Halaman Daftar Akun
│       └── forgot_password_screen.dart# Halaman Reset Password
└── widgets/
    ├── medicine_card.dart             # Komponen kartu jadwal obat harian
    └── stats_card.dart                # Kartu ringkasan progres harian
```

---

## 🚀 Cara Menjalankan Proyek

1. **Clone repositori ini:**
   ```bash
   git clone https://github.com/USERNAME_KAMU/NAMA_REPO_KAMU.git
   cd obat
   ```

2. **Unduh dependencies Flutter:**
   ```bash
   flutter pub get
   ```

3. **Jalankan aplikasi di Emulator atau Perangkat Fisik:**
   ```bash
   flutter run
   ```

---

## 📦 Teknologi & Paket Utama
- **Framework**: Flutter & Dart
- **Database Lokal**: `hive` & `hive_flutter`
- **Notifikasi & Alarm**: `flutter_local_notifications` & `timezone`
- **Audio Pengingat**: `audioplayers`
- **Tipografi & Animasi**: `google_fonts` (Plus Jakarta Sans) & `flutter_animate`
- **Format Tanggal & Lokal**: `intl` (`id_ID`)

---

*Dibuat dengan 💚 untuk membantu menjaga kesehatan dan keteraturan minum obat setiap hari.*
