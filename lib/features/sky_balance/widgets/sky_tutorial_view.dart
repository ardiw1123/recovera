import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../sky_balance_theme.dart';
import 'sky_common.dart';
import 'sky_controls.dart';

/// Explains the three physical moves before the first climb.
class SkyTutorialView extends StatelessWidget {
  const SkyTutorialView({
    super.key,
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    required this.dashAvailable,
  });

  final VoidCallback onBack;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool dashAvailable;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SkyWaveHeader(title: 'How to play', onBack: onBack),
        Expanded(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Three things to know before your first jump up the sky.',
                        style: SkyType.strong(
                          size: 14.5,
                          color: SkyPalette.body,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _InstructionRow(
                        asset: 'lib/assets/sky_tilt.svg',
                        title: 'Tilt to steer',
                        detail:
                            'Lean your phone left or right and your character '
                            'slides across the sky.',
                      ),
                      const SizedBox(height: 12),
                      const _InstructionRow(
                        asset: 'lib/assets/sky_jump.svg',
                        title: 'Land to jump',
                        detail:
                            'Your character jumps automatically. Just aim for '
                            'the next platform.',
                      ),
                      const SizedBox(height: 12),
                      const _InstructionRow(
                        asset: 'lib/assets/sky_food.svg',
                        title: 'Collect food',
                        detail:
                            'Every pickup refills energy and adds score. 20 '
                            'pieces of food on this climb.',
                      ),
                      const SizedBox(height: 16),
                      _DashNote(available: dashAvailable),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                child: Column(
                  children: <Widget>[
                    Text(
                      'You can pause any time from the pause button.',
                      textAlign: TextAlign.center,
                      style: SkyType.body(
                        size: 12,
                        color: SkyPalette.muted,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SkyPrimaryButton(
                      label: primaryLabel,
                      icon: Icons.phone_android_rounded,
                      onPressed: onPrimary,
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onBack,
                      child: Text(
                        'Back to home',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SkyPalette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.asset,
    required this.title,
    required this.detail,
  });

  final String asset;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SkySurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 100,
            height: 68,
            child: SvgPicture.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: SkyType.strong(size: 15)),
                const SizedBox(height: 6),
                Text(detail, style: SkyType.body(size: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashNote extends StatelessWidget {
  const _DashNote({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: SkyPalette.paleSurface,
        borderRadius: BorderRadius.circular(SkyRadii.chip),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            available
                ? Icons.swap_horiz_rounded
                : Icons.do_not_disturb_alt_rounded,
            size: 19,
            color: available ? SkyPalette.cyan : SkyPalette.faint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Dash: ',
                    style: SkyType.body(
                      size: 12.5,
                      color: SkyPalette.body,
                      weight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: available
                        ? 'flick left or right quickly. Recharges in 2 seconds.'
                        : 'not available on this phone because it has no '
                              'gyroscope. You can still climb.',
                    style: SkyType.body(size: 12.5, color: SkyPalette.body),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
