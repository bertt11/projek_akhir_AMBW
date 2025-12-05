import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mqxxpjozuvfncuwsfiwg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeHhwam96dXZmbmN1d3NmaXdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4NzI4MjIsImV4cCI6MjA4MDQ0ODgyMn0.waOjorpJx3P067ErXFvXAlCjRWpd5o-J5zz0zBeDn6k',        
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Auth Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const AuthPage(),
    );
  }
}
