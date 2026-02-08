import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Tesla Sayaç - Elektrik ve enerji temalı dinamik tasarım
class TeslaSayacWidget extends StatefulWidget {
  final bool shouldLoadData;
  const TeslaSayacWidget({super.key, this.shouldLoadData = true});

  @override
  State<TeslaSayacWidget> createState() => _TeslaSayacWidgetState();
}

class _TeslaSayacWidgetState extends State<TeslaSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  Timer? _sparkTimer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};

  late AnimationController _pulseController;
  late AnimationController _arcController;
  late AnimationController _glowController;

  final List<_ElectricArc> _arcs = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _arcController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Elektrik arkları için timer
    _sparkTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _generateSparks();
    });

    if (widget.shouldLoadData) {
      _vakitleriYukle();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _hesaplaKalanSure();
      });
    }
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  void _generateSparks() {
    if (!mounted) return;
    setState(() {
      // Eski arkları temizle
      _arcs.removeWhere((arc) => arc.life <= 0);
      
      // Yeni ark ekle
      if (_random.nextDouble() < 0.3 && _arcs.length < 5) {
        _arcs.add(_ElectricArc(
          startX: _random.nextDouble() * 0.3 + 0.1,
          startY: _random.nextDouble() * 0.3 + 0.3,
          endX: _random.nextDouble() * 0.3 + 0.6,
          endY: _random.nextDouble() * 0.3 + 0.3,
          life: 5,
          segments: List.generate(8, (_) => _random.nextDouble() * 0.1 - 0.05),
        ));
      }
      
      // Yaşları azalt
      for (var arc in _arcs) {
        arc.life--;
        arc.segments = List.generate(8, (_) => _random.nextDouble() * 0.1 - 0.05);
      }
    });
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sparkTimer?.cancel();
    _pulseController.dispose();
    _arcController.dispose();
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
      {'adi': _languageService['imsak'], 'saat': _vakitSaatleri['imsak']!},
      {'adi': _languageService['gunes'], 'saat': _vakitSaatleri['gunes']!},
      {'adi': _languageService['ogle'], 'saat': _vakitSaatleri['ogle']!},
      {'adi': _languageService['ikindi'], 'saat': _vakitSaatleri['ikindi']!},
      {'adi': _languageService['aksam'], 'saat': _vakitSaatleri['aksam']!},
      {'adi': _languageService['yatsi'], 'saat': _vakitSaatleri['yatsi']!},
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
      sonrakiVakitAdi = _languageService['imsak'];
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'];
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
    final accentColor = renkler.yaziPrimary;
    final bgColor = renkler.arkaPlan;
    final cardBg = renkler.kartArkaPlan;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            cardBg,
            bgColor,
            bgColor.withOpacity(0.9),
          ],
        ),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Arka plan grid
            CustomPaint(
              painter: _TeslaGridPainter(color: primaryColor.withOpacity(0.1)),
              size: Size.infinite,
            ),

            // Elektrik arkları
            ...List.generate(_arcs.length, (index) {
              final arc = _arcs[index];
              return CustomPaint(
                painter: _ElectricArcPainter(
                  arc: arc,
                  color: primaryColor,
                ),
                size: Size.infinite,
              );
            }),

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
                              colors: [primaryColor, accentColor],
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
                            _languageService['time_remaining'],
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Tesla coil ikonu
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3 + _pulseController.value * 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2 + _pulseController.value * 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.bolt,
                              color: primaryColor,
                              size: 28,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Zaman göstergesi - Enerji hücresi stili
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            width: 220,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primaryColor.withOpacity(0.1),
                                  secondaryColor.withOpacity(0.05),
                                ],
                              ),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3 + _glowController.value * 0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.1 + _glowController.value * 0.15),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Köşe dekorasyonları
                                Positioned(
                                  top: 5,
                                  left: 5,
                                  child: _buildCornerDecor(primaryColor),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Transform.rotate(
                                    angle: math.pi / 2,
                                    child: _buildCornerDecor(primaryColor),
                                  ),
                                ),
                                Positioned(
                                  bottom: 5,
                                  left: 5,
                                  child: Transform.rotate(
                                    angle: -math.pi / 2,
                                    child: _buildCornerDecor(primaryColor),
                                  ),
                                ),
                                Positioned(
                                  bottom: 5,
                                  right: 5,
                                  child: Transform.rotate(
                                    angle: math.pi,
                                    child: _buildCornerDecor(primaryColor),
                                  ),
                                ),
                                // Zaman
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildElectricDigit(hours.toString().padLeft(2, '0'), primaryColor),
                                      _buildElectricSeparator(primaryColor),
                                      _buildElectricDigit(minutes.toString().padLeft(2, '0'), primaryColor),
                                      _buildElectricSeparator(primaryColor),
                                      _buildElectricDigit(seconds.toString().padLeft(2, '0'), primaryColor),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // İlerleme çubuğu - Enerji seviyesi
                  Row(
                    children: [
                      Icon(Icons.battery_charging_full, color: primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProgressBar(primaryColor, accentColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_ilerlemeOrani * 100).toInt()}%',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Miladi ve Hicri Takvim
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _languageService['gregorian_date'],
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
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _languageService['hijri_date'],
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
                              fontFamily: 'monospace',
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
    if (ay < 1 || ay > 12) return '';
    return _languageService['hijri_month_$ay'] ?? '';
  }

  Widget _buildCornerDecor(Color color) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color.withOpacity(0.5), width: 2),
          left: BorderSide(color: color.withOpacity(0.5), width: 2),
        ),
      ),
    );
  }

  Widget _buildElectricDigit(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: 40,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        letterSpacing: 2,
        shadows: [
          Shadow(color: color, blurRadius: 10),
          Shadow(color: color.withOpacity(0.5), blurRadius: 20),
        ],
      ),
    );
  }

  Widget _buildElectricSeparator(Color color) {
    return AnimatedBuilder(
      animation: _arcController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            ':',
            style: TextStyle(
              color: color.withOpacity(0.5 + _arcController.value * 0.5),
              fontSize: 34,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: color, blurRadius: 8),
              ],
            ),
          ),
        );
      },
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

class _ElectricArc {
  double startX, startY, endX, endY;
  int life;
  List<double> segments;

  _ElectricArc({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.life,
    required this.segments,
  });
}

// Tesla grid çizici
class _TeslaGridPainter extends CustomPainter {
  final Color color;

  _TeslaGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    // Radyal çizgiler
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * size.width,
          center.dy + math.sin(angle) * size.height,
        ),
        paint,
      );
    }

    // Eş merkezli daireler
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, i * 50.0, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Elektrik arkı çizici
class _ElectricArcPainter extends CustomPainter {
  final _ElectricArc arc;
  final Color color;

  _ElectricArcPainter({required this.arc, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(arc.life / 5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(arc.life / 10)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    final startX = arc.startX * size.width;
    final startY = arc.startY * size.height;
    final endX = arc.endX * size.width;
    final endY = arc.endY * size.height;

    path.moveTo(startX, startY);

    final segmentCount = arc.segments.length;
    for (int i = 0; i < segmentCount; i++) {
      final t = (i + 1) / segmentCount;
      final x = startX + (endX - startX) * t;
      final y = startY + (endY - startY) * t + arc.segments[i] * size.height;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ElectricArcPainter oldDelegate) => true;
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
