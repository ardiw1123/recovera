import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/seller_inventory_model.dart';
import '../repositories/seller_repository.dart';
import 'upload_stock_flow_screen.dart';

/// Layar rincian produk inventaris penjual (Seller Product Detail).
///
/// Menampilkan informasi mendalam mengenai stok barang:
/// - Foto produk, nama produk, brand, kategori, nomor batch
/// - Status listing dan alur proses saat ini
/// - Harga normal, harga lelang / mulai, dan harga minimum
/// - Sisa masa kedaluwarsa
/// - Tombol "Lanjutkan Validasi" dan "Hapus Produk" jika status 'draft'
class SellerProductDetailScreen extends StatefulWidget {
  const SellerProductDetailScreen({
    super.key,
    required this.item,
    this.repository,
  });

  final SellerListingItem item;
  final SellerRepository? repository;

  @override
  State<SellerProductDetailScreen> createState() =>
      _SellerProductDetailScreenState();
}

class _SellerProductDetailScreenState extends State<SellerProductDetailScreen> {
  late final SellerRepository _repository;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SellerRepository.instance;
  }

  bool get _isDraft =>
      widget.item.status.toLowerCase() == 'draft' ||
      widget.item.status.toLowerCase() == 'review';

  Future<void> _handleDeleteDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hapus Draf Produk?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Draf produk "${widget.item.productName}" akan dihapus secara permanen. Anda dapat membuat draf baru kapan saja.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            key: const Key('btn_cancel_delete_draft'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(80, 44),
              foregroundColor: const Color(0xFF64748B),
            ),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_delete_draft'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await _repository.deleteDraft(widget.item.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draf "${widget.item.productName}" berhasil dihapus.'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true); // Kembali ke Stok Saya dengan tanda refresh
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus draf: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _continueDraftUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadStockFlowScreen(
          existingDraft: widget.item,
        ),
      ),
    ).then((_) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
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
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: IconButton(
                key: const Key('btn_detail_back'),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF0F172A),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
        title: Text(
          'Detail Produk',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF03045E),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pratinjau Gambar Produk ──────────────────────────────────
              _buildImagePreview(item),
              const SizedBox(height: 18),

              // ── Informasi Utama ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                key: const Key('detail_product_name'),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF03045E),
                                ),
                              ),
                              if (item.brand != null && item.brand!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.brand!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _buildStatusBadge(item),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),

                    _buildInfoRow('Kategori', item.category),
                    const SizedBox(height: 10),
                    _buildInfoRow('Jumlah Stok', '${item.qty} ${item.defaultUnit}'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Nomor Batch', item.batchNumber),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Kedaluwarsa',
                      '${item.expiryDate} (${item.daysRemainingText})',
                      highlightValue: item.daysRemaining < 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Kartu Harga & Lelang ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Struktur Harga',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF03045E),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPriceRow('Harga Normal', item.formattedNormalPrice),
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Harga Lelang (Mulai)',
                      item.formattedStartPrice,
                      isPrimary: true,
                    ),
                    const SizedBox(height: 8),
                    _buildPriceRow('Batas Harga Minimum', item.formattedMinPrice),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Status Alur Saat Ini ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alur Saat Ini',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          Text(
                            item.currentProcessLabel,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF03045E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Tombol Tindakan ──────────────────────────────────────────
              if (_isDraft) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    key: const Key('btn_continue_draft'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      'Lanjutkan Upload & Validasi',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _continueDraftUpload,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    key: const Key('btn_delete_draft'),
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFDC2626),
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFFDC2626)),
                    label: Text(
                      _isDeleting ? 'Menghapus...' : 'Hapus Draf Produk',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isDeleting ? null : _handleDeleteDraft,
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text(
                      'Produk telah aktif di katalog lelang dan dalam mode hanya-baca.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(SellerListingItem item) {
    final img = item.imageUrl;
    Widget imageContent;

    if (img != null && img.isNotEmpty) {
      if (img.startsWith('http://') || img.startsWith('https://')) {
        imageContent = Image.network(
          img,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackThumbnail(item),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0284C7),
              ),
            );
          },
        );
      } else {
        imageContent = Image.file(
          File(img),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackThumbnail(item),
        );
      }
    } else {
      imageContent = _buildFallbackThumbnail(item);
    }

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageContent,
    );
  }

  Widget _buildFallbackThumbnail(SellerListingItem item) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 8),
            Text(
              'Foto Tidak Tersedia',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SellerListingItem item) {
    final isDraft = _isDraft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDraft ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDraft ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Text(
        item.statusBadgeLabel,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDraft ? const Color(0xFFD97706) : const Color(0xFF16A34A),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool highlightValue = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlightValue
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isPrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              color: isPrimary ? const Color(0xFF03045E) : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.end,
          style: GoogleFonts.inter(
            fontSize: isPrimary ? 16 : 14,
            fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
            color: isPrimary ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
