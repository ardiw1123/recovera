import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileCameraScreen extends StatefulWidget {
  const ProfileCameraScreen({super.key});

  @override
  State<ProfileCameraScreen> createState() => _ProfileCameraScreenState();
}

class _ProfileCameraScreenState extends State<ProfileCameraScreen> {
  CameraController? _controller;
  String? _errorMessage;
  bool _takingPicture = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => throw StateError('Kamera depan tidak tersedia.'),
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (error, stackTrace) {
      debugPrint('Unable to initialize profile camera: $error\n$stackTrace');
      await controller?.dispose();
      _setCameraError(
        'Kamera tidak dapat dibuka. Periksa akses kamera lalu coba lagi.',
      );
    } on StateError catch (error, stackTrace) {
      debugPrint('Unable to initialize profile camera: $error\n$stackTrace');
      await controller?.dispose();
      _setCameraError('Kamera depan tidak tersedia di perangkat ini.');
    }
  }

  void _setCameraError(String message) {
    if (mounted) setState(() => _errorMessage = message);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        _takingPicture ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() => _takingPicture = true);
    try {
      final photo = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(photo);
    } on CameraException catch (error, stackTrace) {
      debugPrint('Unable to capture profile photo: $error\n$stackTrace');
      _setCameraError('Foto tidak dapat diambil. Coba buka kamera lagi.');
    } finally {
      if (mounted) setState(() => _takingPicture = false);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF191919),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Batal',
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                    ),
                    const Expanded(
                      child: Text(
                        'Kamera',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: _errorMessage != null
                    ? _CameraError(message: _errorMessage!)
                    : controller == null || !controller.value.isInitialized
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Center(child: CameraPreview(controller)),
              ),
              SizedBox(
                height: 112,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Ambil foto',
                    child: IconButton(
                      onPressed:
                          controller == null ||
                              !controller.value.isInitialized ||
                              _takingPicture ||
                              _errorMessage != null
                          ? null
                          : _takePicture,
                      iconSize: 36,
                      color: Colors.white,
                      icon: _takingPicture
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.camera),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF252525),
                        fixedSize: const Size(72, 72),
                        side: const BorderSide(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
