import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service untuk memantau status konektivitas internet pada perangkat mobile secara reaktif.
class NetworkConnectivityService extends ChangeNotifier {
  NetworkConnectivityService._();

  static final NetworkConnectivityService instance =
      NetworkConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  List<ConnectivityResult> _currentResults = [ConnectivityResult.wifi];

  /// Menunjukkan apakah perangkat saat ini terhubung ke internet (Wi-Fi, Data Seluler, Ethernet, dll.)
  bool get isOnline => _isOnline;

  /// Daftar jenis konektivitas saat ini
  List<ConnectivityResult> get currentResults =>
      List.unmodifiable(_currentResults);

  final _statusController = StreamController<bool>.broadcast();

  /// Stream reaktif yang memancarkan `true` saat internet menyala dan `false` saat mati
  Stream<bool> get onConnectivityChanged => _statusController.stream;

  /// Inisialisasi pengecekan konektivitas dan mulai mendengarkan event perubahan jaringan
  Future<void> init() async {
    if (kIsWeb) {
      _updateStatus([ConnectivityResult.wifi]);
      return;
    }
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (_) {
      _updateStatus([ConnectivityResult.wifi]);
    }

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  /// Cek status konektivitas saat ini secara eksplisit
  Future<bool> checkConnection() async {
    if (kIsWeb) {
      _updateStatus([ConnectivityResult.wifi]);
      return true;
    }
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return _isOnline;
    } catch (_) {
      _updateStatus([ConnectivityResult.wifi]);
      return true;
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    _currentResults = results;
    final hasConnection = kIsWeb ||
        results.any((result) => result != ConnectivityResult.none);

    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      _statusController.add(_isOnline);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
    super.dispose();
  }
}
