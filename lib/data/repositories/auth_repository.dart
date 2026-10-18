import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../features/auth/models/user_profile.dart';
import '../services/auth_api_service.dart';

/// Repository autentikasi terpusat sebagai single source of truth untuk state autentikasi
class AuthRepository extends ChangeNotifier {
  AuthRepository({
    required this.authApiService,
    required this.tokenStorage,
  });

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

  /// Inisialisasi token dari secure storage saat app startup
  Future<bool> init() async {
    _currentTokens = await tokenStorage.getTokens();
    notifyListeners();
    return isAuthenticated;
  }

  /// Login dan simpan token secara aman
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await authApiService.login(email: email, password: password);
      await tokenStorage.saveTokens(tokens);
      _currentTokens = tokens;
      return tokens;
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
    _currentUserProfile = profile;
    notifyListeners();
    return profile;
  }
}
