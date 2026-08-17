import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:safe/screens/splash_screen.dart';
import 'package:safe/theme/app_theme.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bSafe Safety App',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
