import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../seller/screens/upload_stock_flow_screen.dart';

class RichCardWidget extends StatelessWidget {
  final Map<String, dynamic> cardData;

  const RichCardWidget({
    super.key,
    required this.cardData,
  });

  @override
  Widget build(BuildContext context) {
    final type = cardData['type'] as String? ?? '';
    final data = cardData['data'] as Map<String, dynamic>? ?? {};
    final action = cardData['action'] as Map<String, dynamic>?;

    if (type == 'product_simulation') {
      return _buildProductSimulationCard(context, data, action);
    }

    return const SizedBox.shrink();
  }

  Widget _buildProductSimulationCard(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic>? action,
  ) {
    final category = data['category'] as String? ?? 'General';
    final qty = data['qty'] as num? ?? 1;
    final normalPrice = (data['normal_price'] as num? ?? 0).toDouble();
    final startPrice = (data['suggested_start_price'] as num? ?? 0).toDouble();
    final discountPct = (data['suggested_discount_pct'] as num? ?? 0).toDouble();
    final buyersCount = data['matched_buyers_count'] as int? ?? 0;
    final avgDist = (data['average_distance_km'] as num? ?? 0).toDouble();
    final disclaimer = data['disclaimer'] as String? ?? '';

    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Simulasi Model Recovera',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.successBorder),
                ),
                child: Text(
                  'Kategori: $category',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid Metrik
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Saran Diskon Awal',
                  value: '${discountPct.toStringAsFixed(0)}%',
                  subvalue: 'Buka: ${formatter.format(startPrice)}',
                  valueColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Potensi Pembeli',
                  value: '$buyersCount Calon',
                  subvalue: 'Radius ~$avgDist km',
                  valueColor: AppColors.darkNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Detail harga normal & kuantitas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.canvasBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Harga Normal: ${formatter.format(normalPrice)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.slateText),
                ),
                Text(
                  'Qty: $qty unit/karton',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
          ),

          if (disclaimer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              disclaimer,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.slateText,
              ),
            ),
          ],

          if (action != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UploadStockFlowScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  action['label'] as String? ?? 'Terapkan ke Listing Baru',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subvalue,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.canvasBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.slateText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subvalue,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.slateText,
            ),
          ),
        ],
      ),
    );
  }
}
