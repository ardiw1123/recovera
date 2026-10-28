import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/components/flight_platform.dart';
import '../../game/components/flight_scene_painter.dart';
import '../../game/systems/physics_engine.dart';
import 'game_models.dart';
import 'game_storage.dart';
import 'sensor_controller.dart';
import 'sky_balance_audio.dart';
import 'sky_balance_theme.dart';
import 'sky_character.dart';
import 'widgets/sky_common.dart';
import 'widgets/sky_hud.dart';
import 'widgets/sky_lobby_view.dart';
import 'widgets/sky_pause_overlay.dart';
import 'widgets/sky_player_sprite.dart';
import 'widgets/sky_ready_view.dart';
import 'widgets/sky_result_view.dart';
import 'widgets/sky_tutorial_view.dart';

class SkyBalanceScreen extends StatefulWidget {
  const SkyBalanceScreen({super.key, this.isActive = true, this.onExit});

  final bool isActive;
  final VoidCallback? onExit;

  @override
  State<SkyBalanceScreen> createState() => _SkyBalanceScreenState();
}

class _SkyBalanceScreenState extends State<SkyBalanceScreen>
    with WidgetsBindingObserver {
  final SensorController _sensor = SensorController();
  final GameStorage _storage = GameStorage();
  final SkyBalanceAudio _audio = SkyBalanceAudio();
  final SkyBalanceLevel _level = SkyBalanceLevel.firstJump;
  final PhysicsEngine _physics = const PhysicsEngine();
  final PhysicsBody _body = PhysicsBody(
    x: 195,
    y: FlightWorldLayout.startY - 14,
  );
  SkyBalanceStage _stage = SkyBalanceStage.menu;
  SensorAvailability? _sensorAvailability;
  Timer? _gameTimer;
  Timer? _countdownTimer;
  Timer? _feedbackTimer;
  DateTime? _lastTick;
  String _countdownLabel = '3';
  String? _sensorError;
  String? _storageError;
  String _feedback = '';
  String? _lossCause;
  SkyCharacter _character = SkyCharacter.katak;
  int _bestScore = 0;
  int _totalFood = 0;
  bool _soundEnabled = true;
  bool _checkingSensors = false;
  bool _calibrating = false;
  bool _calibrationComplete = false;
  bool _recalibrateAndResume = false;
  bool _tutorialFromMenu = false;
  bool _resultSaved = false;
  bool _newBestScore = false;
  bool _ending = false;
  double _progress = 0;
  double _elapsedSeconds = 0;
  double _energy = 100;
  double _score = 0;
  double _collisionCooldown = 0;
  double _dashCooldown = 0;
  double _cameraY = FlightWorldLayout.startY - 420;
  double _worldHeight = 720;
  double _heightReached = 0;
  int _foodCollected = 0;
  int _obstaclesHit = 0;
  int _checkpointsReached = 0;
  int _lastLandingCount = 0;
  SkyBalanceResult? _result;
  final Set<int> _collectedFoods = <int>{};
  final Map<int, DateTime> _collectingFoods = <int, DateTime>{};
  final Set<int> _passedObstacles = <int>{};
  final Set<int> _passedCheckpoints = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.isActive &&
          _soundEnabled &&
          _stage == SkyBalanceStage.menu) {
        _audio.startBgm();
      }
    });
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _sensor.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _stage == SkyBalanceStage.playing) {
      _pauseGame();
    }
  }

  // ── Profile (best score, lifetime food, selected character) ───────────────

  Future<void> _loadProfile() async {
    try {
      final int best = await _storage.bestScore;
      final int food = await _storage.totalFood;
      final String? characterId = await _storage.characterId;
      if (!mounted) return;
      setState(() {
        _bestScore = best;
        _totalFood = food;
        _character = SkyCharacter.fromId(characterId);
      });
    } on Object catch (error) {
      debugPrint('SkyBalance: could not load profile: $error');
    }
  }

  void _selectCharacter(SkyCharacter character) {
    if (character == _character) return;
    setState(() => _character = character);
    unawaited(_storage.saveCharacterId(character.id));
  }

  // ── Flow ─────────────────────────────────────────────────────────────────

  Future<void> _pressPlay() async {
    await _openSensorCheck();
  }

  Future<void> _openSensorCheck() async {
    setState(() {
      _stage = SkyBalanceStage.sensorCheck;
      _sensorError = null;
      _checkingSensors = true;
    });
    try {
      final SensorAvailability availability = await _sensor.checkAvailability();
      if (!mounted) return;
      setState(() {
        _sensorAvailability = availability;
        _checkingSensors = false;
      });
      if (!availability.accelerometer) {
        setState(
          () =>
              _sensorError = 'Motion sensors are not available on this device.',
        );
      } else if (!availability.gyroscope) {
        setState(
          () => _sensorError = 'Gyroscope unavailable. Dash is disabled.',
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingSensors = false;
        _sensorError = 'Unable to check motion sensors: $error';
      });
    }
  }

  Future<void> _beginCalibration({bool resumeAfter = false}) async {
    if (_sensorAvailability?.accelerometer != true) {
      await _openSensorCheck();
      return;
    }
    if (resumeAfter) {
      _gameTimer?.cancel();
      _gameTimer = null;
      _sensor.stopListening();
      _audio.stopBgm();
    }
    _countdownTimer?.cancel();
    _recalibrateAndResume = resumeAfter;
    setState(() {
      _stage = SkyBalanceStage.calibration;
      _countdownLabel = '3';
      _sensorError = null;
      _calibrating = true;
      _calibrationComplete = false;
    });

    final Future<void> calibration = _sensor.calibrate();
    for (var remaining = 2; remaining >= 1; remaining--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _countdownLabel = '$remaining');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    try {
      await calibration;
      if (!mounted) return;
      setState(() {
        _calibrating = false;
        _calibrationComplete = true;
      });
      if (_recalibrateAndResume) {
        _resumeAfterCalibration();
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _calibrating = false;
        _sensorError = 'Calibration could not finish: $error';
      });
    }
  }

  void _startCountdown() {
    _gameTimer?.cancel();
    _sensor.stopListening();
    _audio.stopBgm();
    setState(() {
      _stage = SkyBalanceStage.countdown;
      _countdownLabel = '3';
    });
    _audio.playCountdownTick();
    var remaining = 3;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      remaining--;
      if (remaining > 0) {
        if (mounted) {
          setState(() => _countdownLabel = '$remaining');
          _audio.playCountdownTick();
        }
      } else {
        timer.cancel();
        if (!mounted) return;
        setState(() => _countdownLabel = 'GO!');
        _audio.playCountdownGo();
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          _startGame();
        });
      }
    });
  }

  void _startGame() {
    _resetRun();
    _body.velocityY = BalanceConfig.jumpImpulse;
    _body.isJumping = true;
    _audio.playJump();
    _audio.stopBgm();
    setState(() => _stage = SkyBalanceStage.playing);
    _lastTick = DateTime.now();
    _sensor.startListening(onDash: _triggerDash);
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _resetRun() {
    _progress = 0;
    _elapsedSeconds = 0;
    _lastLandingCount = 0;
    _body.reset(
      x: FlightWorldLayout.worldWidth / 2,
      y: FlightWorldLayout.startY - _body.radius,
    );
    _energy = 100;
    _score = 0;
    _collisionCooldown = 0;
    _dashCooldown = 0;
    _foodCollected = 0;
    _obstaclesHit = 0;
    _checkpointsReached = 0;
    _heightReached = 0;
    _cameraY = FlightWorldLayout.startY - _worldHeight * .62;
    _result = null;
    _lossCause = null;
    _storageError = null;
    _resultSaved = false;
    _newBestScore = false;
    _ending = false;
    _collectedFoods.clear();
    _collectingFoods.clear();
    _passedObstacles.clear();
    _passedCheckpoints.clear();
  }

  void _tick(Timer timer) {
    if (!mounted || _stage != SkyBalanceStage.playing) return;
    final DateTime now = DateTime.now();
    final double dt =
        (_lastTick == null
                ? .033
                : now.difference(_lastTick!).inMicroseconds / 1000000)
            .clamp(0.0, .08)
            .toDouble();
    _lastTick = now;
    if (dt <= 0) return;
    _collectingFoods.removeWhere(
      (_, DateTime collectedAt) =>
          now.difference(collectedAt) >= const Duration(milliseconds: 360),
    );

    final MotionInput input = _sensor.input;
    _elapsedSeconds += dt;
    _dashCooldown = math.max(0, _dashCooldown - dt).toDouble();
    _collisionCooldown = math.max(0, _collisionCooldown - dt).toDouble();

    final int prevLandings = _lastLandingCount;
    _physics.step(
      body: _body,
      deltaSeconds: dt,
      horizontalTilt: input.horizontal,
      platforms: FlightWorldLayout.platforms,
    );
    if (_body.landingCount > prevLandings) {
      _lastLandingCount = _body.landingCount;
      _audio.playJump();
    }
    final double height = math
        .max(0, FlightWorldLayout.startY - _body.y)
        .toDouble();
    if (height > _heightReached) {
      _score += height - _heightReached;
      _heightReached = height;
    }
    _progress = (_heightReached / FlightWorldLayout.finishHeight)
        .clamp(0.0, 1.0)
        .toDouble();
    _cameraY = math.min(_cameraY, _body.y - _worldHeight * .62).toDouble();

    _checkFood();
    _checkObstacles();
    _checkCheckpoints();
    if (_body.grounded) {
      _body.jumpScale = (_body.jumpScale - 0.08).clamp(1.0, 1.3).toDouble();
      _body.shadowOffset = (_body.shadowOffset - 0.12)
          .clamp(0.0, 1.0)
          .toDouble();
    } else {
      _body.jumpScale = (_body.jumpScale + 0.05).clamp(1.0, 1.25).toDouble();
      _body.shadowOffset = (_body.shadowOffset + 0.1)
          .clamp(0.0, 1.0)
          .toDouble();
    }
    if (_energy <= 0) {
      _endRun(won: false, cause: 'Energy reached 0');
    } else if (_body.y <= FlightWorldLayout.finishY) {
      _progress = 1;
      _endRun(won: true);
    } else if (_body.y > _cameraY + _worldHeight + _body.radius) {
      _endRun(won: false, cause: 'You fell below the platforms');
    } else if (mounted) {
      setState(() {});
    }
  }

  void _checkFood() {
    for (var index = 0; index < _level.food.length; index++) {
      final FoodItem food = _level.food[index];
      if (_collectedFoods.contains(index)) {
        continue;
      }
      final WorldPoint position = FlightWorldLayout.foodPosition(food);
      if ((_body.x - position.x).abs() < 30 &&
          (_body.y - position.y).abs() < 34) {
        _collectedFoods.add(index);
        _collectingFoods[index] = DateTime.now();
        _foodCollected++;
        _energy = recoverEnergy(_energy.round(), food.energy).toDouble();
        _score += food.score;
        _showFeedback('+${food.energy} energy  +${food.score} score');
        _audio.playCollect();
        _playFeedback();
      }
    }
  }

  void _checkObstacles() {
    for (var index = 0; index < _level.obstacles.length; index++) {
      final SkyObstacle obstacle = _level.obstacles[index];
      if (_passedObstacles.contains(index)) continue;
      final double obstacleX = _obstacleX(obstacle, index);
      final WorldPoint position = FlightWorldLayout.obstaclePosition(
        obstacle,
        obstacleX,
      );
      if ((_body.x - position.x).abs() > 32 ||
          (_body.y - position.y).abs() > 32) {
        continue;
      }
      _passedObstacles.add(index);
      _applyDamage(15);
    }
  }

  double _obstacleX(SkyObstacle obstacle, int index) {
    if (obstacle.kind != ObstacleKind.moving) return obstacle.x;
    return obstacle.x + math.sin(_elapsedSeconds * 1.8 + index) * .22;
  }

  void _checkCheckpoints() {
    for (var index = 0; index < _level.checkpoints.length; index++) {
      final SkyCheckpoint checkpoint = _level.checkpoints[index];
      if (_passedCheckpoints.contains(index) ||
          _progress < checkpoint.progress) {
        continue;
      }
      _passedCheckpoints.add(index);
      _checkpointsReached++;
      _score += 100;
      _showFeedback('Checkpoint reached: ${checkpoint.label}');
      _audio.playCheckpoint();
      _playFeedback();
    }
  }

  void _applyDamage(int amount) {
    if (_collisionCooldown > 0) return;
    _energy = math.max(0, _energy - amount).toDouble();
    _score = math.max(0, _score - 50).toDouble();
    _obstaclesHit++;
    _collisionCooldown = 1.15;
    _showFeedback('-$amount energy');
    _audio.playHit();
    _playFeedback();
  }

  void _triggerDash(int direction) {
    if (!mounted || _stage != SkyBalanceStage.playing || _dashCooldown > 0) {
      return;
    }
    _dashCooldown = 2;
    _body.velocityX += direction * 180;
    _body.velocityY -= 30;
    _body.grounded = false;
    _showFeedback(direction < 0 ? 'Dash left' : 'Dash right');
    _audio.playDash();
    _playFeedback();
    setState(() {});
  }

  void _showFeedback(String message) {
    _feedbackTimer?.cancel();
    _feedback = message;
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _feedback = '');
    });
  }

  void _toggleSound() {
    setState(() {
      _soundEnabled = !_soundEnabled;
      _audio.isEnabled = _soundEnabled;
      if (_soundEnabled && _stage == SkyBalanceStage.menu) {
        _audio.startBgm();
      }
    });
  }

  void _playFeedback() {
    if (_soundEnabled) unawaited(SystemSound.play(SystemSoundType.click));
  }

  void _pauseGame() {
    _gameTimer?.cancel();
    _gameTimer = null;
    _sensor.stopListening();
    _audio.stopBgm();
    if (mounted) setState(() => _stage = SkyBalanceStage.paused);
  }

  void _resumeGame() {
    setState(() => _stage = SkyBalanceStage.playing);
    _lastTick = DateTime.now();
    _sensor.startListening(onDash: _triggerDash);
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _resumeAfterCalibration() {
    setState(() {
      _stage = SkyBalanceStage.playing;
      _recalibrateAndResume = false;
    });
    _lastTick = DateTime.now();
    _sensor.startListening(onDash: _triggerDash);
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _endRun({required bool won, String? cause}) {
    if (_ending) return;
    _ending = true;
    _gameTimer?.cancel();
    _gameTimer = null;
    _sensor.stopListening();
    _audio.stopBgm();
    _lossCause = won ? null : cause;
    if (won) {
      _score += 500;
      _audio.playVictory();
    } else {
      _audio.playGameOver();
    }
    _result = SkyBalanceResult.fromRun(
      won: won,
      score: _score.round(),
      foodCollected: _foodCollected,
      energyRemaining: _energy.round(),
      obstaclesHit: _obstaclesHit,
      checkpointsReached: _checkpointsReached,
      progress: _progress,
    );
    setState(
      () => _stage = won ? SkyBalanceStage.victory : SkyBalanceStage.gameOver,
    );
    unawaited(_saveResult());
  }

  Future<void> _saveResult() async {
    final SkyBalanceResult? result = _result;
    if (result == null || _resultSaved) return;
    _resultSaved = true;
    try {
      final bool isNewBest = await _storage.recordResult(result);
      final int best = await _storage.bestScore;
      final int food = await _storage.totalFood;
      if (!mounted) return;
      setState(() {
        _newBestScore = isNewBest;
        _bestScore = best;
        _totalFood = food;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _storageError = '$error');
    }
  }

  Future<void> _retry() async {
    setState(() {
      _tutorialFromMenu = false;
      _result = null;
      _stage = SkyBalanceStage.sensorCheck;
      _sensorError = null;
    });
    await _openSensorCheck();
  }

  void _returnToMenu() {
    setState(() {
      _stage = SkyBalanceStage.menu;
      _tutorialFromMenu = false;
    });
    _audio.startBgm();
    unawaited(_loadProfile());
  }

  void _exitToRecovera() {
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _sensor.stopListening();
    _audio.stopBgm();
    if (widget.onExit != null) {
      widget.onExit!();
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  void _openTutorial() {
    setState(() {
      _tutorialFromMenu = true;
      _stage = SkyBalanceStage.tutorial;
    });
  }

  // ── Derived state ────────────────────────────────────────────────────────

  String get _nextCheckpointLabel {
    final int reached = _passedCheckpoints.length;
    if (reached >= _level.checkpoints.length) return 'SUMMIT';
    return _level.checkpoints[reached].label;
  }

  SkyReadyPhase get _readyPhase {
    if (_stage == SkyBalanceStage.countdown) return SkyReadyPhase.countdown;
    if (_checkingSensors || _sensorAvailability == null) {
      return SkyReadyPhase.checking;
    }
    if (_sensorAvailability!.accelerometer != true) {
      return SkyReadyPhase.unavailable;
    }
    if (_calibrating) return SkyReadyPhase.calibrating;
    if (!_calibrationComplete) return SkyReadyPhase.needsCalibration;
    return SkyReadyPhase.ready;
  }

  void _handleReadyPrimary() {
    switch (_readyPhase) {
      case SkyReadyPhase.unavailable:
        unawaited(_openSensorCheck());
      case SkyReadyPhase.needsCalibration:
        unawaited(_beginCalibration());
      case SkyReadyPhase.ready:
        _startCountdown();
      case SkyReadyPhase.checking:
      case SkyReadyPhase.calibrating:
      case SkyReadyPhase.countdown:
        break;
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkyPalette.skyTop,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: switch (_stage) {
          SkyBalanceStage.playing => _buildGameplay(),
          SkyBalanceStage.paused => _buildPaused(),
          SkyBalanceStage.gameOver ||
          SkyBalanceStage.victory ||
          SkyBalanceStage.result => _buildResult(),
          SkyBalanceStage.tutorial ||
          SkyBalanceStage.introduction => _buildTutorial(),
          SkyBalanceStage.sensorCheck ||
          SkyBalanceStage.calibration ||
          SkyBalanceStage.countdown => _buildReady(),
          SkyBalanceStage.menu => _buildLobby(),
        },
      ),
    );
  }

  Widget _buildLobby() {
    return SkyBackground(
      key: const ValueKey<String>('lobby'),
      child: SafeArea(
        top: false,
        child: SkyLobbyView(
          character: _character,
          onCharacterSelected: _selectCharacter,
          bestScore: _bestScore,
          totalFood: _totalFood,
          checkpoints: _level.checkpoints,
          checkpointsReached: _passedCheckpoints.length,
          nextCheckpointLabel: _nextCheckpointLabel,
          soundEnabled: _soundEnabled,
          onToggleSound: _toggleSound,
          onPlay: () => unawaited(_pressPlay()),
          onHowToPlay: _openTutorial,
          onExit: _exitToRecovera,
        ),
      ),
    );
  }

  Widget _buildTutorial() {
    return SkyBackground(
      key: const ValueKey<String>('tutorial'),
      child: SafeArea(
        top: false,
        child: SkyTutorialView(
          onBack: _returnToMenu,
          primaryLabel: _tutorialFromMenu ? 'GOT IT' : 'CHECK MY PHONE',
          onPrimary: _tutorialFromMenu
              ? _returnToMenu
              : () => unawaited(_openSensorCheck()),
          dashAvailable: _sensorAvailability?.gyroscope ?? false,
        ),
      ),
    );
  }

  Widget _buildReady() {
    return SkyBackground(
      key: const ValueKey<String>('ready'),
      child: SafeArea(
        top: false,
        child: SkyReadyView(
          character: _character,
          phase: _readyPhase,
          countdownLabel: _countdownLabel,
          calibrated: _calibrationComplete,
          dashAvailable: _sensorAvailability?.gyroscope ?? false,
          onBack: _returnToMenu,
          onPrimary: _handleReadyPrimary,
          onRecalibrate: () => unawaited(_beginCalibration()),
          errorMessage: _sensorError,
        ),
      ),
    );
  }

  Widget _buildGameplay() {
    return LayoutBuilder(
      key: const ValueKey<String>('gameplay'),
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale =
            constraints.maxWidth / FlightWorldLayout.worldWidth;
        _worldHeight = constraints.maxHeight / scale;
        _cameraY = math.min(_cameraY, _body.y - _worldHeight * .62).toDouble();
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _buildScene(includePlayerAvatar: false),
            SkyPlayerSprite(
              character: _character,
              body: _body,
              cameraY: _cameraY,
              scale: scale,
            ),
            SkyHud(
              score: _score.round(),
              foodCollected: _foodCollected,
              foodTotal: _level.food.length,
              energy: _energy.round(),
              progress: _progress,
              checkpoints: _level.checkpoints,
              checkpointsReached: _checkpointsReached,
              nextCheckpointLabel: _nextCheckpointLabel,
              onPause: _pauseGame,
              dashAvailable: _sensor.gyroscopeAvailable,
              dashCooldown: _dashCooldown,
              feedback: _feedback,
              sensorWarning: _sensor.signalLost,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaused() {
    return LayoutBuilder(
      key: const ValueKey<String>('paused'),
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale =
            constraints.maxWidth / FlightWorldLayout.worldWidth;
        _worldHeight = constraints.maxHeight / scale;
        _cameraY = math.min(_cameraY, _body.y - _worldHeight * .62).toDouble();
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _buildScene(includePlayerAvatar: false),
            SkyPlayerSprite(
              character: _character,
              body: _body,
              cameraY: _cameraY,
              scale: scale,
            ),
            SkyPauseOverlay(
              score: _score.round(),
              foodCollected: _foodCollected,
              foodTotal: _level.food.length,
              energy: _energy.round(),
              percentage: (_progress * 100).floor().clamp(0, 100),
              soundEnabled: _soundEnabled,
              onToggleSound: (bool value) {
                if (value != _soundEnabled) _toggleSound();
              },
              sensitivity: _sensor.sensitivity,
              onSensitivityChanged: (double value) {
                setState(() => _sensor.sensitivity = value);
              },
              onResume: _resumeGame,
              onRestart: _startCountdown,
              onHome: _returnToMenu,
              onRecalibrate: () =>
                  unawaited(_beginCalibration(resumeAfter: true)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScene({bool includePlayerAvatar = true}) {
    return CustomPaint(
      painter: FlightScenePainter(
        level: _level,
        body: _body,
        cameraY: _cameraY,
        progress: _progress,
        elapsedSeconds: _elapsedSeconds,
        collectedFoods: _collectedFoods,
        collectingFoods: _collectingFoods,
        passedCheckpoints: _passedCheckpoints,
        drawPlayerSprite: includePlayerAvatar,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildResult() {
    final SkyBalanceResult? result = _result;
    if (result == null) return _buildLobby();
    return SkyBackground(
      key: const ValueKey<String>('result'),
      child: SkyResultView(
        character: _character,
        result: result,
        bestScore: math.max(_bestScore, result.score),
        foodTotal: _level.food.length,
        checkpointsTotal: _level.checkpoints.length,
        newBest: _newBestScore,
        lossCause: _lossCause,
        storageError: _storageError,
        onPlayAgain: () => unawaited(_retry()),
        onHome: _returnToMenu,
      ),
    );
  }
}
