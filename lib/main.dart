import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:safe/firebase_options.dart';
import 'package:safe/screens/splash_screen.dart';
import 'package:safe/theme/app_theme.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization warning: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RakshaSetu Safety App',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
