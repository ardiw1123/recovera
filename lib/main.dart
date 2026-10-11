import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://wvlaqrbsikytzflkeeqx.supabase.co',
    publishableKey: 'sb_publishable_ah-pEYuqznIi0cnwwTd0bQ_heRP26B8',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Recovera',
      home: Scaffold(
        body: Center(
          child: Text('Recovera - B2B Near-Expiry Food Liquidation'),
        ),
      ),
    );
  }
}

