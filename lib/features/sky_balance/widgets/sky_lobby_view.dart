import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game_models.dart';
import '../sky_balance_theme.dart';
import '../sky_character.dart';
import '../sky_format.dart';
import 'sky_common.dart';
import 'sky_controls.dart';

/// The game lobby: the selected character on its starting platform, the
/// character picker, this profile's records and the climb ahead.
class SkyLobbyView extends StatelessWidget {
  const SkyLobbyView({
    super.key,
    required this.character,
    required this.onCharacterSelected,
    required this.bestScore,
    required this.totalFood,
    required this.checkpoints,
    required this.checkpointsReached,
    required this.nextCheckpointLabel,
    required this.soundEnabled,
    required this.onToggleSound,
    required this.onPlay,
    required this.onHowToPlay,
    required this.onExit,
  });

  final SkyCharacter character;
  final ValueChanged<SkyCharacter> onCharacterSelected;
  final int bestScore;
  final int totalFood;
  final List<SkyCheckpoint> checkpoints;
  final int checkpointsReached;
  final String nextCheckpointLabel;
  final bool soundEnabled;
  final VoidCallback onToggleSound;
  final VoidCallback onPlay;
  final VoidCallback onHowToPlay;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SkyWaveHeader(
          title: 'Sky Balance',
          titleSize: 24,
          leading: SizedBox(
            width: 30,
            height: 30,
            child: SvgPicture.asset(SkyCharacter.katak.asset),
          ),
          actions: <Widget>[
            SkyCircleIconButton(
              icon: Icons.volume_up_rounded,
              tooltip: 'Sound on',
              onPressed: onToggleSound,
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double stage = (constraints.maxHeight * .29).clamp(
                116.0,
                176.0,
              );
              return Column(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Column(
                        children: <Widget>[
                          _CharacterStage(
                            character: character,
                            size: stage,
                          ),
                          const SizedBox(height: 16),
                          _CharacterPicker(
                            character: character,
                            onSelected: onCharacterSelected,
                          ),
                          const SizedBox(height: 18),
                          _RecordsRow(
                            bestScore: bestScore,
                            totalFood: totalFood,
                          ),
                          const SizedBox(height: 16),
                          _ClimbAheadCard(
                            checkpoints: checkpoints,
                            reached: checkpointsReached,
                            nextLabel: nextCheckpointLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                    child: Column(
                      children: <Widget>[
                        SkyPrimaryButton(
                          label: 'PLAY',
                          icon: Icons.play_arrow_rounded,
                          height: 58,
                          onPressed: onPlay,
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SkyTextAction(
                                label: 'How to play',
                                icon: Icons.help_outline_rounded,
                                color: SkyPalette.primary,
                                onPressed: onHowToPlay,
                              ),
                              const SizedBox(
                                height: 13,
                                child: VerticalDivider(
                                  width: 18,
                                  thickness: 1,
                                  color: Color(0xFFC6E2F2),
                                ),
                              ),
                              SkyTextAction(
                                label: 'Back to Recovera',
                                onPressed: onExit,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CharacterStage extends StatelessWidget {
  const _CharacterStage({required this.character, required this.size});

  final SkyCharacter character;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size + 26,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          SkyCharacterAvatar(character: character, size: size),
          Positioned(
            bottom: 0,
            child: SkyPlatform(width: size + 36, height: 26),
          ),
        ],
      ),
    );
  }
}

class _CharacterPicker extends StatelessWidget {
  const _CharacterPicker({required this.character, required this.onSelected});

  final SkyCharacter character;
  final ValueChanged<SkyCharacter> onSelected;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final SkyCharacter option in SkyCharacter.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              button: true,
              selected: option == character,
              label: 'Choose ${option.label}',
              child: InkResponse(
                onTap: () => onSelected(option),
                radius: 32,
                containedInkWell: true,
                customBorder: const CircleBorder(),
                  child: SkyCharacterAvatar(
                    character: option,
                    size: option == character ? 52 : 44,
                    selected: option == character,
                    showSelectionBadge: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordsRow extends StatelessWidget {
  const _RecordsRow({required this.bestScore, required this.totalFood});

  final int bestScore;
  final int totalFood;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.emoji_events_outlined,
            size: 16,
            color: SkyPalette.cyan,
          ),
          const SizedBox(width: 6),
          Text(
            'Best score',
            style: SkyType.body(size: 12.5, weight: FontWeight.w600),
          ),
          const SizedBox(width: 7),
          Text(formatCount(bestScore), style: SkyType.number(size: 13.5)),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFC6E2F2),
          ),
          Text('🍎', style: GoogleFonts.inter(fontSize: 14, height: 1)),
          const SizedBox(width: 6),
          Text(
            'Food collected',
            style: SkyType.body(size: 12.5, weight: FontWeight.w600),
          ),
          const SizedBox(width: 7),
          Text(formatCount(totalFood), style: SkyType.number(size: 13.5)),
        ],
      ),
    );
  }
}

class _ClimbAheadCard extends StatelessWidget {
  const _ClimbAheadCard({
    required this.checkpoints,
    required this.reached,
    required this.nextLabel,
  });

  final List<SkyCheckpoint> checkpoints;
  final int reached;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final int total = checkpoints.length;
    final double progress = total == 0 ? 0 : reached / total;

    return SkySurfaceCard(
      opacity: .85,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('FIRST CLIMB', style: SkyType.label(size: 10.5)),
                    const SizedBox(height: 5),
                    Text(
                      'Next: $nextLabel',
                      style: SkyType.strong(size: 15),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '$reached / $total',
                    style: SkyType.number(
                      size: 15,
                      color: SkyPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'checkpoints',
                    style: SkyType.body(
                      size: 10.5,
                      color: SkyPalette.muted,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClimbTrack(
            progress: progress,
            checkpoints: checkpoints,
            reached: reached,
          ),
        ],
      ),
    );
  }
}
