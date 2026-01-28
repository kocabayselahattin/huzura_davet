import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

class NurSayacWidget extends StatefulWidget {
  const NurSayacWidget({super.key});

  @override
  State<NurSayacWidget> createState() => _NurSayacWidgetState();
}

class _NurSayacWidgetState extends State<NurSayacWidget>
    with TickerProviderStateMixin {
  Timer? _timer;
  String _gelecekVakit = "Öğle";
  Duration _kalanSure = const Duration();
  Map<String, String> _vakitler = {};
  double _ecirOrani = 0.0;
  late AnimationController _glowController;
  late AnimationController _rotateController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _vakitHesapla();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
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
    final vakitSirasi = ['imsak', 'gunes', 'ogle', 'ikindi', 'aksam', 'yatsi'];
    final vakitIsimleri = {
      'imsak': 'İmsak',
      'gunes': 'Güneş',
      'ogle': 'Öğle',
      'ikindi': 'İkindi',
      'aksam': 'Akşam',
      'yatsi': 'Yatsı',
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
      final imsakStr = _vakitler['imsak'];
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
    final miladi = DateFormat('d MMMM yyyy', 'tr_TR').format(DateTime.now());
    final hicri = '${hijriNow.hDay} ${_getHijriMonth(hijriNow.hMonth)} ${hijriNow.hYear}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A237E),
            Color(0xFF283593),
            Color(0xFF3949AB),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dönen nur efekti
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rotateController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _NurPainter(_rotateController.value),
                );
              },
            ),
          ),
          // İçerik
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Takvim
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.white70, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                'MİLADİ',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            miladi,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.mosque, color: Colors.amber, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                'HİCRİ',
                                style: TextStyle(
                                  color: Colors.amber.withOpacity(0.8),
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hicri,
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Vakit bilgisi
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _glowAnimation.value,
                      child: child,
                    );
                  },
                  child: Text(
                    _gelecekVakit,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Kalan süre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeUnit(hours.toString().padLeft(2, '0')),
                    _buildSeparator(),
                    _buildTimeUnit(minutes.toString().padLeft(2, '0')),
                    _buildSeparator(),
                    _buildTimeUnit(seconds.toString().padLeft(2, '0')),
                  ],
                ),
                const SizedBox(height: 16),
                // Ecir barı
                _buildEcirBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 24,
          color: Colors.white.withOpacity(0.5),
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _buildEcirBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Gün İlerlemesi',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              '${(_ecirOrani * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: _ecirOrani,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

class _NurPainter extends CustomPainter {
  final double progress;

  _NurPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    for (int i = 0; i < 8; i++) {
      final angle = (progress * 2 * math.pi) + (i * math.pi / 4);
      final startPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + (radius + 50) * math.cos(angle),
        center.dy + (radius + 50) * math.sin(angle),
      );

      paint.shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromPoints(startPoint, endPoint));

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(_NurPainter oldDelegate) => true;
}
