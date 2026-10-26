import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game_models.dart';
import '../sky_balance_theme.dart';
import '../sky_format.dart';
import 'sky_controls.dart';

/// Minimal gameplay overlay: score, food, climb progress, energy and pause.
/// Nothing sits in the middle of the screen where the next landing will be.
class SkyHud extends StatelessWidget {
  const SkyHud({
    super.key,
    required this.score,
    required this.foodCollected,
    required this.foodTotal,
    required this.energy,
    required this.progress,
    required this.checkpoints,
    required this.checkpointsReached,
    required this.nextCheckpointLabel,
    required this.onPause,
    required this.dashAvailable,
    required this.dashCooldown,
    required this.feedback,
    required this.sensorWarning,
  });

  final int score;
  final int foodCollected;
  final int foodTotal;
  final int energy;
  final double progress;
  final List<SkyCheckpoint> checkpoints;
  final int checkpointsReached;
  final String nextCheckpointLabel;
  final VoidCallback onPause;
  final bool dashAvailable;
  final double dashCooldown;
  final String feedback;
  final bool sensorWarning;

  @override
  Widget build(BuildContext context) {
    final int percentage = (progress * 100).floor().clamp(0, 100);
    final bool lowEnergy = energy < 30;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: <Widget>[
                            SkyPill(
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    'SCORE',
                                    style: SkyType.label(size: 9.5),
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    formatCount(score),
                                    style: SkyType.number(size: 19),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 9),
                            SkyPill(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    '🍎',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$foodCollected/$foodTotal',
                                    style: SkyType.number(size: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    SkyPill(
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          onPressed: onPause,
                          tooltip: 'Pause',
                          icon: const Icon(Icons.pause_rounded, size: 20),
                          color: SkyPalette.primary,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(SkyRadii.chip),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'NEXT: ${nextCheckpointLabel.toUpperCase()}',
                              style: SkyType.label(
                                size: 10,
                                color: SkyPalette.primary,
                              ),
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: SkyType.number(
                              size: 11,
                              color: SkyPalette.body,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClimbTrack(
                        progress: progress,
                        checkpoints: checkpoints,
                        reached: checkpointsReached,
                        dotSize: 10,
                        trackHeight: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 186,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(SkyRadii.pill),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text('ENERGY', style: SkyType.label(size: 9.5)),
                      const SizedBox(width: 8),
                      Text(
                        '$energy',
                        style: SkyType.number(
                          size: 12.5,
                          color: SkyPalette.body,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(SkyRadii.pill),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: (energy / 100).clamp(0.0, 1.0),
                            color: lowEnergy
                                ? SkyPalette.amber
                                : SkyPalette.cyan,
                            backgroundColor: SkyPalette.track,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (feedback.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Center(
                    child: SkyPill(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: Text(
                          feedback,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SkyType.strong(
                            size: 12,
                            color: SkyPalette.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (sensorWarning) ...<Widget>[
                  const SizedBox(height: 10),
                  SkyPill(
                    background: SkyPalette.amberSurface,
                    opacity: 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 256),
                      child: Text(
                        'Motion sensor signal lost. Hold your phone steady.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SkyType.body(
                          size: 12,
                          color: SkyPalette.amberInk,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (dashAvailable)
            Positioned(
              left: 16,
              bottom: 18,
              child: SkyPill(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: dashCooldown <= 0
                          ? SkyPalette.cyan
                          : SkyPalette.faint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      dashCooldown <= 0
                          ? 'DASH READY'
                          : 'DASH ${dashCooldown.ceil()}s',
                      style: SkyType.label(
                        size: 9.5,
                        color: dashCooldown <= 0
                            ? SkyPalette.primary
                            : SkyPalette.faint,
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
}
