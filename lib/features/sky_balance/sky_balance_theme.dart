import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Colours for the Sky Balance game surface.
///
/// Every base value is taken from [AppColors] so the mini-game keeps the same
/// blue / cyan / white language as the rest of Recovera.
abstract final class SkyPalette {
  SkyPalette._();

  // Sky
  static const Color skyTop = Color(0xFFC1E6F9);
  static const Color skyMiddle = Color(0xFFE6F5FE);
  static const Color skyBottom = Color(0xFFFFFFFF);

  // Brand
  static const Color primary = AppColors.primary;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color cyan = AppColors.secondary;
  static const Color accent = AppColors.accent;

  // Text
  static const Color ink = AppColors.darkNavy;
  static const Color body = Color(0xFF12364A);
  static const Color slate = AppColors.slateText;
  static const Color muted = Color(0xFF7C93A8);
  static const Color faint = Color(0xFF93AFC5);

  // Surfaces
  static const Color border = Color(0xFFD8ECF8);
  static const Color hairline = Color(0xFFEBF5FC);
  static const Color track = Color(0xFFE2F0FA);
  static const Color paleBlue = Color(0xFFDDF1FD);
  static const Color paleSurface = Color(0xFFF1FAFF);

  // Status
  static const Color mint = AppColors.success;
  static const Color mintInk = Color(0xFF0E9F6E);
  static const Color mintSurface = AppColors.successBg;
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberInk = Color(0xFFB7791F);
  static const Color amberSurface = Color(0xFFFFF7E6);
  static const Color star = Color(0xFFF5B301);
}

abstract final class SkyRadii {
  SkyRadii._();

  static const double chip = 18;
  static const double card = 22;
  static const double sheet = 28;
  static const double pill = 999;
}

abstract final class SkyShadows {
  SkyShadows._();

  /// Soft, brand-tinted elevation. Never pure black.
  static List<BoxShadow> floating({double opacity = .22}) => <BoxShadow>[
    BoxShadow(
      color: SkyPalette.primary.withValues(alpha: opacity),
      blurRadius: 28,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> surface = <BoxShadow>[
    BoxShadow(
      color: SkyPalette.ink.withValues(alpha: .16),
      blurRadius: 44,
      offset: const Offset(0, 22),
    ),
  ];

  static List<BoxShadow> pill = <BoxShadow>[
    BoxShadow(
      color: SkyPalette.ink.withValues(alpha: .16),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Typography helpers so every game screen shares one type scale.
abstract final class SkyType {
  SkyType._();

  /// Short uppercase UI labels (SCORE, ENERGY, NEXT).
  static TextStyle label({double size = 10, Color color = SkyPalette.muted}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        height: 1.1,
        color: color,
      );

  static TextStyle strong({
    double size = 15,
    Color color = SkyPalette.ink,
    double height = 1.15,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: height,
    color: color,
  );

  static TextStyle body({
    double size = 12.5,
    Color color = SkyPalette.slate,
    double height = 1.35,
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
  );

  /// Numbers use tabular figures so counters do not jitter while playing.
  static TextStyle number({
    double size = 20,
    Color color = SkyPalette.ink,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: 1,
    color: color,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}
