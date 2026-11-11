# Fase 5 — Hardening & Final Polish

Fase ini menutup revamp dengan penguatan alur gerbang, aksesibilitas, dan
stabilitas preview. Tidak ada perubahan pada endpoint, model, service, atau
utilitas.

## Perubahan utama

- Check-out hanya memilih kendaraan bila nomor polisi cocok persis. Hasil
  pencarian lain tidak lagi dipilih otomatis agar petugas tidak memproses unit
  yang salah.
- Catatan dan foto keluar dibersihkan saat nomor polisi berubah, termasuk saat
  hasil scan ANPR mengganti plat.
- Unggah foto check-in/check-out sekarang menghitung kegagalan. Bila sebagian
  foto gagal, gate pass menampilkan peringatan yang jelas tanpa membatalkan
  transaksi yang sudah tersimpan.
- `BerandaView` menerima jam opsional agar sapaan, tanggal, dan durasi stabil
  saat preview/test.
- Kartu yang dapat diketuk memiliki label semantik; chip filter memakai tinggi
  minimum 48 px agar tetap ramah pembesaran teks.
- Semua bobot font yang dipakai dibundel; runtime fetching Google Fonts
  dimatikan agar tampilan konsisten saat offline.

## Screenshot

Semua screenshot berada di folder ini:

- Beranda: `phone_light_beranda.png`, `phone_dark_beranda.png`,
  `tablet_light_beranda.png`, `tablet_dark_beranda.png`
- Check-in: `phone_light_checkin.png`, `phone_dark_checkin.png`,
  `tablet_light_checkin.png`, `tablet_dark_checkin.png`
- Check-out: `phone_light_checkout.png`, `phone_dark_checkout.png`,
  `tablet_light_checkout.png`, `tablet_dark_checkout.png`
- Check-out tidak cocok: `phone_light_checkout_not_found.png`
- Gate pass: `phone_light_gatepass.png`, `phone_dark_gatepass.png`,
  `tablet_light_gatepass.png`, `tablet_dark_gatepass.png`
- Gate pass dengan peringatan foto: `phone_light_gatepass_warning.png`
- Profil: `phone_light_profile.png`, `phone_dark_profile.png`

## Catatan

- Preview memakai loader dan jam tetap; produksi tetap memakai `ApiService`
  dan waktu perangkat.
- Pengujian kamera, torch, ANPR, dan backend langsung tetap memerlukan
  perangkat/lingkungan nyata.
- `ApiService` masih menelan error jaringan dan mengembalikan daftar kosong.
  Karena itu kondisi offline di produksi dapat tampil sebagai daftar kosong,
  bukan `ErrorState`.
