import 'package:flutter/material.dart';

import '../models/sesi_pengguna.dart';
import '../services/auth_api.dart';
import '../services/sesi_storage.dart';
import '../widgets/field_kata_sandi.dart';
import '../widgets/kartu_sesi.dart';

enum StatusAuth { memeriksa, keluar, memproses, masuk, gagal }

class LoginScreen extends StatefulWidget {
  final AuthApi api;
  final SesiStorage sesiStorage;
  final DateTime Function() jam;

  const LoginScreen({
    super.key,
    required this.api,
    required this.sesiStorage,
    this.jam = DateTime.now,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _sandi = TextEditingController();

  StatusAuth _status = StatusAuth.memeriksa;
  String? _pesanGagal;
  SesiPengguna? _sesi;
  bool _sedangKeluar = false;
  bool _sedangMemperbarui = false;
  bool _tampilkanToken = false;

  @override
  void initState() {
    super.initState();
    _pulihkanSesi();
  }

  @override
  void dispose() {
    _email.dispose();
    _sandi.dispose();
    super.dispose();
  }

  /// Memulihkan sesi dari penyimpanan lokal saat layar dibuka.
  Future<void> _pulihkanSesi() async {
    setState(() {
      _status = StatusAuth.memeriksa;
      _pesanGagal = null;
    });

    final SesiPengguna? tersimpan = await widget.sesiStorage.baca();
    if (!mounted) return;

    if (tersimpan == null) {
      setState(() => _status = StatusAuth.keluar);
      return;
    }

    if (tersimpan.sudahKedaluwarsa(widget.jam())) {
      await widget.sesiStorage.hapus();
      if (!mounted) return;
      setState(() {
        _sesi = null;
        _status = StatusAuth.gagal;
        _pesanGagal = 'Sesi sebelumnya sudah berakhir. Silakan masuk lagi.';
      });
      return;
    }

    setState(() {
      _sesi = tersimpan;
      _status = StatusAuth.masuk;
    });
  }

  Future<void> _kirim() async {
    if (_status == StatusAuth.memproses) return; // Cegah kirim ganda.
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _status = StatusAuth.memproses;
      _pesanGagal = null;
    });

    try {
      final SesiPengguna hasil = await widget.api.masuk(
        email: _email.text,
        sandi: _sandi.text,
      );
      await widget.sesiStorage.simpan(hasil);
      if (!mounted) return;
      setState(() {
        _sesi = hasil;
        _status = StatusAuth.masuk;
        _sandi.clear();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = StatusAuth.gagal;
        _pesanGagal = e.pesan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = StatusAuth.gagal;
        _pesanGagal = 'Terjadi kesalahan tak terduga. Coba lagi.';
      });
      debugPrint('Login gagal tak terduga: $e');
    }
  }

  /// Memperbarui masa berlaku sesi aktif dan menyimpannya kembali (Fase B).
  Future<void> _perbaruiSesi() async {
    final SesiPengguna? sesiSaatIni = _sesi;
    if (sesiSaatIni == null || _sedangMemperbarui) return;

    setState(() => _sedangMemperbarui = true);

    try {
      final SesiPengguna sesiBaru = await widget.api.perbaruiSesi(sesiSaatIni);
      await widget.sesiStorage.simpan(sesiBaru);
      if (!mounted) return;
      setState(() {
        _sesi = sesiBaru;
        _sedangMemperbarui = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masa berlaku sesi berhasil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sedangMemperbarui = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui sesi.')),
      );
    }
  }

  /// Simulasi pengujian: mengubah sesi tersimpan menjadi sudah lewat masa berlaku,
  /// lalu memicu pemeriksaan ulang sesi.
  Future<void> _simulasikanKedaluwarsa() async {
    final SesiPengguna? sesiSaatIni = _sesi;
    if (sesiSaatIni == null) return;

    final DateTime masaLalu = widget.jam().subtract(const Duration(hours: 3));
    final SesiPengguna sesiKedaluwarsa = sesiSaatIni.copyWith(
      masukPada: masaLalu.toIso8601String(),
      kedaluwarsaPada:
      masaLalu.add(const Duration(hours: 2)).toIso8601String(),
    );

    await widget.sesiStorage.simpan(sesiKedaluwarsa);
    if (!mounted) return;
    await _pulihkanSesi();
  }

  Future<void> _keluar() async {
    setState(() => _sedangKeluar = true);
    await widget.sesiStorage.hapus();
    if (!mounted) return;
    setState(() {
      _sesi = null;
      _status = StatusAuth.keluar; // Bukan StatusAuth.gagal.
      _pesanGagal = null;
      _sedangKeluar = false;
      _tampilkanToken = false;
      _email.clear();
      _sandi.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modul 06 — Sesi Persisten (Fase B)'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(child: _bangunIsi()),
    );
  }

  /// Satu-satunya tempat yang memutuskan layar mana yang tampil.
  Widget _bangunIsi() {
    switch (_status) {
      case StatusAuth.memeriksa:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memeriksa sesi tersimpan…'),
            ],
          ),
        );
      case StatusAuth.masuk:
        final SesiPengguna? sesi = _sesi;
        if (sesi == null) {
          return _bangunForm();
        }
        return _bangunBeranda(sesi);
      case StatusAuth.keluar:
      case StatusAuth.memproses:
      case StatusAuth.gagal:
        return _bangunForm();
    }
  }

  Widget _bangunForm() {
    final bool sibuk = _status == StatusAuth.memproses;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const SizedBox(height: 8),
        const Text(
          'Masuk ke Portal Akademik',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        if (_pesanGagal != null) ...<Widget>[
          _KotakPesan(pesan: _pesanGagal!),
          const SizedBox(height: 16),
        ],

        Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _email,
                enabled: !sibuk,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
                validator: _validasiEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FieldKataSandi(
                controller: _sandi,
                enabled: !sibuk,
                validator: (String? nilai) {
                  if (nilai == null || nilai.isEmpty) {
                    return 'Kata sandi wajib diisi.';
                  }
                  if (nilai.length < 8) {
                    return 'Kata sandi minimal 8 karakter.';
                  }
                  return null;
                },
                onSubmitted: _kirim,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: sibuk ? null : _kirim,
            icon: sibuk
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.login_rounded),
            label: Text(sibuk ? 'Memproses…' : 'Masuk'),
          ),
        ),
        const SizedBox(height: 12),
        _KotakInfoDemo(
          onIsiOtomatis: sibuk
              ? null
              : () => setState(() {
            _email.text = AuthApi.emailDemo;
            _sandi.text = AuthApi.sandiDemo;
          }),
        ),
      ],
    );
  }

  static String? _validasiEmail(String? nilai) {
    final String teks = (nilai ?? '').trim();
    if (teks.isEmpty) return 'Email wajib diisi.';
    if (!teks.contains('@') || !teks.contains('.')) {
      return 'Format email belum benar.';
    }
    return null;
  }

  Widget _bangunBeranda(SesiPengguna sesi) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const Text(
          'Beranda',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        KartuSesi(
          sesi: sesi,
          sekarang: widget.jam(),
          onKeluar: _keluar,
          sedangKeluar: _sedangKeluar,
          onPerbarui: _perbaruiSesi,
          sedangMemperbarui: _sedangMemperbarui,
          tampilkanToken: _tampilkanToken,
          onUbahTampilanToken: () =>
              setState(() => _tampilkanToken = !_tampilkanToken),
        ),
        const SizedBox(height: 20),
        _KotakInfoPersisten(
          onSimulasiKedaluwarsa: _simulasikanKedaluwarsa,
        ),
      ],
    );
  }
}

/// Kotak pesan kesalahan dengan warna errorContainer.
class _KotakPesan extends StatelessWidget {
  final String pesan;

  const _KotakPesan({required this.pesan});

  @override
  Widget build(BuildContext context) {
    final ColorScheme skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skema.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: skema.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(color: skema.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak informasi akun demo dengan warna surfaceContainerHighest.
class _KotakInfoDemo extends StatelessWidget {
  final VoidCallback? onIsiOtomatis;

  const _KotakInfoDemo({this.onIsiOtomatis});

  @override
  Widget build(BuildContext context) {
    final ColorScheme skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Akun Demo Pengujian:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('• Normal: ${AuthApi.emailDemo} / ${AuthApi.sandiDemo}'),
          const Text('• Terkunci: ${AuthApi.emailTerkunci}'),
          const Text('• Gangguan: ${AuthApi.emailServerGangguan}'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onIsiOtomatis,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Isi Kredensial Demo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak informasi bahwa sesi kini disimpan secara persisten di perangkat (Fase B).
class _KotakInfoPersisten extends StatelessWidget {
  final VoidCallback onSimulasiKedaluwarsa;

  const _KotakInfoPersisten({required this.onSimulasiKedaluwarsa});

  @override
  Widget build(BuildContext context) {
    final ColorScheme skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skema.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.save_outlined,
                color: skema.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fase B Aktif: Sesi disimpan secara persisten di perangkat. '
                      'Tutup paksa aplikasi lalu buka kembali — Anda akan langsung '
                      'masuk ke Beranda selama sesi belum kedaluwarsa.',
                  style: TextStyle(color: skema.onSecondaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onSimulasiKedaluwarsa,
              icon: const Icon(Icons.history_toggle_off_rounded, size: 18),
              label: const Text('Simulasikan Sesi Kedaluwarsa'),
            ),
          ),
        ],
      ),
    );
  }
}
