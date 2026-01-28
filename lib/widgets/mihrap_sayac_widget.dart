import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

class MihrapSayacWidget extends StatefulWidget {
  const MihrapSayacWidget({super.key});

  @override
  State<MihrapSayacWidget> createState() => _MihrapSayacWidgetState();
}

class _MihrapSayacWidgetState extends State<MihrapSayacWidget>
    with TickerProviderStateMixin {
  Timer? _timer;
  String _gelecekVakit = "Öğle";
  Duration _kalanSure = const Duration();
  Map<String, String> _vakitler = {};
  double _ecirOrani = 0.0;
  late AnimationController _archController;
  late Animation<double> _archAnimation;

  @override
  void initState() {
    super.initState();
    _archController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _archAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _archController, curve: Curves.easeInOut),
    );
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
    _archController.dispose();
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C1810),
            Color(0xFF5D4037),
            Color(0xFF8D6E63),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D4037).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Mihrap kemeri
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _archAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _MihrapPainter(_archAnimation.value),
                );
              },
            ),
          ),
          // Geometrik desenler
          Positioned(
            left: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                size: const Size(150, 150),
                painter: _IslamicPatternPainter(),
              ),
            ),
          ),
          // İçerik
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                // Takvim başlığı
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.mosque, color: Colors.amber, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'TAKVİM',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Takvimler
                Row(
                  children: [
                    Expanded(
                      child: _buildCalendarCard(
                        icon: Icons.today,
                        label: 'MİLADİ',
                        date: miladi,
                        color: Colors.blue.shade300,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildCalendarCard(
                        icon: Icons.nightlight_round,
                        label: 'HİCRİ',
                        date: hicri,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                // Vakit bilgisi
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _gelecekVakit.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'vakti için',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Kalan süre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimePillar(hours.toString().padLeft(2, '0'), 'SAAT'),
                    const SizedBox(width: 15),
                    _buildTimePillar(minutes.toString().padLeft(2, '0'), 'DAKİKA'),
                    const SizedBox(width: 15),
                    _buildTimePillar(seconds.toString().padLeft(2, '0'), 'SANİYE'),
                  ],
                ),
                const Spacer(),
                // Ecir barı
                _buildEcirSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard({
    required IconData icon,
    required String label,
    required String date,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePillar(String value, String label) {
    return Column(
      children: [
        Container(
          width: 75,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.amber.withOpacity(0.3),
                Colors.amber.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildEcirSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.15),
            Colors.amber.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'İbadet Saati',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '%${(_ecirOrani * 100).toInt()}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: _ecirOrani,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.8),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

class _MihrapPainter extends CustomPainter {
  final double progress;

  _MihrapPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.amber.withOpacity(0.1 + (progress * 0.2));

    final center = Offset(size.width / 2, size.height * 0.3);
    final radius = size.width * 0.4;

    // Mihrap kemeri
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      paint,
    );

    // İç kemer
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 20),
      math.pi,
      math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_MihrapPainter oldDelegate) => true;
}

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // Geometrik yıldız deseni
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final x1 = center.dx + radius * math.cos(angle);
      final y1 = center.dy + radius * math.sin(angle);
      final x2 = center.dx + (radius / 2) * math.cos(angle + math.pi / 8);
      final y2 = center.dy + (radius / 2) * math.sin(angle + math.pi / 8);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
