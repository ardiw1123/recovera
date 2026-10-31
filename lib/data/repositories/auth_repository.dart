import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../features/auth/models/user_profile.dart';
import '../services/auth_api_service.dart';

/// Repository autentikasi terpusat sebagai single source of truth untuk state autentikasi
class AuthRepository extends ChangeNotifier {
  AuthRepository({required this.authApiService, required this.tokenStorage});

  final AuthApiService authApiService;
  final ITokenStorage tokenStorage;

  AuthTokens? _currentTokens;
  UserProfile? _currentUserProfile;
  bool _isLoading = false;

  AuthTokens? get currentTokens => _currentTokens;
  UserProfile? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated =>
      _currentTokens != null && _currentTokens!.accessToken.isNotEmpty;
  String get currentUserRole =>
      _currentTokens?.role ?? _currentUserProfile?.role ?? 'buyer';
  bool get isSeller => currentUserRole.toLowerCase() == 'seller';
  bool get isBuyer => !isSeller;

  // Singleton instance untuk akses cepat di seluruh widget jika diperlukan
  static AuthRepository? _instance;
  static AuthRepository get instance {
    if (_instance == null) {
      final client = ApiClient();
      _instance = AuthRepository(
        authApiService: AuthApiService(client: client),
        tokenStorage: client.tokenStorage,
      );
    }
    return _instance!;
  }

  @visibleForTesting
  static set instance(AuthRepository? repo) => _instance = repo;

  @visibleForTesting
  set currentUserProfile(UserProfile? profile) {
    _currentUserProfile = profile;
    notifyListeners();
  }

  /// Inisialisasi token dari secure storage saat app startup
  Future<bool> init() async {
    _currentTokens = await tokenStorage.getTokens();
    notifyListeners();
    return isAuthenticated;
  }

  /// Mode demo langsung tanpa ketergantungan koneksi backend
  void loginAsDemo({
    String role = 'buyer',
    String name = 'Gevinta Aprilia',
    String? companyName,
  }) {
    final tokens = AuthTokens(
      accessToken: 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'demo_refresh_token',
      tokenType: 'Bearer',
      expiresIn: 3600,
      userId: 1,
      role: role,
      name: name,
    );
    _currentTokens = tokens;
    tokenStorage.saveTokens(tokens);
    _currentUserProfile = UserProfile(
      id: 1,
      email: '${name.toLowerCase().replaceAll(' ', '')}@recovera.dev',
      name: name,
      role: role,
      companyName:
          companyName ??
          (role == 'seller' ? 'PT Sumber Pangan (Distributor)' : 'PT. Adaro'),
      businessType: role == 'seller' ? 'distributor' : 'resto',
      address: 'Jl. Merpati No. 12, Klaten',
      city: 'Klaten',
      baseLat: -7.7058,
      baseLng: 110.6053,
      warehouseLat: -7.7058,
      warehouseLng: 110.6053,
    );
    notifyListeners();
  }

  /// Login dan simpan token secara aman
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _currentTokens = null;
    notifyListeners();

    try {
      final tokens = await authApiService.login(
        email: email,
        password: password,
      );
      await tokenStorage.saveTokens(tokens);
      _currentTokens = tokens;
      return tokens;
    } catch (e) {
      // Lempar error ke UI agar pesan validasi (password salah / akun tidak ditemukan) tampil
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registrasi akun baru
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String role,
    required String name,
    String? phone,
    String? companyName,
    String? businessType,
    String? address,
    String? city,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await authApiService.register(
        email: email,
        password: password,
        role: role,
        name: name,
        phone: phone,
        companyName: companyName,
        businessType: businessType,
        address: address,
        city: city,
      );
      await tokenStorage.saveTokens(tokens);
      _currentTokens = tokens;
      return tokens;
    } catch (e) {
      // Lempar error ke UI agar pesan validasi (email sudah terdaftar) tampil
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh token manual bila diperlukan
  Future<AuthTokens> refreshToken() async {
    final currentRefresh = await tokenStorage.getRefreshToken();
    if (currentRefresh == null || currentRefresh.isEmpty) {
      throw Exception('Refresh token tidak tersedia');
    }

    final newTokens = await authApiService.refreshToken(currentRefresh);
    await tokenStorage.saveTokens(newTokens);
    _currentTokens = newTokens;
    notifyListeners();
    return newTokens;
  }

  /// Logout lokal dan server
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      try {
        await authApiService.logout(refreshToken: refreshToken);
      } catch (_) {
        // Abaikan error jaringan saat logout server agar logout lokal tetap tuntas
      }
      await tokenStorage.clearTokens();
      _currentTokens = null;
      _currentUserProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Memuat profil pengguna dari API terautentikasi
  Future<UserProfile> fetchProfile() async {
    final profile = await authApiService.getProfile();
    if (profile.id != 0 ||
        profile.email.isNotEmpty ||
        profile.name.isNotEmpty ||
        _currentUserProfile == null) {
      _currentUserProfile = profile;
    }
    notifyListeners();
    return _currentUserProfile ?? profile;
  }

  /// Update profil pengguna ke backend dan sinkronisasi state lokal
  Future<UserProfile> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    String? companyName,
    String? address,
    double? warehouseLat,
    double? warehouseLng,
    String? city,
    String? businessType,
    double? baseLat,
    double? baseLng,
    List<String>? prefCategories,
    int? maxRadiusKm,
    bool? hasColdStorage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await authApiService.updateProfile(
        name: name,
        phone: phone,
        photoUrl: photoUrl,
        companyName: companyName,
        address: address,
        warehouseLat: warehouseLat,
        warehouseLng: warehouseLng,
        city: city,
        businessType: businessType,
        baseLat: baseLat,
        baseLng: baseLng,
        prefCategories: prefCategories,
        maxRadiusKm: maxRadiusKm,
        hasColdStorage: hasColdStorage,
      );
      _currentUserProfile = updated;
      return updated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update lokasi akun buyer/seller (alamat dan koordinat latitude & longitude)
  Future<UserProfile> updateLocation({
    required String address,
    required double latitude,
    required double longitude,
    String? city,
    bool allowOfflineFallback = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await authApiService.updateLocation(
        address: address,
        latitude: latitude,
        longitude: longitude,
        city: city,
        isSeller: isSeller,
      );
      _currentUserProfile = updated;
      return updated;
    } catch (e) {
      if (allowOfflineFallback) {
        // Fallback simpan lokasi ke profil lokal saat terjadi gangguan jaringan
        final current = _currentUserProfile;
        if (current != null) {
          final fallbackProfile = current.copyWith(
            address: address,
            city: city ?? current.city,
            baseLat: isSeller ? current.baseLat : latitude,
            baseLng: isSeller ? current.baseLng : longitude,
            warehouseLat: isSeller ? latitude : current.warehouseLat,
            warehouseLng: isSeller ? longitude : current.warehouseLng,
          );
          _currentUserProfile = fallbackProfile;
        } else {
          _currentUserProfile = UserProfile(
            id: currentTokens?.userId ?? 0,
            email: currentTokens?.name ?? '',
            role: currentUserRole,
            name: currentTokens?.name ?? 'User',
            address: address,
            city: city,
            baseLat: isSeller ? null : latitude,
            baseLng: isSeller ? null : longitude,
            warehouseLat: isSeller ? latitude : null,
            warehouseLng: isSeller ? longitude : null,
          );
        }
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
