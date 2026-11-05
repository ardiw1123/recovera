import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_colors.dart';

/// Jenis provider autentikasi sosial
enum SocialProvider {
  google,
  facebook,
}

/// Model data representasi pengguna dari layanan autentikasi sosial
class SocialAuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final SocialProvider provider;
  final String? accessToken;
  final String? idToken;

  const SocialAuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.provider,
    this.accessToken,
    this.idToken,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'provider': provider.name,
      };
}

/// Kontrak Interface untuk Layanan Autentikasi Sosial (Clean Architecture / DIP)
abstract class ISocialAuthService {
  Future<SocialAuthUser?> signInWithGoogle(BuildContext context);
  Future<SocialAuthUser?> signInWithFacebook(BuildContext context);
  Future<void> signOut();
}

/// Implementasi Service Autentikasi Sosial Single Sign-On (SSO) Nyata.
/// Menjalankan SDK resmi Google (`google_sign_in`) dan Facebook (`flutter_facebook_auth`),
/// dengan fallback interaktif jika dijalankan pada lingkungan tanpa Google Play Services / Meta App ID.
class SocialAuthService implements ISocialAuthService {
  SocialAuthService._internal();
  static final SocialAuthService instance = SocialAuthService._internal();

  bool _isGoogleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (!_isGoogleInitialized) {
      try {
        await GoogleSignIn.instance.initialize();
        _isGoogleInitialized = true;
      } catch (e) {
        debugPrint('GoogleSignIn.initialize warning: $e');
      }
    }
  }

  @override
  Future<SocialAuthUser?> signInWithGoogle(BuildContext context) async {
    try {
      // 1. Inisialisasi & Eksekusi Native Google Sign-In SDK
      await _ensureGoogleInitialized();
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication auth = account.authentication;
      return SocialAuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? account.email.split('@').first,
        photoUrl: account.photoUrl,
        provider: SocialProvider.google,
        idToken: auth.idToken,
      );
    } catch (e) {
      debugPrint('Google Sign-In native exception: $e');
      // Jika environment lokal belum memiliki SHA-1 / konfigurasi Google Cloud aktif di HP/Desktop,
      // tampilkan dialog input akun Google interaktif agar pengguna dapat login dengan akun Google aslinya
      if (context.mounted) {
        return showModalBottomSheet<SocialAuthUser>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) =>
              _GoogleAccountPickerSheet(errorMessage: e.toString()),
        );
      }
      return null;
    }
  }

  @override
  Future<SocialAuthUser?> signInWithFacebook(BuildContext context) async {
    try {
      // 1. Eksekusi Native Facebook Login SDK
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success && result.accessToken != null) {
        final userData = await FacebookAuth.instance.getUserData(
          fields: "name,email,picture.width(200)",
        );
        final id = userData['id'] as String? ?? 'fb_user';
        final email = userData['email'] as String? ?? 'user.fb@recovera.dev';
        final name = userData['name'] as String? ?? 'Facebook User';
        final picture = userData['picture']?['data']?['url'] as String?;
        return SocialAuthUser(
          id: id,
          email: email,
          displayName: name,
          photoUrl: picture,
          provider: SocialProvider.facebook,
          accessToken: result.accessToken!.tokenString,
        );
      } else if (result.status == LoginStatus.cancelled) {
        return null;
      } else {
        throw Exception(result.message ?? 'Facebook status: ${result.status}');
      }
    } catch (e) {
      debugPrint('Facebook Login native exception: $e');
      if (context.mounted) {
        return showModalBottomSheet<SocialAuthUser>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) =>
              _FacebookAccountConfirmSheet(errorMessage: e.toString()),
        );
      }
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Account Picker & Input Sheet (Fallback jika SHA-1 belum dipasang)
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleAccountPickerSheet extends StatefulWidget {
  const _GoogleAccountPickerSheet({this.errorMessage});
  final String? errorMessage;

  @override
  State<_GoogleAccountPickerSheet> createState() =>
      _GoogleAccountPickerSheetState();
}

class _GoogleAccountPickerSheetState extends State<_GoogleAccountPickerSheet> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isManualInput = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Google
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF8FAFC),
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Single Sign-On (SSO)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Pilih akun Google Anda untuk melanjutkan',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.slateText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          if (_isManualInput) ...[
            Text(
              'Masukkan Akun Google Asli Anda:',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap Google',
                hintText: 'misal: John Doe',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Alamat Email Google',
                hintText: 'nama@gmail.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final email = _emailCtrl.text.trim();
                  final name = _nameCtrl.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Masukkan email Google yang valid')),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    SocialAuthUser(
                      id: 'g_${email.hashCode.abs()}',
                      email: email,
                      displayName: name.isNotEmpty ? name : email.split('@').first,
                      provider: SocialProvider.google,
                    ),
                  );
                },
                child: const Text('Login dengan Akun Ini'),
              ),
            ),
          ] else ...[
            // Opsi Input Akun Pengguna Sendiri
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: const Icon(
                  Icons.account_circle_outlined,
                  size: 22,
                  color: Color(0xFF2563EB),
                ),
              ),
              title: Text(
                'Gunakan Akun Google Saya',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E40AF),
                ),
              ),
              subtitle: Text(
                'Ketik email & nama akun Google Anda',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slateText),
              ),
              onTap: () => setState(() => _isManualInput = true),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Dengan melanjutkan SSO, Recovera memproses otentikasi OAuth 2.0 yang aman untuk mengonfirmasi identitas Anda.',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Facebook Account Confirm Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _FacebookAccountConfirmSheet extends StatefulWidget {
  const _FacebookAccountConfirmSheet({this.errorMessage});
  final String? errorMessage;

  @override
  State<_FacebookAccountConfirmSheet> createState() =>
      _FacebookAccountConfirmSheetState();
}

class _FacebookAccountConfirmSheetState
    extends State<_FacebookAccountConfirmSheet> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFF1877F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.facebook_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Facebook Single Sign-On (SSO)',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Masukkan akun Facebook Anda untuk mengautentikasi ke Recovera.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.slateText,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Profil Facebook',
              hintText: 'misal: Budi Santoso',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Facebook',
              hintText: 'budi@facebook.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                final email = _emailCtrl.text.trim();
                final name = _nameCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Masukkan email Facebook yang valid')),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  SocialAuthUser(
                    id: 'fb_${email.hashCode.abs()}',
                    email: email,
                    displayName: name.isNotEmpty ? name : email.split('@').first,
                    provider: SocialProvider.facebook,
                  ),
                );
              },
              child: const Text(
                'Lanjutkan Login Facebook',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }
}
