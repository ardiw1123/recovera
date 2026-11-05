import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sky_balance_theme.dart';
import '../sky_character.dart';
import 'sky_common.dart';
import 'sky_controls.dart';

/// Sequential states of the single "Get ready" surface.
enum SkyReadyPhase { checking, unavailable, needsCalibration, calibrating, ready, countdown }

/// One preparation surface: sensor status, tilt calibration and the start
/// countdown all live here so the player never loses the scene.
class SkyReadyView extends StatelessWidget {
  const SkyReadyView({
    super.key,
    required this.character,
    required this.phase,
    required this.countdownLabel,
    required this.calibrated,
    required this.dashAvailable,
    required this.onBack,
    required this.onPrimary,
    required this.onRecalibrate,
    this.errorMessage,
  });

  final SkyCharacter character;
  final SkyReadyPhase phase;
  final String countdownLabel;
  final bool calibrated;
  final bool dashAvailable;
  final VoidCallback onBack;
  final VoidCallback onPrimary;
  final VoidCallback onRecalibrate;
  final String? errorMessage;

  String get _primaryLabel => switch (phase) {
    SkyReadyPhase.checking => 'CHECKING SENSORS…',
    SkyReadyPhase.unavailable => 'CHECK AGAIN',
    SkyReadyPhase.needsCalibration => 'SET TILT POSITION',
    SkyReadyPhase.calibrating => 'HOLD STEADY…',
    SkyReadyPhase.ready => 'START CLIMB',
    SkyReadyPhase.countdown => 'GET READY',
  };

  bool get _primaryEnabled =>
      phase == SkyReadyPhase.unavailable ||
      phase == SkyReadyPhase.needsCalibration ||
      phase == SkyReadyPhase.ready;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SkyWaveHeader(title: 'Get ready', onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              children: <Widget>[
                _Stage(character: character),
                const SizedBox(height: 18),
                _CalibrationRow(
                  phase: phase,
                  calibrated: calibrated,
                  onRecalibrate: onRecalibrate,
                ),
                const SizedBox(height: 10),
                SkySurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      _StatusRow(
                        icon: Icons.phone_android_rounded,
                        label: 'Tilt control',
                        value: switch (phase) {
                          SkyReadyPhase.checking => 'Checking…',
                          SkyReadyPhase.unavailable => 'Unavailable',
                          _ => 'Ready',
                        },
                        tone: switch (phase) {
                          SkyReadyPhase.checking => _Tone.neutral,
                          SkyReadyPhase.unavailable => _Tone.warning,
                          _ => _Tone.positive,
                        },
                      ),
                      const SkyHairline(),
                      _StatusRow(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Dash',
                        value: dashAvailable ? 'Ready' : 'Not on this phone',
                        tone: dashAvailable ? _Tone.positive : _Tone.warning,
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: SkyType.body(
                      size: 12.5,
                      color: SkyPalette.amberInk,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _PhaseRing(
                  phase: phase,
                  label: countdownLabel,
                  calibrated: calibrated,
                ),
                const SizedBox(height: 18),
                Text(
                  switch (phase) {
                    SkyReadyPhase.calibrating =>
                      'Hold your phone comfortably and keep it still.',
                    SkyReadyPhase.countdown =>
                      'The climb starts at GO.',
                    SkyReadyPhase.ready =>
                      'Tilt position saved. You are ready to climb.',
                    SkyReadyPhase.checking =>
                      'Checking your phone before the first jump.',
                    SkyReadyPhase.unavailable =>
                      'This phone needs an accelerometer to steer.',
                    _ => 'Hold your phone comfortably and keep it still.',
                  },
                  textAlign: TextAlign.center,
                  style: SkyType.body(
                    size: 13,
                    color: SkyPalette.body,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                if (phase != SkyReadyPhase.countdown)
                  SkyPrimaryButton(
                    label: _primaryLabel,
                    icon: phase == SkyReadyPhase.ready
                        ? Icons.vertical_align_top_rounded
                        : null,
                    onPressed: _primaryEnabled ? onPrimary : null,
                  )
                else
                  const SizedBox(height: 56),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.character});

  final SkyCharacter character;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 138,
          child: Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              SkyCharacterAvatar(character: character, size: 118),
              const Positioned(bottom: 0, child: SkyPlatform(width: 150)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(character.label, style: SkyType.strong(size: 14)),
      ],
    );
  }
}

class _CalibrationRow extends StatelessWidget {
  const _CalibrationRow({
    required this.phase,
    required this.calibrated,
    required this.onRecalibrate,
  });

  final SkyReadyPhase phase;
  final bool calibrated;
  final VoidCallback onRecalibrate;

  @override
  Widget build(BuildContext context) {
    final bool busy = phase == SkyReadyPhase.calibrating;
    final String label = calibrated
        ? 'Tilt position set'
        : switch (phase) {
            SkyReadyPhase.checking => 'Checking tilt control',
            SkyReadyPhase.calibrating => 'Setting tilt position',
            SkyReadyPhase.unavailable => 'Tilt position not set',
            _ => 'Tilt position not set yet',
          };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(SkyRadii.chip),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            calibrated
                ? Icons.check_circle_rounded
                : (phase == SkyReadyPhase.unavailable
                      ? Icons.error_outline_rounded
                      : Icons.screen_rotation_alt_rounded),
            size: 16,
            color: calibrated
                ? SkyPalette.mintInk
                : SkyPalette.faint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: SkyType.body(
                size: 12.5,
                color: SkyPalette.body,
                weight: FontWeight.w700,
              ),
            ),
          ),
          if (calibrated)
            TextButton(
              onPressed: busy ? null : onRecalibrate,
              style: TextButton.styleFrom(
                foregroundColor: SkyPalette.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
    );
  }
}

enum _Tone { positive, warning, neutral }

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      _Tone.positive => SkyPalette.mintInk,
      _Tone.warning => SkyPalette.amberInk,
      _Tone.neutral => SkyPalette.muted,
    };
    final Color dot = switch (tone) {
      _Tone.positive => SkyPalette.mint,
      _Tone.warning => SkyPalette.amber,
      _Tone.neutral => SkyPalette.faint,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: SkyPalette.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: SkyType.body(
                size: 13,
                color: SkyPalette.body,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            value,
            style: SkyType.body(size: 12, color: color, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PhaseRing extends StatelessWidget {
  const _PhaseRing({
    required this.phase,
    required this.label,
    required this.calibrated,
  });

  final SkyReadyPhase phase;
  final String label;
  final bool calibrated;

  /// 3 -> one third, 2 -> two thirds, 1 and GO -> full ring.
  static double _countdownProgress(String label) {
    final int? seconds = int.tryParse(label);
    if (seconds == null) return 1;
    if (seconds >= 3) return 1 / 3;
    if (seconds == 2) return 2 / 3;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final bool counting =
        phase == SkyReadyPhase.countdown || phase == SkyReadyPhase.calibrating;
    final String text = counting ? label : '';
    final bool showCheck = calibrated && phase == SkyReadyPhase.ready;

    // The ring fills as the count goes 3 -> 2 -> 1 -> GO, so the player can
    // see the countdown progressing instead of a frozen arc.
    final double progress = switch (phase) {
      SkyReadyPhase.countdown || SkyReadyPhase.calibrating =>
        _countdownProgress(label),
      _ => showCheck ? 1 : .12,
    };
    final Color ringColor = switch (phase) {
      SkyReadyPhase.unavailable => SkyPalette.amber,
      SkyReadyPhase.ready => SkyPalette.mint,
      _ => SkyPalette.cyan,
    };

    return SizedBox(
      width: 186,
      height: 186,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.linear,
            builder: (BuildContext context, double value, Widget? _) {
              return CustomPaint(
                size: const Size(186, 186),
                painter: _RingPainter(progress: value, color: ringColor),
              );
            },
          ),
          if (showCheck)
            Icon(
              Icons.check_rounded,
              size: 64,
              color: SkyPalette.mintInk,
            )
          else if (phase == SkyReadyPhase.checking)
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: SkyPalette.cyan,
              ),
            )
          else if (phase == SkyReadyPhase.unavailable)
            const Icon(
              Icons.screen_rotation_alt_rounded,
              size: 54,
              color: SkyPalette.amber,
            )
          else if (phase == SkyReadyPhase.needsCalibration)
            const Icon(
              Icons.screen_rotation_alt_rounded,
              size: 54,
              color: SkyPalette.cyan,
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  text.isEmpty ? '3' : text,
                  style: SkyType.number(
                    size: text == 'GO!' ? 46 : 66,
                    color: SkyPalette.ink,
                  ),
                ),
                if (text.isNotEmpty && text != 'GO!')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('SECONDS', style: SkyType.label(size: 10.5)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 7;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = SkyPalette.border,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
