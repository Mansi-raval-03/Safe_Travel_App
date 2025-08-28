import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/home/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xtndrzhtcjalwggisavp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh0bmRyemh0Y2phbHdnZ2lzYXZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzOTgwODQsImV4cCI6MjA3MTk3NDA4NH0.faxzqPBdX_bxUveRvk_wLDWjCNDKQyPg1Cm5OKqJ244',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
       colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeScreen(),
    );
  }
}