import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

class MihrapSayacWidget extends StatefulWidget {
  const MihrapSayacWidget({super.key});

  @override
  State<MihrapSayacWidget> createState() => _MihrapSayacWidgetState();
}

class _MihrapSayacWidgetState extends State<MihrapSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
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
    _temaService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _archController.dispose();
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          // İçerik
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tarih satırı (kompakt)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white60, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      miladi,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: Colors.white38)),
                    const Icon(Icons.mosque, color: Colors.amber, size: 12),
                    const SizedBox(width: 4),
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
                // Vakit bilgisi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    _gelecekVakit.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Kalan süre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimePillar(hours.toString().padLeft(2, '0'), 'SAAT'),
                    const SizedBox(width: 10),
                    _buildTimePillar(minutes.toString().padLeft(2, '0'), 'DAKİKA'),
                    const SizedBox(width: 10),
                    _buildTimePillar(seconds.toString().padLeft(2, '0'), 'SANİYE'),
                  ],
                ),
                const SizedBox(height: 10),
                // Ecir barı
                _buildEcirSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePillar(String value, String label) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.amber.withOpacity(0.3),
                Colors.amber.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEcirSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 14),
                SizedBox(width: 6),
                Text(
                  'İbadet Saati',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '%${(_ecirOrani * 100).toInt()}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: _ecirOrani,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
