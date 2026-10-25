import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/auth_api.dart';
import 'services/sesi_storage.dart';

class Modul06App extends StatefulWidget {
  /// Dapat disuntikkan oleh pengujian.
  final AuthApi? api;
  final SesiStorage? sesiStorage;

  /// `--dart-define=LAMBAT=true` → API tiruan lambat 2 detik, supaya
  /// keadaan "sedang memproses" dapat diamati dengan tenang.
  static const bool lambatSimulasi = bool.fromEnvironment('LAMBAT');

  const Modul06App({super.key, this.api, this.sesiStorage});

  @override
  State<Modul06App> createState() => _Modul06AppState();
}

class _Modul06AppState extends State<Modul06App> {
  late final SesiStorage _sesiStorage = widget.sesiStorage ?? SesiStorage();

  late final AuthApi _api = widget.api ??
      (Modul06App.lambatSimulasi
          ? const AuthApi(tunda: Duration(seconds: 2))
          : const AuthApi());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Modul 06 — Sesi Persisten (Fase B)',
      theme: ThemeData(
        colorScheme:
        ColorScheme.fromSeed(seedColor: const Color(0xFF0284C7)),
        useMaterial3: true,
      ),
      home: LoginScreen(api: _api, sesiStorage: _sesiStorage),
    );
  }
}
