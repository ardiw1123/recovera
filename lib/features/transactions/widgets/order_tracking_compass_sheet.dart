import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../models/transaction_order_model.dart';

/// Modal dialog detail lokasi gudang & instruksi penjemputan mandiri (Self Pick-up)
class OrderTrackingCompassSheet extends StatefulWidget {
  const OrderTrackingCompassSheet({
    super.key,
    required this.order,
    this.onStatusUpdated,
  });

  final TransactionOrder order;
  final ValueChanged<String>? onStatusUpdated;

  static void show(
    BuildContext context, {
    required TransactionOrder order,
    ValueChanged<String>? onStatusUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderTrackingCompassSheet(
        order: order,
        onStatusUpdated: onStatusUpdated,
      ),
    );
  }

  @override
  State<OrderTrackingCompassSheet> createState() =>
      _OrderTrackingCompassSheetState();
}

class _OrderTrackingCompassSheetState extends State<OrderTrackingCompassSheet> {
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final distanceText = order.distanceKm != null
        ? '${order.distanceKm!.toStringAsFixed(1)} km'
        : '4.2 km';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.orderCode,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Self Pick-up (Ambil Sendiri)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Panduan Lokasi & Pengambilan',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B), size: 24),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Order Status Stepper (Self Pick-up: Dibayar -> Siap Diambil -> Selesai)
                  _buildStatusStepper(order.status),
                  const SizedBox(height: 20),

                  // 2. Warehouse Location & Address Card
                  _buildWarehouseCard(order, distanceText),
                  const SizedBox(height: 18),

                  // 3. Pickup Warning & Deadline Card
                  _buildDeadlineCard(order),
                  const SizedBox(height: 20),

                  // 4. Action Button
                  if (order.status != 'completed' && order.status != 'cancelled')
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded,
                            size: 20),
                        label: Text(
                          'Konfirmasi Barang Sudah Diterima',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          widget.onStatusUpdated?.call('completed');
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Pesanan ${order.orderCode} berhasil diselesaikan!',
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Order Stepper Widget (Self Pick-up: Tanpa 'Di Jalan') ───────────────
  Widget _buildStatusStepper(String currentStatus) {
    final stages = [
      {'code': 'paid', 'label': 'Dibayar'},
      {'code': 'in_progress', 'label': 'Siap Diambil'},
      {'code': 'completed', 'label': 'Selesai'},
    ];

    int activeIdx = 0;
    if (currentStatus == 'in_progress' || currentStatus == 'picked_up') {
      activeIdx = 1;
    } else if (currentStatus == 'completed') {
      activeIdx = 2;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: List.generate(stages.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stageIndex = index ~/ 2;
            final isDone = stageIndex < activeIdx;
            return Expanded(
              child: Container(
                height: 3,
                color: isDone ? AppColors.primary : const Color(0xFFCBD5E1),
              ),
            );
          }
          final stageIndex = index ~/ 2;
          final isCompleted = stageIndex < activeIdx;
          final isCurrent = stageIndex == activeIdx;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.primary
                      : (isCurrent
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.white),
                  border: Border.all(
                    color: isCompleted || isCurrent
                        ? AppColors.primary
                        : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : Text(
                          '${stageIndex + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isCurrent
                                ? AppColors.primary
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stages[stageIndex]['label']!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight:
                      isCurrent || isCompleted ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent || isCompleted
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── 2. Warehouse Location Card ────────────────────────────────────────────
  Widget _buildWarehouseCard(TransactionOrder order, String distanceText) {
    final warehouseName = order.warehouseName ?? 'Gudang Penjual';
    final address = order.warehouseAddress ??
        'Kawasan Pergudangan Logistik Blok B-4, Jakarta Barat';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warehouse_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warehouseName,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      order.partnerName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      distanceText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alamat Pengambilan:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(
                'Salin Alamat Lengkap',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Alamat gudang disalin ke clipboard!',
                        style: GoogleFonts.inter(color: Colors.white)),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Deadline Warning Card ──────────────────────────────────────────────
  Widget _buildDeadlineCard(TransactionOrder order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batas Pengambilan Mandiri',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '25 Okt 2026, 21:00 WIB (Sisa 6 Jam). Alokasi batch pangan akan dibatalkan otomatis jika melewati batas waktu.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF92400E),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
