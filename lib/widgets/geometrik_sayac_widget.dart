import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Geometrik Sayaç - Sacred Geometry temalı mistik ve hipnotik tasarım
class GeometrikSayacWidget extends StatefulWidget {
  final bool shouldLoadData;
  const GeometrikSayacWidget({super.key, this.shouldLoadData = true});

  @override
  State<GeometrikSayacWidget> createState() => _GeometrikSayacWidgetState();
}

class _GeometrikSayacWidgetState extends State<GeometrikSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};

  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    if (widget.shouldLoadData) {
      _vakitleriYukle();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _hesaplaKalanSure();
      });
    }
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rotateController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId != null) {
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (vakitler != null && mounted) {
        setState(() {
          _vakitSaatleri = {
            'imsak': vakitler['Imsak'] ?? '05:30',
            'gunes': vakitler['Gunes'] ?? '07:00',
            'ogle': vakitler['Ogle'] ?? '12:30',
            'ikindi': vakitler['Ikindi'] ?? '15:45',
            'aksam': vakitler['Aksam'] ?? '18:15',
            'yatsi': vakitler['Yatsi'] ?? '19:45',
          };
        });
        _hesaplaKalanSure();
      }
    }
  }

  void _hesaplaKalanSure() {
    if (_vakitSaatleri.isEmpty) return;

    final now = DateTime.now();
    final nowTotalSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    final vakitListesi = [
      {'adi': _languageService['imsak'] ?? 'İmsak', 'saat': _vakitSaatleri['imsak']!},
      {'adi': _languageService['gunes'] ?? 'Güneş', 'saat': _vakitSaatleri['gunes']!},
      {'adi': _languageService['ogle'] ?? 'Öğle', 'saat': _vakitSaatleri['ogle']!},
      {'adi': _languageService['ikindi'] ?? 'İkindi', 'saat': _vakitSaatleri['ikindi']!},
      {'adi': _languageService['aksam'] ?? 'Akşam', 'saat': _vakitSaatleri['aksam']!},
      {'adi': _languageService['yatsi'] ?? 'Yatsı', 'saat': _vakitSaatleri['yatsi']!},
    ];

    List<int> vakitSaniyeleri = [];
    for (final vakit in vakitListesi) {
      final parts = vakit['saat']!.split(':');
      vakitSaniyeleri.add(int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60);
    }

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';
    double oran = 0.0;

    int sonrakiIndex = -1;
    for (int i = 0; i < vakitSaniyeleri.length; i++) {
      if (vakitSaniyeleri[i] > nowTotalSeconds) {
        sonrakiIndex = i;
        break;
      }
    }

    if (sonrakiIndex == -1) {
      final yarin = now.add(const Duration(days: 1));
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(yarin.year, yarin.month, yarin.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds + (24 * 3600 - yatsiSaniye);
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else {
      final parts = vakitListesi[sonrakiIndex]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitListesi[sonrakiIndex]['adi']!;
      final toplamSure = vakitSaniyeleri[sonrakiIndex] - vakitSaniyeleri[sonrakiIndex - 1];
      final gecenSure = nowTotalSeconds - vakitSaniyeleri[sonrakiIndex - 1];
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    }

    if (mounted) {
      setState(() {
        _kalanSure = sonrakiVakitZamani!.difference(now);
        _sonrakiVakit = sonrakiVakitAdi;
        _ilerlemeOrani = oran;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes % 60;
    final seconds = _kalanSure.inSeconds % 60;

    // Takvim bilgileri
    final now = DateTime.now();
    final miladiTarih = DateFormat('dd.MM.yyyy').format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';

    // Tema renklerini kullan
    final primaryColor = renkler.vurgu;
    final secondaryColor = renkler.vurguSecondary;
    final bgColor = renkler.arkaPlan;
    final cardBg = renkler.kartArkaPlan;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            cardBg,
            bgColor,
            bgColor.withOpacity(0.8),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Sacred Geometry arka plan
            AnimatedBuilder(
              animation: Listenable.merge([_rotateController, _pulseController]),
              builder: (context, child) {
                return CustomPaint(
                  painter: _SacredGeometryPainter(
                    rotation: _rotateController.value * 2 * math.pi,
                    pulse: _pulseController.value,
                    color: primaryColor,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst bilgi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [primaryColor, secondaryColor],
                            ).createShader(bounds),
                            child: Text(
                              _sonrakiVakit,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          Text(
                            _languageService['time_remaining'] ?? 'Kalan Süre',
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Flower of Life mini ikon
                      AnimatedBuilder(
                        animation: _rotateController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: -_rotateController.value * math.pi,
                            child: CustomPaint(
                              painter: _FlowerOfLifeMiniPainter(
                                color: primaryColor,
                              ),
                              size: const Size(50, 50),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Zaman göstergesi - Altıgen içinde
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            width: 200,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primaryColor.withOpacity(0.1 + _glowController.value * 0.05),
                                  secondaryColor.withOpacity(0.05),
                                ],
                              ),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.1 + _glowController.value * 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildGoldenDigit(hours.toString().padLeft(2, '0'), primaryColor, secondaryColor),
                                _buildGoldenSeparator(primaryColor),
                                _buildGoldenDigit(minutes.toString().padLeft(2, '0'), primaryColor, secondaryColor),
                                _buildGoldenSeparator(primaryColor),
                                _buildGoldenDigit(seconds.toString().padLeft(2, '0'), primaryColor, secondaryColor),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // İlerleme çubuğu
                  _buildProgressBar(primaryColor, primaryColor),

                  const SizedBox(height: 10),

                  // Miladi ve Hicri Takvim
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _languageService['gregorian_date'] ?? 'Miladi',
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.4),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            miladiTarih,
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      // İlerleme yüzdesi
                      Text(
                        '${(_ilerlemeOrani * 100).toInt()}%',
                        style: TextStyle(
                          color: primaryColor.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _languageService['hijri_date'] ?? 'Hicri',
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.4),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            hicriTarih,
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
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

  String _getHicriAyAdi(int ay) {
    const aylar = ['', 'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 
      'Cemaziyelevvel', 'Cemaziyelahir', 'Recep', 'Şaban', 'Ramazan', 
      'Şevval', 'Zilkade', 'Zilhicce'];
    return aylar[ay];
  }

  Widget _buildGoldenDigit(String value, Color primary, Color secondary) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primary, secondary],
      ).createShader(bounds),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w300,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildGoldenSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(
          color: color.withOpacity(0.6),
          fontSize: 34,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color primaryColor, Color textColor) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: textColor.withOpacity(0.15),
        border: Border.all(color: textColor.withOpacity(0.1), width: 0.5),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _ProgressBarLinesPainter(lineColor: textColor.withOpacity(0.08)),
            ),
          ),
          FractionallySizedBox(
            widthFactor: _ilerlemeOrani.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [primaryColor.withOpacity(0.7), primaryColor, Color.lerp(primaryColor, Colors.white, 0.2)!],
                ),
                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 6, spreadRadius: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Sacred Geometry çizici
class _SacredGeometryPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final Color color;

  _SacredGeometryPainter({
    required this.rotation,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Dönen dış daireler
    for (int i = 0; i < 6; i++) {
      final angle = rotation + (i * math.pi / 3);
      final radius = 60.0 + pulse * 10;
      final circleCenter = Offset(
        center.dx + math.cos(angle) * radius * 0.8,
        center.dy + math.sin(angle) * radius * 0.8,
      );
      
      canvas.drawCircle(
        circleCenter,
        radius * 0.6,
        Paint()
          ..color = color.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Merkez Flower of Life
    _drawFlowerOfLife(canvas, center, 50 + pulse * 5, color.withOpacity(0.15));

    // Dönen üçgenler (Merkaba benzeri)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    
    // Yukarı bakan üçgen
    _drawTriangle(canvas, 0, 70 + pulse * 10, color.withOpacity(0.1));
    
    // Aşağı bakan üçgen
    canvas.rotate(math.pi);
    _drawTriangle(canvas, 0, 70 + pulse * 10, color.withOpacity(0.08));
    
    canvas.restore();

    // Dış altıgen
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rotation * 0.5);
    _drawHexagon(canvas, 0, 90 + pulse * 10, color.withOpacity(0.12));
    canvas.restore();
  }

  void _drawFlowerOfLife(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Merkez daire
    canvas.drawCircle(center, radius * 0.4, paint);

    // 6 çevre dairesi
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final circleCenter = Offset(
        center.dx + math.cos(angle) * radius * 0.4,
        center.dy + math.sin(angle) * radius * 0.4,
      );
      canvas.drawCircle(circleCenter, radius * 0.4, paint);
    }
  }

  void _drawTriangle(Canvas canvas, double offset, double size, Color color) {
    final path = Path();
    path.moveTo(0, -size * 0.6);
    path.lineTo(-size * 0.5, size * 0.3);
    path.lineTo(size * 0.5, size * 0.3);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawHexagon(Canvas canvas, double offset, double size, Color color) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - math.pi / 6;
      final point = Offset(
        math.cos(angle) * size,
        math.sin(angle) * size,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SacredGeometryPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.pulse != pulse;
  }
}

// Flower of Life mini çizici
class _FlowerOfLifeMiniPainter extends CustomPainter {
  final Color color;

  _FlowerOfLifeMiniPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.15;

    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Merkez
    canvas.drawCircle(center, radius, paint);

    // 6 çevre
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final circleCenter = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(circleCenter, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressBarLinesPainter extends CustomPainter {
  final Color lineColor;
  _ProgressBarLinesPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarLinesPainter oldDelegate) => oldDelegate.lineColor != lineColor;
}
