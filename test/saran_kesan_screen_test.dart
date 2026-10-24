import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recovera/features/feedback/screens/saran_kesan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'displays static course reflections without submission controls',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SaranKesanScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Saran & Kesan'), findsOneWidget);
      expect(find.text('BAGUS MUHAMMAD AKBAR'), findsOneWidget);
      expect(find.text('Pemrograman Mobile'), findsOneWidget);
      expect(find.text('Kesan Perkuliahan'), findsOneWidget);
      expect(find.text('Saran untuk Perkuliahan'), findsOneWidget);
      expect(find.text('Terima Kasih!'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Kirim Saran & Kesan'), findsNothing);
      expect(find.text('Saran & Kesan Terkirim!'), findsNothing);
    },
  );

  testWidgets('keeps the appreciation content reachable by scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SaranKesanScreen()));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terima Kasih!'), findsOneWidget);
    expect(
      find.text(
        'Terima kasih atas ilmu, arahan, dan pengalaman yang diberikan selama perkuliahan.',
      ),
      findsOneWidget,
    );
  });
}
