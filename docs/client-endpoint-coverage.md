# Flutter Client Endpoint Coverage & Architecture Record

Dokumen ini mencatat pemetaan lengkap antara alur data klien Flutter (`lib`), inventaris endpoint backend FastAPI (`backend/app`), dan perilaku yang sengaja dipertahankan sebagai *device-only* / lokal (tanpa padanan backend).

---

## 1. Ringkasan Eksekusi Alignment

Berdasarkan validasi kontrak backend di tahap sebelumnya (`docs/backend-client-contract.md`), telah dilakukan penyelarasan menyeluruh pada klien Flutter:
1. **Perbaikan Registrasi Seller & Feedback Validasi:**
   - Menambahkan pengumpulan dan transmisi field wajib role seller: `company_name` di samping display `name`.
   - Menambahkan class `ApiException` untuk mengekstraksi amplop error standar backend (`{ "success": false, "error": { "code": "...", "message": "..." } }`). Pesan kegagalan backend seperti `MISSING_SELLER_INFO` ("Company name is required for seller registration"), `EMAIL_ALREADY_EXISTS`, dan `VALIDATION_ERROR` ditampilkan secara akurat di SnackBar UI.
2. **Pembersihan Total Supabase:**
   - Inisialisasi `Supabase.initialize(...)` dan dependensi `supabase_flutter` telah dihapus sepenuhnya dari `lib/main.dart` dan `pubspec.yaml`.
   - Seluruh siklus autentikasi, session storage (JWT), dan token lifecycle sepenuhnya berjalan di atas REST service (`ApiClient`, `AuthApiService`, `AuthInterceptor`, `SecureTokenStorage`).
3. **Penyambungan Alur Data Bisnis ke Endpoint Backend:**
   - Katalog lelang pada `StokScreen` dihubungkan ke `ListingRepository` dengan implementasi `ListingApiService` (`GET /listings` dan `POST /listings`).
   - Riwayat pesanan dihubungkan via `OrderApiService` (`GET /orders` dan `GET /orders/{order_id}`).
   - Layar profil dihubungkan ke `GET /profile` melalui `AuthRepository.fetchProfile()`.
   - Layar Saran & Kesan dihubungkan ke `POST /feedback` melalui `FeedbackApiService`.
4. **Pelestarian Perilaku Offline & Device-Only:**
   - Mode offline tetap beroperasi dengan SQLite cache fallback (`cached_listings`, `cached_orders`, `draft_listings`, `game_scores`, `app_prefs`).
   - Fitur lokal perangkat seperti Mini-game skor dan Biometric lock dipertahankan di SQLite tanpa merekayasa endpoint palsu.

---

## 2. Matriks Cakupan Endpoint Backend (`lib` vs `backend`)

| Endpoint Backend | Metode | Hak Akses | Service / Komponen Flutter | Status Integrasi | Catatan Perilaku Klien |
|---|---|---|---|---|---|
| `/auth/register` | `POST` | Publik | `AuthApiService.register` / `RegisterScreen` | **Terhubung** | Mengirim `role`, `name`, `company_name` (wajib untuk seller), `email`, `password`. Menampilkan feedback error backend. |
| `/auth/login` | `POST` | Publik | `AuthApiService.login` / `LoginScreen` | **Terhubung** | Menyimpan `access_token` & `refresh_token` di secure storage. |
| `/auth/refresh` | `POST` | Publik | `AuthInterceptor` / `AuthApiService.refreshToken` | **Terhubung** | Single-flight silent refresh saat 401 dan pembersihan sesi saat expired. |
| `/auth/logout` | `POST` | Bearer | `AuthApiService.logout` / `ProfileScreen` | **Terhubung** | Revokasi refresh token di server dan pembersihan token lokal. |
| `/profile` | `GET` | Bearer | `AuthApiService.getProfile` / `ProfileScreen` | **Terhubung** | Memuat profil dinamis user/seller/buyer dan menampilkannya di header profil. |
| `/profile` | `PATCH` | Bearer | Tersedia di backend | *Tersedia* | Update profil (opsional untuk editing profil di masa depan). |
| `/listings` | `GET` | Publik | `ListingApiService.fetchRemoteListings` / `StokScreen` | **Terhubung** | Filter pencarian, kategori, harga, umur simpan, dan sort. Fallback ke SQLite saat offline. |
| `/listings` | `POST` | Seller | `ListingApiService.uploadDraftListing` / `ListingRepository.syncPendingDrafts` | **Terhubung** | Sinkronisasi antrean draf lelang lokal ke backend. |
| `/orders` | `GET` | Bearer | `OrderApiService.fetchRemoteOrders` / `OrderRepository` | **Terhubung** | Mengambil riwayat transaksi caller dan menyimpan cache lokal. |
| `/orders/{order_id}` | `GET` | Bearer | `OrderApiService.fetchRemoteOrderDetail` / `OrderRepository` | **Terhubung** | Detail pesanan untuk navigasi kompas dan bukti serah terima. |
| `/feedback` | `POST` | Bearer | `FeedbackApiService.submitFeedback` / `SaranKesanScreen` | **Terhubung** | Pengiriman evaluasi, saran, dan kesan perkuliahan PAM. |
| `/products` | `GET` | Publik | Tersedia di backend | *Tersedia* | Digunakan backend saat join listing dan relasi produk katalog. |
| `/listings/{id}` | `GET` | Publik | Tersedia di backend | *Tersedia* | Detail individual listing untuk deep-link. |
| `/listings/{id}/buy`| `POST` | Buyer | Tersedia di backend | *Tersedia* | Endpoint transaksi langsung Buy-It-Now lelang. |

---

## 3. Fitur yang Sengaja Dipertahankan Sebagai *Device-Only* (Lokal)

Sesuai aturan arsitektur, tidak ada endpoint tiruan/palsu yang dibuat untuk fitur-fitur berikut karena merupakan kapabilitas perangkat lokal:

1. **Mini-game "Food Saver Challenge" (`game_scores`):**
   - **Komponen:** `GameRepository`, `LocalDatabaseService`, `GameScoreModel`.
   - **Perilaku:** Pencatatan skor mini-game, lencana (*badge*), dan papan peringkat lokal (*device leaderboard*). Backend tidak memiliki modul gamifikasi, sehingga data sepenuhnya dipertahankan di SQLite.
2. **Pengaturan Perangkat & Biometrik (`app_prefs`):**
   - **Komponen:** `AppPrefsRepository`, `LocalDatabaseService`, `AppPrefModel`.
   - **Perilaku:** Pengaturan sakelar otentikasi biometrik perangkat keras (fingerprint/Face ID), preferensi zona waktu lokal (WIB/WITA/WIT/London), dan cache nilai tukar mata uang offline.
3. **Antrean Draf Lelang Offline (`draft_listings`):**
   - **Komponen:** `ListingRepository`, `DraftListingModel`.
   - **Perilaku:** Penyimpanan draf lelang saat perangkat tidak memiliki koneksi internet, dengan status `pending`, `synced`, atau `failed`. Draf disinkronkan ke backend saat koneksi pulih.
4. **Cache Listing & Pesanan Offline (`cached_listings`, `cached_orders`):**
   - **Komponen:** `ListingRepository`, `OrderRepository`.
   - **Perilaku:** Menjamin pengalaman pengguna *offline-first* (US-05 dan US-10). Saat offline, aplikasi tetap menampilkan data terakhir yang tersimpan di SQLite dengan indikator visual *"Mode Offline — Menampilkan data cache SQLite"*.
5. **Dashboard Shell Placeholder (`HomeScreen`):**
   - **Komponen:** `lib/features/home/screens/home_screen.dart`.
   - **Perilaku:** Tab beranda saat ini berfungsi sebagai scaffold antarmuka shell. Tidak ada endpoint `/home` di backend karena data operasional utama difokuskan pada Stok & Katalog (`/listings`).
