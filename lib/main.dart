// lib/main.dart
import 'package:flutter/material.dart';
import 'services/auth_store.dart';

// start on the welcome/login flow (or go straight to MainScreen if you prefer)
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'screens/supervisor_screen.dart';
import 'screens/analyst_screen.dart';
// If you want to start directly on the capture tabs, import this instead:
// import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.instance.load();
  runApp(const HydroGaugeApp());
}

class HydroGaugeApp extends StatelessWidget {
  const HydroGaugeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HydroGauge',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E88E5),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          bodyMedium: TextStyle(height: 1.3),
        ),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // Start at Welcome/Login screen
      home: const WelcomeScreen(),
      routes: {
        '/home': (_) => const HomeShell(),
        '/supervisor': (_) => const SupervisorScreen(),
        '/analyst': (_) => const AnalystScreen(),
      },
    );
  }
}