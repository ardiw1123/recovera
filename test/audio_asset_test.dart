import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Verify all audio assets can be loaded by rootBundle', () async {
    const assets = [
      'assets/audio/bgm.wav',
      'assets/audio/jump.wav',
      'assets/audio/dash.wav',
      'assets/audio/collect.wav',
      'assets/audio/hit.wav',
      'assets/audio/game_over.wav',
      'assets/audio/victory.wav',
      'assets/audio/checkpoint.wav',
      'assets/audio/countdown_tick.wav',
      'assets/audio/countdown_go.wav',
    ];

    for (final path in assets) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0));
    }
  });
}
