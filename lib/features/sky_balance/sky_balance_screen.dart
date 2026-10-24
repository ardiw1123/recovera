import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../game/components/flight_platform.dart';
import '../../game/components/flight_scene_painter.dart';
import '../../game/systems/physics_engine.dart';
import 'game_models.dart';
import 'game_storage.dart';
import 'sensor_controller.dart';
import 'sky_balance_audio.dart';

class SkyBalanceScreen extends StatefulWidget {
  const SkyBalanceScreen({super.key});

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
  String _checkpointLabel = 'START';
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
  int? _lastDashDirection;
  SkyBalanceResult? _result;
  final Set<int> _collectedFoods = {};
  final Map<int, DateTime> _collectingFoods = {};
  final Set<int> _passedObstacles = {};
  final Set<int> _passedCheckpoints = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _soundEnabled) {
        _audio.startBgm();
      }
    });
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

  Future<void> _openSensorCheck() async {
    setState(() {
      _stage = SkyBalanceStage.sensorCheck;
      _sensorError = null;
      _checkingSensors = true;
    });
    try {
      final availability = await _sensor.checkAvailability();
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

    final calibration = _sensor.calibrate();
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

  Future<void> _pressStartFromMenu() async {
    if (_sensorAvailability == null) {
      try {
        _sensorAvailability = await _sensor.checkAvailability();
      } catch (_) {}
    }
    _startCountdown();
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
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    _checkpointLabel = 'START';
    _heightReached = 0;
    _cameraY = FlightWorldLayout.startY - _worldHeight * .62;
    _lastDashDirection = null;
    _result = null;
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
    final now = DateTime.now();
    final dt =
        (_lastTick == null
                ? .033
                : now.difference(_lastTick!).inMicroseconds / 1000000)
            .clamp(0.0, .08)
            .toDouble();
    _lastTick = now;
    if (dt <= 0) return;
    _collectingFoods.removeWhere(
      (_, collectedAt) =>
          now.difference(collectedAt) >= const Duration(milliseconds: 360),
    );

    final input = _sensor.input;
    _elapsedSeconds += dt;
    _dashCooldown = math.max(0, _dashCooldown - dt).toDouble();
    _collisionCooldown = math.max(0, _collisionCooldown - dt).toDouble();

    final prevLandings = _lastLandingCount;
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
    final height = math.max(0, FlightWorldLayout.startY - _body.y).toDouble();
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
      _endRun(won: false);
    } else if (_body.y <= FlightWorldLayout.finishY) {
      _progress = 1;
      _endRun(won: true);
    } else if (_body.y > _cameraY + _worldHeight + _body.radius) {
      _endRun(won: false);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _checkFood() {
    for (var index = 0; index < _level.food.length; index++) {
      final food = _level.food[index];
      if (_collectedFoods.contains(index)) {
        continue;
      }
      final position = FlightWorldLayout.foodPosition(food);
      if ((_body.x - position.x).abs() < 30 &&
          (_body.y - position.y).abs() < 34) {
        _collectedFoods.add(index);
        _collectingFoods[index] = DateTime.now();
        _foodCollected++;
        _energy = recoverEnergy(_energy.round(), food.energy).toDouble();
        _score += food.score;
        _showFeedback('+${food.energy} ENERGY   +${food.score}');
        _audio.playCollect();
        _playFeedback();
      }
    }
  }

  void _checkObstacles() {
    for (var index = 0; index < _level.obstacles.length; index++) {
      final obstacle = _level.obstacles[index];
      if (_passedObstacles.contains(index)) continue;
      final obstacleX = _obstacleX(obstacle, index);
      final position = FlightWorldLayout.obstaclePosition(obstacle, obstacleX);
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
      final checkpoint = _level.checkpoints[index];
      if (_passedCheckpoints.contains(index) ||
          _progress < checkpoint.progress) {
        continue;
      }
      _passedCheckpoints.add(index);
      _checkpointsReached++;
      _checkpointLabel = checkpoint.label;
      _score += 100;
      _showFeedback('CHECKPOINT REACHED');
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
    _showFeedback('-$amount ENERGY');
    _audio.playHit();
    _playFeedback();
  }

  void _triggerDash(int direction) {
    if (!mounted || _stage != SkyBalanceStage.playing || _dashCooldown > 0) {
      return;
    }
    _lastDashDirection = direction;
    _dashCooldown = 2;
    _body.velocityX += direction * 180;
    _body.velocityY -= 30;
    _body.grounded = false;
    _showFeedback(direction < 0 ? 'DASH LEFT!' : 'DASH RIGHT!');
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

  void _endRun({required bool won}) {
    if (_ending) return;
    _ending = true;
    _gameTimer?.cancel();
    _gameTimer = null;
    _sensor.stopListening();
    _audio.stopBgm();
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
    if (won) {
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && _stage == SkyBalanceStage.victory) {
          setState(() => _feedback = 'SKY SUMMIT!');
        }
      });
    }
  }

  Future<void> _saveResult() async {
    final result = _result;
    if (result == null || _resultSaved) return;
    _resultSaved = true;
    try {
      final isNewBest = await _storage.recordResult(result);
      if (!mounted) return;
      setState(() => _newBestScore = isNewBest);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _storageError = 'Could not save this result: $error');
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
    setState(() => _stage = SkyBalanceStage.menu);
    _audio.startBgm();
  }

  void _exitToRecovera() {
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _sensor.stopListening();
    _audio.stopBgm();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF8FF),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: switch (_stage) {
            SkyBalanceStage.playing => _buildGameplay(),
            SkyBalanceStage.menu => _buildMenu(),
            SkyBalanceStage.introduction => _buildIntroduction(),
            SkyBalanceStage.tutorial => _buildTutorial(),
            SkyBalanceStage.sensorCheck => _buildSensorCheck(),
            SkyBalanceStage.calibration => _buildCalibration(),
            SkyBalanceStage.countdown => _buildCountdown(),
            SkyBalanceStage.paused => _buildPause(),
            SkyBalanceStage.gameOver => _buildGameOver(),
            SkyBalanceStage.victory => _buildVictory(),
            SkyBalanceStage.result => _buildResult(),
          },
        ),
      ),
    );
  }

  Widget _page({
    required String title,
    required Widget body,
    Widget? trailing,
  }) {
    return Column(
      key: ValueKey(_stage),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _calibrating
                    ? null
                    : _stage == SkyBalanceStage.menu
                    ? _exitToRecovera
                    : _returnToMenu,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(width: 48, child: trailing),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: body,
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return _page(
      title: 'Sky Balance',
      trailing: IconButton(
        tooltip: _soundEnabled ? 'Sound on' : 'Sound off',
        onPressed: _toggleSound,
        icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
        color: AppColors.primary,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _jumpIllustration(height: 210),
          const SizedBox(height: 22),
          const Text(
            'Sky Balance',
            style: TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF12364A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recovera Jump · Motion Platformer',
            style: TextStyle(fontSize: 15, color: AppColors.slateText),
          ),
          const SizedBox(height: 18),
          const Text(
            "Tilt your phone to jump from platform to platform.",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          _primaryButton('START', Icons.play_arrow_rounded, () {
            _pressStartFromMenu();
          }),
          const SizedBox(height: 12),
          _secondaryButton('HOW TO PLAY', Icons.help_outline, () {
            setState(() {
              _tutorialFromMenu = true;
              _stage = SkyBalanceStage.tutorial;
            });
          }),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _exitToRecovera,
            child: const Text(
              'BACK TO RECOVERA',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FutureBuilder<int>(
            future: _storage.bestScore,
            builder: (context, snapshot) =>
                snapshot.data == null || snapshot.data == 0
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'PERSONAL BEST  ${snapshot.data}',
                      style: const TextStyle(
                        color: AppColors.slateText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroduction() {
    return _page(
      title: 'Ready to Jump?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _softCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ready to Jump?',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 12),
                Text(
                  'Tilt your phone left and right to guide your character '
                  'upward. Land on floating platforms, collect healthy food, '
                  'avoid flying obstacles, and reach the sky summit!',
                  style: TextStyle(
                    height: 1.55,
                    fontSize: 15,
                    color: AppColors.slateText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _goalCard(
            'TILT',
            'Steer left and right with your phone.',
            Icons.screen_rotation_alt,
          ),
          _goalCard('COLLECT', 'Grab food for energy and score.', Icons.eco),
          _goalCard(
            'CLIMB',
            'Land on platforms to bounce to the summit.',
            Icons.vertical_align_top,
          ),
          const SizedBox(height: 22),
          _primaryButton('CONTINUE', Icons.arrow_forward, () {
            setState(() => _stage = SkyBalanceStage.tutorial);
          }),
        ],
      ),
    );
  }

  Widget _buildTutorial() {
    return _page(
      title: 'How to Play',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _softCard(
            child: Column(
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 10),
                const Text(
                  'TILT TO CLIMB',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                _controlLine('←', 'Tilt phone left', 'Move left'),
                _controlLine('→', 'Tilt phone right', 'Move right'),
                _controlLine('↑', 'Land on a platform', 'Auto-jump'),
                _controlLine('↔', 'Reach a screen edge', 'Wrap around'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _softCard(
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Quickly rotate your phone left or right to dash across '
                    'a tricky landing. Dash recharges in 2 seconds.',
                    style: TextStyle(height: 1.4, color: AppColors.slateText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Each landing launches another jump. Collect food and avoid '
            'flying obstacles on your way to the sky summit.',
            style: TextStyle(height: 1.5, color: AppColors.slateText),
          ),
          const SizedBox(height: 22),
          _primaryButton(
            _tutorialFromMenu ? 'GOT IT' : 'CHECK SENSORS',
            _tutorialFromMenu ? Icons.check : Icons.sensors,
            () {
              if (_tutorialFromMenu) {
                _returnToMenu();
              } else {
                _openSensorCheck();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCheck() {
    final availability = _sensorAvailability;
    return _page(
      title: 'Sensor Check',
      body: Column(
        children: [
          const SizedBox(height: 22),
          const Text(
            'MOTION CHECK',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Checking your phone before the first jump.',
            style: TextStyle(color: AppColors.slateText),
          ),
          const SizedBox(height: 26),
          _sensorStatus(
            'Accelerometer',
            availability?.accelerometer,
            _checkingSensors,
          ),
          const SizedBox(height: 12),
          _sensorStatus('Gyroscope', availability?.gyroscope, _checkingSensors),
          if (_sensorError != null) ...[
            const SizedBox(height: 18),
            Text(
              _sensorError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: availability?.accelerometer == true
                    ? AppColors.slateText
                    : AppColors.error,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (availability?.accelerometer == true)
            _primaryButton('CONTINUE TO CALIBRATION', Icons.tune, () {
              _beginCalibration();
            })
          else
            _primaryButton(
              _checkingSensors ? 'CHECKING SENSORS…' : 'CHECK AGAIN',
              Icons.refresh,
              _checkingSensors ? null : _openSensorCheck,
            ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _returnToMenu,
            child: const Text('BACK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibration() {
    return _page(
      title: 'Calibrate Your Phone',
      body: Column(
        children: [
          const SizedBox(height: 12),
          _softCard(
            child: Column(
              children: [
                const Icon(
                  Icons.screen_rotation_alt_rounded,
                  size: 68,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hold your phone in the position that feels comfortable for you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.45),
                ),
                const SizedBox(height: 18),
                _numberedInstruction(1, 'Hold your phone comfortably.'),
                _numberedInstruction(
                  2,
                  'Keep it steady; small tilts are enough to steer.',
                ),
                _numberedInstruction(
                  3,
                  'Tap CALIBRATE and wait for the countdown.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can adjust tilt sensitivity from the pause menu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slateText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _calibrating ? _countdownLabel : '✓',
            style: TextStyle(
              color: _calibrating ? AppColors.primary : AppColors.success,
              fontSize: 62,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _calibrating ? 'Hold steady…' : 'Calibration complete',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.slateText,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_sensorError != null) ...[
            const SizedBox(height: 12),
            Text(
              _sensorError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 22),
          if (!_calibrating && _calibrationComplete && _sensorError == null)
            _primaryButton(
              'START GAME',
              Icons.vertical_align_top_rounded,
              _startCountdown,
            )
          else if (!_calibrating)
            _primaryButton(
              _calibrationComplete ? 'RECALIBRATE' : 'CALIBRATE',
              _calibrationComplete ? Icons.refresh : Icons.tune,
              _beginCalibration,
            )
          else
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: Color(0xFFD7EDF7),
            ),
          if (!_calibrating &&
              _calibrationComplete &&
              _sensorError == null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _beginCalibration,
              child: const Text('RECALIBRATE'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return ColoredBox(
      key: const ValueKey('countdown'),
      color: const Color(0xFFBDEAFF),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'READY TO JUMP',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _countdownLabel,
              style: const TextStyle(
                fontSize: 84,
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameplay() {
    return LayoutBuilder(
      key: const ValueKey('gameplay'),
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 390;
        _worldHeight = constraints.maxHeight / scale;
        _cameraY = math.min(_cameraY, _body.y - _worldHeight * .62).toDouble();
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: FlightScenePainter(
                level: _level,
                body: _body,
                cameraY: _cameraY,
                progress: _progress,
                elapsedSeconds: _elapsedSeconds,
                collectedFoods: _collectedFoods,
                collectingFoods: _collectingFoods,
                passedCheckpoints: _passedCheckpoints,
              ),
              size: Size.infinite,
            ),
            Positioned(left: 0, right: 0, top: 0, child: _buildHud()),
            if (_feedback.isNotEmpty)
              Positioned(
                top: constraints.maxHeight * .42,
                left: 20,
                right: 20,
                child: Center(
                  child: _pill(
                    _feedback,
                    color: const Color(0xFF143E52),
                    foreground: Colors.white,
                  ),
                ),
              ),
            if (_sensor.signalLost)
              Positioned(
                top: 132,
                left: 14,
                right: 14,
                child: _pill(
                  'Motion sensor signal lost. Please hold your phone steady.',
                  color: const Color(0xFFFFF3D8),
                  foreground: const Color(0xFF805A12),
                ),
              ),
            if (_lastDashDirection != null && _dashCooldown > 0)
              Positioned(
                bottom: 22,
                left: 0,
                right: 0,
                child: Center(
                  child: _pill(
                    'DASH COOLDOWN (${_dashCooldown.ceil()}s)',
                    color: Colors.white,
                    foreground: AppColors.primaryDark,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHud() {
    final percentage = (_progress * 100).floor().clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _hudDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'ENERGY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_energy.round()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: (_energy / 100).clamp(0, 1).toDouble(),
                          color: _energy < 30
                              ? AppColors.error
                              : const Color(0xFF36B785),
                          backgroundColor: const Color(0xFFE7EFF3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Recalibrate motion',
                onPressed: () => _beginCalibration(resumeAfter: true),
                icon: const Icon(Icons.screen_rotation_alt_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Pause',
                onPressed: _pauseGame,
                icon: const Icon(Icons.pause_rounded),
              ),
              IconButton.filledTonal(
                tooltip: _soundEnabled ? 'Sound off' : 'Sound on',
                onPressed: _toggleSound,
                icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _tiltMeter(),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: _hudDecoration(),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '🍎  FOOD  $_foodCollected / ${_level.food.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'HEIGHT  ${_heightReached.round()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'SCORE  ${_score.round()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: _progress,
                          color: AppColors.primary,
                          backgroundColor: const Color(0xFFE7EFF3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      _checkpointLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _sensor.gyroscopeAvailable
                          ? _dashCooldown <= 0
                                ? '⚡ DASH READY'
                                : '⚡ DASH COOLDOWN (${_dashCooldown.ceil()}s)'
                          : 'DASH OFF',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiltMeter() {
    final tilt = _sensor.input.horizontal.clamp(-1.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: _hudDecoration(),
      child: Row(
        children: [
          const Icon(
            Icons.arrow_left_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          Expanded(
            child: SizedBox(
              height: 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5E6EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Align(
                    alignment: Alignment(tilt, 0),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: .25),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.arrow_right_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          const Text(
            'TILT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _hudDecoration() => BoxDecoration(
    color: Colors.white.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(17),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: .08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _buildPause() {
    return _page(
      title: 'Game Paused',
      body: Column(
        children: [
          const SizedBox(height: 28),
          const Icon(
            Icons.pause_circle_filled_rounded,
            size: 84,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'GAME PAUSED',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          _softCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'TILT SENSITIVITY',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    Text(
                      '${(_sensor.sensitivity * 100).round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _sensor.sensitivity,
                  min: 0.5,
                  max: 1.5,
                  divisions: 4,
                  label: '${(_sensor.sensitivity * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _sensor.sensitivity = value);
                  },
                ),
                const Text(
                  'Lower is gentler; raise it if the character feels slow.',
                  style: TextStyle(color: AppColors.slateText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _primaryButton('RESUME', Icons.play_arrow_rounded, _resumeGame),
          const SizedBox(height: 12),
          _secondaryButton(
            'RECALIBRATE',
            Icons.tune,
            () => _beginCalibration(resumeAfter: true),
          ),
          const SizedBox(height: 12),
          _secondaryButton('EXIT GAME', Icons.exit_to_app, _exitToRecovera),
        ],
      ),
    );
  }

  Widget _buildVictory() {
    final result = _result!;
    return _page(
      title: 'Summit Reached',
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text('🎉', style: TextStyle(fontSize: 66)),
          const Text(
            'YOU DID IT!',
            style: TextStyle(
              fontSize: 31,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You reached the sky summit!',
            style: TextStyle(color: AppColors.slateText, fontSize: 15),
          ),
          const SizedBox(height: 18),
          Text('⭐' * result.stars, style: const TextStyle(fontSize: 27)),
          const SizedBox(height: 18),
          _resultCard(result, compact: true),
          const SizedBox(height: 14),
          _softCard(
            child: Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RECOVERY REWARD',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text('+${result.recoveryPoints} Recovery Points'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_newBestScore)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'NEW BEST SCORE!',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: 18),
          _primaryButton('PLAY AGAIN', Icons.replay, _retry),
          const SizedBox(height: 9),
          _secondaryButton('VIEW RESULT', Icons.assessment, () {
            setState(() => _stage = SkyBalanceStage.result);
          }),
          TextButton(
            onPressed: _exitToRecovera,
            child: const Text('BACK TO RECOVERA'),
          ),
          if (_storageError != null) _storageErrorBox(),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    final result = _result!;
    return _page(
      title: 'Jump Result',
      body: Column(
        children: [
          const SizedBox(height: 14),
          const Text('🪂', style: TextStyle(fontSize: 60)),
          const Text(
            'GAME OVER',
            style: TextStyle(
              fontSize: 28,
              color: AppColors.error,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You fell below the platforms or lost all your energy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slateText, height: 1.4),
          ),
          const SizedBox(height: 20),
          _resultCard(result, compact: false),
          const SizedBox(height: 18),
          _primaryButton('TRY AGAIN', Icons.replay, _retry),
          const SizedBox(height: 10),
          _secondaryButton('RECALIBRATE', Icons.tune, () async {
            await _openSensorCheck();
            if (_sensorAvailability?.accelerometer == true) {
              await _beginCalibration();
            }
          }),
          TextButton(
            onPressed: _exitToRecovera,
            child: const Text('BACK TO RECOVERA'),
          ),
          if (_storageError != null) _storageErrorBox(),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return _page(
      title: 'Result Details',
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            result.won ? 'VICTORY!' : 'JUMP SUMMARY',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _resultCard(result, compact: false),
          if (result.won) ...[
            const SizedBox(height: 14),
            Text(
              'RATING   ${'⭐' * result.stars}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _softCard(
              child: Text(
                '🎉  RECOVERY REWARD\n\n'
                '+${result.recoveryPoints} Recovery Points\n'
                '${result.foodCollected} healthy foods collected',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  height: 1.5,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (_newBestScore)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'NEW BEST SCORE!',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          if (_storageError != null) _storageErrorBox(),
          const SizedBox(height: 18),
          _primaryButton('PLAY AGAIN', Icons.replay, _retry),
          TextButton(
            onPressed: _exitToRecovera,
            child: const Text('BACK TO RECOVERA'),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(SkyBalanceResult result, {required bool compact}) {
    return _softCard(
      child: Column(
        children: [
          _statRow(
            'Height climbed',
            '${(result.progress * FlightWorldLayout.finishHeight).round()}',
          ),
          _statRow('Food', '${result.foodCollected} / ${_level.food.length}'),
          _statRow('Energy left', '${result.energyRemaining}%'),
          _statRow('Obstacles hit', '${result.obstaclesHit}'),
          _statRow(
            'Checkpoints',
            '${result.checkpointsReached} / ${_level.checkpoints.length}',
          ),
          if (!compact) ...[
            const Divider(height: 20),
            _statRow('Final score', '${result.score}', strong: true),
            _statRow('Rating', result.won ? '⭐' * result.stars : 'Try again'),
          ] else
            _statRow('Final score', '${result.score}', strong: true),
        ],
      ),
    );
  }

  Widget _storageErrorBox() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      _storageError!,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.error, fontSize: 12),
    ),
  );

  Widget _statRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.slateText,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jumpIllustration({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDF5FF), Color(0xFFA6E2F5)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            top: 38,
            child: Icon(
              Icons.cloud_rounded,
              size: 54,
              color: Colors.white.withValues(alpha: .9),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 28,
            child: Icon(
              Icons.cloud_rounded,
              size: 68,
              color: Colors.white.withValues(alpha: .8),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: _illustrationPlatform(48),
                ),
                _illustrationPlatform(58),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _illustrationPlatform(44),
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 55,
            child: Text('🐸', style: TextStyle(fontSize: 84)),
          ),
          Positioned(
            bottom: 14,
            child: Text(
              'TILT LEFT & RIGHT TO CLIMB',
              style: TextStyle(
                color: AppColors.primaryDark.withValues(alpha: .8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _illustrationPlatform(double width) => Container(
    width: width,
    height: 10,
    decoration: BoxDecoration(
      color: const Color(0xFF67B985),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white, width: 2),
    ),
  );

  Widget _softCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9EEF7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _goalCard(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _softCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F6FC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slateText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlLine(String icon, String action, String movement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              icon,
              style: const TextStyle(
                fontSize: 20,
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            movement,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorStatus(String name, bool? available, bool loading) {
    final color = available == null
        ? AppColors.slateText
        : available
        ? AppColors.success
        : AppColors.error;
    return _softCard(
      child: Row(
        children: [
          Icon(
            available == true ? Icons.check_circle : Icons.sensors,
            color: color,
            size: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name ${available == true ? 'detected' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (available == true)
            Icon(Icons.check, color: color),
        ],
      ),
    );
  }

  Widget _numberedInstruction(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFFE5F6FC),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.slateText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: .45),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: Color(0xFF9CCFDF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _pill(
    String text, {
    required Color color,
    Color foreground = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
