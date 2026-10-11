import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://wvlaqrbsikytzflkeeqx.supabase.co',
    anonKey: 'sb_publishable_ah-pEYuqznIi0cnwwTd0bQ_heRP26B8',
  );
  runApp(MyApp());
}
