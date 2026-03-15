import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_store_plus/media_store_plus.dart' show MediaStore;
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_section.dart';
import 'screens/upload_section.dart';
import 'screens/history_section.dart';
import 'screens/manual_section.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MediaStore.ensureInitialized();
  MediaStore.appFolder = 'Silkreto';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SILKRETO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B5B95),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6B5B95),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B5B95),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      themeMode: ThemeMode.light,

      initialRoute: '/splash',

      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const ScanSection(),
        '/upload': (context) => const UploadSection(),
        '/history': (context) => const HistorySection(),
        '/manual': (context) => const ManualSection(),
      },

      // Good practice: handle unknown routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text(
                '404 - Route not found\n\n${settings.name}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
