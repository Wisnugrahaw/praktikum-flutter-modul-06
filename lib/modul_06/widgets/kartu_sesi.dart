import 'package:flutter/material.dart';

import '../models/sesi_pengguna.dart';

class KartuSesi extends StatelessWidget {
  final SesiPengguna sesi;

  /// Waktu acuan untuk menghitung sisa masa berlaku.
  final DateTime sekarang;

  final VoidCallback? onKeluar;
  final bool sedangKeluar;

  /// Callback untuk memperpanjang masa berlaku sesi (Fase B).
  final VoidCallback? onPerbarui;
  final bool sedangMemperbarui;

  /// Menampilkan token apa adanya. Default `false`.
  final bool tampilkanToken;

  /// Callback opsional untuk mengubah visibilitas token.
  final VoidCallback? onUbahTampilanToken;

  const KartuSesi({
    super.key,
    required this.sesi,
    required this.sekarang,
    this.onKeluar,
    this.sedangKeluar = false,
    this.onPerbarui,
    this.sedangMemperbarui = false,
    this.tampilkanToken = false,
    this.onUbahTampilanToken,
  });

  /// Menyamarkan token: hanya 6 karakter awal yang terlihat.
  static String samarkanToken(String token) {
    if (token.isEmpty) return '(kosong)';
    if (token.length <= 6) return _titik(token.length);
    return '${token.substring(0, 6)}${_titik(12)}';
  }

  static String _titik(int jumlah) =>
      List<String>.filled(jumlah, '\u2022').join();

  /// Mengubah `2026-09-21T10:15:00.000` menjadi `21 Sep 2026, 10:15`.
  static String formatWaktu(String iso) {
    const List<String> bulan = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final DateTime? waktu = DateTime.tryParse(iso);
    if (waktu == null) return 'tidak diketahui';
    final String jam = waktu.hour.toString().padLeft(2, '0');
    final String menit = waktu.minute.toString().padLeft(2, '0');
    return '${waktu.day} ${bulan[waktu.month - 1]}${waktu.year}, '
        '$jam:$menit';
  }

  /// Mengubah Duration menjadi `1 jam 5 menit` / `45 detik`.
  static String formatSisa(Duration sisa) {
    if (sisa.inSeconds <= 0) return 'sudah berakhir';
    if (sisa.inMinutes < 1) return '${sisa.inSeconds} detik';
    if (sisa.inHours < 1) return '${sisa.inMinutes} menit';
    final int menit = sisa.inMinutes.remainder(60);
    return menit == 0
        ? '${sisa.inHours} jam'
        : '${sisa.inHours} jam$menit menit';
  }

  @override
  Widget build(BuildContext context) {
    final Duration sisa = sesi.sisaWaktu(sekarang);
    final String tokenTampil =
    tampilkanToken ? sesi.token : samarkanToken(sesi.token);
    final bool sibuk = sedangKeluar || sedangMemperbarui;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  child: Text(
                    sesi.nama.isNotEmpty ? sesi.nama[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        sesi.nama,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sesi.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(SesiPengguna.labelPeran(sesi.peran)),
                ),
              ],
            ),
            const Divider(height: 24),
            _BarisInfo(
              label: 'Waktu Masuk',
              nilai: formatWaktu(sesi.masukPada),
            ),
            const SizedBox(height: 8),
            _BarisInfo(
              label: 'Kedaluwarsa Pada',
              nilai: formatWaktu(sesi.kedaluwarsaPada),
            ),
            const SizedBox(height: 8),
            _BarisInfo(
              label: 'Sisa Masa Berlaku',
              nilai: formatSisa(sisa),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Token Sesi',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tokenTampil,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (onUbahTampilanToken != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: tampilkanToken
                            ? 'Samarkan token'
                            : 'Tampilkan token',
                        icon: Icon(
                          tampilkanToken
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: onUbahTampilanToken,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (onPerbarui != null) ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: sibuk ? null : onPerbarui,
                  icon: sedangMemperbarui
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    sedangMemperbarui ? 'Memperbarui…' : 'Perbarui Sesi (+2 Jam)',
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: sibuk ? null : onKeluar,
                icon: const Icon(Icons.logout_rounded),
                label: Text(sedangKeluar ? 'Keluar…' : 'Keluar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisInfo extends StatelessWidget {
  final String label;
  final String nilai;

  const _BarisInfo({required this.label, required this.nilai});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            nilai,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
