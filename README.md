# SiKulak

SiKulak adalah aplikasi Flutter untuk kebutuhan tugas MRP/ABMAS. README ini menjelaskan cara men-setup lingkungan pengembangan, menjalankan aplikasi secara lokal, serta membangun artefak untuk target platform (Android, iOS, Web, Desktop).

## Fitur Singkat
- Autentikasi dasar (login/registrasi)
- Halaman beranda dan welcome
- Support: Android, iOS, Web, Windows, macOS, Linux

## Prasyarat
- Git
- Flutter SDK (lihat dokumentasi resmi: https://docs.flutter.dev/get-started/install)
- Untuk Android: Android Studio + Android SDK + Platform-tools
- Untuk iOS (macOS): Xcode
- Untuk Windows desktop: Visual Studio (dengan komponen "Desktop development with C++")

Pastikan `flutter doctor` bersih atau hanya menyisakan hal yang Anda bisa abaikan untuk target yang tidak Anda gunakan.

## Instalasi & Setup Lokal

1. Clone repository:

```
git clone https://github.com/oryzarey/SiKulak.git
cd SiKulak
```

2. Install dependencies:

```
flutter pub get
```

3. Menjalankan aplikasi di emulator / device:

- Untuk Android (emulator atau device terpasang):

```
flutter run -d <device_id>
```

- Untuk web (Chrome):

```
flutter run -d chrome
```

- Untuk Windows/macOS/Linux desktop (jika dikonfigurasi):

```
flutter run -d windows
```

4. Build release:

- Android APK / AAB:

```
flutter build apk --release
flutter build appbundle --release
```

- iOS (di macOS, setelah konfigurasi signing di Xcode):

```
flutter build ios --release
```

- Web:

```
flutter build web --release
```

## Test & Analisis

- Jalankan unit/widget tests:

```
flutter test
```

- Analisa statis / lint:

```
flutter analyze
```

## Konfigurasi Environment

- Untuk Android SDK dan tools, pastikan `ANDROID_HOME`/`ANDROID_SDK_ROOT` ditetapkan dan `platform-tools` ada di `PATH`.
- Jika ada variabel environment khusus aplikasi (contoh: API keys), simpan di file `.env` atau gunakan mekanisme konfigurasi yang aman dan jangan commit ke repo.

## Setup Database Supabase

Jika aplikasi menampilkan pesan tidak bisa membaca tabel `todos`, jalankan skrip berikut di Supabase SQL Editor:

- `scripts/create_todos.sql`

Langkah singkat:

1. Buka Supabase Dashboard.
2. Pilih project SiKulak.
3. Buka SQL Editor.
4. Tempel isi `scripts/create_todos.sql` dan jalankan.

Skrip tersebut akan membuat tabel `public.todos` dan policy agar data bisa dibaca dari aplikasi.

## Asset & Font

Semua asset (gambar, font, ikon) berada di folder `assets/`, font di `fonts/`. Jika menambah asset baru, daftarkan ke `pubspec.yaml` pada bagian `flutter/assets` atau `flutter/fonts`.

### App Icon

App icon aplikasi menggunakan SVG file di `assets/images/icon-app.svg`. Untuk menghasilkan launcher icons untuk berbagai platform:

**Menggunakan flutter_launcher_icons:**

1. SVG harus di-convert ke PNG terlebih dahulu (512x512 minimum):
   - Gunakan Figma, Inkscape, atau online converter (e.g., convertio.co, zamzar.com)
   - Simpan sebagai `assets/images/icon-app.png`

2. Update `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.14.4
   
   flutter_launcher_icons:
     image_path: "assets/images/icon-app.png"
     android: true
     ios: true
   ```

3. Generate icons:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

**Manual Setup (Jika diperlukan):**
- Android: Tempatkan PNG icons di `android/app/src/main/res/mipmap-*/`
- iOS: Update `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Troubleshooting Singkat
- Jika `flutter pub get` gagal: periksa koneksi internet dan versi Flutter yang kompatibel.
- Jika emulator/device tidak muncul: jalankan `flutter devices` untuk verifikasi.
- Jika build Android gagal terkait signing: periksa konfigurasi `key.properties` dan `build.gradle.kts` di modul `android/app`.

## Kontribusi

Silakan buka issue atau pull request. Ikuti praktik umum: buat branch fitur dari `main`, sertakan deskripsi singkat dan langkah reproduksi bila perlu.

## Lisensi

Lisensi proyek tidak ditentukan. Tambahkan file `LICENSE` jika ingin menetapkan lisensi terbuka.

---

Jika Anda ingin, saya bisa:
- Menambahkan badge build/test
- Menjalankan `flutter analyze` dan `flutter test` di repo ini
- Membuat panduan debugging untuk masalah umum

Beritahu saya langkah mana yang Anda inginkan selanjutnya.
