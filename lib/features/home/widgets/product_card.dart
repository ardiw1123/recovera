import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/app_prefs_repository.dart';
import '../models/product_model.dart';
import '../screens/product_detail_screen.dart';

/// Kartu satu listing produk dengan metrik rekomendasi proximity — field sesuai skema DB.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.listing,
    this.onTap,
  });

  final Listing listing;
  final VoidCallback? onTap;

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(listing: listing),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = listing.effectiveDaysToExpiry <= 3;

    return GestureDetector(
      key: Key('product_card_${listing.id}'),
      onTap: () => _handleTap(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Gambar / ikon produk (dengan pita diskon) ─────────────
              _ListingImage(listing: listing),
              const SizedBox(width: 12),

              // ── Detail di samping foto: Nama, Brand, Lokasi, Harga ────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          listing.companyName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          listing.productName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (listing.brand != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            listing.brand!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (listing.matchScore != null) ...[
                          const SizedBox(height: 3),
                          Container(
                            key: Key('match_score_badge_${listing.id}'),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.radar_rounded, size: 9, color: Color(0xFF059669)),
                                const SizedBox(width: 2),
                                Text(
                                  listing.matchScorePercentage,
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                  // Proximity distance + city + MOQ (qty + default_unit)
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        size: 11,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        listing.distanceText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '•',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          listing.city,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                    // Harga (tidak membuat baris baru terpisah di bawah foto)
                    ListenableBuilder(
                      listenable: AppPrefsRepository.instance,
                      builder: (context, _) {
                        final curPrice = AppPrefsRepository.instance.formatPrice(listing.currentPrice);
                        final norPrice = AppPrefsRepository.instance.formatPrice(listing.normalPrice);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              curPrice,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '/ ${listing.defaultUnit}',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              norPrice,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ── Kanan: Sisa Hari (Atas) & Tombol [->] (Bawah) ──────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ExpiryBadge(
                    days: listing.effectiveDaysToExpiry,
                    isUrgent: isUrgent,
                  ),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: Key('btn_open_detail_${listing.id}'),
                      onTap: () => _handleTap(context),
                      borderRadius: BorderRadius.circular(10),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format angka menjadi "8.250" dsb.
  String _fmt(double price) {
    final str = price.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ListingImage — gambar/ikon + badge diskon + Live Dutch + storage_type
// ─────────────────────────────────────────────────────────────────────────────

class _ListingImage extends StatelessWidget {
  const _ListingImage({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          // Gambar atau ikon fallback
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: listing.imageUrl != null
                ? Image.network(
                    listing.imageUrl!,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _iconFallback(),
                  )
                : _iconFallback(),
          ),

          // Badge diskon berbentuk potongan pita (tidak bold)
          Positioned(
            top: 4,
            left: 0,
            child: ClipPath(
              clipper: _RibbonClipper(),
              child: Container(
                key: Key('discount_badge_${listing.id}'),
                padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                ),
                child: Text(
                  '-${listing.effectiveDiscountPercent}%',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Badge storage_type (frozen / chilled)
          if (listing.storageType != 'ambient')
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: listing.storageType == 'frozen'
                      ? const Color(0xFF0891B2)
                      : const Color(0xFF0369A1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  listing.storageType == 'frozen'
                      ? Icons.ac_unit_rounded
                      : Icons.thermostat_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconFallback() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: listing.category.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: listing.category.color.withValues(alpha: 0.15),
        ),
      ),
      child: Icon(
        listing.category.icon,
        size: 36,
        color: listing.category.color.withValues(alpha: 0.6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExpiryBadge — days_to_expiry badge
// ─────────────────────────────────────────────────────────────────────────────

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.days, required this.isUrgent});
  final int days;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    // Langsung tulisan saja tanpa background dan rounded border, warna sesuai urgensi
    final Color textColor;
    if (isUrgent || days <= 3) {
      textColor = const Color(0xFFDC2626); // Merah
    } else if (days <= 7) {
      textColor = const Color(0xFFD97706); // Amber / Kuning Oranye
    } else {
      textColor = const Color(0xFF16A34A); // Hijau
    }

    return Text(
      'Sisa $days Hari',
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }
}

/// Custom Clipper untuk potongan pita diskon (ujung kanan berlekuk ribbon tail)
class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width - 5, size.height / 2); // lekuk potongan pita
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

