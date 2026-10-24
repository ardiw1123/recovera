import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RecoveraWaveHeader extends StatelessWidget {
  const RecoveraWaveHeader({
    super.key,
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _WaveBackdropClipper(),
              child: ColoredBox(
                color: AppColors.accent.withValues(alpha: 0.45),
              ),
            ),
          ),
          ClipPath(
            clipper: _WaveHeaderClipper(),
            child: Container(
              height: height,
              width: double.infinity,
              color: AppColors.primary,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 18)
      ..cubicTo(
        size.width * 0.3,
        size.height + 4,
        size.width * 0.68,
        size.height - 34,
        size.width,
        size.height - 14,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WaveHeaderClipper oldClipper) => false;
}

class _WaveBackdropClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 8)
      ..cubicTo(
        size.width * 0.34,
        size.height + 10,
        size.width * 0.7,
        size.height - 26,
        size.width,
        size.height - 5,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WaveBackdropClipper oldClipper) => false;
}
