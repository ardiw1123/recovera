import 'package:flutter/material.dart';

import '../../../game/systems/physics_engine.dart';
import '../sky_character.dart';
import 'sky_controls.dart';

/// The character that actually jumps in the scene: the avatar the player
/// picked, framed in the same circle used in the lobby.
///
/// Only the visual changes with the avatar — the physics radius stays the
/// same for every character, so difficulty never shifts.
class SkyPlayerSprite extends StatelessWidget {
  const SkyPlayerSprite({
    super.key,
    required this.character,
    required this.body,
    required this.cameraY,
    required this.scale,
  });

  final SkyCharacter character;
  final PhysicsBody body;
  final double cameraY;
  final double scale;

  /// Diameter of the portrait in world pixels.
  static const double worldDiameter = 40;

  @override
  Widget build(BuildContext context) {
    final double size = worldDiameter * scale;
    final double left = body.x * scale - size / 2;
    final double top = (body.y - cameraY) * scale - size / 2;

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: (body.velocityX * .001).clamp(-.3, .3),
          child: Transform.scale(
            scale: body.jumpScale,
            child: SkyCharacterAvatar(character: character, size: size),
          ),
        ),
      ),
    );
  }
}
