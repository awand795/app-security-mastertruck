# Aplikasi Mobile Security Master Truck (Flutter Native Android)

Aplikasi mobile Android native untuk Pos Security Gerbang Bengkel Master Truck KIM 3.
Dibangun menggunakan **Flutter 3.47** dengan arsitektur Material 3 modern (**Clean Light Corporate: Pure White + Deep Navy + Amber Gold**).

---

## 1. Keunggulan Dibandingkan Web Browser
1. **Akses Kamera Native (100% Bebas Kendala SSL/HTTPS)**:
   - Tidak lagi muncul error *"Kamera langsung tidak didukung peramban pada koneksi HTTP tanpa SSL"*.
   - Kamera langsung terbuka 0 detik via Android Camera Hardware.
2. **AI ANPR Otomatis (Dual Model YOLO11 + SVTR Server)**:
   - Mengambil frame kamera HP dan mengirimkan langsung ke container AI server (`http://52.77.133.95:3500/anpr/detect`).
   - Akurasi tinggi termasuk membaca huruf `O` bergaris tengah (`Ø`), font plat putih Korlantas, dan plat kuning truk.
3. **Dokumentasi 4 Sudut Fisik Kendaraan**:
   - Pengambilan foto Depan, Belakang, Kiri, dan Kanan dengan thumbnail visual interaktif.
4. **Gate Pass / Tiket Digital dengan QR Code**:
   - Validasi invoice lunas sebelum kendaraan diizinkan keluar gerbang.
   - Penerbitan memo keluar digital langsung di layar HP petugas.

---

## 2. Struktur Proyek
- `lib/config/api_config.dart` : Konfigurasi API Production (`http://94.237.69.119:8081` & ANPR `http://52.77.133.95:3500`)
- `lib/config/theme.dart` : Tema Modern Clean Light (Navy Blue + Amber Gold)
- `lib/models/` : Model data Booking, Active Vehicle, Memo Keluar
- `lib/services/` : Service Auth DarkoPOS, API Gateway, dan AI ANPR
- `lib/views/` :
  - `login_view.dart` : Login Petugas Security
  - `home_nav_view.dart` : Navigasi 4 Tab Utama
  - `check_in_view.dart` : Registrasi Masuk + Scan Plat AI + Foto 4 Sudut
  - `active_inside_view.dart` : Kendaraan Aktif di Dalam Bengkel
  - `check_out_view.dart` : Pemeriksaan Keluar & Validasi Status Lunas
  - `today_exit_view.dart` : Histori Kendaraan Keluar & Gate Pass
- `lib/widgets/` : Scanner Sheet, Photo Picker 4 Sudut, Gate Pass QR Modal

---

## 3. Menjalankan & Membangun APK
```bash
# Debug APK:
flutter build apk --debug

# Release APK siap instal di HP:
flutter build apk --release
```
File APK akan berada di: `build/app/outputs/flutter-apk/app-debug.apk` atau `app-release.apk`.
