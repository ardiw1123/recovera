import 'package:flutter/material.dart';

import '../game_models.dart';
import '../sky_balance_theme.dart';
import '../sky_character.dart';
import '../sky_format.dart';
import 'sky_common.dart';
import 'sky_controls.dart';

/// Shared result surface for an unsuccessful climb and for reaching the summit.
class SkyResultView extends StatelessWidget {
  const SkyResultView({
    super.key,
    required this.character,
    required this.result,
    required this.bestScore,
    required this.foodTotal,
    required this.checkpointsTotal,
    required this.newBest,
    required this.onPlayAgain,
    required this.onHome,
    this.lossCause,
    this.storageError,
  });

  final SkyCharacter character;
  final SkyBalanceResult result;
  final int bestScore;
  final int foodTotal;
  final int checkpointsTotal;
  final bool newBest;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
  final String? lossCause;
  final String? storageError;

  @override
  Widget build(BuildContext context) {
    final bool won = result.won;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          children: <Widget>[
            _Stage(character: character),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(SkyRadii.sheet),
                boxShadow: SkyShadows.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (won) ...<Widget>[
                    _StarRating(stars: result.stars),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Summit reached', style: _titleStyle),
                    ),
                  ] else ...<Widget>[
                    Text('Game over', style: _titleStyle),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.battery_alert_rounded,
                          size: 16,
                          color: SkyPalette.amber,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lossCause ?? 'The climb ended early.',
                            style: SkyType.body(
                              size: 12.5,
                              color: SkyPalette.amberInk,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'FINAL SCORE',
                              style: SkyType.label(size: 9.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatCount(result.score),
                              style: SkyType.number(size: 42).copyWith(
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (won && newBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: SkyPalette.mintSurface,
                            borderRadius: BorderRadius.circular(SkyRadii.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 12,
                                color: SkyPalette.mintInk,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'New best',
                                style: SkyType.body(
                                  size: 10.5,
                                  color: SkyPalette.mintInk,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'Best score ',
                          style: SkyType.body(
                            size: 12,
                            color: SkyPalette.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: formatCount(bestScore),
                          style: SkyType.number(
                            size: 12,
                            color: SkyPalette.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SkyHairline(),
                  SkyDataRow(
                    label: 'Food collected',
                    leading: const Text('🍎', style: TextStyle(fontSize: 15)),
                    value: '${result.foodCollected} / $foodTotal',
                  ),
                  const SkyHairline(),
                  SkyDataRow(
                    label: won ? 'Checkpoints' : 'Climb reached',
                    leading: Icon(
                      won ? Icons.flag_rounded : Icons.flag_outlined,
                      size: 16,
                      color: SkyPalette.primary,
                    ),
                    value: won
                        ? '${result.checkpointsReached} / $checkpointsTotal'
                        : '${(result.progress * 100).round()}%',
                    valueSubLabel: won
                        ? null
                        : '${result.checkpointsReached} of $checkpointsTotal checkpoints',
                    valueColor: won ? SkyPalette.mintInk : null,
                  ),
                  const SkyHairline(),
                  SkyDataRow(
                    label: 'Recovery points',
                    muted: !won,
                    leading: Icon(
                      Icons.redeem_rounded,
                      size: 16,
                      color: won ? SkyPalette.cyan : SkyPalette.faint,
                    ),
                    value: won
                        ? '+${result.recoveryPoints}'
                        : '0 this run',
                    valueColor: won ? SkyPalette.mintInk : null,
                  ),
                  const SizedBox(height: 16),
                  SkyPrimaryButton(
                    label: 'PLAY AGAIN',
                    icon: Icons.restart_alt_rounded,
                    onPressed: onPlayAgain,
                  ),
                  const SizedBox(height: 10),
                  SkySecondaryButton(
                    label: 'HOME',
                    icon: Icons.home_outlined,
                    height: 48,
                    onPressed: onHome,
                  ),
                  if (storageError != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'Result not saved: $storageError',
                      textAlign: TextAlign.center,
                      style: SkyType.body(
                        size: 11.5,
                        color: SkyPalette.amberInk,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _titleStyle => SkyType.strong(size: 22, height: 1.1).copyWith(
    fontWeight: FontWeight.w900,
    letterSpacing: -.3,
  );
}

class _Stage extends StatelessWidget {
  const _Stage({required this.character});

  final SkyCharacter character;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          SkyCharacterAvatar(character: character, size: 104),
          const Positioned(
            bottom: 0,
            child: SkyPlatform(width: 142, height: 20),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int index = 0; index < 3; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 32,
                  color: index < stars
                      ? SkyPalette.star
                      : SkyPalette.track,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$stars of 3 stars',
          style: SkyType.label(size: 10.5),
        ),
      ],
    );
  }
}
