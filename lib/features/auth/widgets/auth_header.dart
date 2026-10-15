import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Widget Header Biru — pola berulang di semua layar Auth Recovera.
///
/// Layout:
/// ┌─────────────────────────────┐
/// │  [leftAction]   [rightAction]│  ← Row navigasi
/// │                             │
/// │       [child]               │  ← Konten tengah (logo / badge)
/// └─────────────────────────────┘
///
/// Tinggi default = 30% layar, bisa disesuaikan via [height].
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.height,
    this.leftAction,
    this.rightAction,
    this.child,
  });

  final double? height;
  final Widget? leftAction;
  final Widget? rightAction;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final h = height ?? MediaQuery.of(context).size.height * 0.29;

    return Container(
      height: h,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Row Navigasi ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  leftAction ?? const SizedBox(width: 40),
                  rightAction ?? const SizedBox(width: 40),
                ],
              ),

              // ── Konten Tengah (opsional) ─────────────────────────────
              // bottom: 52 supaya logo naik cukup dan tidak terpotong
              // oleh OverlappingSheet yang menimpa 28px dari bawah header
              if (child != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 52),
                  child: child,
                ),
              ] else
                const SizedBox(height: 52),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol bulat transparan untuk navigasi di atas header biru.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.white, size: 20),
        ),
      ),
    );
  }
}
