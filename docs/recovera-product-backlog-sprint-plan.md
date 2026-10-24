# Recovera — Spesifikasi Fitur, Product Backlog & Rencana Pembagian Tugas Tim (Sprint Plan)

> **Dokumen Resmi Acuan Tim Pengembang:** Recovera (B2B Near-Expiry Food Liquidation & Diversion)  
> **Mata Kuliah:** Pemrograman Aplikasi Mobile (PAM) — Tugas Akhir  
> **Status Proyek:** Fase Implementasi Frontend & Integrasi Hardware / Sensor  
> **Susunan Tim (3 Orang):**
> * **Ardi:** Backend & Core Integration Lead *(Status: Endpoint REST API Selesai)*
> * **Gevi:** Database & UI/UX Lead *(Status: Schema, Seeder 1000+ Data Selesai)*
> * **Anggota 3:** Native Hardware, Sensors & Gamification Lead *(Status: In Progress)*

---

## 1. Pemetaan 14 Kriteria Wajib Mata Kuliah PAM

Dokumen ini menjamin seluruh kriteria wajib evaluasi UAS terpenuhi secara seimbang di antara 3 anggota tim:

| # | Kriteria Wajib Dosen | Fitur & Implementasi di Recovera | Penanggung Jawab (PIC) | Target Status |
| :-: | :--- | :--- | :---: | :---: |
| **1** | **Login Enkripsi + Session** | Password bcrypt, JWT Token (Access 60 mnt, Refresh 7 hari), `flutter_secure_storage`, Dio Interceptor auto-refresh. | **Ardi** | In Progress |
| **2** | **Login Biometrik** | Package `local_auth` di Flutter; Fingerprint login & Step-up Authentication saat konfirmasi *Buy Now*. | **Anggota 3** | To Do |
| **3** | **Database Lokal & Online** | PostgreSQL Supabase (13 tabel online) + SQLite `sqflite` (5 tabel offline: cache feed, draft listing, order, game, prefs). | **Ardi & Gevi** | In Progress |
| **4** | **Web Service / Multi-API** | FastAPI Backend, Google Gemini AI (OCR Faktur), API Kurs Valuta Asing, Firebase FCM, RPC Node Web3. | **Ardi** | In Progress |
| **5** | **Fasilitas LBS & Peta** | Titik `lat/lng` gudang seller, peta interaktif OSM/Google Maps, Location Pin Picker dengan auto-reverse geocoding. | **Anggota 3** | To Do |
| **6** | **Bottom Navigation Wajib** | 5 Tab: **Home · Stok/Lelang · Profil · Saran & Kesan · Logout** (dengan dialog konfirmasi). | **Gevi** | In Progress |
| **7** | **Konversi Mata Uang ($\ge$ 3)** | Nilai transaksi IDR dikonversi ke **USD, EUR, dan GBP** via cache kurs endpoint `/rates`. | **Gevi** | To Do |
| **8** | **Konversi Waktu (4 Zona)** | Tampilan deadline lelang & tanggal kedaluwarsa dalam zona **WIB, WITA, WIT, dan London**. | **Gevi** | To Do |
| **9** | **Minimal 2 Sensor Fisik** | **Magnetometer** (Kompas penjemputan barang ke gudang) & **Accelerometer / Gyroscope** (Shake-to-refresh & Tilt Mini-Game). | **Anggota 3** | To Do |
| **10** | **Integrasi AI / LLM** | Multimodal Gemini API (Ekstraksi teks faktur fisik $\rightarrow$ auto-fill form lelang) & AI Pricing Advisor rationale. | **Ardi** | In Progress |
| **11** | **Mini Game Sederhana** | Mini-game edukasi "Food Saver Challenge" berbasis sensor kemiringan; skor tersimpan di SQLite `game_scores`. | **Anggota 3** | To Do |
| **12** | **Pencarian & Pemilihan** | Search bar (nama/merek) + filter multi-kategori (Dairy, Frozen, dll) + filter radius + sorting (termurah/terdekat). | **Gevi** | Done |
| **13** | **Notifikasi Mobile** | Push notification FCM untuk penawaran top-5 buyer lelang & local notification saat status order berubah. | **Ardi** | To Do |
| **14** | **Blockchain Sederhana** | Bukti transaksi order & sertifikat ESG dicatat on-chain via hash transaksi di BOT Chain Testnet / Block Explorer. | **Ardi** | To Do |

---

## 2. Product Backlog Lengkap (PBI-01 s/d PBI-23)

### Epic 1: Autentikasi, Keamanan & Profil Pengguna

#### PBI-01: Backend Auth Endpoint & Hash Keamanan
* **User Story:** Sebagai sistem, saya ingin endpoint pendaftaran dan login terenkripsi agar kredensial pengguna tersimpan aman.
* **Kriteria Terima (AC):** Password wajib bcrypt; JWT HS256 berumur 60 menit; refresh token 7 hari berstatus revocable.
* **PIC:** Ardi | **Status:** `DONE`

#### PBI-02: Dio Interceptor & Secure Storage di Flutter
* **User Story:** Sebagai pengguna mobile, saya ingin sesi login saya bertahan tanpa harus mengetik password berulang kali.
* **Kriteria Terima (AC):** Token disimpan di `flutter_secure_storage`; Dio Interceptor otomatis menyisipkan header Authorization; silent refresh otomatis jika access token kedaluwarsa (401).
* **PIC:** Ardi | **Status:** `IN PROGRESS`

#### PBI-03: UI Layar Auth (Login, Register & Profil)
* **User Story:** Sebagai pengguna, saya ingin antarmuka masuk dan daftar yang bersih dan mudah dipahami.
* **Kriteria Terima (AC):** Form login & register dengan pilihan peran (Seller Distributor / Buyer UMKM); tab profil menampilkan identitas akun dan foto avatar.
* **PIC:** Gevi | **Status:** `IN PROGRESS`

#### PBI-04: Login Biometrik & Step-up Auth (Fingerprint)
* **User Story:** Sebagai pengguna, saya ingin membuka aplikasi menggunakan sensor sidik jari perangkat gawai saya.
* **Kriteria Terima (AC):** Toggle biometrik di tab Profil; saat aktif, login membuka access token via `local_auth`; fallback aman jika gawai tidak memiliki sensor biometrik.
* **PIC:** Anggota 3 | **Status:** `TO DO`

---

### Epic 2: Kerangka Shell, Navigasi & Utilitas Wajib

#### PBI-05: Bottom Navigation Bar 5 Tab Wajib
* **User Story:** Sebagai pengguna, saya ingin navigasi bawah yang konsisten untuk berpindah antar menu utama.
* **Kriteria Terima (AC):** 5 tab: **Home**, **Stok**, **Profil**, **Saran & Kesan**, **Logout**; tab Logout memunculkan dialog konfirmasi sebelum menghapus token sesi.
* **PIC:** Gevi | **Status:** `IN PROGRESS`

#### PBI-06: Modul Konversi Waktu Multi-Zona (WIB, WITA, WIT, London)
* **User Story:** Sebagai pengguna, saya ingin melihat tenggat waktu lelang dalam zona waktu lokal dan jam kantor London.
* **Kriteria Terima (AC):** Menampilkan badge multi-zona pada tanggal kedaluwarsa produk; jam penerbitan sertifikat ESG selalu diformat zona London (GMT+0).
* **PIC:** Gevi | **Status:** `TO DO`

#### PBI-07: Modul Konversi Mata Uang Valuta Asing (IDR $\rightarrow$ USD, EUR, GBP)
* **User Story:** Sebagai pembeli/penjual bahan impor, saya ingin melihat estimasi harga barang dalam mata uang internasional.
* **Kriteria Terima (AC):** Konsumsi endpoint `/rates`; widget switcher/toggle menampilkan estimasi harga dalam USD, EUR, dan GBP dengan nilai tukar terkini.
* **PIC:** Gevi | **Status:** `TO DO`

#### PBI-08: Menu Saran & Kesan Mata Kuliah PAM
* **User Story:** Sebagai mahasiswa, saya ingin mengisi form evaluasi perkuliahan PAM langsung dari aplikasi.
* **Kriteria Terima (AC):** Form input teks kesan dan saran; mengirim payload ke endpoint `POST /feedback` dan menyimpan ke tabel `course_feedbacks`.
* **PIC:** Gevi | **Status:** `TO DO`

---

### Epic 3: Penemuan Katalog, Peta LBS & Lelang Dinamis

#### PBI-09: Pencarian, Penyaringan (Filter) & Urutan (Sort) Katalog
* **User Story:** Sebagai pembeli, saya ingin mencari bahan baku murah berdasarkan kategori, sisa umur, dan jarak terdekat.
* **Kriteria Terima (AC):** Search bar (case-insensitive); filter kategori (Dairy, Flour, Oil, Frozen, Canned); filter sisa hari kedaluwarsa; sort terdekat & termurah.
* **PIC:** Gevi | **Status:** `DONE`

#### PBI-10: Tampilan Peta LBS Gudang Seller
* **User Story:** Sebagai pembeli, saya ingin melihat sebaran lokasi gudang seller di sekitar saya pada peta.
* **Kriteria Terima (AC):** Peta interaktif OpenStreetMap (`flutter_map`) menampilkan pin/marker gudang seller; klik pin memunculkan kartu ringkasan toko.
* **PIC:** Anggota 3 | **Status:** `TO DO`

#### PBI-11: Location Picker saat Registrasi Seller
* **User Story:** Sebagai seller, saya ingin menentukan titik gudang saya di peta dan alamatnya terisi otomatis.
* **Kriteria Terima (AC):** Geser pin di peta $\rightarrow$ ekstrak koordinat `warehouse_lat` & `warehouse_lng` $\rightarrow$ reverse geocoding otomatis mengisi teks `warehouse_address`.
* **PIC:** Anggota 3 | **Status:** `TO DO`

#### PBI-12: Detail Listing & Countdown Dutch Auction
* **User Story:** Sebagai pembeli, saya ingin mengetahui harga lelang saat ini dan kapan harga akan turun berikutnya.
* **Kriteria Terima (AC):** Menampilkan harga saat ini, grafik penurunan harga, dan *countdown timer* menuju periode penurunan harga berikutnya (`next_drop_at`).
* **PIC:** Gevi | **Status:** `TO DO`

#### PBI-13: Shake-to-Refresh Feed (Sensor Accelerometer)
* **User Story:** Sebagai pembeli, saya ingin mengguncang gawai untuk memperbarui daftar lelang terbaru.
* **Kriteria Terima (AC):** Menggunakan `sensors_plus` (accelerometer); mendeteksi hentakan tangan (ambang threshold $\ge 25$) $\rightarrow$ memicu fetch data lelang terbaru.
* **PIC:** Anggota 3 | **Status:** `TO DO`

---

### Epic 4: Alur Upload Distributor & AI Ingestion

#### PBI-14: Backend Gemini OCR & AI Pricing Advisor
* **User Story:** Sebagai sistem, saya ingin endpoint yang mampu mengekstrak gambar faktur dan memberikan saran harga lelang.
* **Kriteria Terima (AC):** Endpoint `POST /ai/invoice` mengembalikan JSON produk; endpoint `POST /ai/price-advice` mengembalikan persentase diskon dan penjelasan 2 kalimat.
* **PIC:** Ardi | **Status:** `DONE`

#### PBI-15: Alur Foto Faktur Gemini OCR di Mobile
* **User Story:** Sebagai seller, saya ingin memotret faktur kertas pembelian agar data barang lelang terisi otomatis.
* **Kriteria Terima (AC):** Ambil foto via kamera $\rightarrow$ kirim multipart ke backend $\rightarrow$ form lelang otomatis terisi: nama produk, batch, expired date, qty, harga normal.
* **PIC:** Ardi | **Status:** `TO DO`

#### PBI-16: Widget Rekomendasi Harga AI di Form Listing
* **User Story:** Sebagai seller, saya ingin melihat alasan penetapan harga lelang dari AI sebelum menerbitkan lelang.
* **Kriteria Terima (AC):** Kartu saran harga AI menampilkan rekomendasi harga pembukaan lelang dan penjelasan singkat dari Gemini.
* **PIC:** Ardi | **Status:** `TO DO`

---

### Epic 5: Transaksi, Logistik Penjemputan & Hardware

#### PBI-17: Buy Now dengan Step-Up Biometrik
* **User Story:** Sebagai pembeli, saya ingin transaksi pembelian instan diproteksi sidik jari agar tidak tertekan secara tidak sengaja.
* **Kriteria Terima (AC):** Tombol "Beli Sekarang" memicu pop-up biometrik; setelah sidik jari lolos, eksekusi endpoint `POST /listings/{id}/buy` untuk membuat `orders`.
* **PIC:** Anggota 3 | **Status:** `TO DO`

#### PBI-18: Mode Ambil Barang: Kompas Penunjuk Arah (Magnetometer)
* **User Story:** Sebagai pembeli, saya ingin panduan arah panah kompas menuju lokasi gudang penjual saat mengambil barang.
* **Kriteria Terima (AC):** Menggunakan sensor magnetometer; menghitung bearing sudut antara GPS pembeli dan koordinat gudang seller $\rightarrow$ jarum kompas berputar dinamis.
* **PIC:** Anggota 3 | **Status:** `TO DO`

#### PBI-19: Riwayat Pesanan & Manajemen Status Order
* **User Story:** Sebagai pengguna, saya ingin memantau daftar transaksi saya dan menandai barang yang sudah selesai diambil.
* **Kriteria Terima (AC):** Layar riwayat pesanan; seller dan buyer dapat mengubah status order (`paid` $\rightarrow$ `picked_up` $\rightarrow$ `completed`).
* **PIC:** Gevi | **Status:** `TO DO`

---

### Epic 6: Pengalihan Pangan, Blockchain ESG & Gamifikasi

#### PBI-20: Tampilan Sertifikat ESG & Verifikasi Blockchain
* **User Story:** Sebagai distributor, saya ingin sertifikat dampak pengalihan makanan terverifikasi di penjelajah blok on-chain.
* **Kriteria Terima (AC):** Menampilkan sertifikat donasi (Grade A/B/C, kg CO2e, jam London); tombol "Verifikasi" membuka hash transaksi di Block Explorer / RPC verify.
* **PIC:** Ardi | **Status:** `TO DO`

#### PBI-21: Mini Game "Food Saver Challenge" (Sensor Gyroscope & Tilt)
* **User Story:** Sebagai pengguna, saya ingin memainkan game edukasi pemilahan makanan kedaluwarsa menggunakan sensor gerak.
* **Kriteria Terima (AC):** Kartu makanan dengan sisa hari; memiringkan HP (*Gyroscope tilt*): kiri (Lelang), kanan (Jual Normal), depan (Donasi); skor tersimpan di SQLite `game_scores`.
* **PIC:** Anggota 3 | **Status:** `TO DO`

#### PBI-22: Notifikasi Inbox In-App & FCM
* **User Story:** Sebagai pengguna, saya ingin mendapatkan pemberitahuan saat ada lelang baru atau saat harga barang turun drastis.
* **Kriteria Terima (AC):** Ikon lonceng notifikasi di AppBar; menampilkan badge jumlah pesan belum dibaca; notifikasi dapat ditandai telah dibaca.
* **PIC:** Ardi | **Status:** `TO DO`

#### PBI-23: Sinkronisasi Offline-First SQLite (`sqflite`)
* **User Story:** Sebagai pengguna, saya ingin aplikasi tetap dapat dibuka dan menyiapkan draf lelang saat tidak ada koneksi internet.
* **Kriteria Terima (AC):** Menyimpan cache lelang di `cached_listings`; draf upload disimpan di `draft_listings` dan otomatis di-sync ke server saat koneksi internet pulih.
* **PIC:** Ardi & Gevi | **Status:** `TO DO`

---

## 3. Rencana Kerja & Pembagian Tugas Per Anggota

### Tanggung Jawab Ardi (Backend & Integrasi Mobile)
1. Menuntaskan `PBI-02` (Dio Interceptor, JWT secure storage di Flutter).
2. Mengintegrasikan `PBI-15 & 16` (Kamera/Galeri $\rightarrow$ API Gemini OCR $\rightarrow$ Form pre-fill).
3. Mengatur `PBI-20` (Tampilan sertifikat ESG & verifikasi hash on-chain).
4. Membangun logika sinkronisasi `PBI-23` (SQLite sync queue saat online).

### Tanggung Jawab Gevi (UI/UX, State Management & Konversi)
1. Menyelesaikan layout UI `PBI-03 & 05` (Auth screen, Profil, 5 Tab Bottom Nav).
2. Membangun halaman katalog `PBI-09 & 12` (Search, Filter kategori, Detail lelang, Dutch Auction timer).
3. Membuat widget utilitas `PBI-06 & 07` (Konversi 4 zona waktu & konversi valas USD/EUR/GBP).
4. Menyelesaikan halaman `PBI-08 & 19` (Form Saran & Kesan PAM, Riwayat Order).

### Tanggung Jawab Anggota 3 (Hardware Native, Sensor & Gamifikasi)
1. Mengintegrasikan `PBI-04 & 17` (Sensor sidik jari `local_auth` untuk login & step-up Buy Now).
2. Membangun modul peta `PBI-10 & 11` (Peta gudang OSM & Location Pin Picker saat registrasi).
3. Mengimplementasikan sensor kompas `PBI-18` (Magnetometer penunjuk arah gudang seller).
4. Mengimplementasikan sensor gerak `PBI-13` (Accelerometer shake-to-refresh).
5. Membangun mini-game `PBI-21` (Food Saver Challenge dengan sensor kemiringan Gyroscope).

---

## 4. Jadwal Roadmap Sprint (Target Siap Demo UAS)

```
Minggu 1:
[Ardi]      ──────► Dio Interceptor & Auth State
[Gevi]      ──────► Layout Shell, 5 Bottom Nav & Feed Katalog
[Anggota 3] ──────► Setup Biometrik local_auth & Peta Dasar

Minggu 2:
[Ardi]      ──────► Integrasi Gemini OCR Upload Faktur
[Gevi]      ──────► Detail Dutch Auction, Konversi Kurs & Waktu
[Anggota 3] ──────► Kompas Magnetometer & Shake-to-Refresh

Minggu 3:
[Ardi]      ──────► SQLite Offline Sync & Notifikasi
[Gevi]      ──────► Menu Saran & Kesan PAM, Riwayat Pesanan
[Anggota 3] ──────► Mini Game Gyroscope (Food Saver Challenge)

Minggu 4:
[Seluruh Tim] ────► Pengujian End-to-End, Bug Fixing, Seed Data Demo, Gladi Bersih Presentasi
```
