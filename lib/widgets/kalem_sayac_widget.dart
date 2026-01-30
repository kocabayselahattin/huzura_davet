import 'package:flutter/material.dart';
import 'dart:async';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

class KalemSayacWidget extends StatefulWidget {
  const KalemSayacWidget({super.key});

  @override
  State<KalemSayacWidget> createState() => _KalemSayacWidgetState();
}

class _KalemSayacWidgetState extends State<KalemSayacWidget>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  Timer? _timer;
  String _gelecekVakit = "Öğle";
  Duration _kalanSure = const Duration();
  Map<String, String> _vakitler = {};
  double _ecirOrani = 0.0;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _vakitHesapla();
      }
    });
    _temaService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final konumlar = await KonumService.getKonumlar();
    final aktifIndex = await KonumService.getAktifKonumIndex();

    if (konumlar.isEmpty || aktifIndex >= konumlar.length) return;

    final konum = konumlar[aktifIndex];
    final ilceId = konum.ilceId;

    try {
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);

      if (mounted && vakitler != null) {
        setState(() {
          _vakitler = vakitler;
        });
        _vakitHesapla();
      }
    } catch (e) {
      debugPrint('Vakitler yüklenemedi: $e');
    }
  }

  void _vakitHesapla() {
    if (_vakitler.isEmpty) return;

    final now = DateTime.now();
    final vakitSirasi = ['Imsak', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];
    final vakitIsimleri = {
      'Imsak': 'İmsak',
      'Gunes': 'Güneş',
      'Ogle': 'Öğle',
      'Ikindi': 'İkindi',
      'Aksam': 'Akşam',
      'Yatsi': 'Yatsı',
    };

    DateTime? gelecekVakitZamani;
    String? gelecekVakitIsmi;
    String? gelecekVakitKey;
    final vakitTimes = <String, DateTime>{};

    for (final vakit in vakitSirasi) {
      final vakitStr = _vakitler[vakit];
      if (vakitStr == null) continue;

      final parts = vakitStr.split(':');
      if (parts.length != 2) continue;

      final vakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      vakitTimes[vakit] = vakitZamani;

      if (gelecekVakitZamani == null && vakitZamani.isAfter(now)) {
        gelecekVakitZamani = vakitZamani;
        gelecekVakitIsmi = vakitIsimleri[vakit];
        gelecekVakitKey = vakit;
      }
    }

    if (gelecekVakitZamani == null) {
      final imsakZamani = vakitTimes['Imsak'];
      if (imsakZamani != null) {
        gelecekVakitZamani = imsakZamani.add(const Duration(days: 1));
        gelecekVakitIsmi = 'İmsak';
        gelecekVakitKey = 'Imsak';
      }
    }

    if (gelecekVakitZamani != null &&
        gelecekVakitIsmi != null &&
        gelecekVakitKey != null) {
      final kalan = gelecekVakitZamani.difference(now);

      final imsakToday = vakitTimes['Imsak'];
      final yatsiToday = vakitTimes['Yatsi'];
      DateTime? onceVakitZamani;

      if (gelecekVakitKey == 'Imsak' &&
          imsakToday != null &&
          now.isBefore(imsakToday) &&
          yatsiToday != null) {
        onceVakitZamani = yatsiToday.subtract(const Duration(days: 1));
      } else {
        final nextIndex = vakitSirasi.indexOf(gelecekVakitKey);
        if (nextIndex != -1) {
          final prevKey =
              vakitSirasi[(nextIndex - 1 + vakitSirasi.length) %
                  vakitSirasi.length];
          onceVakitZamani = vakitTimes[prevKey];
        }
        onceVakitZamani ??= yatsiToday;
      }

      onceVakitZamani ??= now;
      final toplamSure = gelecekVakitZamani
          .difference(onceVakitZamani)
          .inSeconds;
      final gecenSure = now.difference(onceVakitZamani).inSeconds;
      final oran = toplamSure <= 0
          ? 0.0
          : (gecenSure / toplamSure).clamp(0.0, 1.0);

      setState(() {
        _gelecekVakit = gelecekVakitIsmi ?? '';
        _kalanSure = kalan;
        _ecirOrani = oran;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes.remainder(60);
    final seconds = _kalanSure.inSeconds.remainder(60);

    final hijriNow = HijriCalendar.now();
    final miladi = DateFormat('d MMM yyyy', 'tr_TR').format(DateTime.now());
    final hicri =
        '${hijriNow.hDay} ${_getHijriMonth(hijriNow.hMonth)} ${hijriNow.hYear}';

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF40916C)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF40916C).withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Kalem deseni
            Positioned(
              right: -30,
              top: -30,
              child: Transform.rotate(
                angle: 0.3,
                child: Icon(
                  Icons.edit,
                  size: 150,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // İçerik
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tarih satırı (kompakt)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        miladi,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(color: Colors.white38),
                      ),
                      Text(
                        hicri,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Gelecek vakit
                  Text(
                    _gelecekVakit.toUpperCase(),
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w300,
                      inherit: false,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Kalan süre
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildTimeBlock(hours.toString().padLeft(2, '0'), 'SAAT'),
                      const SizedBox(width: 4),
                      const Text(
                        ':',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.white70,
                          inherit: false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildTimeBlock(
                        minutes.toString().padLeft(2, '0'),
                        'DAKİKA',
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        ':',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.white70,
                          inherit: false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildTimeBlock(
                        seconds.toString().padLeft(2, '0'),
                        'SANİYE',
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  // Ecir barı
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: _ecirOrani,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.amber, Colors.orange],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlock(String time, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            time,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
              inherit: false,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 1,
            inherit: false,
          ),
        ),
      ],
    );
  }

  String _getHijriMonth(int month) {
    const months = [
      'Muharrem',
      'Safer',
      'Rebiülevvel',
      'Rebiülahir',
      'Cemaziyelevvel',
      'Cemaziyelahir',
      'Recep',
      'Şaban',
      'Ramazan',
      'Şevval',
      'Zilkade',
      'Zilhicce',
    ];
    return months[month - 1];
  }
}
