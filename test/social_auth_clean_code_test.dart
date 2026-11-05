import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/network/api_client.dart';
import 'package:recovera/core/services/social_auth_service.dart';
import 'package:recovera/core/storage/token_storage.dart';
import 'package:recovera/data/repositories/auth_repository.dart';
import 'package:recovera/data/services/auth_api_service.dart';
import 'package:recovera/features/auth/screens/login_screen.dart';

class _FakeTokenStorage implements ITokenStorage {
  AuthTokens? _tokens;

  @override
  Future<void> clearTokens() async => _tokens = null;

  @override
  Future<String?> getAccessToken() async => _tokens?.accessToken;

  @override
  Future<String?> getRefreshToken() async => _tokens?.refreshToken;

  @override
  Future<AuthTokens?> getTokens() async => _tokens;

  @override
  Future<bool> hasValidToken() async => _tokens != null;

  @override
  Future<void> saveAccessToken(String accessToken) async {}

  @override
  Future<void> saveRefreshToken(String refreshToken) async {}

  @override
  Future<void> saveTokens(AuthTokens tokens) async => _tokens = tokens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SocialAuthService & Clean Architecture Tests', () {
    test('SocialAuthUser models Google and Facebook data correctly', () {
      const googleUser = SocialAuthUser(
        id: 'g_123',
        email: 'tester@gmail.com',
        displayName: 'Google Tester',
        provider: SocialProvider.google,
      );

      expect(googleUser.provider, SocialProvider.google);
      expect(googleUser.email, 'tester@gmail.com');
      final json = googleUser.toJson();
      expect(json['provider'], 'google');
      expect(json['displayName'], 'Google Tester');

      const fbUser = SocialAuthUser(
        id: 'fb_456',
        email: 'tester@fb.com',
        displayName: 'Facebook Tester',
        provider: SocialProvider.facebook,
      );
      expect(fbUser.provider, SocialProvider.facebook);
      expect(fbUser.toJson()['provider'], 'facebook');
    });

    test('AuthRepository loginWithSocial provisions tokens and sets profile', () async {
      final fakeStorage = _FakeTokenStorage();
      final authRepo = AuthRepository(
        authApiService: AuthApiService(client: ApiClient(tokenStorage: fakeStorage)),
        tokenStorage: fakeStorage,
      );

      const user = SocialAuthUser(
        id: 'g_999',
        email: 'social.user@test.dev',
        displayName: 'Social User',
        provider: SocialProvider.google,
      );

      final tokens = await authRepo.loginWithSocial(user);

      expect(tokens.accessToken, isNotEmpty);
      expect(authRepo.isAuthenticated, isTrue);
      expect(authRepo.currentUserProfile?.name, 'Social User');
      expect(authRepo.currentUserProfile?.email, 'social.user@test.dev');
      expect(authRepo.currentUserRole, 'buyer');

      final saved = await fakeStorage.getTokens();
      expect(saved?.accessToken, tokens.accessToken);
    });

    testWidgets('LoginScreen displays Social Login Google and Facebook buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.byIcon(Icons.facebook_rounded), findsOneWidget);
    });
  });
}
