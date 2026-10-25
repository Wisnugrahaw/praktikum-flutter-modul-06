import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sesi_pengguna.dart';

class SesiStorage {
  static const String kunciSesi = 'modul_06.sesi_pengguna.v1';

  /// Jeda opsional agar keadaan "Memeriksa sesi tersimpan…" dapat diamati
  /// dan dikendalikan saat pengujian.
  final Duration tunda;

  int jumlahPenulisan = 0; // Dipakai pengujian.

  SesiStorage({this.tunda = const Duration(milliseconds: 400)});

  /// Membaca sesi dari penyimpanan perangkat.
  /// Mengembalikan `null` jika belum ada sesi atau jika data JSON rusak.
  Future<SesiPengguna?> baca() async {
    if (tunda > Duration.zero) {
      await Future<void>.delayed(tunda);
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? mentah = prefs.getString(kunciSesi);

    if (mentah == null || mentah.trim().isEmpty) {
      return null;
    }

    try {
      final Object? hasilDecode = jsonDecode(mentah);
      if (hasilDecode is! Map<String, dynamic>) {
        await hapus();
        return null;
      }
      return SesiPengguna.fromJson(hasilDecode);
    } catch (_) {
      // Data rusak di perangkat = anggap tidak sah dan bersihkan.
      await hapus();
      return null;
    }
  }

  /// Menyimpan sesi ke perangkat dalam format JSON.
  Future<void> simpan(SesiPengguna sesi) async {
    if (tunda > Duration.zero) {
      await Future<void>.delayed(tunda);
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String teksJson = jsonEncode(sesi.toJson());
    await prefs.setString(kunciSesi, teksJson);
    jumlahPenulisan++;
  }

  /// Menghapus sesi dari perangkat saat keluar atau kedaluwarsa.
  Future<void> hapus() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kunciSesi);
  }
}
