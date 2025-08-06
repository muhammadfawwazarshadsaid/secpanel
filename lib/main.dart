import 'package:flutter/material.dart';
import 'package:secpanel/login.dart'; // Asumsi halaman login Anda ada di sini
import 'package:secpanel/login_change_password.dart';
import 'package:secpanel/main_screen.dart'; // Halaman utama setelah login
import 'package:secpanel/theme/colors.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // [TAMBAHKAN] Blok ini untuk inisialisasi
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  final prefs = await SharedPreferences.getInstance();
  final companyId = prefs.getString('companyId');

  runApp(MyApp(isLoggedIn: companyId != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEC Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.schneiderGreen,
        scaffoldBackgroundColor: AppColors.white,
        fontFamily: 'Lexend',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.schneiderGreen),
        useMaterial3: true,
      ),

      // initialRoute: isLoggedIn ? '/home' : '/login',
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/login-change-password': (context) => const LoginChangePasswordPage(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}
