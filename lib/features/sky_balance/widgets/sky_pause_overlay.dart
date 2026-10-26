import 'package:flutter/material.dart';

import '../sky_balance_theme.dart';
import '../sky_format.dart';
import 'sky_controls.dart';

/// Modal over the frozen climb. The scene stays visible behind the scrim so
/// pausing reads as an interruption, not a different page.
class SkyPauseOverlay extends StatelessWidget {
  const SkyPauseOverlay({
    super.key,
    required this.score,
    required this.foodCollected,
    required this.foodTotal,
    required this.energy,
    required this.percentage,
    required this.soundEnabled,
    required this.onToggleSound,
    required this.sensitivity,
    required this.onSensitivityChanged,
    required this.onResume,
    required this.onRestart,
    required this.onHome,
    required this.onRecalibrate,
  });

  final int score;
  final int foodCollected;
  final int foodTotal;
  final int energy;
  final int percentage;
  final bool soundEnabled;
  final ValueChanged<bool> onToggleSound;
  final double sensitivity;
  final ValueChanged<double> onSensitivityChanged;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback onRecalibrate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ModalBarrier(
          dismissible: false,
          color: const Color(0x7304263C),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: _card(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SkyRadii.sheet),
        boxShadow: SkyShadows.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Paused',
            style: SkyType.strong(size: 23, height: 1).copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'First climb, $percentage% of the way up.',
            style: SkyType.body(
              size: 12.5,
              color: SkyPalette.muted,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: SkyPalette.paleSurface,
              borderRadius: BorderRadius.circular(SkyRadii.chip),
            ),
            child: Row(
              children: <Widget>[
                _miniStat('SCORE', formatCount(score)),
                const _StatDivider(),
                _miniStat('FOOD', '$foodCollected/$foodTotal'),
                const _StatDivider(),
                _miniStat('ENERGY', '$energy'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SkyPrimaryButton(
            label: 'RESUME',
            icon: Icons.play_arrow_rounded,
            height: 52,
            onPressed: onResume,
          ),
          const SizedBox(height: 10),
          SkySecondaryButton(
            label: 'Restart',
            icon: Icons.restart_alt_rounded,
            onPressed: onRestart,
          ),
          const SizedBox(height: 8),
          Text(
            'Restart ends this climb and starts a fresh one.',
            textAlign: TextAlign.center,
            style: SkyType.body(size: 11, color: SkyPalette.faint),
          ),
          const SizedBox(height: 14),
          const SkyHairline(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: SkyPalette.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sound',
                    style: SkyType.body(
                      size: 13.5,
                      color: SkyPalette.body,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  soundEnabled ? 'On' : 'Off',
                  style: SkyType.body(
                    size: 12,
                    color: soundEnabled
                        ? SkyPalette.mintInk
                        : SkyPalette.muted,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: soundEnabled,
                  onChanged: onToggleSound,
                  activeThumbColor: Colors.white,
                  activeTrackColor: SkyPalette.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: SkyPalette.track,
                ),
              ],
            ),
          ),
          const SkyHairline(),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 17,
                      color: SkyPalette.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Tilt controls',
                        style: SkyType.body(
                          size: 13.5,
                          color: SkyPalette.body,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRecalibrate,
                      style: TextButton.styleFrom(
                        foregroundColor: SkyPalette.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(
                        'Recalibrate',
                        style: SkyType.body(
                          size: 12,
                          color: SkyPalette.primary,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Text(
                      'Gentle',
                      style: SkyType.body(size: 11.5, color: SkyPalette.muted),
                    ),
                    Expanded(
                      child: Slider(
                        value: sensitivity.clamp(.5, 1.5),
                        min: .5,
                        max: 1.5,
                        divisions: 4,
                        onChanged: onSensitivityChanged,
                        activeColor: SkyPalette.cyan,
                        inactiveColor: SkyPalette.track,
                        label: '${(sensitivity * 100).round()}%',
                      ),
                    ),
                    Text(
                      'Fast',
                      style: SkyType.body(
                        size: 11.5,
                        color: SkyPalette.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SkyHairline(),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onHome,
            icon: const Icon(Icons.home_outlined, size: 17),
            label: const Text('Home'),
            style: TextButton.styleFrom(
              foregroundColor: SkyPalette.muted,
              textStyle: SkyType.body(
                size: 13,
                color: SkyPalette.muted,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: SkyType.label(size: 9.5)),
          const SizedBox(height: 4),
          Text(value, style: SkyType.number(size: 17)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: SkyPalette.border,
    );
  }
}
