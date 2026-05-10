// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FIX: Corrected the import path from 'package.flutter' to 'package:flutter'
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash_screen.dart';
import 'widgets/live_map_widget.dart';

// A global variable to access the Supabase client from anywhere in the app.
// Make sure you have run 'flutter pub get' in your terminal after adding dependencies.
final supabase = Supabase.instance.client;

Future<void> main() async {
  // Ensure that Flutter widgets are initialized before running async code.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load the environment variables from the .env file
  // Ensure you have a file named ".env" in your project's root directory.
  await dotenv.load(fileName: ".env");

  // 3. Initialize Supabase with the secure variables loaded from .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 4. Run your application.
  runApp(const TaxigoApp());
}

class TaxigoApp extends StatelessWidget {
  const TaxigoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxigo',
      debugShowCheckedModeBanner: false,
      // Using the detailed theme you created for Taxigo.
      theme: ThemeData(
        primaryColor: const Color(0xFFFFC107),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC107),
          primary: const Color(0xFFFFC107),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFC107),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      // Your app will start with the SplashScreen. The SplashScreen can then
      // handle logic like checking if a user is logged in and navigating
      // to the appropriate screen (e.g., AuthScreen or HomeScreen).
      home: const SplashScreen(),
      routes: {
        '/live_map': (context) => const Scaffold(
              body: SafeArea(
                child: LiveMapWidget(),
              ),
            ),
      },
    );
  }
}
