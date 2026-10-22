import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Audio manager for the Sky Balance minigame.
/// Manages background music (BGM) and sound effects (SFX).
class SkyBalanceAudio {
  SkyBalanceAudio() {
    _initPlayers();
  }

  late final AudioPlayer _bgmPlayer;
  late final AudioPlayer _sfxPlayer;
  late final AudioPlayer _jumpPlayer;

  bool _enabled = true;
  bool _isBgmPlaying = false;

  bool get isEnabled => _enabled;
  set isEnabled(bool value) {
    _enabled = value;
    if (!_enabled) {
      stopBgm();
    }
  }

  void _initPlayers() {
    // Configure global audio context so music plays through media stream
    try {
      AudioPlayer.global.setAudioContext(AudioContextConfig().build());
    } catch (e) {
      debugPrint('SkyBalanceAudio: AudioContextConfig build failed: $e');
    }

    _bgmPlayer = AudioPlayer();
    _sfxPlayer = AudioPlayer();
    _jumpPlayer = AudioPlayer();

    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _bgmPlayer.setVolume(1.0);

    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    _sfxPlayer.setVolume(1.0);

    _jumpPlayer.setReleaseMode(ReleaseMode.stop);
    _jumpPlayer.setVolume(1.0);
  }

  /// Start playing looping background music
  Future<void> startBgm() async {
    if (!_enabled) return;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(1.0);
      await _bgmPlayer.play(
        AssetSource('audio/bgm.wav'),
        volume: 1.0,
        mode: PlayerMode.mediaPlayer,
      );
      _isBgmPlaying = true;
    } catch (e) {
      debugPrint('SkyBalanceAudio: Failed to play BGM - $e');
    }
  }

  /// Pause background music (e.g. when game paused)
  Future<void> pauseBgm() async {
    if (!_isBgmPlaying) return;
    try {
      await _bgmPlayer.pause();
    } catch (e) {
      debugPrint('SkyBalanceAudio: Failed to pause BGM - $e');
    }
  }

  /// Resume background music
  Future<void> resumeBgm() async {
    if (!_enabled) return;
    try {
      await _bgmPlayer.resume();
      _isBgmPlaying = true;
    } catch (e) {
      // Fallback: if resume fails, start afresh
      await startBgm();
    }
  }

  /// Stop background music (game over, victory, exit)
  Future<void> stopBgm() async {
    _isBgmPlaying = false;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('SkyBalanceAudio: Failed to stop BGM - $e');
    }
  }

  /// Play sound on countdown numbers (3, 2, 1)
  void playCountdownTick() {
    _playSound(_sfxPlayer, 'audio/countdown_tick.wav');
  }

  /// Play sound when countdown reaches GO!
  void playCountdownGo() {
    _playSound(_sfxPlayer, 'audio/countdown_go.wav');
  }

  /// Play sound when bouncing off a platform
  void playJump() {
    _playSound(_jumpPlayer, 'audio/jump.wav');
  }

  /// Play sound when gyroscope triggers a dash
  void playDash() {
    _playSound(_sfxPlayer, 'audio/dash.wav');
  }

  /// Play sound when food is collected
  void playCollect() {
    _playSound(_sfxPlayer, 'audio/collect.wav');
  }

  /// Play sound when hitting an obstacle
  void playHit() {
    _playSound(_sfxPlayer, 'audio/hit.wav');
  }

  /// Play sound when crossing a checkpoint
  void playCheckpoint() {
    _playSound(_sfxPlayer, 'audio/checkpoint.wav');
  }

  /// Play sound when game is over (falling or out of energy)
  void playGameOver() {
    stopBgm();
    _playSound(_sfxPlayer, 'audio/game_over.wav');
  }

  /// Play fanfare when player reaches the sky summit
  void playVictory() {
    stopBgm();
    _playSound(_sfxPlayer, 'audio/victory.wav');
  }

  void _playSound(AudioPlayer player, String assetPath) {
    if (!_enabled) return;
    try {
      unawaited(
        player.stop().then(
          (_) => player.play(
            AssetSource(assetPath),
            volume: 1.0,
            mode: PlayerMode.lowLatency,
          ),
        ),
      );
    } catch (e) {
      debugPrint('SkyBalanceAudio: Failed to play sound $assetPath - $e');
    }
  }

  /// Clean up all audio resources
  void dispose() {
    try {
      _bgmPlayer.dispose();
      _sfxPlayer.dispose();
      _jumpPlayer.dispose();
    } catch (e) {
      debugPrint('SkyBalanceAudio: Error disposing players - $e');
    }
  }
}
