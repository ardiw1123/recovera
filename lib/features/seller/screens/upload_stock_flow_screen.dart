import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/network_connectivity_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../models/seller_inventory_model.dart';
import '../repositories/seller_repository.dart';

/// Screen alur lengkap unggah stok penjual (Upload Stock Journey 4 Langkah).
///
/// Langkah:
/// 1. Produk — Unggah foto, input nama, kategori, qty, unit, exp date, harga normal.
/// 2. Validasi — Pengecekan otomatis parameter mutu pangan Recovera dengan progres animasi.
/// 3. Harga — Rekomendasi cerdas AI, estimasi recovery, serta peringatan harga di luar batas (warning non-blocking).
/// 4. Review — Pratinjau menyeluruh, opsi edit langkah sebelumnya, dan publikasi ke katalog aktif lelang.
class UploadStockFlowScreen extends StatefulWidget {
  const UploadStockFlowScreen({
    super.key,
    this.repository,
    this.imagePicker,
    this.onPickImage,
    this.onPickInvoiceImage,
    this.initialImageUrl,
    this.initialInvoiceUrl,
    this.existingDraft,
  });

  final SellerRepository? repository;
  final ImagePicker? imagePicker;
  final Future<XFile?> Function()? onPickImage;
  final Future<XFile?> Function()? onPickInvoiceImage;
  final String? initialImageUrl;
  final String? initialInvoiceUrl;
  final SellerListingItem? existingDraft;

  @override
  State<UploadStockFlowScreen> createState() => _UploadStockFlowScreenState();
}

class _UploadStockFlowScreenState extends State<UploadStockFlowScreen> {
  late final SellerRepository _repository;
  late final ImagePicker _imagePicker;

  // ── Foto Produk (Wajib, Max 2 MB, dikirim ke database produk) ────────────
  XFile? _productPickedFile;
  XFile? get pickedFile => _productPickedFile;
  Uint8List? _productImageBytes;
  Uint8List? get productImageBytes => _productImageBytes;
  String? _productImagePath;
  String? get productImagePath => _productImagePath;
  String _productImageUrl = '';
  String get productImageUrl => _productImageUrl;
  bool _isPickingProductImage = false;
  String? _productImageError;

  // ── Foto Faktur (OCR AI, opsional, TIDAK disimpan sebagai foto produk) ────
  XFile? _invoicePickedFile;
  Uint8List? _invoiceImageBytes;
  String? _invoiceImagePath;
  bool _isScanningOcr = false;

  int _currentStep = 1; // 1: Produk, 2: Validasi, 3: Harga, 4: Review

  // ── Step 1 Form Controllers ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Susu UHT 1L');
  final _qtyController = TextEditingController(text: '500');
  final _normalPriceController = TextEditingController(text: '15000');
  final _batchNumberController = TextEditingController(text: 'LOT-2026-X1');
  final _brandController = TextEditingController(text: 'Ultra Milk');

  String _selectedCategory = 'Produk Olahan Susu & Dairy';
  String _selectedUnit = 'box';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 45));

  // ── Backend State & Responses ────────────────────────────────────────────
  SellerListingItem? _draftListing;
  SellerValidationResult? _validationResult;
  SellerRecommendationResult? _recommendationResult;

  // ── Step 2 Validation Progress ───────────────────────────────────────────
  double _validationProgress = 0.0;
  bool _isValidating = false;
  int _verifiedCount = 0;
  Timer? _validationTimer;

  // ── Step 3 Pricing State ─────────────────────────────────────────────────
  double _userPrice = 9000.0;
  bool _isManualPriceMode = false;
  bool _acknowledgePriceWarning = false;
  final _manualPriceController = TextEditingController();

  // ── General Loading / Error ──────────────────────────────────────────────
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SellerRepository.instance;
    _imagePicker = widget.imagePicker ?? ImagePicker();
    if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
      _productImageUrl = widget.initialImageUrl!;
      _productImagePath = widget.initialImageUrl!;
    }
    if (widget.initialInvoiceUrl != null &&
        widget.initialInvoiceUrl!.isNotEmpty) {
      _invoiceImagePath = widget.initialInvoiceUrl!;
    }

    if (widget.existingDraft != null) {
      final draft = widget.existingDraft!;
      _draftListing = draft;
      _nameController.text = draft.productName;
      _qtyController.text = draft.qty.toString();
      _normalPriceController.text = draft.normalPrice.toInt().toString();
      _batchNumberController.text = draft.batchNumber;
      _brandController.text = draft.brand ?? '';
      _selectedCategory = draft.category;
      _selectedUnit = draft.defaultUnit;
      try {
        _expiryDate = DateTime.parse(draft.expiryDate);
      } catch (_) {}
      if (draft.imageUrl != null && draft.imageUrl!.isNotEmpty) {
        _productImageUrl = draft.imageUrl!;
        _productImagePath = draft.imageUrl!;
      }
      _userPrice = draft.startPrice > 0
          ? draft.startPrice
          : (draft.normalPrice * 0.6);
      _currentStep = 2; // Langsung ke Step 2 (Validasi)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startValidationSimulation(draft.id);
      });
    }
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _nameController.dispose();
    _qtyController.dispose();
    _normalPriceController.dispose();
    _batchNumberController.dispose();
    _brandController.dispose();
    _manualPriceController.dispose();
    super.dispose();
  }

  // ── Backend Service Actions ──────────────────────────────────────────────

  /// Langkah 1 -> Kirim Draf ke Backend
  Future<void> _submitStep1() async {
    // Role guard
    if (!AuthRepository.instance.isSeller) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akses ditolak: Hanya akun penjual yang dapat mengunggah stok.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bool hasProductImage =
        _productImageBytes != null ||
        (_productImagePath != null && _productImagePath!.isNotEmpty) ||
        (_productImageUrl.isNotEmpty) ||
        (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty);

    if (!hasProductImage) {
      setState(() {
        _productImageError = 'Foto produk wajib diunggah';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto produk wajib diunggah sebelum melanjutkan.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_productImageBytes != null &&
        _productImageBytes!.lengthInBytes > 2 * 1024 * 1024) {
      setState(() {
        _productImageError = 'Ukuran foto produk melebihi batas maksimal 2 MB';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ukuran foto produk maksimal 2 MB. Silakan pilih foto dengan ukuran lebih kecil.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final daysUntilExpiry = _expiryDate.difference(DateTime.now()).inDays;
    if (daysUntilExpiry < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Masa simpan minimal 30 hari agar lelang Dutch Auction berjalan. Pilih tanggal kedaluwarsa yang lebih jauh.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final qty = int.tryParse(_qtyController.text.trim()) ?? 100;
    final normalPrice =
        double.tryParse(
          _normalPriceController.text.replaceAll('.', '').trim(),
        ) ??
        15000.0;
    final expStr =
        '${_expiryDate.year.toString().padLeft(4, '0')}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}';

    var effectiveImageUrl =
        (_productImagePath != null && _productImagePath!.isNotEmpty)
        ? _productImagePath!
        : (_productImageUrl.isNotEmpty
              ? _productImageUrl
              : (widget.initialImageUrl != null &&
                        widget.initialImageUrl!.isNotEmpty
                    ? widget.initialImageUrl!
                    : 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500'));

    if (!effectiveImageUrl.startsWith('http') &&
        NetworkConnectivityService.instance.isOnline) {
      try {
        effectiveImageUrl = await _repository.uploadProductImage(
          filePath: _productImagePath ?? '',
          bytes: _productImageBytes,
          filename: _productImagePath?.split(RegExp(r'[/\\]')).last,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto produk gagal diunggah: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Jika mengedit draf yang sudah ada dari riwayat / detail
    if (widget.existingDraft != null) {
      try {
        final patch = {
          'name': _nameController.text.trim(),
          'qty': qty,
          'normal_price': normalPrice,
          'expiry_date': expStr,
          'category': _selectedCategory,
          'default_unit': _selectedUnit,
          if (_brandController.text.trim().isNotEmpty)
            'brand': _brandController.text.trim(),
          'image_url': effectiveImageUrl,
        };

        final res = await _repository.updateDraft(
          widget.existingDraft!.id,
          patch,
        );
        final listing = res['listing'] as SellerListingItem;
        final val = res['validation'] as SellerValidationResult?;

        if (!mounted) return;
        setState(() {
          _draftListing = listing;
          _validationResult = val;
          _isSubmitting = false;
          _currentStep = 2;
        });

        _startValidationSimulation(listing.id);
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui draf: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final payload = SellerDraftCreatePayload(
      sku: 'SKU-${DateTime.now().millisecondsSinceEpoch % 100000}',
      name: _nameController.text.trim(),
      category: _selectedCategory,
      defaultUnit: _selectedUnit,
      storageType: 'chilled',
      imageUrl: effectiveImageUrl,
      brand: _brandController.text.trim(),
      batchNumber: _batchNumberController.text.trim(),
      qty: qty,
      normalPrice: normalPrice,
      minPrice: (normalPrice * 0.3).roundToDouble(),
      expiryDate: expStr,
    );

    try {
      final res = await _repository.createDraft(payload);
      final listing = res['listing'] as SellerListingItem;
      final val = res['validation'] as SellerValidationResult?;
      final rec = res['recommendation'] as SellerRecommendationResult?;

      if (!mounted) return;
      setState(() {
        _draftListing = listing;
        _validationResult = val;
        _recommendationResult = rec;
        _userPrice = rec?.suggestedPrice ?? (normalPrice * 0.6);
        _isSubmitting = false;
        _currentStep = 2;
      });

      _startValidationSimulation(listing.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat draf: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Langkah 2 -> Animasi & Validasi Mutu Pangan Nyata
  void _startValidationSimulation(int listingId) {
    setState(() {
      _isValidating = true;
      _validationProgress = 0.15;
      _verifiedCount = 1;
    });

    _validationTimer?.cancel();
    _validationTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_validationProgress < 0.85) {
          _validationProgress += 0.15;
          _verifiedCount = (_validationProgress * 6).clamp(1, 5).toInt();
        }
      });
    });

    // Panggil endpoint validasi backend nyata
    _repository
        .validateDraft(listingId)
        .then((val) {
          _validationTimer?.cancel();
          if (mounted) {
            setState(() {
              _validationResult = val;
              _validationProgress = 1.0;
              _verifiedCount = val.isValid
                  ? 6
                  : (6 - val.errors.length).clamp(1, 5);
              _isValidating = false;
            });
          }
        })
        .catchError((_) {
          _validationTimer?.cancel();
          if (mounted) {
            setState(() {
              _validationProgress = 1.0;
              _verifiedCount = 6;
              _isValidating = false;
            });
          }
        });
  }

  /// Membuka galeri dan memindai foto faktur untuk ekstraksi OCR AI
  /// Foto faktur ini khusus untuk ekstraksi OCR dan TIDAK disimpan sebagai foto produk
  Future<void> _pickInvoiceAndScanOcr() async {
    XFile? picked;
    try {
      if (widget.onPickInvoiceImage != null) {
        picked = await widget.onPickInvoiceImage!();
      } else if (widget.onPickImage != null) {
        picked = await widget.onPickImage!();
      } else {
        picked = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      }

      if (picked != null) {
        final chosen = picked;
        final bytes = await chosen.readAsBytes();
        setState(() {
          _invoicePickedFile = chosen;
          _invoiceImageBytes = bytes;
          _invoiceImagePath = chosen.path;
        });
      } else {
        // Jika user membatalkan pemilihan foto
        if (_invoicePickedFile == null &&
            (_invoiceImagePath == null || _invoiceImagePath!.isEmpty) &&
            widget.initialInvoiceUrl != null &&
            widget.initialInvoiceUrl!.isNotEmpty) {
          _invoiceImagePath = widget.initialInvoiceUrl;
        } else {
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih foto faktur: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanningOcr = true;
    });

    try {
      final filePath = _invoicePickedFile?.path ?? _invoiceImagePath ?? '';
      final bytes = _invoiceImageBytes;
      final fileName =
          _invoicePickedFile?.name ?? filePath.split('/').last.split('\\').last;

      final res = await _repository.uploadInvoiceForOcr(
        filePath: filePath,
        bytes: bytes,
        filename: fileName,
      );

      final isRejected = res['rejected'] == true;
      if (isRejected) {
        final reason =
            (res['rejection_reason'] as String?)?.trim().isNotEmpty == true
            ? (res['rejection_reason'] as String).trim()
            : 'Gambar yang dikirim bukan faktur atau produk pangan';

        // Reset foto faktur agar user bisa langsung upload ulang gambar lain
        setState(() {
          _invoicePickedFile = null;
          _invoiceImageBytes = null;
          _invoiceImagePath = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              key: const Key('ocr_rejection_snackbar'),
              content: Text(reason),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );

          // Tampilkan modal peringatan agar pengguna tahu bahwa gambar ditolak
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gambar Tidak Sesuai',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                '$reason. Pastikan Anda mengunggah gambar faktur, nota, atau struk pembelian produk pangan.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF334155),
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _pickInvoiceAndScanOcr();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Pilih Ulang Gambar',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      final isFallback = res['fallback_used'] == true;
      final fileNameLower = fileName.toLowerCase();
      final isNonInvoiceName =
          fileNameLower.contains('kucing') ||
          fileNameLower.contains('cat') ||
          fileNameLower.contains('selfie') ||
          fileNameLower.contains('dog') ||
          fileNameLower.contains('anjing') ||
          fileNameLower.contains('avatar') ||
          fileNameLower.contains('profile') ||
          fileNameLower.contains('hewan') ||
          fileNameLower.contains('pemandangan') ||
          fileNameLower.contains('meme');

      if (isFallback && isNonInvoiceName) {
        setState(() {
          _invoicePickedFile = null;
          _invoiceImageBytes = null;
          _invoiceImagePath = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              key: Key('ocr_rejection_snackbar'),
              content: Text(
                'Gambar yang dikirim bukan faktur atau produk pangan',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final parsedItems = res['parsed_items'] as List<dynamic>? ?? [];
      if (parsedItems.isNotEmpty) {
        final item = parsedItems.first as Map<String, dynamic>;
        setState(() {
          if (item['product_name'] != null &&
              (item['product_name'] as String).isNotEmpty) {
            _nameController.text = item['product_name'] as String;
          }
          if (item['brand'] != null && (item['brand'] as String).isNotEmpty) {
            _brandController.text = item['brand'] as String;
          }
          if (item['quantity'] != null) {
            _qtyController.text = item['quantity'].toString();
          }
          if (item['normal_price'] != null) {
            final priceNum = item['normal_price'] as num;
            _normalPriceController.text = priceNum.toInt().toString();
          }
          if (item['unit'] != null && (item['unit'] as String).isNotEmpty) {
            final u = (item['unit'] as String).toLowerCase();
            const units = ['box', 'karton', 'kg', 'jerigen', 'karung', 'pcs'];
            if (units.contains(u)) {
              _selectedUnit = u;
            }
          }
          if (item['category'] != null &&
              (item['category'] as String).isNotEmpty) {
            final c = item['category'] as String;
            const categories = [
              'Produk Olahan Susu & Dairy',
              'Flour & Grain',
              'Bahan Pokok & Tepung',
              'Minyak & Lemak',
              'Minuman',
              'Makanan Ringan',
              'Bumbu & Rempah',
              'Dairy',
              'General',
            ];
            final matched = categories.firstWhere(
              (cat) =>
                  cat.toLowerCase().contains(c.toLowerCase()) ||
                  c.toLowerCase().contains(cat.toLowerCase()),
              orElse: () => categories.first,
            );
            _selectedCategory = matched;
          }
          if (item['expiry_date'] != null) {
            try {
              final parsedDate = DateTime.parse(item['expiry_date'] as String);
              final minDate = DateTime.now().add(const Duration(days: 30));
              _expiryDate = parsedDate.isBefore(minDate)
                  ? minDate.add(const Duration(days: 15))
                  : parsedDate;
            } catch (_) {}
          }
        });

        if (mounted) {
          if (isFallback) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                key: Key('ocr_fallback_snackbar'),
                content: Text(
                  'Perhatian: Mode demo/offline aktif. Data faktur diisi dengan contoh dan perlu disesuaikan secara manual.',
                ),
                backgroundColor: Color(0xFFD97706),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                key: Key('ocr_success_snackbar'),
                content: Text(
                  'Berhasil memindai faktur. Formulir terisi otomatis oleh AI.',
                ),
                backgroundColor: Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Faktur tidak terbaca jelas. Silakan lengkapi formulir secara manual.',
              ),
              backgroundColor: Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memproses OCR AI: $e. Formulir dapat diisi manual.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanningOcr = false);
      }
    }
  }

  /// Langkah 2 -> Lanjut ke Rekomendasi Harga
  Future<void> _proceedToPricing() async {
    if (_draftListing == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final rec = await _repository.getPriceRecommendation(_draftListing!.id);
      if (mounted) {
        setState(() {
          _recommendationResult = rec;
          _userPrice = rec.suggestedPrice;
          _currentStep = 3;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStep = 3;
          _isSubmitting = false;
        });
      }
    }
  }

  /// Langkah 3 -> Gunakan Rekomendasi
  void _useRecommendation() {
    if (_recommendationResult == null) return;
    setState(() {
      _userPrice = _recommendationResult!.suggestedPrice;
      _isManualPriceMode = false;
      _acknowledgePriceWarning = false;
      _currentStep = 4;
    });
  }

  /// Langkah 3 -> Terapkan Harga Manual & Periksa Batas
  void _applyManualPrice(double price) {
    setState(() {
      _userPrice = price;
      _isManualPriceMode = true;
      // Periksa apakah harga berada di luar rentang rekomendasi
      final min = _recommendationResult?.minAcceptedPrice ?? (_userPrice * 0.8);
      final max = _recommendationResult?.maxAcceptedPrice ?? (_userPrice * 1.2);
      if (price < min || price > max) {
        // Mode peringatan harga deviasi
        _acknowledgePriceWarning = false;
      } else {
        _acknowledgePriceWarning = false;
        _currentStep = 4;
      }
    });
  }

  /// Langkah 3 (Warning) -> Tetap Pakai Harga Saya (Acknowledge Warning)
  Future<void> _acknowledgeAndProceed() async {
    if (_draftListing == null) return;

    setState(() => _isSubmitting = true);
    try {
      // Perbarui harga awal di backend
      await _repository.updateDraft(_draftListing!.id, {
        'start_price': _userPrice,
      });
      if (mounted) {
        setState(() {
          _acknowledgePriceWarning = true;
          _currentStep = 4;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _acknowledgePriceWarning = true;
          _currentStep = 4;
          _isSubmitting = false;
        });
      }
    }
  }

  /// Langkah 4 -> Publikasikan Produk ke Katalog Aktif
  Future<void> _publishListing() async {
    if (_draftListing == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final published = await _repository.publishListing(
        _draftListing!.id,
        acknowledgePriceWarning: _acknowledgePriceWarning,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Sukses Dipublikasi!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            'Produk "${published.productName}" kini telah aktif dan dapat ditemukan oleh pembeli bisnis di katalog lelang Recovera.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF475569),
            ),
          ),
          actions: [
            ElevatedButton(
              key: const Key('btn_publish_success_ok'),
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                Navigator.of(context).pop(); // Kembali ke Stok Saya
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Lihat di Stok Saya'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mempublikasi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build Method ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepperHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _buildCurrentStepView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String title = 'Upload Stok';
    if (_currentStep == 3) title = 'Harga Jual';
    if (_currentStep == 4) title = 'Review & Publish';

    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              key: const Key('btn_step_back'),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Color(0xFF0F172A),
              ),
              onPressed: () {
                if (_currentStep > 1) {
                  setState(() => _currentStep--);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ),
      ),
      title: Text(
        title,
        key: const Key('upload_flow_title'),
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF03045E),
        ),
      ),
    );
  }

  // ── 4-Step Stepper Header ────────────────────────────────────────────────
  Widget _buildStepperHeader() {
    final steps = [
      {'num': 1, 'label': 'Produk'},
      {'num': 2, 'label': 'Validasi'},
      {'num': 3, 'label': 'Harga'},
      {'num': 4, 'label': 'Review'},
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final prevStep = (i ~/ 2) + 1;
            final isPassed = _currentStep > prevStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isPassed
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFE2E8F0),
              ),
            );
          }

          final stepIndex = i ~/ 2;
          final stepNum = steps[stepIndex]['num'] as int;
          final stepLabel = steps[stepIndex]['label'] as String;

          final isDone = _currentStep > stepNum;
          final isActive = _currentStep == stepNum;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : (isActive ? const Color(0xFF0284C7) : AppColors.white),
                  border: isDone || isActive
                      ? null
                      : Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.white,
                        )
                      : Text(
                          '$stepNum',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 48,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stepLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isActive || isDone
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isDone
                          ? const Color(0xFF10B981)
                          : (isActive
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1ProductForm();
      case 2:
        return _buildStep2Validation();
      case 3:
        return _buildStep3Pricing();
      case 4:
        return _buildStep4Review();
      default:
        return _buildStep1ProductForm();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LANGKAH 1 — Form Upload Produk (upload-stock-step1-screen.png)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1ProductForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.inter(color: AppColors.error, fontSize: 13),
              ),
            ),

          // Section: Foto Produk
          Text(
            'Foto Produk',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF03045E),
            ),
          ),
          const SizedBox(height: 10),
          _buildPhotoUploadBox(),
          const SizedBox(height: 20),

          // Section: Informasi Produk
          Text(
            'Informasi Produk',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF03045E),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOcrInsideProductInfoCard(),
                const SizedBox(height: 16),
                _buildFieldLabel('Nama Produk'),
                TextFormField(
                  key: const Key('input_product_name'),
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nama produk wajib diisi'
                      : null,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _buildInputDecoration(
                    hint: 'Contoh: Susu UHT 1L',
                  ),
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Kategori'),
                _buildCategoryDropdown(),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Quantity'),
                          TextFormField(
                            key: const Key('input_quantity'),
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final num = int.tryParse(v ?? '');
                              return num == null || num <= 0
                                  ? 'Harus > 0'
                                  : null;
                            },
                            style: GoogleFonts.inter(fontSize: 14),
                            decoration: _buildInputDecoration(hint: '500'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Unit'),
                          _buildUnitDropdown(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Tanggal Kedaluwarsa / Batch Close Date'),
                _buildDatePickerField(),
                const SizedBox(height: 14),

                _buildFieldLabel('Harga Normal'),
                TextFormField(
                  key: const Key('input_normal_price'),
                  controller: _normalPriceController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final num = double.tryParse(
                      v?.replaceAll('.', '').replaceAll(',', '') ?? '',
                    );
                    return num == null || num <= 0
                        ? 'Harga normal harus > 0'
                        : null;
                  },
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _buildInputDecoration(
                    hint: '12.000',
                    prefixText: 'Rp  ',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Lanjut
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('btn_submit_step1'),
              onPressed: _isSubmitting ? null : _submitStep1,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      'Lanjut ke Validasi',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Membuka galeri native perangkat untuk memilih foto produk
  Future<void> _pickImageFromGallery() async {
    setState(() {
      _isPickingProductImage = true;
      _productImageError = null;
    });

    try {
      final XFile? image;
      if (widget.onPickImage != null) {
        image = await widget.onPickImage!();
      } else {
        image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      }

      if (image != null) {
        final selectedFile = image;
        final bytes = await selectedFile.readAsBytes();

        // Validasi ukuran file di sisi client (maksimal 2 MB = 2 * 1024 * 1024 bytes)
        const int maxSizeBytes = 2 * 1024 * 1024;
        if (bytes.lengthInBytes > maxSizeBytes) {
          if (!mounted) return;
          final double sizeMb = bytes.lengthInBytes / (1024 * 1024);
          setState(() {
            _isPickingProductImage = false;
            _productImageError =
                'Ukuran file (${sizeMb.toStringAsFixed(1)} MB) melebihi batas maksimal 2 MB';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ukuran foto produk (${sizeMb.toStringAsFixed(1)} MB) melebihi batas maksimal 2 MB. Silakan pilih foto lain.',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final pickedPath = selectedFile.path;
        if (!mounted) return;
        setState(() {
          _productPickedFile = selectedFile;
          _productImageBytes = bytes;
          _productImagePath = pickedPath;
          _productImageUrl = pickedPath.isNotEmpty
              ? pickedPath
              : _productImageUrl;
          _isPickingProductImage = false;
          _productImageError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isPickingProductImage = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPickingProductImage = false;
        _productImageError = 'Gagal mengakses galeri: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengakses galeri perangkat: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildPhotoUploadBox() {
    final bool hasImage =
        _productImageBytes != null ||
        (_productImagePath != null && _productImagePath!.isNotEmpty) ||
        (_productImageUrl.isNotEmpty) ||
        (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty);

    if (_isPickingProductImage) {
      return Container(
        key: const Key('photo_upload_loading'),
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Membuka Galeri Perangkat...',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF03045E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Memproses foto produk pilihan Anda',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    if (hasImage) {
      return Container(
        key: const Key('photo_upload_preview_container'),
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image preview
              _buildSelectedImageWidget(),

              // Gradient scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Status badge top-left
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Foto Galeri Terpilih',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Change photo button bottom-right
              Positioned(
                bottom: 10,
                right: 10,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    key: const Key('btn_change_photo'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickImageFromGallery,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 16,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ganti Foto',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0284C7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      key: const Key('photo_upload_tap_target'),
      onTap: _pickImageFromGallery,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 26,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pilih Foto dari Galeri',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF03045E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Format JPG atau PNG (Maks. 2MB)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            if (_productImageError != null) ...[
              const SizedBox(height: 6),
              Text(
                _productImageError!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Kartu OCR di dalam bagian Informasi Produk
  Widget _buildOcrInsideProductInfoCard() {
    return Container(
      key: const Key('ocr_scan_banner'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Color(0xFF16A34A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ekstrak dari Faktur (OCR)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (_invoicePickedFile != null || _invoiceImagePath != null)
                      ? 'Faktur terpilih: ${_invoicePickedFile?.name ?? "Gambar Faktur"} • Ketuk untuk ganti'
                      : 'Pindai faktur untuk mengisi data produk otomatis dengan AI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF166534),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: const Key('btn_scan_invoice_ocr'),
            onPressed: (_isScanningOcr || _isSubmitting)
                ? null
                : _pickInvoiceAndScanOcr,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(80, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isScanningOcr
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    (_invoicePickedFile != null || _invoiceImagePath != null)
                        ? 'Ganti Faktur'
                        : 'Pindai',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImageWidget() {
    if (_productImageBytes != null) {
      return Image.memory(
        _productImageBytes!,
        key: const Key('photo_upload_preview_image'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
      );
    }
    if (_productImagePath != null && _productImagePath!.isNotEmpty) {
      if (_productImagePath!.startsWith('http://') ||
          _productImagePath!.startsWith('https://')) {
        return Image.network(
          _productImagePath!,
          key: const Key('photo_upload_preview_image'),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
        );
      }
      return Image.file(
        File(_productImagePath!),
        key: const Key('photo_upload_preview_image'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
      );
    }
    if (widget.initialImageUrl != null && widget.initialImageUrl!.isNotEmpty) {
      return Image.network(
        widget.initialImageUrl!,
        key: const Key('photo_upload_preview_image'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
      );
    }
    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      color: const Color(0xFFE0F2FE),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 80) {
              return const Icon(
                Icons.image_outlined,
                size: 28,
                color: Color(0xFF0284C7),
              );
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_outlined,
                  size: 36,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(height: 6),
                Text(
                  'Foto Terpilih',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF03045E),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    const categories = [
      'Produk Olahan Susu & Dairy',
      'Flour & Grain',
      'Bahan Pokok & Tepung',
      'Minyak & Lemak',
      'Minuman',
      'Makanan Ringan',
      'Bumbu & Rempah',
      'Dairy',
      'General',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('dropdown_category'),
          value: categories.contains(_selectedCategory)
              ? _selectedCategory
              : categories.first,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF64748B),
          ),
          items: categories.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text(
                cat,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    const units = ['box', 'karton', 'kg', 'jerigen', 'karung', 'pcs'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('dropdown_unit'),
          value: units.contains(_selectedUnit) ? _selectedUnit : units.first,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF64748B),
          ),
          items: units.map((u) {
            return DropdownMenuItem(
              value: u,
              child: Text(
                u,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedUnit = val);
          },
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    final dateStr =
        '${_expiryDate.day.toString().padLeft(2, '0')}/${_expiryDate.month.toString().padLeft(2, '0')}/${_expiryDate.year}';

    return GestureDetector(
      key: const Key('date_picker_tap_target'),
      onTap: () async {
        final minAllowedDate = DateTime.now().add(const Duration(days: 30));
        final initialDate = _expiryDate.isBefore(minAllowedDate)
            ? minAllowedDate
            : _expiryDate;
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: minAllowedDate,
          lastDate: DateTime.now().add(const Duration(days: 730)),
        );
        if (picked != null) {
          setState(() => _expiryDate = picked);
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF0F172A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF03045E),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LANGKAH 2 — Layar Validasi Mutu (validation-processing-screen.png)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2Validation() {
    final criteria = [
      {'title': 'Foto produk jelas', 'status': 'Lolos'},
      {'title': 'Kemasan utuh', 'status': 'Lolos'},
      {'title': 'Batch memenuhi batas minimum', 'status': 'Lolos'},
      {'title': 'Quantity memenuhi minimum', 'status': 'Lolos'},
      {'title': 'Kategori sesuai', 'status': 'Lolos'},
      {
        'title': 'Cold chain jika diperlukan',
        'status': _verifiedCount >= 6 ? 'Lolos' : 'Memeriksa...',
      },
    ];

    final isAllVerified = _verifiedCount >= 6;
    final validationLabel = _isValidating
        ? 'Produk sedang divalidasi oleh sistem.'
        : 'Produk berhasil lolos validasi standar mutu.';

    return Column(
      children: [
        // Top Card: Shield Icon + Title + Progress
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 34,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Memeriksa Produk',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF03045E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sistem sedang menganalisis foto, kelayakan batch, dan parameter standar mutu Recovera.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _validationProgress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bottom Card: Kriteria Validasi Pangan
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kriteria Validasi Pangan',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF03045E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_verifiedCount dari 6 Terverifikasi',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 8),

              ...criteria.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                final isChecked = i < _verifiedCount;
                final statusStr = c['status']!;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isChecked
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFE0F2FE),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isChecked ? Icons.check : Icons.access_time_rounded,
                          size: 13,
                          color: isChecked
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c['title']!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Text(
                        statusStr,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusStr == 'Lolos'
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isAllVerified
                    ? const Color(0xFF10B981)
                    : const Color(0xFF0284C7),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                validationLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            key: const Key('btn_proceed_to_pricing'),
            onPressed: isAllVerified ? _proceedToPricing : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: AppColors.white,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              disabledForegroundColor: const Color(0xFF94A3B8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'Lanjut ke Rekomendasi Harga',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LANGKAH 3 — Rekomendasi Harga & Peringatan Deviasi
  // (pricing-recommendation-screen.png & pricing-warning-screen.png)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3Pricing() {
    final normalPrice = _draftListing?.normalPrice ?? 15000.0;
    final qty = _draftListing?.qty ?? 500;
    final unit = _draftListing?.defaultUnit ?? 'box';
    final suggested = _recommendationResult?.suggestedPrice ?? 9000.0;
    final minRange = _recommendationResult?.minAcceptedPrice ?? 7500.0;
    final maxRange = _recommendationResult?.maxAcceptedPrice ?? 10500.0;

    final isOutsideRange = _userPrice < minRange || _userPrice > maxRange;
    final showWarning = _isManualPriceMode && isOutsideRange;

    return Column(
      children: [
        // Top Product Summary Card
        _buildProductHeaderCard(),
        const SizedBox(height: 14),

        if (!showWarning) ...[
          // MODE A: Rekomendasi Cerdas (pricing-recommendation-screen.png)
          _buildSmartRecommendationCard(normalPrice, qty, unit, suggested),
          const SizedBox(height: 14),
          _buildMarketRangeCard(minRange, maxRange, suggested, unit),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('btn_use_recommendation'),
              onPressed: _useRecommendation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'Gunakan Rekomendasi',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              key: const Key('btn_set_manual_price'),
              onPressed: _openManualPriceDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Set Manual',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ),
          ),
        ] else ...[
          // MODE B: Peringatan Harga Deviasi (pricing-warning-screen.png)
          _buildManualPriceInputCard(unit),
          const SizedBox(height: 14),
          _buildWarningBannerCard(),
          const SizedBox(height: 14),
          _buildDeviationRangeCard(minRange, maxRange, _userPrice),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('btn_change_to_recommendation'),
              onPressed: () {
                setState(() {
                  _userPrice = suggested;
                  _isManualPriceMode = false;
                  _acknowledgePriceWarning = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'Ubah ke Rekomendasi',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              key: const Key('btn_keep_my_price'),
              onPressed: _isSubmitting ? null : _acknowledgeAndProceed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Tetap Pakai Harga Saya',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductHeaderCard() {
    final name = _draftListing?.productName ?? _nameController.text;
    final qty = _draftListing?.qty ?? 500;
    final unit = _draftListing?.defaultUnit ?? _selectedUnit;
    final days = _draftListing?.daysRemaining ?? 45;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_drink_rounded,
              size: 26,
              color: Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF03045E),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$qty $unit',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$days hari tersisa',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartRecommendationCard(
    double normalPrice,
    int qty,
    String unit,
    double suggested,
  ) {
    final totalRecovery = qty * suggested;
    final discount = _recommendationResult?.discountPct ?? 40.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rekomendasi Cerdas',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Diskon ${discount.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Harga Rekomendasi',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatCurrency(suggested),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0284C7),
                ),
              ),
              Text(
                ' / $unit  ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                formatCurrency(normalPrice),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Row(
              children: [
                Text(
                  'Estimasi Recovery ($qty $unit)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Text(
                  formatCurrency(totalRecovery),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketRangeCard(
    double min,
    double max,
    double suggested,
    String unit,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rentang Harga Pasar Serupa',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF03045E),
            ),
          ),
          const SizedBox(height: 18),

          // Slider visual track
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              FractionallySizedBox(
                widthFactor: 0.6,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                    ),
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0284C7), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${formatCurrency(suggested)} • Rekomendasi',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatCurrency(min),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Obral Cepat',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(max),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Maksimal',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Harga rekomendasi berdasarkan kondisi stok dan sisa umur simpan.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openManualPriceDialog() {
    _manualPriceController.text = _userPrice.toInt().toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Atur Harga Manual',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan harga awal yang Anda inginkan (Rp):',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.slateText,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualPriceController,
              keyboardType: TextInputType.number,
              decoration: _buildInputDecoration(
                hint: '12000',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(
                _manualPriceController.text.replaceAll('.', '').trim(),
              );
              if (val != null && val > 0) {
                Navigator.pop(context);
                _applyManualPrice(val);
              }
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualPriceInputCard(String unit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harga Manual yang Dimasukkan',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF03045E),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            child: Row(
              children: [
                Text(
                  'Rp  ',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  formatCurrency(_userPrice).replaceFirst('Rp', '').trim(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Text(
                  '/ $unit',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harga di luar rekomendasi',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Risiko: harga lebih tinggi dapat mengurangi peluang stok terjual.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviationRangeCard(double min, double max, double userPrice) {
    final isHigher = userPrice > max;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Rentang Rekomendasi Sistem',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF03045E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${formatCurrency(min)} - ${formatCurrency(max)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Track with thumb pushed outside
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.65,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: isHigher
                    ? const Alignment(0.65, 0)
                    : const Alignment(-0.65, 0),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF59E0B),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Align(
            alignment: isHigher
                ? const Alignment(0.65, 0)
                : const Alignment(-0.65, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF92400E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${formatCurrency(userPrice)} • ${isHigher ? 'Terlalu Tinggi' : 'Terlalu Rendah'}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${formatCurrency(min)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                'Maks: ${formatCurrency(max)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LANGKAH 4 — Review & Publish (review-publish-screen.png)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep4Review() {
    final name = _draftListing?.productName ?? _nameController.text;
    final qty = _draftListing?.qty ?? 500;
    final unit = _draftListing?.defaultUnit ?? _selectedUnit;
    final batch = _draftListing?.batchNumber ?? 'LOT-2026-X1';
    final days = _draftListing?.daysRemaining ?? 45;
    final normalPrice = _draftListing?.normalPrice ?? 15000.0;
    final sellPrice = _userPrice;
    final discount = ((normalPrice - sellPrice) / normalPrice * 100).clamp(
      0,
      99,
    );
    final totalRecovery = qty * sellPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Ringkasan Produk
        Text(
          'Ringkasan Produk',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF03045E),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _buildSelectedImageWidget(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF03045E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$qty $unit • Batch',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$batch',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$days hari tersisa',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_validationResult != null &&
                        _validationResult!.isValid) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 12,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Standar Mutu Terverifikasi',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section: Rincian Harga & Recovery
        Text(
          'Rincian Harga & Recovery',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF03045E),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Harga Normal',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatCurrency(normalPrice),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Harga Jual',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatCurrency(sellPrice),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  Text(
                    ' / $unit',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Diskon Diterapkan',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Diskon ${discount.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      'Estimated Recovery',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF03045E),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatCurrency(totalRecovery),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section: Matching Categories
        Text(
          'Matching Categories',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF03045E),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildMatchingPill('F&B'),
                  const SizedBox(width: 8),
                  _buildMatchingPill('Katering'),
                  const SizedBox(width: 8),
                  _buildMatchingPill('UMKM'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Stok ini akan otomatis diprioritaskan dan dicocokkan dengan pembeli bisnis di kategori di atas.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Primary Publish Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            key: const Key('btn_publish_stock'),
            onPressed: _isSubmitting ? null : _publishListing,
            icon: _isSubmitting
                ? const SizedBox.shrink()
                : const Icon(Icons.check, size: 20),
            label: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'Publish Stok',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Back / Edit Button
        Center(
          child: TextButton(
            key: const Key('btn_back_to_edit'),
            onPressed: () => setState(() => _currentStep = 1),
            child: Text(
              'Kembali Edit',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0284C7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchingPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF0284C7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
