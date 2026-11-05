import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/features/sky_balance/game_models.dart';
import 'package:recovera/features/sky_balance/sky_character.dart';
import 'package:recovera/features/sky_balance/widgets/sky_hud.dart';
import 'package:recovera/features/sky_balance/widgets/sky_lobby_view.dart';
import 'package:recovera/features/sky_balance/widgets/sky_result_view.dart';

const List<SkyCheckpoint> _checkpoints = <SkyCheckpoint>[
  SkyCheckpoint(progress: .25, label: 'TRAINING'),
  SkyCheckpoint(progress: .5, label: 'BALANCE'),
  SkyCheckpoint(progress: .75, label: 'CHALLENGE'),
];

Future<void> _pumpInPhone(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox.expand(child: child)),
      // The lobby and HUD use Google Fonts and SvgPicture; both must resolve
      // synchronously enough for a single pump in tests.
    ),
  );
  // SkyBackground runs a looping drift animation, so never pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  group('Sky Balance redesigned surfaces', () {
    testWidgets('Lobby fits a compact phone without overflow', (tester) async {
      await _pumpInPhone(
        tester,
        SkyLobbyView(
          character: SkyCharacter.katak,
          onCharacterSelected: (_) {},
          bestScore: 1240,
          totalFood: 86,
          checkpoints: _checkpoints,
          checkpointsReached: 0,
          nextCheckpointLabel: 'TRAINING',
          soundEnabled: true,
          onToggleSound: () {},
          onPlay: () {},
          onHowToPlay: () {},
          onExit: () {},
        ),
        size: const Size(320, 640),
      );

      expect(find.text('Sky Balance'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HUD renders score, food and checkpoint track', (tester) async {
      await _pumpInPhone(
        tester,
        SkyHud(
          score: 1240,
          foodCollected: 7,
          foodTotal: 20,
          energy: 85,
          progress: .34,
          checkpoints: _checkpoints,
          checkpointsReached: 1,
          nextCheckpointLabel: 'TRAINING',
          onPause: () {},
          dashAvailable: true,
          dashCooldown: 0,
          feedback: '+10 energy  +50 score',
          sensorWarning: false,
        ),
        size: const Size(320, 640),
      );

      expect(find.text('1,240'), findsOneWidget);
      expect(find.text('7/20'), findsOneWidget);
      expect(find.text('34%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Result surface shows score, food and reward', (tester) async {
      final SkyBalanceResult result = SkyBalanceResult.fromRun(
        won: true,
        score: 1860,
        foodCollected: 16,
        energyRemaining: 72,
        obstaclesHit: 2,
        checkpointsReached: 3,
        progress: 1,
      );

      await _pumpInPhone(
        tester,
        SkyResultView(
          character: SkyCharacter.katak,
          result: result,
          bestScore: 1860,
          foodTotal: 20,
          checkpointsTotal: 3,
          newBest: true,
          onPlayAgain: () {},
          onHome: () {},
        ),
        size: const Size(320, 640),
      );

      expect(find.text('Summit reached'), findsOneWidget);
      expect(find.text('1,860'), findsWidgets);
      expect(find.text('+50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
