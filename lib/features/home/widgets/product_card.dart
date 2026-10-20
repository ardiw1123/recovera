import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gambar / ikon produk ──────────────────────────────────
            _ListingImage(listing: listing),
            const SizedBox(width: 12),

            // ── Detail ───────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // company_name + expiry badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.companyName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _ExpiryBadge(
                        days: listing.effectiveDaysToExpiry,
                        isUrgent: isUrgent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // products.name
                  Text(
                    listing.productName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // brand (jika ada)
                  if (listing.brand != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      listing.brand!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),

                  // Proximity match score badge (jika ada)
                  if (listing.matchScore != null) ...[
                    Container(
                      key: Key('match_score_badge_${listing.id}'),
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded, size: 9, color: Color(0xFF059669)),
                          const SizedBox(width: 3),
                          Text(
                            listing.matchScorePercentage,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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
                      const SizedBox(width: 4),
                      Text(
                        '•',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Stok: ${listing.qty} ${listing.defaultUnit}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(height: 1, color: const Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),

                  // normal_price (coret) + start_price + tombol Beli
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rp ${_fmt(listing.normalPrice)}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'Rp ${_fmt(listing.currentPrice)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/ ${listing.defaultUnit}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Tombol Lihat Detail / Beli
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: Key('btn_open_detail_${listing.id}'),
                          onTap: () => _handleTap(context),
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

          // Badge diskon
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              key: Key('discount_badge_${listing.id}'),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '-${listing.effectiveDiscountPercent}%',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Badge Live Dutch Auction
          if (listing.isLiveDutch)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C4A6E).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38BDF8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Dutch',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFBAE6FD),
                      ),
                    ),
                  ],
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
    final bgColor =
        isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final textColor =
        isUrgent ? const Color(0xFFDC2626) : const Color(0xFFB45309);
    final borderColor =
        isUrgent ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.warning_rounded : Icons.timer_outlined,
            size: 10,
            color: textColor,
          ),
          const SizedBox(width: 3),
          Text(
            'Sisa $days Hari',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
