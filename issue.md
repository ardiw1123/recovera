# Issue: Perbaikan Upload Foto Stok Produk & Pemisahan OCR Faktur

## Ringkasan Perubahan

Perlu memodifikasi alur **Upload Stok (Seller)** agar membedakan dua jenis foto:
1. **Foto Produk** — wajib, maksimal 1 foto, ukuran maksimal 2 MB, dikirim ke server database sebagai gambar produk
2. **Foto Faktur (OCR)** — wajib, untuk ekstraksi informasi oleh AI, **tidak dikirim ke database penyimpanan**

Fitur OCR faktur dipindahkan ke dalam **section/kartu "Informasi Produk"** (bukan lagi banner terpisah di bawah upload foto).

---

## Detail Perubahan

### 1. Halaman Upload Stok (Step 1: Produk) — `upload_stock_flow_screen.dart`

#### A. Upload Foto Produk (Wajib)
- Batas: **maksimal 1 foto**
- Ukuran file: **maksimal 2 MB**
- Validasi: tampilkan error jika melebihi 2 MB atau belum memilih foto
- Foto ini akan dikirim ke backend sebagai `image_url` produk
- Tampilan preview tetap ada (seperti sekarang), dengan tombol "Ganti Foto"

#### B. Foto Faktur untuk OCR (Opsional)
- Dipindahkan ke dalam **kartu "Informasi Produk"** (section yang sama dengan Nama Produk, Kategori, dll)
- UI: tombol "Pindai Faktur dengan AI" di dalam kartu informasi produk
- Saat dipilih: buka galeri, pilih foto faktur
- Foto faktur **hanya dipakai untuk proses OCR** (memanggil endpoint `/ai/invoice`)
- **JANGAN** simpan foto faktur ke `_imagePath` / `_imageUrl` produk
- **JANGAN** kirim foto faktur ke server sebagai gambar produk
- Hasil OCR mengisi form otomatis (nama, brand, qty, harga, kategori, unit, expired date)

#### C. Perbaikan Validasi & Pesan
- Ubah teks "Format JPG atau PNG (Maks. 10MB)" → "Format JPG atau PNG (Maks. 2MB)"
- Validasi ukuran file sebelum upload (client-side)
- Error message yang jelas jika file > 2 MB

---

### 2. Halaman Detail Produk Buyer — `product_detail_screen.dart`
- Foto produk (dari `image_url`) sudah ditampilkan di Hero Image → **sudah benar, tidak perlu ubah**
- Pastikan data `image_url` dari seller benar-benar tersimpan & ditampilkan

---

### 3. Kartu Produk Buyer (Home) — `product_card.dart`
- Menampilkan thumbnail dari `image_url` → **sudah benar, tidak perlu ubah**

---

### 4. Halaman Inventaris & Detail Seller
- `seller_inventory_screen.dart`: thumbnail produk dari `image_url` → **sudah benar**
- `seller_product_detail_screen.dart`: preview foto produk dari `image_url` → **sudah benar**

---

### 5. Backend / Repository (Jika Perlu)
- `seller_api_service.dart`: method `uploadInvoiceForOcr` sudah ada → **gunakan yang ada, jangan buat baru**
- `seller_repository.dart`: method `uploadInvoiceForOcr` sudah ada → **gunakan yang ada**
- Payload `SellerDraftCreatePayload` sudah punya field `imageUrl` → **pakai untuk foto produk**

---

## Langkah Implementasi (Step-by-Step)

### Tahap 1: Refactor State & Variabel di `UploadStockFlowScreen`
1. Pisahkan state foto produk dan foto faktur:
   - `_productImageBytes`, `_productImagePath`, `_productImageUrl` → untuk foto produk (kirim ke server)
   - `_invoiceImageBytes`, `_invoiceImagePath` → untuk foto faktur (hanya OCR, jangan kirim ke server)
2. Hapus variabel `_imageBytes`, `_imagePath`, `_imageUrl` yang dipakai campur-campur
3. Update `_pickImageFromGallery` jadi dua method:
   - `_pickProductImage()` — validasi max 2MB, set state foto produk
   - `_pickInvoiceImage()` — tanpa validasi ukuran ketat, set state foto faktur, lalu panggil OCR

### Tahap 2: Update UI Step 1 (Produk)
1. **Section "Foto Produk"**: gunakan state foto produk baru, tampilkan preview & tombol ganti, validasi 2MB
2. **Hapus banner OCR lama** (`_buildOcrScanButton`) di luar kartu informasi produk
3. **Di dalam kartu "Informasi Produk"**: tambahkan baris/bagian "Ekstrak dari Faktur (OCR)" dengan tombol "Pindai Faktur"
4. Tombol "Pindai Faktur" memanggil `_pickInvoiceImage()` → pilih foto → panggil OCR → isi form

### Tahap 3: Logika OCR
1. Method `_scanInvoiceWithAi` dipakai ulang, tapi ambil file dari `_invoiceImagePath` / `_invoiceImageBytes`
2. Jangan set `_productImagePath` atau `_productImageUrl` dari hasil pick invoice
3. Setelah OCR sukses: isi controller form, tampilkan snackbar sukses

### Tahap 4: Validasi Submit Step 1
1. Pastikan validasi foto produk wajib & max 2MB
2. Kirim `_productImageUrl` / `_productImagePath` ke backend sebagai `image_url` di payload

### Tahap 5: Testing & Polish
1. Test upload foto produk 2MB → sukses
2. Test upload foto produk >2MB → error
3. Test OCR faktur → form terisi, foto produk tidak berubah
4. Test publish → buyer lihat foto produk di home & detail
5. Test edit draft existing → foto produk tetap, OCR bisa dipakai lagi

---

## Catatan Penting

- **JANGAN HAPUS KODE LAMA** sebelum yakin yang baru jalan — gunakan refactor bertahap
- **JANGAN BUAT FILE BARU** kalau cukup edit file existing
- Prioritaskan memperbaiki `upload_stock_flow_screen.dart` — file lain hanya verifikasi tampilannya
- Gunakan `ImagePicker` dengan `maxWidth: 1920, maxHeight: 1920, imageQuality: 85` (sudah ada), lalu cek ukuran bytes di client sebelum set state
- Endpoint OCR: `POST /ai/invoice` via `SellerApiService.uploadInvoiceForOcr` / `SellerRepository.uploadInvoiceForOcr`

---

## File yang Perlu Diubah (Estimasi)

| File | Perubahan |
|------|-----------|
| `lib/features/seller/screens/upload_stock_flow_screen.dart` | **Utama** — refactor state, UI, validasi, logika OCR |
| `lib/features/seller/screens/seller_inventory_screen.dart` | Verifikasi saja (tidak perlu ubah) |
| `lib/features/seller/screens/seller_product_detail_screen.dart` | Verifikasi saja (tidak perlu ubah) |
| `lib/features/home/screens/product_detail_screen.dart` | Verifikasi saja (tidak perlu ubah) |
| `lib/features/home/widgets/product_card.dart` | Verifikasi saja (tidak perlu ubah) |

---

## Definition of Done

- [x] Seller bisa upload **1 foto produk** max **2 MB**
- [x] Foto produk dikirim ke server & tampil di buyer (home & detail)
- [x] OCR faktur ada di dalam kartu "Informasi Produk"
- [x] Foto faktur **hanya** dipakai OCR, **tidak** terkirim ke database sebagai gambar produk
- [x] Validasi ukuran file di client-side (error jelas jika > 2MB)
- [x] Semua flow existing (edit draft, publish, validasi, harga, review) masih jalan normal
- [x] Tidak ada regression di halaman seller inventory, seller detail, buyer home, buyer detail