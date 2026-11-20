# Revamp Fase 6 — Redesign UI Light-First (Dribbble Style)

Dokumentasi ringkas perubahan lapisan UI untuk aplikasi **Pos Security Gerbang Bengkel Master Truck KIM 3** (`bengkel_kim3_security_app`).

## Ringkasan Perubahan

### 1. Design Tokens & Theme (`lib/config/theme.dart`)
- **Light-First Palette**: Latar `#F5F7FC`, kartu `#FFFFFF`, teks utama `#0F1B3D`, teks sekunder `#5B6785`, isian field `#F1F4FB` (radius `16`, tinggi min `52`, tanpa border default), garis `#D5DCEE` / `#E1E7F5`.
- **Primary & Gradients**: Biru `#2349C9`, gradien 135° `#2349C9` → `#4C74F5` (`AppGradients.primary`), tint `#E6EDFF`, bayangan kartu `0 8 24 rgba(35,73,201,.08)`.
- **Semantic Colors (`AppSemanticColors`)**:
  - Sukses: `#12A06E` / container `#DFF5EA` / teks `#0B5A41`
  - Pengerjaan / Keluar Sementara (ungu): container `#EFE9FF` / teks `#4C2BB0`
  - Wajib / Error: `#D92D5A`
  - Plat nomor: putih `#FFFFFF`, border `#0F1B3D` 2px, strip bawah biru `#2349C9`, font `Chivo 900`
  - Tanpa warna orange/kuning/amber dan tanpa hitam pekat; dark mode tetap berfungsi penuh.
- **Radius**: Kartu `22`, tombol/field/tile `16`, chip `pill`.

### 2. Widget Bersama (`lib/widgets/`)
- `app_card.dart` — `AppCard` (putih, radius `22`, bayangan lembut, opsional accent).
- `section_card.dart` — `SectionCard` (badge nomor 26px tint biru, judul, subjudul, slot trailing).
- `app_text_field.dart` — `AppTextField` (filled `#F1F4FB`, label atas + tanda `*` merah untuk wajib, ikon kiri, error state rapi).
- `app_button.dart` — `AppButton` (tinggi 50 large / 44 medium, primary gradien + bayangan, secondary outline).
- `segmented_pill.dart` — `SegmentedPill` (`Service | Umum`, track `#EEF2FB`, thumb putih bergeser).
- `option_tile.dart` — `OptionTile` (3 kolom jenis layanan dengan chip ikon, state terpilih border 2px biru + `#F0F4FF`).
- `app_choice_chips.dart` — `AppChoiceChips` (pill tinggi 40, state terpilih biru solid).
- `plate_badge.dart` — `PlateBadge` (plat putih, border `#0F1B3D`, strip biru bawah, `Chivo 900`).
- `photo_quad_picker.dart` — `PhotoTile` / `PhotoQuadPicker` (border dashed `#B8C4E4`, state terisi gradien biru muda + centang, tanda `*` wajib pada `Depan` dan `Supir`, mode 4 foto keluar).
- `plate_viewfinder.dart` — `PlateViewfinder` (gradien biru muda, 4 sudut siku biru, garis pindai, plat di tengah).
- `bottom_dock.dart` — `BottomDock` + `BottomNavItem` (container putih menyatu berisi CTA di atas + 5 tab navigasi di bawah).
- `gate_pass_dialog.dart` — Tiket putih berlubang perforasi kiri-kanan, QR `#0F1B3D`, kode `Chivo`, status `LUNAS` hijau, tombol `Bagikan` & `Selesai`.

### 3. Layar yang Diperbarui (`lib/views/`)
- `login_view.dart` & `gate_select_view.dart`: Latar putih dengan gradasi biru radial di sudut, logo tile gradien biru, judul `"Selamat datang"`, field filled, tombol gradien, kartu pilihan gerbang senada.
- `home_nav_view.dart`: Tata letak satu kolom terpusat pada tablet, `BottomDock` 5 tab (`Beranda`, `Masuk`, `Di Dalam`, `Keluar`, `Riwayat`) tetap tampil di semua tab termasuk `Check Out`.
- `beranda_view.dart`: Header chip gate/shift + avatar gradien, kartu hero gradien biru (jumlah kendaraan + 3 mini-stat), 2 kartu aksi putih (`Scan Plat Masuk` & `Scan Plat Keluar`), daftar `"Di dalam sekarang"`.
- `check_in_view.dart`: 4 `SectionCard` bernomor (Nomor polisi + viewfinder + status strip, Tujuan kunjungan `SegmentedPill` + `OptionTile`, Data pengemudi + selector PIC / input manual Umum, Foto kendaraan & supir + pill `x/2 wajib`) + CTA di `BottomDock`.
- `check_out_view.dart`: Pencarian plat + scan di dalam field, kartu kendaraan (`Gate Masuk -> Gate Keluar`, 3 mini-stat, banner ungu FIR belum terbit), `AppChoiceChips` alasan keluar dengan opsi wajib `"Lainnya"` → field `"Jelaskan alasan"`, catatan keluar & 4 `PhotoTile` `x/4`, CTA di `BottomDock`.

## Yang Sengaja Tidak Diubah
- Seluruh logika bisnis, `ApiService`, `AuthService`, model data (`lib/models/`), validasi plat, alur ANPR, nama state/controller utama, dan payload API tetap utuh tanpa perubahan.

## Verifikasi & Screenshot
Dijalankan dengan:
- `dart.bat format .` → `Formatted 53 files (0 changed)`
- `flutter.bat analyze` → `No issues found!`
- `flutter.bat test` → `All tests passed!` (8/8 test lolos, termasuk golden test)

Daftar screenshot golden di `docs/revamp/fase-6/`:
- `phone_light_login.png`
- `phone_light_beranda.png`
- `phone_dark_beranda.png`
- `tablet_light_beranda.png`
- `phone_light_checkin.png`
- `phone_light_checkout.png`
- `phone_light_gatepass.png`
- `tablet_dark_gatepass.png`
