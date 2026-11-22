# AI AGENT CONTEXT & BACKEND SYNC GUIDE
## Proyek: Aplikasi Mobile & Tablet Pos Security Master Truck KIM 3 (`bengkel_kim3_security_app`)

Dokumen ini menjadi panduan utama bagi AI Agent yang melanjutkan pengembangan aplikasi Flutter **Pos Security Gerbang Bengkel Master Truck KIM 3** serta sinkronisasi backend API Builder dan database antara **Production** dan **Development**.

---

## 1. Identitas & Ekosistem Proyek
- **Direktori Kerja**: `D:\my-project\Project Backendless\bengkel_kim3_security_app`
- **Platform**: Flutter (Android APK untuk HP & Tablet petugas security gerbang)
- **Proyek Terkait**:
  - Web Fleet Customer (`../Bengkel-Kim3`)
  - Web Pos Security (`../Bengkel-Kim3-Security`)
- **Dokumentasi UI Terbaru**: [`docs/revamp/fase-6/README.md`](./docs/revamp/fase-6/README.md) (desain light-first Dribbble style, `BottomDock` 5 tab, `ThemeData` + `AppSemanticColors`).

---

## 2. Kredensial & Rahasia (WAJIB Baca dari `.env`)
> [!CAUTION]
> **Semua password, API key, dan jalur SSH key disimpan di file `.env` di root proyek ini (diabaikan oleh `.gitignore`).**
> - **JANGAN PERNAH** menuliskan password atau secret mentah ke dalam `AGENTS.md`, komentar kode, atau commit Git.
> - Jika membutuhkan akses SSH ke server API Builder, database `data_setting_sync`, database `bengkeldarkopos` (Prod), atau `dba_dev_pos` (Dev), **baca variabel terkait langsung dari `.env`**.
> - Template variabel tersedia di [`.env.example`](./.env.example).

### Cara Cepat Akses Server 94 (`API Builder`) & Database
Gunakan variabel dari `.env` (`API_BUILDER_SSH_*`, `SYNC_DB_*`, `PROD_DB_*`, `DEV_DB_*`):
1. **SSH ke Server 94**:
   ```powershell
   ssh -i "$API_BUILDER_SSH_KEY_PATH" -p $API_BUILDER_SSH_PORT -o StrictHostKeyChecking=no "$API_BUILDER_SSH_USER@$API_BUILDER_SSH_HOST"
   ```
2. **Kelola Endpoint API Builder (`sch_sync.api_endpoints`)**:
   - Database `data_setting_sync` berjalan di dalam server `94.237.69.119` pada `127.0.0.1:8832` (akses via SSH di atas menggunakan `psql` / script dengan `SYNC_DB_USER` & `SYNC_DB_PASSWORD` dari `.env`).
   - Dari dalam tabel/konfigurasi koneksi API Builder, Anda dapat memeriksa contoh endpoint `/mastertruck/security/*` (`connection_id = 1789369839047`) dan `/kim3/security/*` (`connection_id = 1790050800000`) sebelum menambah atau mengubah endpoint.
3. **Akses Database Operasional**:
   - **Dev (`dba_dev_pos`)**: langsung via `DEV_DB_HOST`, `DEV_DB_PORT`, `DEV_DB_NAME`, `DEV_DB_USER`, `DEV_DB_PASSWORD` di `.env`.
   - **Prod (`bengkeldarkopos`)**: gunakan `PROD_DB_NAME` & `PROD_DB_PASSWORD` di `.env` (host/port/user koneksi `1789369839047` dapat dicek pada konfigurasi koneksi di server API Builder).
4. **SSH ke Server `52.77.133.95` (Cek Service ANPR, Web & DarkoPOS)**:
   ```powershell
   ssh -i "$APP_SERVER_SSH_KEY_PATH" -p $APP_SERVER_SSH_PORT -o StrictHostKeyChecking=no "$APP_SERVER_SSH_USER@$APP_SERVER_SSH_HOST"
   ```
   - Gunakan akses ini untuk mengecek service/container Docker (`docker ps`), log, dan konfigurasi backend **ANPR** (`/anpr/detect` yang dipakai versi web di `../Bengkel-Kim3-Security/src/components/security/PlateOcrScannerModal.tsx`) serta **DarkoPOS Auth** (`:9004`).
   - Sebagai perbandingan, di APK Flutter saat ini pembacaan plat berjalan on-device di [`lib/services/anpr_service.dart`](./lib/services/anpr_service.dart) (`google_mlkit_text_recognition`). Cek server `52.77.133.95` bila ingin membandingkan atau menyamakan alur/akurasi ANPR dengan versi server.

---

## 3. Fokus Environment APK: **PRODUCTION (`/mastertruck/*`)**
- Aplikasi Flutter APK ini **difokuskan untuk langsung mengarah ke Production**:
  - Konfigurasi utama ada di [`lib/config/api_config.dart`](./lib/config/api_config.dart) dan [`lib/services/api_service.dart`](./lib/services/api_service.dart).
  - Seluruh endpoint Gateway pada APK menggunakan prefix **`/mastertruck/security/*`**.
  - **Jangan** mengubah endpoint APK release menjadi `/kim3/*` (Development).

| Environment | Prefix Endpoint (`sch_sync.api_endpoints`) | `connection_id` API Builder | Database Target | Status untuk APK |
| :--- | :--- | :--- | :--- | :--- |
| **Production** | `/mastertruck/*` | `1789369839047` | `bengkeldarkopos` | **TARGET UTAMA APK** |
| **Development** | `/kim3/*` | `1790050800000` | `dba_dev_pos` | Wajib dijaga tetap identik dengan Prod |

---

## 4. Aturan Wajib Sinkronisasi Backend (Prod & Dev Harus Sama!)
Setiap kali Anda menambah atau memodifikasi endpoint di server API Builder (`sch_sync.api_endpoints` pada database `data_setting_sync`) maupun mengubah struktur tabel/view di database operasional (`sch_pos`, `sch_fleet`):

1. **Samakan Query & Konfigurasi Endpoint**:
   - Query SQL, `parameters`, `enable_pagination`, HTTP method, dan `security_mode` antara **`/mastertruck/security/*` (Prod)** dan **`/kim3/security/*` (Dev)** **HARUS IDENTIK**.
   - Untuk endpoint bertipe `GATEWAY`, isi `gateway_config` (routes, condition, target URL, headers, `requestScript`, `responseTemplate`) juga **HARUS IDENTIK**; hanya `connection_id`/prefix path yang berbeda (gateway sendiri tidak memakai koneksi DB).
   - **Perbedaan yang wajib dipertahankan hanya `connection_id`**:
     - `/mastertruck/*` → `1789369839047` (`bengkeldarkopos`)
     - `/kim3/*` → `1790050800000` (`dba_dev_pos`)
2. **Samakan Skema Database**:
   - Jika ada penambahan tabel (mis. tabel `gate`), kolom (mis. kolom gate pada check-in / check-out, `alasan_keluar`, status `KELUAR_SEMENTARA`), atau view/fungsi baru, terapkan perubahan skema yang **sama persis** di **kedua database** (`bengkeldarkopos` Prod dan `dba_dev_pos` Dev).
   - **Jangan menimpa** tabel yang sudah ada di Production jika belum diverifikasi strukturnya terlebih dahulu; cek tabel eksisting sebelum `ALTER` / `CREATE`.
3. **Verifikasi Kedua Environment**:
   - Setelah update endpoint di API Builder, uji endpoint `/mastertruck/security/*` (Prod) dan pastikan `/kim3/security/*` (Dev) memiliki definisi yang sama dan merespons tanpa error SQL.

---

## 5. Daftar Endpoint Backend yang Dipakai APK

### A. Autentikasi Security (`lib/services/auth_service.dart`)
- `POST /mastertruck/security/login` — **Login staf security via API Builder Gateway** (bukan langsung ke DarkoPOS).
  - Bertipe `GATEWAY` (bukan `DATABASE`), `security_mode = HYBRID`, `auth_token = KIM3-SECURE-TOKEN-2026-X998A7B6C`.
  - APK mengirim body `{ userid, password, company }` + header `X-Api-Key` gateway.
  - `gateway_config` meneruskan request ke `http://52.77.133.95:9004/api/v1/users/login` (DarkoPOS) memakai `requestScript` yang menyisipkan header `x-api-key` DarkoPOS dan menyusun body JSON. **Kunci API DarkoPOS tidak lagi disimpan di APK** (hanya di `gateway_config`).
  - Status & body upstream diteruskan apa adanya: sukses (2xx) mengembalikan JSON DarkoPOS (`token`/`idToken`/`sessionId`/`name`), gagal (mis. 401) diteruskan dengan status yang sama.
  - Endpoint ID & grouping:
    - Prod: `ep-mastertruck-security-login`, path `/mastertruck/security/login`, group `Prod - Web Fleet & Security`, `connection_id = 1789369839047`.
    - Dev: `ep-kim3-security-login`, path `/kim3/security/login`, group `Dev - Web Fleet Customer Bengkel Kim3`, `connection_id = 1790050800000`. Konfigurasi `gateway_config` wajib sama persis dengan Prod.
  - Logika APK: bila respons `401` dan `company` terisi, APK mengulang sekali dengan `company = ''` (fallback portal web). Perilaku ini dipertahankan.
- `POST /api/v1/users/login` — **tidak lagi dipanggil langsung oleh APK** (jalur lama, hanya untuk referensi).
- `POST /mastertruck/security/logout` — **Logout staf security via API Builder Gateway** (endpoint `GATEWAY`).
  - APK mengirim body `{ token, sessionId }` + header `X-Api-Key` gateway; gateway meneruskan ke `http://52.77.133.95:9004/api/v1/users/logout` dengan header `Authorization: JWT <token>` dan `x-api-key` DarkoPOS.
  - Endpoint ID & grouping:
    - Prod: `ep-mastertruck-security-logout`, path `/mastertruck/security/logout`, group `Prod - Web Fleet & Security`, `connection_id = 1789369839047`.
    - Dev: `ep-kim3-security-logout`, path `/kim3/security/logout`, group `Dev - Web Fleet Customer Bengkel Kim3`, `connection_id = 1790050800000`. Konfigurasi `gateway_config` wajib sama persis dengan Prod.
- `POST /api/v1/users/logout` — **tidak lagi dipanggil langsung oleh APK** (jalur lama, hanya untuk referensi).

#### Cara Menambah Backend Login Lain (tanpa mengubah APK)
Endpoint login memakai `executionMode: "SWITCH"`. Tambahkan route baru pada `gateway_config` endpoint `.../security/login`:
1. Route dengan `condition` kosong = **default** (saat ini DarkoPOS). Jangan hapus route default ini.
2. Route tambahan diisi `condition` berupa ekspresi **Spring SpEL** memakai nama parameter request, contoh `#company == 'XYZ'` atau `#provider == 'xyz'`. Variabel `#provider` opsional: jika APK belum mengirimnya, nilainya `null`.
3. Isi `url`, `method`, `contentType`, `headers`/`authType`, serta `requestScript` (JS) bila perlu menyusun body/header rahasia. Script harus mendefinisikan `function transformRequest(params, req) { ...; return req; }`.
4. `responseKey` hanya untuk penamaan hasil; pada `SWITCH` body respons route terpilih dikembalikan langsung.
5. **Tidak ada failover otomatis** antar route: route dipilih berdasarkan `condition` (bukan karena route sebelumnya gagal). `errorPolicy` hanya mengatur lanjut/berhenti saat `AGGREGATE`.
6. Sinkronkan `gateway_config` ke endpoint Dev dengan definisi identik, lalu uji kedua endpoint.

> Catatan: `sch_sync.api_endpoints` dibaca ulang tiap request (tanpa cache), jadi perubahan lewat SQL langsung berlaku; tetap lakukan perubahan lewat UI API Builder bila memungkinkan agar tervalidasi.

### B. API Builder Gateway — Production (`lib/services/api_service.dart`)
Semua dipanggil melalui `gatewayBaseUrl` (`/api/data`) dengan header `X-Api-Key`:
- `/mastertruck/security/login` — Login staf security (endpoint `GATEWAY` → DarkoPOS, detail di bagian A)
- `/mastertruck/security/logout` — Logout staf security (endpoint `GATEWAY` → DarkoPOS, detail di bagian A)
- `/mastertruck/security/gates` — Daftar gerbang (dipilih setelah login sebelum masuk aplikasi utama)
- `/mastertruck/security/checkin-candidates` — Pencarian kandidat booking / member berdasarkan nomor polisi
- `/mastertruck/security/check-in` — Simpan transaksi check-in + foto wajib (`Depan`, `Supir`, opsional sudut lain) + `gate_id`
- `/mastertruck/security/add-foto` — Tambah foto dokumentasi tambahan
- `/mastertruck/security/active-inside` — Daftar kendaraan aktif di dalam bengkel (`waktu_check_out IS NULL`) & histori keluar hari ini
- `/mastertruck/security/re-enter` — Masuk kembali dari status `KELUAR_SEMENTARA`
- `/mastertruck/security/check-out` — Proses check-out (cek FIR untuk service / status keluar sementara, validasi alasan keluar, konfirmasi beda gate, dan foto keluar)
- `/mastertruck/security/memo-keluar` — Data Gate Pass / Memo Keluar digital
- `/mastertruck/security/employees` — Daftar PIC / karyawan bengkel untuk kunjungan `Service`

---

## 6. Alur Bisnis Inti yang Harus Dijaga
1. **Login → Pilih Gate**: Setelah login berhasil, user wajib memilih Gate terlebih dahulu sebelum masuk ke `HomeNavView` (gate disimpan di `UserSession`).
2. **Check-In**:
   - Tujuan `Service` (sub-menu: `Service`, `Kunjungan`, `Beli Sparepart`) memilih PIC dari daftar karyawan.
   - Tujuan `Umum` menyembunyikan sub-menu (`_subTujuan = 'UMUM'`) dan input PIC diketik manual (wajib).
   - Foto `Depan` dan `Supir` wajib diunggah, serta mendukung penambahan foto ekstra.
3. **Check-Out**:
   - Kunjungan `Service` dengan proses pengerjaan memeriksa ketersediaan **FIR** (bukan sekadar status lunas invoice); jika FIR belum terbit, status dicatat sebagai **Keluar Sementara** dan wajib mengisi alasan keluar.
   - Kunjungan non-service / keluar sementara wajib memilih alasan keluar (atau mengetik manual bila memilih `Lainnya`).
   - Jika gerbang keluar berbeda dengan gerbang masuk, tampilkan dialog konfirmasi beda gerbang sebelum eksekusi.

---

## 7. Perintah Pengembangan & Verifikasi (Windows)
Gunakan binary Flutter/Dart lokal di `D:\flutter\bin\`:

```powershell
# Format kode
& "D:\flutter\bin\dart.bat" format .

# Static analysis
& "D:\flutter\bin\flutter.bat" analyze

# Jalankan seluruh test (termasuk golden test UI Fase 6)
& "D:\flutter\bin\flutter.bat" test

# Build APK Release (fokus Production /mastertruck/*)
& "D:\flutter\bin\flutter.bat" build apk --release
```
