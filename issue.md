# 📋 Recovera — Rencana Implementasi Fitur & Perbaikan

> **Untuk**: Programmer junior / AI model yang lebih murah  
> **Prinsip utama**: Edit kode yang sudah ada terlebih dahulu. Buat file baru hanya jika belum ada.  
> **Tanggal**: 26 Oktober 2026

---

## Daftar Issue

| # | Issue | Prioritas | Estimasi |
|---|-------|-----------|----------|
| 1 | [Restrukturisasi Bottom Navigation Bar](#issue-1-restrukturisasi-bottom-navigation-bar) | 🔴 Tinggi | Sedang |
| 2 | [Redesign Beranda Seller](#issue-2-redesign-beranda-seller) | 🔴 Tinggi | Besar |
| 3 | [Halaman Notifikasi (Buyer & Seller)](#issue-3-halaman-notifikasi-buyer--seller) | 🟡 Sedang | Sedang |
| 4 | [Edit Informasi Bisnis di Profil](#issue-4-edit-informasi-bisnis-di-profil) | 🟡 Sedang | Kecil |
| 5 | [Perbaikan Overflow & Gambar Produk](#issue-5-perbaikan-overflow--gambar-produk) | 🟡 Sedang | Kecil |
| 6 | [Banner Sinkronisasi Lokal — Hanya Tampil Saat Offline](#issue-6-banner-sinkronisasi-lokal--hanya-tampil-saat-offline) | 🟢 Rendah | Kecil |
| 7 | [Verifikasi Dampak ESG — Tampilkan Sertifikat Seller](#issue-7-verifikasi-dampak-esg--tampilkan-sertifikat-seller) | 🟡 Sedang | Sedang |
| 8 | [Push Notification System (FCM)](#issue-8-push-notification-system-fcm) | 🔴 Tinggi | Besar |

---

## Issue 1: Restrukturisasi Bottom Navigation Bar

### Konteks
File utama: [`main_shell.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/shell/main_shell.dart)

Saat ini:
- **Seller**: Beranda, Stok, (Tambah), Profil, Saran, Keluar
- **Buyer**: Home, Profil, Saran

Yang diinginkan:
- **Seller**: Beranda, Stok, Tambah, Game, Profil *(5 tab, full Bahasa Indonesia)*
- **Buyer**: Beranda, Riwayat, Game, Profil *(4 tab, full Bahasa Indonesia)*

### Langkah Implementasi

1. **Edit `_buildBuyerNavRow()` di `main_shell.dart`**
   - Ubah label `'Home'` → `'Beranda'`
   - Tambah tab **"Riwayat"** (ikon `Icons.receipt_long_outlined`) → arahkan ke `BuyerTransactionScreen`
   - Tambah tab **"Game"** (ikon `Icons.sports_esports_outlined`) → arahkan ke `SkyBalanceScreen` (sudah ada di [`lib/features/sky_balance/sky_balance_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/sky_balance/sky_balance_screen.dart))
   - Hapus tab **"Saran"**
   - Pastikan label semuanya Bahasa Indonesia

2. **Edit `_buildSellerNavRow()` di `main_shell.dart`**
   - Hapus tab **"Saran"** dan tombol **"Keluar"** dari navbar
   - Tambah tab **"Game"** (ikon `Icons.sports_esports_outlined`) di antara Tambah dan Profil
   - Pastikan urutan: Beranda → Stok → Tambah → Game → Profil

3. **Update daftar `pages` di `build()` method**
   - **Seller pages**: `[SellerDashboardScreen, SellerInventoryScreen, ProfileScreen]`
     - Tombol "Tambah" tetap push `UploadStockFlowScreen` (tanpa menambah ke IndexedStack)
     - Tambahkan `SkyBalanceScreen` ke IndexedStack
   - **Buyer pages**: `[HomeScreen, BuyerTransactionScreen, SkyBalanceScreen, ProfileScreen]`

4. **Sesuaikan `_currentIndex.clamp()`** dengan jumlah page baru

> [!IMPORTANT]
> Tab "Tambah" di seller bukan halaman di IndexedStack — ia tetap `Navigator.push` ke `UploadStockFlowScreen`. Jadi jumlah page seller = 4 (Beranda, Stok, Game, Profil), tapi nav item = 5.

---

## Issue 2: Redesign Beranda Seller

### Konteks
File utama: [`seller_dashboard_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/seller/screens/seller_dashboard_screen.dart)  
Model data: [`seller_dashboard_model.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/seller/models/seller_dashboard_model.dart)  
Referensi lengkap: [`rekomendasi_beranda_seller.md`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/rekomendasi_beranda_seller.md)

### 2A. Perluas Bento Cards dari 2 → 4

**Edit method `_buildBentoCards()` di `seller_dashboard_screen.dart`:**

- Ubah layout dari Row menjadi **Grid 2×2** (gunakan `Wrap` atau 2 Row)
- Card yang sudah ada:
  - ✅ Stok Aktif (`data.activeListingsCount`)
  - ✅ Transaksi Bulan Ini (`data.currentMonthOrdersCount`)
- Tambah 2 card baru:
  - **Stok Segera Expired**: hitung dari `data.nearExpiryListings.where((e) => e.daysRemaining <= 7).length`
  - **Sertifikat ESG**: gunakan `data.esgCertificateCount` — field ini sudah ada di model tapi belum ditampilkan

### 2B. Tambah Quick Actions Bar

**Tambah widget baru `_buildQuickActionsBar()` di `seller_dashboard_screen.dart`:**

Letakkan di antara Bento Cards dan Stok Mendekati Expired. Tampilkan 4 tombol shortcut horizontal:

| Tombol | Navigasi ke | File tujuan |
|--------|-------------|-------------|
| Upload Stok | `UploadStockFlowScreen` | Sudah ada |
| Inventaris | `SellerInventoryScreen` | Sudah ada |
| Sertifikat ESG | `EsgCertificateListScreen` | Sudah ada |
| Pesanan | `SellerOrderScreen` | Sudah ada |

Gunakan `Row` dengan 4 `Column` (ikon + label) dalam container bergaya chip/card ringan.

### 2C. Ganti "Aktivitas Terbaru" → "Pesanan Menunggu Tindakan"

**Edit atau replace method `_buildRecentActivitiesCard()` di `seller_dashboard_screen.dart`:**

- Ganti section Aktivitas Terbaru menjadi **Pesanan Menunggu Tindakan**
- Tampilkan daftar order yang statusnya `paid` atau `picked_up` (butuh aksi seller)
- Untuk data: panggil `OrderRepository.getOrders()` lalu filter status `paid` dan `picked_up`
- Tiap item tampilkan: nama produk, nama buyer, status saat ini, tombol aksi (Siapkan / Selesaikan)
- Import `OrderRepository` dan `TransactionOrder` model

> [!NOTE]
> Jika belum ada endpoint yang mengembalikan pending orders dalam dashboard, ambil data order secara terpisah menggunakan `OrderRepository` yang sudah ada.

### 2D. Tambah Ringkasan Dampak ESG

**Tambah method `_buildEsgImpactSummary()` di `seller_dashboard_screen.dart`** (atau edit `_buildEsgCertificateCard()` yang sudah ada):

- Tampilkan `data.totalCarbonSaved` (kg CO₂ yang diselamatkan)
- Tampilkan `data.esgCertificateCount` (jumlah sertifikat)
- Tombol **"Lihat Sertifikat"** → navigasi ke `EsgCertificateListScreen`
- Desain: card compact hijau dengan ikon daun dan angka besar

### 2E. Update urutan section di `_buildBody()`

Ubah urutan children di `SingleChildScrollView` → `Column` menjadi:

```
1. _buildHeader()
2. _buildBentoCards()        ← diperluas 4 card
3. _buildQuickActionsBar()   ← BARU
4. _buildNearExpiryCard()    ← pertahankan
5. _buildPendingOrdersCard() ← GANTI dari _buildRecentActivitiesCard
6. _buildEsgImpactSummary()  ← BARU / edit yang sudah ada
```

---

## Issue 3: Halaman Notifikasi (Buyer & Seller)

### Konteks
- Buyer: tombol notifikasi ada di [`home_screen.dart` L777-810](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/screens/home_screen.dart#L777-L810) — saat ini hanya tampil SnackBar "Belum ada notifikasi"
- Seller: tombol notifikasi ada di [`seller_dashboard_screen.dart` L278-292](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/seller/screens/seller_dashboard_screen.dart#L278-L292) — belum ada aksi onTap
- Backend sudah punya endpoint: `GET /notifications` dan `PATCH /notifications/{id}/read` — lihat [`notifications.py`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/backend/app/routers/notifications.py)

### Langkah Implementasi

1. **Buat `NotificationListScreen`** di `lib/features/home/screens/` (file baru — belum ada)
   - Tampilkan daftar notifikasi dari `GET /notifications`
   - Tiap item: judul, isi, waktu relatif, indikator sudah/belum dibaca
   - Klik notifikasi → tandai dibaca via `PATCH /notifications/{id}/read`
   - Pull-to-refresh

2. **Buat `NotificationRepository`** atau tambahkan method di `OrderRepository` (file baru jika perlu)
   - Method: `fetchNotifications()` → panggil API `/notifications`
   - Method: `markAsRead(int notificationId)` → panggil API `/notifications/{id}/read`

3. **Edit `home_screen.dart`**: Ubah `onTap` tombol notifikasi → `Navigator.push` ke `NotificationListScreen`

4. **Edit `seller_dashboard_screen.dart`**: Bungkus container notifikasi dengan `GestureDetector` → `Navigator.push` ke `NotificationListScreen`

5. **Tambah badge unread count** di ikon notifikasi (lingkaran merah kecil di pojok kanan atas ikon)

---

## Issue 4: Edit Informasi Bisnis di Profil

### Konteks
File: [`profile_screen.dart` L1242-1249](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/auth/screens/profile_screen.dart#L1242-L1249)  
Saat ini menu "Informasi Bisnis" punya `onTap: () {}` — tidak melakukan apa-apa.  
Backend sudah punya `PATCH /profile` yang bisa update field bisnis — lihat [`profile.py`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/backend/app/routers/profile.py)

### Langkah Implementasi

1. **Buat `BusinessInfoEditScreen`** di `lib/features/auth/screens/` (file baru)
   - Form yang menampilkan data bisnis yang sudah ada (pre-filled dari `AuthRepository.instance.currentUserProfile`)
   - **Seller**: company_name, address, city, warehouse_lat, warehouse_lng
   - **Buyer**: business_type, address, pref_categories, max_radius_km, has_cold_storage
   - Tombol "Simpan" → panggil `PATCH /profile` dengan field yang diubah
   - Setelah berhasil, refresh `AuthRepository.instance.currentUserProfile`

2. **Edit `profile_screen.dart`**: Ubah `onTap: () {}` pada menu "Informasi Bisnis" → `Navigator.push` ke `BusinessInfoEditScreen`

---

## Issue 5: Perbaikan Overflow & Gambar Produk

### Konteks Gambar
- Model `Listing` punya field `imageUrl` — lihat [`product_model.dart` L64](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/models/product_model.dart#L64)
- [`product_card.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/widgets/product_card.dart) sudah handle null imageUrl dengan `_iconFallback()`
- **Semua dummy data** punya `imageUrl: null` — lihat [`product_model.dart` L298-438](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/models/product_model.dart#L298-L438)
- Data dari API mengambil `image_url` dari tabel `products` — [`product_model.dart` L188](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/models/product_model.dart#L188)

### Diagnosa

Gambar tidak muncul karena:
1. **Dummy data tidak punya imageUrl** (semua `null`) → fallback icon muncul
2. **Data real dari API** → tergantung apakah `products.image_url` terisi di database. Perlu verifikasi apakah kolom `image_url` di tabel `products` terisi saat seller upload stok

### Langkah Perbaikan

1. **Periksa alur upload stok** di [`upload_stock_flow_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/seller/screens/upload_stock_flow_screen.dart):
   - Cek apakah foto produk yang diambil oleh seller dikirim dan disimpan ke `products.image_url`
   - Jika belum ada fitur upload foto → tambahkan field foto produk di flow upload
   - Pastikan foto diunggah ke storage (Supabase Storage / server) dan URL-nya disimpan ke kolom `image_url`

2. **Perbaikan overflow**: Audit halaman-halaman berikut dengan menjalankan aplikasi di berbagai ukuran layar:
   - `product_detail_screen.dart` — bungkus widget yang mungkin overflow dengan `Flexible`, `Expanded`, atau `SingleChildScrollView`
   - `seller_inventory_screen.dart` — periksa teks panjang yang terpotong
   - `buyer_transaction_screen.dart` — periksa card yang tidak muat
   - Gunakan `flutter run` dan perhatikan warning **"A RenderFlex overflowed"** di console

3. **Perbaikan praktis**: Di tempat yang sering overflow, pastikan:
   - Teks panjang selalu punya `overflow: TextOverflow.ellipsis` dan `maxLines`
   - Row/Column yang berisi widget dinamis dibungkus `Flexible` atau `Expanded`
   - Widget gambar punya ukuran tetap (`width`/`height`) atau constraint

---

## Issue 6: Banner Sinkronisasi Lokal — Hanya Tampil Saat Offline

### Konteks
File: [`buyer_transaction_screen.dart` L225-253](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/transactions/screens/buyer_transaction_screen.dart#L225-L253)  
Banner "Menampilkan data lokal (SQLite cached_orders) • Otomatis sinkron" selalu tampil.

### Langkah Implementasi

1. **Edit `buyer_transaction_screen.dart`**:
   - Import `NetworkConnectivityService` dari [`lib/core/services/network_connectivity_service.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/core/services/network_connectivity_service.dart)
   - Bungkus Container banner (L226-253) dengan kondisi:
     ```dart
     if (!NetworkConnectivityService.instance.isConnected) ...[
       // banner container
     ],
     ```
   - Listen ke perubahan koneksi: di `initState()` tambahkan `NetworkConnectivityService.instance.addListener(_onConnectivityChanged)`
   - Di `dispose()` remove listener
   - Method `_onConnectivityChanged()` → `setState((){})` agar rebuild UI

---

## Issue 7: Verifikasi Dampak ESG — Tampilkan Sertifikat Seller

### Konteks
Di [`product_detail_screen.dart` L2000-2131](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/screens/product_detail_screen.dart#L2000-L2131) ada section "Verifikasi Dampak ESG" dengan teks:
> *"Penyelamatan 150 kg pangan (-375 kg CO₂e). Sertifikat audit otomatis usai transaksi."*

### Penjelasan Konteks
- "Sertifikat audit otomatis usai transaksi" **bukan** berarti buyer mendapat sertifikat saat beli
- Sertifikat ESG diterbitkan **untuk seller** saat produk expired dialihkan ke donasi (Grade A/B/C) — bukan dari transaksi jual-beli
- Section ini seharusnya menampilkan **kredibilitas ESG seller** kepada buyer, sebagai trust signal

### Langkah Implementasi

1. **Edit section Verifikasi Dampak ESG di `product_detail_screen.dart`**:
   - Ubah teks statis menjadi data dinamis dari listing/seller
   - Tampilkan: "Seller ini memiliki X sertifikat ESG" (data bisa diambil dari API seller atau ditambahkan ke response listing)
   - Buat keseluruhan card **bisa diklik** (`GestureDetector` / `InkWell`)

2. **Saat diklik**, tampilkan `EsgCertificateListScreen` milik seller tersebut:
   - Screen [`esg_certificate_list_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/seller/screens/esg_certificate_list_screen.dart) sudah ada
   - Navigasi: `Navigator.push` → `EsgCertificateListScreen`
   - Saat ini screen tersebut fetch dari `SellerRepository.fetchMyCertificates()` — ini hanya fetch milik user yang login
   - Jika buyer yang melihat, perlu **endpoint baru** atau **modifikasi** agar bisa fetch sertifikat milik seller tertentu berdasarkan `seller_id`

3. **Backend** (jika perlu):
   - Tambah endpoint `GET /sellers/{seller_id}/certificates` di [`backend/app/routers/listings.py`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/backend/app/routers/listings.py) atau buat router baru
   - Atau tambahkan field `esg_certificate_count` ke response listing yang sudah ada

4. **Perbaiki teks deskripsi**:
   - Ganti "Sertifikat audit otomatis usai transaksi" → "Lihat riwayat sertifikat ESG penjual ini"
   - Tambahkan visual indicator bahwa card bisa diklik (ikon chevron / arrow)

---

## Issue 8: Push Notification System (FCM)

### Konteks
Backend sudah punya infrastruktur dasar:
- Endpoint registrasi device token: [`devices.py`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/backend/app/routers/devices.py) → `POST /devices` (simpan FCM token)
- Model `DeviceToken` dengan field `fcm_token` sudah ada
- Endpoint list notifikasi: [`notifications.py`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/backend/app/routers/notifications.py) → `GET /notifications`
- Tabel `notifications` sudah ada di backend

**Yang belum ada**: Firebase Cloud Messaging (FCM) belum terintegrasi di Flutter app dan belum ada logic pengiriman push di backend.

### Tahapan Implementasi

#### Tahap 1: Setup Firebase di Flutter App

1. **Buat project Firebase** di Firebase Console, daftarkan app Android dan iOS
2. **Tambah dependency** di `pubspec.yaml`:
   ```yaml
   firebase_core: ^latest
   firebase_messaging: ^latest
   flutter_local_notifications: ^latest
   ```
3. **Konfigurasi native**:
   - Android: letakkan `google-services.json` di `android/app/`, edit `build.gradle`
   - iOS: letakkan `GoogleService-Info.plist`, edit `AppDelegate.swift`
4. **Inisialisasi Firebase** di `main.dart`:
   - `await Firebase.initializeApp()`
   - Request permission notifikasi ke user (`FirebaseMessaging.instance.requestPermission()`)
   - Dapatkan FCM token dan kirim ke backend via `POST /devices`

#### Tahap 2: Service Layer Flutter

1. **Buat `PushNotificationService`** di `lib/core/services/`:
   - `init()`: request permission, get token, register ke backend
   - `onTokenRefresh()`: listen token refresh, update ke backend
   - `onForegroundMessage()`: tampilkan local notification saat app terbuka
   - `onBackgroundMessage()`: handler saat app tertutup (top-level function)
   - `onNotificationTap()`: handle navigasi saat user klik notifikasi → buka halaman yang relevan (misal: produk detail atau riwayat transaksi)
2. **Panggil `PushNotificationService.init()`** di `main.dart` setelah login berhasil
3. **Kirim FCM token** ke `POST /devices` setiap kali login atau token refresh

#### Tahap 3: Backend — Kirim Push Notification

1. **Tambah dependency** di `requirements.txt`: `firebase-admin`
2. **Buat `push_service.py`** di `backend/app/services/`:
   - Initialize Firebase Admin SDK dengan service account key
   - Method `send_push(user_id, title, body, data)`:
     - Query `DeviceToken` untuk user tersebut
     - Kirim FCM message ke semua device token user
     - Simpan notifikasi ke tabel `notifications`
3. **Tambah kolom `data` (JSON)** di tabel `notifications` untuk menyimpan payload navigasi (misal: `{"type": "product", "listing_id": 123}`)
4. **Tambah kolom `last_notification_sent_at`** di tabel yang relevan untuk rate limiting

#### Tahap 4: Trigger Notifikasi per Skenario

##### 4A. Seller Upload Stok → Notifikasi ke Top Buyer
- **Trigger**: Setelah proses upload listing berhasil (endpoint yang sudah ada)
- **Di backend**: Setelah listing disimpan, jalankan AI matching yang sudah ada untuk cari top buyer potensial, lalu panggil `send_push()` ke buyer tersebut
- **Payload**: `{"type": "new_listing", "listing_id": <id>}`
- **Di Flutter**: Saat notifikasi diklik → buka `ProductDetailScreen` dengan `listingId` dari payload

##### 4B. Buyer Beli Produk → Notifikasi ke Seller
- **Trigger**: Setelah order berhasil dibuat (endpoint `POST /orders`)
- **Di backend**: Panggil `send_push()` ke seller pemilik listing
- **Judul**: "Pesanan Baru Masuk!"
- **Payload**: `{"type": "new_order", "order_id": <id>}`
- **Di Flutter**: Saat notifikasi diklik → buka `SellerOrderScreen`

##### 4C. Buyer Klik "Hubungi Seller" → Notifikasi ke Seller
- **File Flutter**: [`buyer_transaction_screen.dart` L617](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/transactions/screens/buyer_transaction_screen.dart#L617)
- **Saat ini**: hanya tampil SnackBar, tidak kirim apa-apa
- **Perubahan**:
  - Panggil endpoint baru `POST /orders/{id}/remind-seller` di backend
  - Backend: cek `last_notification_sent_at`, jika < 3 jam lalu → tolak dengan pesan "Sudah dikirim, tunggu 3 jam"
  - Jika lolos → `send_push()` ke seller: "Pembeli menunggu pesanan Anda"
  - Update `last_notification_sent_at`
- **Rate limit**: **3 jam sekali per order**

##### 4D. Seller Klik "Produk Siap" → Notifikasi ke Buyer
- **File Flutter**: [`seller_order_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/transactions/screens/seller_order_screen.dart) — tombol update status
- **Perubahan**:
  - Saat seller ubah status dari `paid` → `picked_up` (artinya produk sudah disiapkan)
  - Endpoint yang sudah ada (`PATCH /orders/{id}/status`) tambahkan logic: `send_push()` ke buyer
  - Judul: "Pesanan Anda Sudah Siap Diambil!"
  - **Rate limit**: **3 jam sekali per order** (cek `last_notification_sent_at`)
  - Payload: `{"type": "order_ready", "order_id": <id>}`

#### Tahap 5: Navigasi dari Notifikasi

1. **Edit `PushNotificationService.onNotificationTap()`**:
   - Parse `data` dari notifikasi
   - Berdasarkan `type`:
     - `new_listing` → `Navigator.push(ProductDetailScreen(listingId: ...))`
     - `new_order` → `Navigator.push(SellerOrderScreen())`
     - `order_ready` → `Navigator.push(BuyerTransactionScreen())`
     - `reminder` → `Navigator.push(SellerOrderScreen())`
2. **Gunakan `AppNavigator.navigatorKey`** yang sudah ada untuk navigasi dari luar widget tree

---

## Ringkasan File yang Perlu Diedit vs Dibuat Baru

### File yang DIEDIT (prioritas — kode sudah ada):

| File | Issue |
|------|-------|
| [`main_shell.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/shell/main_shell.dart) | #1 |
| [`seller_dashboard_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/seller/screens/seller_dashboard_screen.dart) | #2, #3 |
| [`home_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/screens/home_screen.dart) | #3 |
| [`profile_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/auth/screens/profile_screen.dart) | #4 |
| [`product_detail_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/home/screens/product_detail_screen.dart) | #7 |
| [`buyer_transaction_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/transactions/screens/buyer_transaction_screen.dart) | #6, #8 |
| [`seller_order_screen.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/features/transactions/screens/seller_order_screen.dart) | #8 |
| [`main.dart`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/lib/main.dart) | #8 |
| `pubspec.yaml` | #8 |
| [`backend/app/routers/orders.py`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/backend/app/routers/orders.py) | #8 |
| [`backend/app/routers/listings.py`](file:///d:/Documents/MOBILE/TEORI/TA/recovera/recovera/backend/app/routers/listings.py) | #7, #8 |

### File yang DIBUAT BARU (hanya jika belum ada):

| File Baru | Issue | Alasan |
|-----------|-------|--------|
| `lib/features/home/screens/notification_list_screen.dart` | #3 | Belum ada halaman daftar notifikasi |
| `lib/data/repositories/notification_repository.dart` | #3 | Belum ada repository untuk fetch notifikasi |
| `lib/features/auth/screens/business_info_edit_screen.dart` | #4 | Belum ada form edit informasi bisnis |
| `lib/core/services/push_notification_service.dart` | #8 | Belum ada service FCM di Flutter |
| `backend/app/services/push_service.py` | #8 | Belum ada service kirim push di backend |

---

## Urutan Implementasi yang Disarankan

```
1. Issue 1 (Bottom Nav)        ← fondasi navigasi, kerjakan pertama
2. Issue 6 (Banner Offline)    ← perbaikan kecil, cepat selesai
3. Issue 5 (Overflow & Gambar) ← perbaikan kecil, cepat selesai  
4. Issue 4 (Edit Bisnis)       ← fitur baru tapi kecil
5. Issue 2 (Redesign Beranda)  ← perubahan besar tapi visual saja
6. Issue 3 (Halaman Notifikasi)← perlu sebelum push notification
7. Issue 7 (ESG Certificate)   ← tergantung data seller
8. Issue 8 (Push Notification) ← paling kompleks, kerjakan terakhir
```
