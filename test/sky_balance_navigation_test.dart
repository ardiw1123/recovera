import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/features/sky_balance/sky_balance_screen.dart';
import 'package:recovera/main.dart';

void main() {
  testWidgets('Recovera exposes Sky Balance at its named route', (
    tester,
  ) async {
    await tester.pumpWidget(const RecoveraApp(initialRoute: '/sky-balance'));
    await tester.pump();

    expect(find.text('Sky Balance'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('Back to Recovera'), findsOneWidget);
  });

  testWidgets('SkyBalanceScreen triggers onExit when BACK TO RECOVERA is tapped', (
    tester,
  ) async {
    bool exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SkyBalanceScreen(
          onExit: () => exited = true,
        ),
      ),
    );
    await tester.pump();

    final backButton = find.text('BACK TO RECOVERA');
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pump();

    expect(exited, isTrue);
  });

  testWidgets('SkyBalanceScreen respects isActive flag during tab switching', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SkyBalanceScreen(isActive: false),
      ),
    );
    await tester.pump();

    expect(find.text('Sky Balance'), findsOneWidget);

    // Switch to active
    await tester.pumpWidget(
      const MaterialApp(
        home: SkyBalanceScreen(isActive: true),
      ),
    );
    await tester.pump();

    expect(find.text('Sky Balance'), findsOneWidget);

    // Switch back to inactive
    await tester.pumpWidget(
      const MaterialApp(
        home: SkyBalanceScreen(isActive: false),
      ),
    );
    await tester.pump();

    expect(find.text('Sky Balance'), findsOneWidget);
  });
}

