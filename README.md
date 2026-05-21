# 🛒 SiKulak: Revolusi Kulakan Pedagang Modern

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![UI/UX](https://img.shields.io/badge/UI%2FUX-Glassmorphism-purple?style=for-the-badge)

**SiKulak** adalah platform ekosistem B2B (*Business-to-Business*) modern yang dirancang khusus untuk merevolusi cara pedagang warung, toko kelontong, dan UMKM melakukan *kulakan* (restock barang). Kami memadukan estetika UI kelas dunia dengan *analytics* tajam untuk memberikan pengalaman belanja grosir terbaik di kelasnya.

Ucapkan selamat tinggal pada catatan kertas dan antrean panjang di agen grosir. Dengan SiKulak, suplai toko Anda hanya berjarak satu ketukan.

---

## ✨ Fitur Unggulan

- 💎 **Premium Glassmorphism UI:** Pengalaman visual memukau dengan *liquid glass header*, transisi tanpa hambatan (flush navigation), dan *floating* komponen yang elegan.
- 📊 **Advanced Analytics Dashboard:** Lacak tren keuntungan Anda secara harfiah *per jam*! Dilengkapi dengan grafik penjualan mingguan (*Bar Chart*) dan garis tren profit (*Line Chart*) menggunakan `fl_chart`.
- 🛒 **Sistem Keranjang Presisi:** Manajemen keranjang belanja dinamis dengan notifikasi *floating pill* semi-transparan yang responsif dan tidak menutupi produk.
- 🔐 **Autentikasi Aman:** Sistem pendaftaran dan masuk yang dipersenjatai oleh Supabase Auth.
- 📱 **Cross-Platform:** Tulis kode sekali, jalankan di Android, iOS, Web, dan Desktop dengan performa *native*.

---

## 🛠 Tech Stack

SiKulak dibangun menggunakan *cutting-edge technologies*:

- **Frontend:** [Flutter](https://flutter.dev/) (Dart)
- **Backend & Database:** [Supabase](https://supabase.com/) (PostgreSQL)
- **Visualisasi Data:** [fl_chart](https://pub.dev/packages/fl_chart)
- **State & Routing:** Flutter Stateful Widgets + Custom Navigator

---

## 🚀 Cara Mulai (Quick Setup)

Siap untuk meluncurkan SiKulak di mesin lokal Anda? Ikuti langkah-langkah di bawah ini.

### 1. Prasyarat Sistem
Pastikan mesin Anda sudah menginstal:
- [Git](https://git-scm.com/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi 3.0 ke atas direkomendasikan).
- Android Studio / Xcode (sesuai target OS Anda).

### 2. Kloning Repositori
```bash
git clone https://github.com/oryzarey/SiKulak.git
cd SiKulak
```

### 3. Instalasi Dependensi
Jalankan perintah berikut untuk mengunduh semua *library* yang diperlukan (seperti `supabase_flutter` dan `fl_chart`):
```bash
flutter pub get
```

### 4. Setup Backend (Supabase)
Aplikasi ini membutuhkan database untuk autentikasi dan menyimpan data analitik/transaksi.
1. Buat proyek baru secara gratis di [Supabase Dashboard](https://supabase.com/dashboard/).
2. Buka menu **SQL Editor** di dalam proyek Supabase Anda.
3. *Copy* seluruh isi file `scripts/create_analytics_schema.sql` dan jalankan (*Run*). Skrip ini akan membuat tabel `products`, `transactions`, `transaction_items` beserta pengaturan keamanannya (*Row Level Security*).
4. *(Opsional)* Jika Anda ingin mencoba fitur *Todos* dasar, jalankan juga `scripts/create_todos.sql`.

> **⚠️ Penting:** Pastikan `supabaseUrl` dan `supabaseAnonKey` di dalam `lib/main.dart` telah diisi dengan API Keys dari proyek Supabase milik Anda (lihat di menu *Project Settings > API*).

### 5. Jalankan Aplikasi
Tancapkan perangkat Anda atau nyalakan Emulator, lalu jalankan:
```bash
flutter run
```

---

## 🎨 Konvensi UI (Catatan Tim)

Jika Anda ingin berkontribusi pada pengembangan UI SiKulak, harap patuhi *guidelines* berikut yang juga tercatat di `GEMINI.md`:
- **Navigation Bar:** Setiap halaman yang butuh bilah navigasi bawah **wajib** memanggil `CustomNavBar` (tanpa teks, hanya ikon kapsul).
- **Scaffold Setup:** Wajib mengatur `extendBody: true` dan `extendBodyBehindAppBar: true` agar efek *glassmorphism* dan *floating bar* bekerja sempurna.
- **Notifikasi:** Semua peringatan, sukses, atau error dilarang menggunakan *snackbar* bawaan. Wajib memakai *floating pill snackbar* (`SnackBarBehavior.floating`, radius 30) dengan *opacity* 80% (untuk login/register) atau 50% (di halaman utama).

---

## 🤝 Kontribusi

SiKulak lahir dari kolaborasi. Jika Anda memiliki ide brilian, optimasi performa, atau perbaikan *bug*:
1. *Fork* repository ini.
2. Buat *branch* fitur Anda (`git checkout -b feature/IdeBrilian`).
3. Lakukan *Commit* (`git commit -m 'Menambahkan IdeBrilian'`).
4. *Push* ke *branch* (`git push origin feature/IdeBrilian`).
5. Buka **Pull Request**.

---
*Dibuat dengan ❤️ untuk memajukan pedagang Nusantara.*
