import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recovera/features/auth/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('keeps the profile name below the avatar on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();

    final avatarRect = tester.getRect(
      find.byKey(const Key('profile_avatar_image')),
    );
    final nameRect = tester.getRect(
      find.byKey(const Key('profile_company_name')),
    );

    expect(nameRect.top, greaterThan(avatarRect.bottom));
    expect(find.byKey(const Key('profile_online_status_dot')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the static appreciation page from the profile menu', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();

    final feedbackMenu = find.byKey(const Key('menu_feedback'));
    await tester.ensureVisible(feedbackMenu);
    await tester.tap(feedbackMenu);
    await tester.pumpAndSettle();

    expect(find.text('Saran & Kesan'), findsOneWidget);
    expect(find.text('BAGUS MUHAMMAD AKBAR'), findsOneWidget);
    expect(find.text('Kirim Saran & Kesan'), findsNothing);
  });
}
