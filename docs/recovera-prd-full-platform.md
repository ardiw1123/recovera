---
type: prd
tags:
  - prd
  - recovera
  - food-loss
  - requirements
  - ai
  - mobile
  - b2b-marketplace
created: 2026-10-07
updated: 2026-10-07
status: draft-v1
scope: full-platform
sources:
  - "[[Recovera - Blueprint Tugas Akhir Mobile]]"
  - "[[2026-10-06-arsitektur-model-ai-recovera]]"
  - "[[matching-algorithm]]"
  - "[[food-loss-matching-implementation-recommendation]]"
  - "[[recovera-value-proposition]]"
  - "[[recovera-customer-segmentation]]"
related:
  - "[[Recovera - Katalog Fitur & User Flow Detail]]"
  - "[[Recovera-user-flow]]"
  - "[[recovera-brand-guidelines]]"
---

# PRD — Recovera (B2B Near-Expiry Food Liquidation Platform)

> **Status:** Draft v1 — menunggu review tim (Anggota A/B/C) sebelum dibekukan.
> **Jenis dokumen:** spesifikasi kebutuhan internal (dev spec) untuk desarrollo.
> **Cakupan:** platform penuh (MVP → v1.1 → v2.0), bukan hanya scope tugas akhir.
> **Catatan konvensi:** angka bertanda *(usulan)* adalah target yang **dibuat untuk dokumen ini** dan belum dikonfirmasi stakeholders — wajib diverifikasi sebelum dipakai sebagai kriteria terima. Angka tanpa tanda berasal dari dokumen sumber.

---

## 0. Decision Log & Konflik Sumber (baca sebelum implementasi)

Dokumen sumber memuat beberapa keputusan yang **saling bertentangan**. PRD ini memilih satu jalur dan menandai sisanya sebagai conditional.

| # | Topik | Sumber A | Sumber B | **Keputusan PRD** | Alasan |
|---|-------|----------|----------|--------------------|--------|
| D1 | Mekanisme pricing | Blueprint §3: harga **rule-based murni** (`pricing.py`), LLM hanya menjelaskan | Arsitektur AI §2: **LightGBM** `pricing_model.pkl` untuk diskon awal | **MVP = rule-based.** LightGBM = v1.1, diaktifkan lewat feature flag bila data cukup | Aturan deterministik mudah didemokan & audited; model butuh data historis yang belum ada |
| D2 | Peringkat pembeli | Blueprint §3: skor bobot tetap (`0.4/0.3/0.2/0.1`) | Arsitektur AI §3: LightGBM probabilitas | **MVP = skor berbobot.** Ganti ke LightGBM di v1.1 dengan baseline skor tetap sebagai pembanding | Menyediakan baseline yang selalu bisaNjadi fallback saat model gagal dimuat |
| D3 | Notifikasi kanal | Blueprint §0: FCM + local notification | Value prop §2.1: **WhatsApp** matching notification | **MVP = FCM + in-app inbox.** WhatsApp = v2.0 | WhatsApp Business API butuh biaya pesan per percakapan & kebijakan template |
| D4 | Pembayaran | Blueprint §0: **disimulasikan** (status `paid`) | Nilai dokumen: escrow + dispute system | **MVP = simulasi.** Integrasi Midtrans/Xendit production = v1.1 (sandbox lebih dulu) | Escrow nyata di luar jangkauan 8 minggu pertama |
| D5 | Frontend | Blueprint §3: **Flutter** | Rekomendasi implementasi: **Next.js** | **Flutter.** Dokumen Next.js ditulis untuk market research/arsitektur backend, bukan untuk app mobile TA | Kriteria TA menuntut sensor, biometrik, dan LBS native; Next.js tidak cocok |
| D6 | AI tabular | Arsitektur AI §2: LightGBM/CatBoost | — | **LightGBM**,ikoń TabFM/KumoTabular | TabFM/Prior-Labs berlisensi **non-komersial**; KumoTabular butuh GPU (biaya tinggi) |

**Risiko yang harus dikonfirmasi ke dosen** (dari Blueprint §0): (a) tema marketplace sering kembar antar kelompok — cek Recovera belum dipakai; (b) apakah kamera dihitung sebagai sensor (kita tidak bergantung padanya); (c) FCM untuk push diperbolehkan (aturan hanya melarang Firebase *untuk auth*).

---

## 1. Ringkasan Eksekutif

### 1.1 Problem Statement

Distributor pangan menengah dan mikro di Indonesia kehilangan 2–7% nilai inventori per bulan karena stok mendekati kedaluwarsa, ditambah biaya pemusnahan Rp 500–1.000/kg. Di sisi lain, UMKM kuliner dan katering membutuhkan bahan baku bermerek dengan harga 30–60% di bawah pasar dalam jumlah kecil (≥5 kg), namun kanal informal tidak menjamin keaslian batch, jarak, maupun tanggal kedaluwarsa.

Ringkasnya: stok mendekati kedaluwarsa pada distributor tidak memiliki kanal likuidasi yang cepat, murah, dan terbukti patuh, sehingga harus dimusnahkan atau dibiarkan kedaluwarsa.

### 1.2 Proposed Solution

**Recovera** adalah platform B2B *smart liquidation & diversion* yang (a) mengotomatiskan pencocokan stok distributor dengan pembeli terdekat dalam radius ≤15 km, (b) menjalankan harga berjenjang berbasis waktu (*Dutch auction*) untuk memaksa stok terserap sebelum kedaluwarsa, dan (c) menjamin jalur keluar terakhir (*zero-waste*) melalui pengalihan otomatis ke Food Bank / pabrik pakan / kompos, dengan jejak audit terverifikasi (*hash-chain*) dan sertifikat ESG yang dapat dipakai untuk pelaporan kepatuhan EPR/ESG.

### 1.3 Success Criteria (KPI)

**Bisnis**
- Match rate ≥ 70% pada akhir Fase 2; ≥ 85% pada Fase 3 *(sumber: implementation-recommendation)*.
- Recovery rate 40–70% dari nilai normal inventori *(sumber: value-proposition)*.
- Rata-rata jarak pencocokan ≤ 15 km *(sumber)*.
- ≥ 60% dari listing yang dialihkan (diverted) benar-benar*tidak* berakhir sebagai sampah *(usulan — perlu konfirmasi)*.

**Operasional**
- Match time ≤ 12 jam (*batch*) dan ≤ 2 jam (*flash matching*) *(sumber)*.
- 100% stok terdaftar yang melewati batas 14 hari tanpa transaksi menghasilkan entri `donations` + hash sertifikat on-chain di BOT Chain Testnet (bukti zero-waste).
- 0 insiden kebocoran token/kredensial pada audit keamanan pra-demo.

**Teknis**
- P95 latency API read endpoint (browse/search/filter) ≤ 400 ms untuk dataset 10.000 listing *(usulan — TBD setelah baseline)*.
- P95 latency endpoint AI OCR faktur ≤ 8 detik *(usulan — TBD sesuai kuota Gemini)*.
- Prediksi model saat runtime < 10 ms per transaksi (LightGBM, CPU-only) *(sumber: arsitektur AI)*.

**Model / AI**
- Field-level accuracy OCR faktur ≥ 90% pada benchmark 50 foto *(usulan)*.
- Precision@5 model ranking ≥ 0.70 pada split waktu, dan **tidak boleh lebih buruk** dari baseline berbasis jarak saja *(usulan)*.
- Guardrail violation rate = 0 (koma keras) pada seluruh skenario uji.

**Adopsi**
- ≥ 5–10 mitra distributor dan ≥ 3–5 pembeli/merchant aktif pada Fase 2 *(sumber: implementation-recommendation MVP)*.

---

## 2. Pengalaman Pengguna & Fungsionalitas

### 2.1 User Personas

| Persona | Deskripsi | Kebutuhan Utama |
|---------|-----------|------------------|
| **Distributor Seller** | Distributor/grosir menengah, punya gudang, manage stok operasional harian | Jangan sampai expired; pulihkan modal kerja; hemat biaya disposal; bukti kepatuhan |
| **Buyer UMKM Kulinery** | UMKM kuliner, bakery, katering; belanja HPP 30–50% berfluktuasi | Bahan baku murah, mutu terjamin, MOQ kecil, akses nearby |
| **Food Bank / Off-taker** | LSM dan mitra penerima donasi (Food Bank, pabrik pakan, kompos) | Pipa donasi terprediksi, logistics ditanggung platform, data dampak untuk laporan |
| **Admin / Regulator** *(fase v1.1+)* | Admin platform; KLHK/Bappenas sebagai konsumen laporan |Agregasi data FLW, jejak audit EPR, dashboard impact |

### 2.2 User Stories & Acceptance Criteria

#### US-01 — Autentikasi & Sesi (Seller & Buyer)
**Story:** Sebagai pengguna, saya ingin mendaftar/login dengan aman sehingga saya dapat mengakses fitur sesuai role saya.

**AC:**
- Registrasi mewajibkan `email` unik, `password` ≥ 8 karakter, `role` (seller/buyer), dan `company_name`.
- Seller wajib menandai lokasi gudang (lat/lng) dan mengisi alamat saat registrasi.
- Buyer wajib menandai lokasi utama usaha (lat/lng) dan mengisi alamat saat registrasi.
- Password disimpan sebagai hash **bcrypt/argon2** — tidak pernah plaintext, tidak pernah log.
- Login mengembalikan access token berumur **60 menit** dan refresh token berumur **7 hari**.
- Refresh token disimpan di DB **sebagai hash** dan dapat di-revoke (`POST /auth/logout`).
- Access & refresh token disimpan di `flutter_secure_storage` (Android Keystore), **tidak** di SharedPreferences, **tidak** tercetak di log.
- Token access yang kedaluwarsa diproses otomatis oleh Dio interceptor (silent refresh).
- Bila refresh gagal → pengguna dikembalikan ke Login dengan pesan jelas.

#### US-02 — Biometrik & Step-up Authentication
**Story:** Sebagai pengguna, saya ingin membuka aplikasi dengan sidik jari agar cepat masuk tanpa mengetik password.

**AC:**
- Toggle "Aktifkan sidik jari" tersedia di tab Profil setelah login pertama.
- Bila aktif, app start menjalankan `local_auth`; bila biometrik sukses, app memakai refresh token dari Secure Storage untuk meminta access token baru.
- Biometrik **dipicu ulang (step-up)** saat konfirmasi **Buy Now**.
- Biometrik gagal / dibatalkan / perangkat tidak mendukung → pengguna tetap di Login, tanpa crash.

#### US-03 — Upload Listing & OCR Faktur (Seller)
**Story:** Sebagai seller, saya ingin memotret faktur pembelian agar data stok terisi otomatis dan cepat.

**AC:**
- Seller dapat mengambil foto atau memilih gambar dari galeri.
- Foto dikirim ke `POST /ai/invoice` (multipart); Gemini mengubahnya menjadi JSON produk yang sesuai skema.
- Hasil OCR mengisi pre-fill form: `product_name`, `brand`, `category`, `quantity`, `unit`, `expiry_date`, `normal_price`.
- Seller wajib review/ubah setiap field sebelum publish.
- Bila foto buram/Gemini gagal → form manual terbuka dengan pesan, **tidak** memblokir alur.
- Field yang tidak ditemukan terisi kosong, bukan tebakan. Level keyakinan per field ditampilkan. *(usulan)*

#### US-04 — AI Pricing Advisor (Seller)
**Story:** Sebagai seller, saya ingin rekomendasi harga beserta alasan agar saya tidak menentukan diskon secara buta.

**AC:**
- Harga dihitung server-side dari fungsi deterministik (rule-based pada MVP).
- LLM **hanya menjelaskan** alasan maksimal 2 kalimat; angka dalam penjelasan harus cocok dengan angka hasil perhitungan.
- Explanation tidak boleh mengarang fakta (mis. "kami menjamin 5 pembeli tertarik" jika tidak ada data).
- Endpoint mengembalikan `{suggested_price, discount_pct, rationale, next_drop_at}`.
- Bila LLM gagal → `rationale` diisi template deterministik, fitur tetap berfungsi.

#### US-05 — Browse, Search, Filter, Peta/LBS (Buyer)
**Story:** Sebagai buyer, saya ingin melihat stok murah di sekitar saya agar saya hemat ongkir dan waktu.

**AC:**
- Search mencocokkan `product_name` dan `brand` (case-insensitive).
- Filter: kategori, radius (5/10/20 km), sisa umur minimum (`min_days`), rentang harga, dan sort (terdekat / termurah / segera kedaluwarsa).
- Peta OSM menampilkan pin lokasi gudang; toggle List ⇄ Peta.
- GPS ditolak → pesan izin jelas; listing tetap tampil dengan urutan default.
- Angka hasil berubah konsisten antara radius 5 km vs 20 km.
- Saat offline → listing tampil dari cache SQLite dengan indikator "data cache".

#### US-06 — Dutch Auction & Buy Now (Seller & Buyer)
**Story:** Sebagai seller, saya ingin harga turun otomatis agar stok terjual sebelum kedaluwarsa; sebagai buyer, saya ingin membeli langsung saat harga reached acceptable.

**AC:**
- `harga_sekarang = max(min_price, harga_normal × (1 - diskon_awal) × (1 - step_turun(umur_listing)))`.
- Diskon awal berdasar sisa umur: >90 h 25%; 60–90 h 30%; 30–60 h 40%; 15–30 h 50%; <15 h 55%.
- Harga **dihitung saat dibaca** (fungsi waktu), bukan cron per listing; `next_drop_at` dikirim ke client.
- Harga **tidak pernah** turun di bawah `min_price` (invariant, wajib diuji).
- Countdown auction ditampilkan dalam 3 zona Indonesia + London.
- Buy Now memerlukan step-up biometrik, membuat `orders`.
- Dua buyer menekan Buy Now pada listing yang sama secara bersamaan → **hanya satu** yang berhasil (stok dicek di dalam transaksi DB).

#### US-07 — Notifikasi
**Story:** Sebagai pengguna, saya ingin diberi tahu tentang tawaran dan perubahan harga agar tidak perlu polling manual.

**AC:**
- Push FCM saat listing publish ke top-5 buyer, saat harga turun, dan saat pesanan berubah status.
- Countdown reminder H-3 dan H-1 sebelum kedaluwarsa.
- Inbox in-app dengan badge count belum dibaca; tandai sudah dibaca.
- Bila FCM tidak terkonfigurasi/ditolak → fallback local notification + polling; fitur notifikasi tetap berjalan.

#### US-08 — Diversion & Sertifikat ESG
**Story:** Sebagai seller, saya ingin stok yang tak laku dialihkan ke food bank agar tidak terbuang dan saya mendapat bukti ESG.

**AC:**
- Automated job: listing tak laku **dan** sisa umur < 14 hari →ikoł dialihkan.
- Grade: **A** (≥7 hari, layak konsumsi manusia) → Food Bank; **B** → Pabrik Pakan Ternak; **C** → Kompos/Pupuk Organik.
- Diversion membuat entri `donations`, **hash sertifikat dicatat on-chain** di BOT Chain Testnet via smart contract (`storeHash()`), dan nomor sertifikat.
- Sertifikat menampilkan nilai pangan terselamatkan dalam **USD/EUR/GBP/IDR** dan waktu terbit dalam zona **WIB**.
- Tombol "Verifikasi" memanggil `GET /blockchain/verify/{tx_hash}` dan menampilkan status verifikasi hash di BOT Chain Testnet via Block Explorer.
- Hash sertifikat yang sudah dicatat on-chain dapat diverifikasi oleh siapa pun via Block Explorer publik.

#### US-09 — Conversion Mata Uang (IDR → USD/EUR/GBP)
**Story:** Sebagai seller, saya ingin nilai pangan yang saya selamatkan ditampilkan dalam mata uang yang dilaporkan prinsipal atau instansi.

**AC:**
- Konversi IDR → USD, EUR, GBP ditampilkan di (a) detail listing untuk produk bahan impor sebagai harga acuan, (b) sertifikat ESG, (c) ringkasan order.
- Kurs diambil dari exchange-rate API, di-cache server & lokal, dengan fallback ke nilai statis *(TBD: nilai fallback & tanggal sparkes)*.
- Nilai konversi konsisten di seluruh aplikasi untuk nilai yang sama pada satu waktu.

#### US-10 — Conversion Waktu (WIB/WITA/WIT/London)
**Story:** Sebagai pengguna, saya ingin melihat deadline dalam zona waktu saya agar tidak salah mengambil barang.

**AC:**
- Deadline auction & tanggal kedaluwarsa tampil dalam WIB, WITA, WIT, dan London.
- Zona utama mengikuti zona perangkat pengguna; dapat diganti di preferensi.
- Jam terbit sertifikat ESG selalu London (kantor pusat prinsipal).

#### US-11 — Sensor (≥2)
**Story:** Sebagai pengguna, saya ingin interaksi Sensoragar app terasa hidup & fungsional di lapangan.

**AC:**
- **Accelerometer:** shake-to-refresh feed listing.
- **Magnetometer (kompas):** panah arah ke gudang pada mode buyer "Ambil Barang".
- Cadangan: gyroscope untuk parallax onboarding. Pendukung: GPS, kamera.
- Tidak ada sensor yang menjadi satu-satunya cara menyelesaikan tugas kritis (accessibility fallback tersedia).

#### US-12 — Database Lokal & Offline
**Story:** Sebagai seller/buyer, saya ingin tetap bisa browse dan menyiapkan upload saat jaringan buruk.

**AC:**
- SQLite (sqflite) menyimpan: `cached_listings`, `draft_listings` (queue `pending/synced`), `cached_orders`, `game_scores`, `app_prefs`.
- Upload saat offline → masuk `draft_listings`, auto-sync saat online.
- Browse saat offline → tampil dari cache dengan indikator.
- Preferensi (biometrik aktif, zona waktu, kurs terakhir) persisten.

#### US-13 — Search, Filter, dan Sort (lintas)
**AC:** Lihat US-05. Endpoint `GET /listings` menerima `search, category, lat, lng, radius_km, max_price, min_days, sort, page` dan mengembalikan payload berpaginasi.

#### US-14 — Mini Game "Food Saver Challenge"
**Story:** Sebagai pengguna, saya ingin latihan cepat agar memahami logikaexpires tanpa risiko.

**AC:**
- Swipe kartu produk → **Jual / Diskon / Donasikan** sesuai sisa umur.
- Skor + badge; berjalan lokal, tanpa API.
- purely *cuttable* — tidak memengaruhi alur inti.

#### US-15 — Bottom Navigation & Shell
**AC:**
- 5 tab: **Home · Stok · Profil · Saran & Kesan · Logout**.
- Notifikasi via ikon AppBar (bell) dengan badge.
- Logout memunculkan dialog konfirmasi, menghapus token dari Secure Storage, kembali ke Login.
- Alur 12 layar minimum terpetakan di Figma: Splash, Login, Register, Home-Seller, Home-Buyer, Stok-List, Stok-Peta, Detail Listing, Upload (2 langkah), Order/Mode Ambil, Sertifikat ESG, Profil/Saran-Kesan/Notif.

#### US-16 — Saran & Kesan
**AC:** Halaman menampilkan form saran/kesan terhadap platform + tautan ke dosen/kampus sesuai aturan TA; data dikirim ke endpoint sendiri atau disimpan lokal bila offline. *(Detail endpoint TBD)*

### 2.3 Non-Goals (apa yang TIDAK kita bangun)

**Untuk MVP (8 minggu):**
- Pembayaran nyata / escrow produksi (status `paid` disimulasikan; Midtrans sandbox opsional).
- Tracking kurir real-time.
- Verifikasi legal NIB / KYC.
- Panel admin ter dedicate.
- Integrasi Food Bank *nyata* (data off-taker = simulasi/seed).
- Auto-buy & bidding windowXZ accept (skor → push top-5, tanpa window accept).
- Machine-learning forecasting permintaan.
- iOS sebagai target demo (Android dulu).
- Cron per listing untuk penurunan harga.

**Sepanjang hidup produk (tetap di luar scope):**
- Ethereum/NFT untuk sertifikat ESG (menggunakan hash-chain sederhana).
- Model tabular transformer TabFM/KumoTabular (lisensi/biaya — lihat D6).
- Penyewaan GPU di server produksi.

---

## 3. Persyaratan Sistem AI (jika relevan)

Recovera memakai AI pada dua jalur yang **sengaja dipisah** agar bisa diaudit: (a) jalur **deterministik/kebijakan** yang memutuskan angka, dan (b) jalur **model generatif/prediktif** yang membantu. Jalur (a) tidak boleh digantikan AI tanpa persetujuan.

### 3.1 Tool Requirements

| Tool / API | Peran | Dipanggil dari | Guardrail |
|-------------|-------|----------------|-----------|
| **Gemini API (multimodal)** | (a) OCR faktur → JSON produk; (b) Pricing Advisor: penjelasan maks. 2 kalimat | **Backend saja** (API key tidak pernah ada di app) | Output harus valid terhadap JSON schema; field tak yakin → kosong, bukan tebakan;Rationale wajib ground pada angka server |
| **LightGBM / CatBoost** (`ranking_model.pkl`, `pricing_model.pkl`, via `joblib`) | v1.1: prediksi diskon awal & probabilitas transaksi | Backend, dimuat ke memori saat app boot | Dijepit oleh hard rules; prediksi < 10 ms; fallback ke skor berbobot bila model gagal dimuat |
| **Hard rules / guardrail** | Batas yang tidak boleh dilanggar | Backend, deterministik | Radius ≤15 km; verifikasi pendingin untuk beku; MOQ; auto-diversion saat sisa umur <15 h; harga ≥ min_price |
| **FCM** | Push notification | Backend → device tokens | Fallback local notif + polling |
| **Cloudinary** | Penyimpanan foto listing/faktur | Backend (upload) | Validasi tipe/ukuran file |
| **Exchange-rate API** | IDR→USD/EUR/GBP | Backend (di-cache) | Fallback nilai statis *(TBD)* |

**Model tabular: LightGBM dipilih karena** - (i) 1.000-5.000 baris selesai dalam hitungan detik di CPU laptop; (ii) file `.pkl` < 1 MB, muat di server $5/bulan; (iii) prediksi instan < 1 ms tanpa GPU; (iv) kategori cukup pakai dropdown baku (tidak butuh embedding). **Dihindari:** TabFM/Prior-Labs TabPFN (lisensi non-komersial) dan KumoTabular (butuh GPU aktif, biaya tinggi).

**TRAINING-SERVING GAP & DATA COLD-START.** Sumber data retraining adalah tabel `offers` (log tiap penawaran: `days_to_expiry, discount_pct, distance_km, category_match, status, final_deal_price`). Karena platform baru, tabel ini **kosong** di MVP → meta-approach: MVP pakai rule/scoring, rekam `offers` sejak hari pertama, latih LightGBM di Fase 2 saat data cukup. Fallback ke baseline berbobot dijaga sebagai *fail-safe*.

### 3.2 Evaluation Strategy

**Benchmark tetap (golden set):**
- **OCR faktur:** 50 foto faktur seed (berbagai kondisi: buram, miring, multi-item, tangan-terulis). Ukur **field-level accuracy** (per field: nama, brand, kategori, qty, tanggal, harga) + **schema validity** + **fallback rate**.
- **Ranking:** split waktu (train bulan sebelumnya, test bulan berikutnya — mencegah data leakage). Ukur **Precision@5**, **AUC**, dan **lift vs baseline radius-saja**.
- **Pricing (regresi):** **MAE dalam poin persen diskon**, dan **% hasil di dalam `min_price`**. Guardrail violation harus 0.
- **Harga salah turun di bawah min_price:** diuji sebagai unit test fungsi harga untuk semua titik waktu (property-based test).
- **Pertahanan platform:** **Bid dua buyer bersamaan** (race condition) → tepat 1 order sukses.

**Ambang kelulusan yang diusulkan (perlu konfirmasi):**

| Metrik | Ambang (usulan) |
|--------|------------------|
| OCR field-level accuracy | ≥ 90% |
| OCR JSON schema validity | 100% |
| Ranking Precision@5 | ≥ 0.70, dan ≥ baseline radius |
| Pricing MAE | ≤ 5 poin persen |
| Guardrail violation | 0 |
| Prediksi latency (model) | < 10 ms |

**Evaluasi kualitatif (Pricing Advisor):** 30 skenario harga; dua rater menilai *faithfulness* (angka cocok dengan perhitungan), *no-hallucination*, dan *kelanjesan ≤2 kalimat*. LLM dinilai **hanya** pada kualitas penjelasan; angka tetap ditentukan server.

**Pemantauan berkelanjutan (continuous):** catat *feature-drift* (distribusi `discount_pct`/`distance_km`), *ground-truth-vs-prediksi* per minggu, dan *override rate* seller terhadap saran harga. Override tinggi → sinyal model belum layak dinaikkan otoritatif.

---

## 4. Spesifikasi Teknis

### 4.1 Architecture Overview

```
Flutter (UI → Provider → Repository → [Dio API | sqflite])
    ⇅  REST/JSON (Bearer access token)
FastAPI (router → service → SQLAlchemy)  ──► APScheduler (diversion job)
    ├──► PostgreSQL          (users, sellers, buyers, products, listings, offers, orders, offtakers, donations, course_feedbacks)
    ├──► Gemini API          (OCR + price advice)
    ├──► LightGBM .pkl       (ranking + pricing, v1.1)
    ├──► BOT Chain Testnet     (smart contract sertifikat ESG, via web3.py)
    ├──► FCM / Cloudinary / Exchange-rate API
```

**Data flow inti:** Seller upload (foto/OCR) → server hitung fitur → harga saran (rule/LGBM) → filter pembeli radius ≤15 km (jarak dihitung dari `sellers.warehouse_lat/lng` vs `buyers.base_lat/base_lng`) → skor/probabilitas → push top-5 (dicatat di `offers`) → harga turun seiring waktu → Buy Now (biometrik) → `orders` → seller tandai diambil → selesai. Bila tak laku & sisa umur <14 hari → `donations` + hash sertifikat ESG dicatat on-chain (BOT Chain Testnet).

**Prinsip arsitektur:** (1) semua keputusan angka di server (konsistensi antar device); (2) AI generatif hanya *advisory*, tidak pernah menulis angka final; (3) offline-first untuk read & draft; (4) sertifikat ESG tercatat on-chain di BOT Chain Testnet, diverifikasi via Block Explorer publik.

### 4.2 Integration Points

**API internal (FastAPI, JSON).** Header: `Authorization: Bearer <access_token>`. Sukses: `{"success":true,"data":{...}}`. Error: `{"success":false,"error":{"code":"...","message":"..."}}`. Swagger otomatis di `/docs` (lampiran Bab Perancangan).

| Method | Endpoint | Fungsi | Role |
|--------|----------|--------|------|
| POST | `/auth/register` | Daftar (role; lokasi gudang jika seller) | publik |
| POST | `/auth/login` | → access + refresh token | publik |
| POST | `/auth/refresh` | Tukar refresh token (juga dipakai setelah biometrik) | publik |
| POST | `/auth/logout` | Revoke refresh token | semua |
| GET/PATCH | `/profile` | Data profil + upload foto | semua |
| GET | `/products` | Master katalog produk | semua |
| GET | `/listings` | Browse: `search, category, lat, lng, radius_km, max_price, min_days, sort, page` | buyer |
| POST | `/listings` | Buat listing (multipart foto) | seller |
| GET | `/listings/my` | Listing milik seller | seller |
| PATCH | `/listings/{id}` | Edit / tarik stok | seller |
| GET | `/listings/{id}` | Detail + `current_price, next_drop_at, expiry, auction_end` multi-zona | semua |
| POST | `/listings/{id}/buy` | Buy Now (biometrik) → order | buyer |
| POST | `/ai/invoice` | Foto faktur → produk (JSON) | seller |
| POST | `/ai/price-advice` | Harga rekomendasi + penjelasan | seller |
| GET | `/orders`, `/orders/{id}` | Riwayat order | semua |
| PATCH | `/orders/{id}/status` | Tandai diambil/selesai | seller/buyer |
| GET | `/donations/{id}/certificate` | Sertifikat ESG (waktu London; USD/EUR/GBP; `certificate_tx_hash`, `block_number`) | seller |
| GET | `/blockchain/verify/{tx_hash}` | Verifikasi hash sertifikat ESG di BOT Chain Testnet via RPC / Block Explorer | semua |
| GET | `/rates` | Kurs IDR→USD/EUR/GBP (di-cache) | semua |
| GET | `/notifications`, PATCH `…/read` | Inbox | semua |
| POST | `/devices` | Registrasi token FCM | semua |
| POST | `/feedback` | Form saran & kesan mata kuliah PAM | semua |

**Auth.** JWT **ditandatangani HS256** (bukan "dienkripsi AES-256"); password di-hash bcrypt/argon2; refresh token 7 hari di-hash di DB & revocable; akses 60 menit; disimpan di `flutter_secure_storage`; Dio interceptor auto-refresh. *(Catatan: JWT tidak dienkripsi AES — koreksi wajib agar tidak caught dosen.)*

**Database online (PostgreSQL — 13 Tabel).** Tabel: `users`, `sellers`, `buyers`, `refresh_tokens`, `device_tokens`, `products`, `listings`, `offers`, `orders`, `notifications`, `offtakers`, `donations`, `course_feedbacks`. Relasi: `users 1─1 sellers/buyers`, `sellers 1─N listings`, `products 1─N listings`, `listings 1─N offers/orders >─ 1 buyers`, `listings 1─0..1 donations N─1 offtakers`. Gambar ERD dari tabel ini untuk laporan.

**Database lokal (SQLite/sqflite — 5 Tabel).** `cached_listings`, `draft_listings(sync_status)`, `cached_orders`, `game_scores`, `app_prefs(biometric_enabled, timezone, last_rate)`.

**Tech stack final.** Mobile: Flutter (Android demo target), Provider, dio, sqflite, flutter_secure_storage, local_auth, flutter_map + latlong2 + geolocator, sensors_plus, timezone + intl, image_picker, firebase_messaging (FCM saja), flutter_local_notifications. Backend: FastAPI, SQLAlchemy, Alembic, PyJWT, passlib[bcrypt], APScheduler, web3.py. DB: PostgreSQL (Neon/Supabase sebagai hosting DB saja, **bukan** auth). AI: Gemini API dari backend. Media: Cloudinary via backend. Blockchain: Smart contract di BOT Chain Testnet (hanya untuk sertifikat ESG). Hosting: Render/Railway *(cek free tier terbaru; cadangan demo: backend lokal + ngrok)*.

### 4.3 Security & Privacy

- **Kredensial:** password bcrypt/argon2; refresh token di-hash; tidak ada token/kredensial di SharedPreferences atau log; API key Gemini hanya di backend.
- **Otorisasi:** tiap endpointseller/buyer dijaga role (tabel di atas); seller hanya boleh ubah listing-nya sendiri.
- **Data pribadi:** app menyimpan email, nama, nomor telepon, lokasi (gudang/dapur). Kepatuhan **UU PDP (UU No. 27/2022)**: persetujuan eksplisit, minimisasi data, hak portabilitas/penghapusan; lokasi di-cache lokal dan dapat dihapus pengguna.
- **Integritas data:** jejak sertifikat ESG dicatat pada smart contract di BOT Chain Testnet (`certificate_tx_hash`, `block_number`) → endpoint verifikasi dan Block Explorer publik mendeteksi keaslian dan integritas data sertifikat.
- **Kepatuhan pangan:** cerita diverifikasi secara visual/OCR sebelum tayang; ketidaksesuaian tanggal/batch memblokir listing; jejak audit ESG/EPR untuk pelaporan KLHK/Bappenas (v1.1+).
- **Anti-fraud Guardrails (MVP):** di iframe dua buyer → satu order; harga tidak di bawah `min_price`; radius ≤15 km sebagai default notificering; off-taker & kurs = data simulasi (ditandai jelas agar tidak disalahartikan sebagai facts).

---

## 5. Risiko & Roadmap

### 5.1 Phased Rollout

**MVP — Minggu 1–8 (target demo UAS, sesuai Blueprint §8)**

| Minggu | Target |
|--------|--------|
| 1 | Finalisasi tema ke dosen, Figma 12 layar, kontrak API, repo + skema DB |
| 2 | Auth+JWT end-to-end, shell + bottom nav, biometrik, deploy backend awal |
| 3 | Listing CRUD, browse+search+filter, SQLite cache **(MVP demo-able)** |
| 4 | LBS+peta, auction pricing + demo mode, order/Buy Now |
| 5 | Notifikasi, timezone+kurs, sensor |
| 6 | Gemini OCR + price advice, diversion + smart contract + sertifikat ESG |
| 7 | Mini game, polish, bug fix, seed data demo |
| 8 | Laporan final, pengujian, cetak halaman pengesahan *(syarat UAS)* |

*Demo mode:* `TIME_SCALE` (1 hari = 1 menit) agar penurunan harga terlihat saat presentasi. Demo sensor pakai HP fisik + scrcpy untuk proyeksi.

**v1.1 — Fase 2 (Minggu 9–16): Penguatan data & AI**
- LightGBM ranking + pricing diaktifkan (behind feature flag) dengan baseline berbobot sebagai pembanding & fallback.
- Pembayaran: integrasi Midtrans/Xendit **sandbox**, lalu production; escrow & dispute alur dasar.
- Panel admin dasar; dashboard agregasi FLW/EPR.
- Batch matching (interval 12 jam) & flash matching (<2 jam); A/B framework untuk bobot skor.
- Redis + feature store untuk sinyal real-time; monitoring Prometheus/Grafana; logging ELK.
- Target: match rate ≥ 70%, recovery 40–70%, rata-rata jarak ≤ 15 km.

**v2.0 - Fase 3 (Minggu 17-24): Skala & Optimasi**
- Real-time flash matching (<2 jam), route optimization logistik.
- Prediktive demand matching & demand forecasting.
- Integrasi Food Bank nyata & MOU; WhatsApp Business API untuk matching notification (D3).
- Multi-language; dukungan 100+ mitra.
- Target: match rate ≥ 85%, recovery ≥ 70%.

### 5.2 Prioritas Potong (bila terlambat)

Potong **berurutan**: (1) mini game → (2) Pricing Advisor LLM (rationale falls back ke template) → (3) FCM (ganti local notif + polling) → (4) peta OSM (pertahankan filter radius berbasis daftar). **Jangan dipotong: syarat wajib TA #1–9** (auth+enkripsi, biometrik, DB lokal+online, web service/API, LBS, bottom nav, konversi mata uang, konversi waktu, ≥2 sensor).

### 5.3 Technical Risks

| # | Risiko | Dampak | Mitigasi | Contingency |
|---|--------|--------|-----------|-------------|
| R1 | **Data cold-start** — tabel `offers` kosong, model tidak bisa dilatih | Tinggi (blokir v1.1) | Rekam `offers` sejak hari pertama; seed data realistis | Tetap di rule/scoring berbobot sampai cukup data |
| R2 | **Free-tier habis/ditutup** (Neon/Supabase, Render, Gemini, FCM) | Tinggi (layanan mati saat demo) | Cek kuota terbaru **sebelum** implementasi; jangan anggap free tier stabil | Backend lokal + ngrok untuk demo; export data manual |
| R3 | **Gemini OCR gagal / kuota habis / faktur buram** | Sedang | Fallback form manual; retry; validasi JSON schema | Rationale template deterministik; seller isi manual |
| R4 | **Race condition Buy Now** (2 buyer bersamaan) | Tinggi (stok minus / order ganda) | Cek stok di dalam transaksi DB + constraint | Uji concurrent; unique constraint pada order aktif |
| R5 | **Bug di fungsi harga** (harga < min_price, atau salah zona waktu) | Tinggi (rugi & kredibilitas) | Unit/property test fungsi harga & timezone; `TIME_SCALE` demo | Turunkan ke rule-based deterministik; rollback |
| R6 | **Model bias / feedback loop** (data di-generate model sendiri) | Sedang | Split waktu; bandingkan dengan baseline; pantau override seller | Naikkan bobot guardrail; turunkan ke skor tetap |
| R7 | **Ketergantungan pihak ketiga** (OSM tile, API kurs, Cloudinary) | Sedang | Fallback & cache; abstraksi provider | Cache statis; ganti provider |
| R8 | **Model tabular terlarang lisensi** (TabFM non-komersial) | Tinggi (legal) | LightGBM (MIT/Apache) sejak awal | Jangan sentuh TabFM/Prior-Labs di produksi |
| R9 | **Perubahan kebijakan TA** (FCM/ kamera/_sensor) | Sedang | Konfirmasi awal ke dosen (lihat Decision Log) | Ganti FCM → local notif; sediakan jalur non-kamera |
| R10 | **Over-scope** ( gumsaya Ambitions "full platform" vs 8 minggu) | Tinggi | Roadmap berphase; prioritas potong eksplisit | Kunci MVP; v1.1/v2.0 hanya dokumen |

---

## Referensi
- [[Recovera - Blueprint Tugas Akhir Mobile]] — patokan tim, kriteria TA, timeline
- [[2026-10-06-arsitektur-model-ai-recovera]] —pilihan model AI & skema DB
- [[matching-algorithm]] & [[food-loss-matching-implementation-recommendation]] — dua-tier matching, tech stack, target performa
- [[recovera-value-proposition]] — pain point, recovery rate, differensiasi
- [[recovera-customer-segmentation]] & [[Recovera - Katalog Fitur & User Flow Detail]] — persona & fitur
