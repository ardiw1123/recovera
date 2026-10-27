# Rekomendasi Redesign Beranda Seller

## Analisis Kondisi Saat Ini

Halaman beranda seller ([seller_dashboard_screen.dart](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/lib/features/seller/screens/seller_dashboard_screen.dart)) saat ini menampilkan 4 bagian:

| # | Section | Verdict |
|---|---------|---------|
| 1 | Header (sapaan + logo) | ✅ Pertahankan |
| 2 | Bento Cards (Stok Aktif + Transaksi Bulan Ini) | ✅ Pertahankan, tapi tambah 1–2 card lagi |
| 3 | Stok Mendekati Expired | ✅ Pertahankan — paling kritis untuk seller |
| 4 | **Aktivitas Terbaru** | ❌ **Hapus** — generic log tanpa aksi, tidak membantu keputusan |

> [!IMPORTANT]
> Bagian "Aktivitas Terbaru" hanya menampilkan event log (`sold`, `uploaded`, `expired`) tanpa konteks aksi. Seller tidak bisa melakukan apa-apa dari situ. Ruang layar lebih baik dipakai untuk data yang mendorong tindakan segera.

---

## Rekomendasi: 6 Section Beranda Seller

Berdasarkan [PRD](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/docs/recovera-prd-full-platform.md), [Product Backlog](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/docs/recovera-product-backlog-sprint-plan.md), dan [Database Schema](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/docs/recovera-database-schema.md):

### 1. Header Sapaan *(pertahankan, perbaiki)*

Sama seperti sekarang — sapaan `Halo, {company_name}` + subtitle motivasi + ikon notifikasi.

**Perbaikan:** Tambahkan tanggal hari ini dan indikator koneksi online/offline.

---

### 2. Bento Summary Cards *(perluas menjadi 4 card)*

Saat ini hanya 2 card. Tambahkan **2 card** yang relevan sesuai data dari tabel `listings`, `orders`, dan `donations`:

| Card | Angka | Sumber Data | Alasan (PRD) |
|------|-------|-------------|--------------|
| **Stok Aktif** | Count listing `status=active` | `listings` | ✅ Sudah ada |
| **Transaksi Bulan Ini** | Count orders bulan berjalan | `orders` | ✅ Sudah ada |
| **⚡ Stok Segera Expired** | Count listing sisa ≤7 hari | `listings.expiry_date` | US-06/US-08: seller harus tahu berapa listing yang mendekati batas auto-diversion 14 hari |
| **🌱 Sertifikat ESG** | Count donasi/sertifikat | `donations` | US-08: bukti ESG adalah value proposition utama Recovera — data `esgCertificateCount` sudah ada di [model](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/lib/features/seller/models/seller_dashboard_model.dart#L12-L13) tapi **belum ditampilkan** |

Layout: **grid 2×2** agar ringkas.

---

### 3. Stok Mendekati Expired *(pertahankan, perkuat)*

Sudah ada dan sangat relevan. **Perkuat** dengan:

- Tambahkan **tombol aksi per item** → "Turunkan Harga" / "Lihat Detail" agar langsung actionable
- Tambahkan label **auto-diversion countdown**: "Otomatis didonasikan dalam X hari" untuk listing ≤14 hari (sesuai US-08: grade A/B/C)
- Sort by `daysRemaining` ascending (paling mendesak di atas)

---

### 4. 🆕 Pesanan Menunggu Tindakan *(ganti "Aktivitas Terbaru")*

**Ini pengganti utama section "Aktivitas Terbaru".**

Tampilkan daftar `orders` dengan status yang **butuh aksi seller** (`paid` → seller perlu tandai `picked_up`, atau `picked_up` → tandai `completed`).

| Kolom | Sumber |
|-------|--------|
| Nama produk | `orders` → `listings` → `products.name` |
| Nama buyer | `orders` → `buyers` via `users.name` |
| Status saat ini | `orders.status` |
| Tombol aksi | `PATCH /orders/{id}/status` |

**Kenapa lebih baik dari Aktivitas Terbaru:**
- Aktivitas Terbaru = read-only log (**pasif**)
- Pesanan Menunggu = task list yang harus ditindak (**aktif**)
- Sesuai PBI-19 dan US-06: seller perlu memantau dan mengubah status order

---

### 5. 🆕 Ringkasan Dampak ESG *(section baru)*

Recovera punya value proposition ESG yang kuat (US-08, US-09). Data sudah ada di model tapi belum ditampilkan:
- `esgCertificateCount` dan `totalCarbonSaved` sudah ada di [`SellerDashboardData`](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/lib/features/seller/models/seller_dashboard_model.dart#L12-L13)

**Tampilkan:**
- Total kg CO₂ terselamatkan (`totalCarbonSaved`)
- Total sertifikat ESG diterbitkan (`esgCertificateCount`)
- Tombol "Lihat Sertifikat" → navigasi ke [esg_certificate_list_screen.dart](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/lib/features/seller/screens/esg_certificate_list_screen.dart)
- Konversi nilai pangan terselamatkan ke USD/EUR/GBP (US-09)

Bisa berupa **card compact** dengan ikon daun + angka besar.

---

### 6. 🆕 Quick Actions Bar *(shortcut section)*

Baris tombol shortcut di bawah bento cards agar seller tidak perlu navigasi ke tab lain:

| Aksi | Navigasi | Relevansi PRD |
|------|----------|---------------|
| ➕ Upload Stok | `UploadStockFlowScreen` | US-03: upload listing + OCR faktur |
| 📦 Inventaris | `SellerInventoryScreen` | US-03: manage stok |
| 📜 Sertifikat ESG | `EsgCertificateListScreen` | US-08: lihat bukti ESG |
| 📋 Pesanan | `SellerOrderScreen` | PBI-19: riwayat order |

Ini menggantikan ketergantungan pada FAB "Upload Stok" saja, dan mempercepat akses ke fitur yang sering dipakai.

---

## Ringkasan Perubahan

```diff
  Beranda Seller:
  ─────────────────
  [Header Sapaan]                          ← pertahankan
- [Bento: 2 cards]                         ← perluas
+ [Bento: 4 cards — grid 2×2]             ← + Stok Segera Expired + Sertifikat ESG
+ [Quick Actions Bar]                      ← BARU: 4 shortcut tombol
  [Stok Mendekati Expired]                 ← pertahankan + tambah tombol aksi
- [Aktivitas Terbaru]                      ← HAPUS (useless log)
+ [Pesanan Menunggu Tindakan]              ← GANTI: task list aktif
+ [Ringkasan Dampak ESG]                   ← BARU: CO₂ + sertifikat
```

## Data yang Sudah Tersedia vs Perlu Ditambah

| Section | Data di Model/API | Perlu Tambah? |
|---------|-------------------|---------------|
| Bento: Stok Segera Expired | Bisa dihitung dari `nearExpiryListings` | Tidak |
| Bento: Sertifikat ESG | `esgCertificateCount` sudah di model | Tidak |
| Pesanan Menunggu | Perlu query `GET /orders` filter `status=paid` | ✅ Perlu tambah field `pendingOrders` ke dashboard endpoint **atau** panggil `GET /orders` terpisah |
| Ringkasan ESG | `totalCarbonSaved` sudah di model | Tidak |
| Quick Actions | Navigasi saja, tanpa data | Tidak |

> [!TIP]
> Sebagian besar data sudah tersedia di [`SellerDashboardData`](file:///d:/UPN%20VY/Semester%205/Mobile/Tugas/Project%20Akhir/recovera/lib/features/seller/models/seller_dashboard_model.dart) — hanya belum ditampilkan. Implementasi bisa dimulai tanpa mengubah backend sama sekali (kecuali untuk section Pesanan Menunggu).
