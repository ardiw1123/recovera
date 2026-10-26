import 'package:flutter_test/flutter_test.dart';
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
}
