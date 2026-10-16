import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/feedback_api_service.dart';
import '../../auth/widgets/auth_widgets.dart';

/// PBI-08 — Layar Saran & Kesan PAM
///
/// Terhubung langsung dengan backend FastAPI via POST /feedback
class SaranKesanScreen extends StatefulWidget {
  const SaranKesanScreen({super.key});

  @override
  State<SaranKesanScreen> createState() => _SaranKesanScreenState();
}

class _SaranKesanScreenState extends State<SaranKesanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kesanCtrl = TextEditingController();
  final _saranCtrl = TextEditingController();

  late final FeedbackApiService _feedbackService;
  bool _isLoading = false;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _feedbackService = FeedbackApiService(client: ApiClient());
  }

  @override
  void dispose() {
    _kesanCtrl.dispose();
    _saranCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _feedbackService.submitFeedback(
        kesan: _kesanCtrl.text.trim(),
        saran: _saranCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terima kasih! Saran & kesan Anda berhasil dikirim.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.white),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleReset() {
    setState(() {
      _kesanCtrl.clear();
      _saranCtrl.clear();
      _isSubmitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Saran & Kesan',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _isSubmitted ? _buildSuccessCard() : _buildFeedbackForm(),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saran & Kesan Perkuliahan PAM',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      Text(
                        'Evaluasi dan masukan Anda sangat berarti bagi pengembangan.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.slateText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Kesan ───────────────────────────────────────────────
            Text(
              'Kesan',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _kesanCtrl,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkNavy),
              decoration: InputDecoration(
                hintText:
                    'Bagikan pengalaman dan kesan Anda selama mengikuti perkuliahan atau menggunakan aplikasi Recovera...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.slateText),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Kesan wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // ── Saran ───────────────────────────────────────────────
            Text(
              'Saran',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _saranCtrl,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkNavy),
              decoration: InputDecoration(
                hintText:
                    'Berikan saran konstruktif untuk pengembangan sistem atau perkuliahan ke depan...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.slateText),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Saran wajib diisi' : null,
            ),
            const SizedBox(height: 24),

            // ── Submit Button ───────────────────────────────────────
            PillButton(
              label: 'Kirim Saran & Kesan',
              onPressed: _handleSubmit,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF059669),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Saran & Kesan Terkirim!',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Terima kasih atas kontribusi dan apresiasi Anda. Masukan ini telah tersimpan di sistem backend Recovera.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.slateText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          PillButton(
            label: 'Tulis Saran Baru',
            outlined: true,
            onPressed: _handleReset,
          ),
        ],
      ),
    );
  }
}
