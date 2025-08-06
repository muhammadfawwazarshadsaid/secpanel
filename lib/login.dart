import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secpanel/helpers/db_helper.dart'; // Sesuaikan jika path helper Anda berbeda
import 'package:secpanel/models/company.dart'; // Sesuaikan jika path model Anda berbeda
import 'package:secpanel/theme/colors.dart'; // Sesuaikan jika path theme Anda berbeda
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingPermissions =
      true; // State baru untuk menandai pengecekan izin
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Ganti fungsi lama dengan alur startup yang baru
    _handleStartupChecks();
  }

  // --- [LOGIKA BARU DITAMBAHKAN DI SINI] ---

  /// Fungsi utama yang menangani semua pengecekan saat halaman login dimuat.
  Future<void> _handleStartupChecks() async {
    // [PERBAIKAN] Cek apakah kita TIDAK di web, DAN apakah kita di Android/iOS.
    // Ini memastikan kode izin hanya berjalan di platform mobile.
    if ((Platform.isAndroid || Platform.isIOS)) {
      print("Platform mobile terdeteksi, menjalankan pengecekan izin...");
      // 1. Minta Izin Notifikasi
      await _requestNotificationPermission();
      // 2. Minta pengecekan optimisasi baterai (khusus Android)
      await _requestBatteryOptimizationExemption();
    } else {
      print("Bukan platform mobile (Web/Desktop), melewati pengecekan izin.");
    }

    // Setelah semua selesai, aktifkan tombol-tombol di UI
    if (mounted) {
      setState(() {
        _isCheckingPermissions = false;
      });
    }
  }

  /// Fungsi untuk meminta izin notifikasi.
  Future<void> _requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(
        title: 'Izin Notifikasi Dibutuhkan',
        content:
            'Aplikasi ini butuh izin notifikasi untuk update penting. Silakan aktifkan di pengaturan aplikasi.',
      );
    }
  }

  /// Fungsi untuk meminta pengecualian optimisasi baterai.
  Future<void> _requestBatteryOptimizationExemption() async {
    if (Platform.isAndroid) {
      PermissionStatus status =
          await Permission.ignoreBatteryOptimizations.status;
      if (status.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  /// Dialog untuk mengarahkan pengguna ke pengaturan jika izin ditolak permanen.
  Future<void> _showSettingsDialog({
    required String title,
    required String content,
  }) async {
    if (mounted) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Buka Pengaturan'),
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // --- [AKHIR DARI LOGIKA BARU] ---

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Tombol tidak akan bisa ditekan jika izin sedang dicek atau sedang login
    if (_isLoading || _isCheckingPermissions) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));

      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        _showErrorSnackBar('Username dan password tidak boleh kosong.');
        setState(() => _isLoading = false);
        return;
      }

      final Company? company = await DatabaseHelper.instance.login(
        username,
        password,
      );

      if (mounted) {
        if (company != null) {
          setState(() {
            _isLoading = false;
          });
          _showSuccessSnackBar('Login berhasil! Mengalihkan...');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedInUsername', username);
          await prefs.setString('companyId', company.id);
          await prefs.setString('companyRole', company.role.name);

          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showErrorSnackBar('Username atau password salah.');
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Terjadi kesalahan: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kondisi untuk menonaktifkan tombol
    final bool areButtonsDisabled = _isLoading || _isCheckingPermissions;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bagian atas (Logo dan Form)
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  // Logo dan Judul
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/images/logo.png', height: 44),
                      const SizedBox(height: 24),
                      const Text(
                        'Masuk Akun',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w400,
                          fontSize: 32,
                          color: AppColors.black,
                        ),
                      ),
                      // [UI BARU] Tampilkan status jika sedang cek izin
                      if (_isCheckingPermissions) ...[
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Memeriksa izin aplikasi...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Username TextField
                  TextField(
                    controller: _usernameController,
                    cursorColor: AppColors.schneiderGreen,
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w300,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.schneiderGreen,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.grayNeutral,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password TextField
                  TextField(
                    controller: _passwordController,
                    cursorColor: AppColors.schneiderGreen,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w300,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.schneiderGreen,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.grayNeutral,
                          width: 1,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.gray,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bagian bawah (Tombol)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(height: 1, color: AppColors.grayNeutral),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            side: const BorderSide(
                              color: AppColors.schneiderGreen,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          // [DIUBAH] Tombol dinonaktifkan saat cek izin
                          onPressed: areButtonsDisabled
                              ? null
                              : () {
                                  Navigator.pushNamed(
                                    context,
                                    '/login-change-password',
                                  );
                                },
                          child: const Text(
                            'Masuk & Ubah Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: AppColors.schneiderGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            shadowColor: Colors.transparent,
                            backgroundColor: AppColors.schneiderGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.schneiderGreen
                                .withOpacity(0.7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          // [DIUBAH] Tombol dinonaktifkan saat cek izin
                          onPressed: areButtonsDisabled ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
