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
      final vakitler = await DiyanetApiService.getBugunVakitler(
        ilceId,
      );

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

      if (vakitZamani.isAfter(now)) {
        gelecekVakitZamani = vakitZamani;
        gelecekVakitIsmi = vakitIsimleri[vakit];
        break;
      }
    }

    if (gelecekVakitZamani == null) {
      final imsakStr = _vakitler['Imsak'];
      if (imsakStr != null) {
        final parts = imsakStr.split(':');
        if (parts.length == 2) {
          gelecekVakitZamani = DateTime(
            now.year,
            now.month,
            now.day + 1,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          gelecekVakitIsmi = 'İmsak';
        }
      }
    }

    if (gelecekVakitZamani != null && gelecekVakitIsmi != null) {
      final kalan = gelecekVakitZamani.difference(now);
      
      // Ecir oranı hesaplama (gün içindeki ilerleme)
      final gunBaslangic = DateTime(now.year, now.month, now.day, 0, 0);
      final gunBitis = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final gunSuresi = gunBitis.difference(gunBaslangic).inSeconds;
      final gecenSure = now.difference(gunBaslangic).inSeconds;
      final oran = (gecenSure / gunSuresi).clamp(0.0, 1.0);

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
    final hicri = '${hijriNow.hDay} ${_getHijriMonth(hijriNow.hMonth)} ${hijriNow.hYear}';

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B4332),
              Color(0xFF2D6A4F),
              Color(0xFF40916C),
            ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih satırı (kompakt)
                  Row(
                    children: [
                      Text(
                        miladi,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.white38)),
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Kalan süre
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildTimeBlock(hours.toString().padLeft(2, '0'), 'SAAT'),
                      const SizedBox(width: 3),
                      const Text(':', style: TextStyle(fontSize: 26, color: Colors.white70)),
                      const SizedBox(width: 3),
                      _buildTimeBlock(minutes.toString().padLeft(2, '0'), 'DAKİKA'),
                      const SizedBox(width: 3),
                      const Text(':', style: TextStyle(fontSize: 26, color: Colors.white70)),
                      const SizedBox(width: 3),
                      _buildTimeBlock(seconds.toString().padLeft(2, '0'), 'SANİYE'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Ecir barı
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                          const SizedBox(width: 6),
                          const Text(
                            'Günün Bereketi',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(_ecirOrani * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: _ecirOrani,
                              child: Container(
                                height: 5,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  String _getHijriMonth(int month) {
    const months = [
      'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir',
      'Cemaziyelevvel', 'Cemaziyelahir', 'Recep', 'Şaban',
      'Ramazan', 'Şevval', 'Zilkade', 'Zilhicce'
    ];
    return months[month - 1];
  }
}
