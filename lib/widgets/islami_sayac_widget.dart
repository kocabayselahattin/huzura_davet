import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// İslami Sayaç - Hilal, yıldız ve İslami geometrik desenlerle tasarım
class IslamiSayacWidget extends StatefulWidget {
  const IslamiSayacWidget({super.key});

  @override
  State<IslamiSayacWidget> createState() => _IslamiSayacWidgetState();
}

class _IslamiSayacWidgetState extends State<IslamiSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};

  late AnimationController _rotateController;
  late AnimationController _shimmerController;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _starController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hesaplaKalanSure();
    });
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
    _shimmerController.dispose();
    _starController.dispose();
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
    final accentColor = renkler.yaziPrimary;
    final bgColor = renkler.arkaPlan;
    final cardBg = renkler.kartArkaPlan;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bgColor,
            cardBg,
            bgColor,
          ],
        ),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // İslami geometrik desen arka planı
            AnimatedBuilder(
              animation: _rotateController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _IslamicPatternPainter(
                    rotation: _rotateController.value * 2 * math.pi * 0.1,
                    color: secondaryColor.withOpacity(0.1),
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Yıldızlar
            AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _IslamicStarsPainter(
                    twinkle: _starController.value,
                    color: secondaryColor,
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
                              colors: [secondaryColor, accentColor],
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
                              color: accentColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Hilal ve yıldız
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  secondaryColor.withOpacity(0.1 + _shimmerController.value * 0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: CustomPaint(
                              painter: _CrescentStarPainter(
                                color: secondaryColor,
                                shimmer: _shimmerController.value,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Zaman göstergesi - İslami çerçeve
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
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
                                  primaryColor.withOpacity(0.5),
                                  accentColor.withOpacity(0.2),
                                ],
                              ),
                              border: Border.all(
                                color: secondaryColor.withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.1 + _shimmerController.value * 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Köşe süslemeleri
                                Positioned(
                                  top: 5,
                                  left: 5,
                                  child: _buildIslamicCorner(secondaryColor),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Transform.scale(
                                    scaleX: -1,
                                    child: _buildIslamicCorner(secondaryColor),
                                  ),
                                ),
                                Positioned(
                                  bottom: 5,
                                  left: 5,
                                  child: Transform.scale(
                                    scaleY: -1,
                                    child: _buildIslamicCorner(secondaryColor),
                                  ),
                                ),
                                Positioned(
                                  bottom: 5,
                                  right: 5,
                                  child: Transform.scale(
                                    scaleX: -1,
                                    scaleY: -1,
                                    child: _buildIslamicCorner(secondaryColor),
                                  ),
                                ),
                                // Zaman
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildIslamicDigit(hours.toString().padLeft(2, '0'), secondaryColor),
                                      _buildSeparator(secondaryColor),
                                      _buildIslamicDigit(minutes.toString().padLeft(2, '0'), secondaryColor),
                                      _buildSeparator(secondaryColor),
                                      _buildIslamicDigit(seconds.toString().padLeft(2, '0'), secondaryColor),
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

                  // İlerleme çubuğu
                  _buildProgressBar(primaryColor, secondaryColor),

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
                              color: secondaryColor.withOpacity(0.5),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            miladiTarih,
                            style: TextStyle(
                              color: secondaryColor.withOpacity(0.9),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      // İlerleme yüzdesi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: secondaryColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${(_ilerlemeOrani * 100).toInt()}%',
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _languageService['hijri_date'] ?? 'Hicri',
                            style: TextStyle(
                              color: secondaryColor.withOpacity(0.5),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            hicriTarih,
                            style: TextStyle(
                              color: secondaryColor.withOpacity(0.9),
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

  Widget _buildIslamicCorner(Color color) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _IslamicCornerPainter(color: color),
      ),
    );
  }

  Widget _buildIslamicDigit(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: 38,
        fontWeight: FontWeight.w500,
        fontFamily: 'monospace',
        letterSpacing: 2,
        shadows: [
          Shadow(color: color.withOpacity(0.5), blurRadius: 8),
        ],
      ),
    );
  }

  Widget _buildSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '۞',  // İslami sembol
        style: TextStyle(
          color: color.withOpacity(0.7),
          fontSize: 20,
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

// İslami geometrik desen çizici
class _IslamicPatternPainter extends CustomPainter {
  final double rotation;
  final Color color;

  _IslamicPatternPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 8 köşeli yıldız deseni tekrarı
    final spacing = 60.0;
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        _drawEightPointStar(canvas, 20, paint);
        canvas.restore();
      }
    }
  }

  void _drawEightPointStar(Canvas canvas, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final outerX = math.cos(angle) * size;
      final outerY = math.sin(angle) * size;
      final innerAngle = angle + math.pi / 8;
      final innerX = math.cos(innerAngle) * size * 0.4;
      final innerY = math.sin(innerAngle) * size * 0.4;
      
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

// İslami yıldızlar çizici
class _IslamicStarsPainter extends CustomPainter {
  final double twinkle;
  final Color color;

  _IslamicStarsPainter({required this.twinkle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);

    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 2.0 + random.nextDouble() * 4;
      final phase = random.nextDouble() * math.pi * 2;
      final twinkleAmount = (math.sin(twinkle * 2 * math.pi + phase) + 1) / 2;

      // Küçük 5 köşeli yıldız
      _drawFivePointStar(
        canvas,
        Offset(x, y),
        starSize * (0.5 + twinkleAmount * 0.5),
        Paint()..color = color.withOpacity(0.3 + twinkleAmount * 0.4),
      );
    }
  }

  void _drawFivePointStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 72 - 90) * math.pi / 180;
      final innerAngle = ((i * 72) + 36 - 90) * math.pi / 180;
      
      final outerX = center.dx + math.cos(outerAngle) * size;
      final outerY = center.dy + math.sin(outerAngle) * size;
      final innerX = center.dx + math.cos(innerAngle) * size * 0.4;
      final innerY = center.dy + math.sin(innerAngle) * size * 0.4;
      
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IslamicStarsPainter oldDelegate) {
    return oldDelegate.twinkle != twinkle;
  }
}

// Hilal ve yıldız çizici
class _CrescentStarPainter extends CustomPainter {
  final Color color;
  final double shimmer;

  _CrescentStarPainter({required this.color, required this.shimmer});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(0.8 + shimmer * 0.2)
      ..style = PaintingStyle.fill;

    // Hilal (Crescent)
    final crescentPath = Path();
    final outerRadius = size.width * 0.35;
    final innerRadius = size.width * 0.28;
    final innerOffset = size.width * 0.12;

    crescentPath.addOval(Rect.fromCircle(center: center, radius: outerRadius));
    crescentPath.addOval(Rect.fromCircle(
      center: Offset(center.dx + innerOffset, center.dy - innerOffset * 0.3),
      radius: innerRadius,
    ));
    crescentPath.fillType = PathFillType.evenOdd;

    canvas.drawPath(crescentPath, paint);

    // Yıldız
    final starCenter = Offset(center.dx + size.width * 0.15, center.dy - size.height * 0.1);
    _drawFivePointStar(canvas, starCenter, 8, paint);
  }

  void _drawFivePointStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 72 - 90) * math.pi / 180;
      final innerAngle = ((i * 72) + 36 - 90) * math.pi / 180;
      
      final outerX = center.dx + math.cos(outerAngle) * size;
      final outerY = center.dy + math.sin(outerAngle) * size;
      final innerX = center.dx + math.cos(innerAngle) * size * 0.4;
      final innerY = center.dy + math.sin(innerAngle) * size * 0.4;
      
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CrescentStarPainter oldDelegate) {
    return oldDelegate.shimmer != shimmer;
  }
}

// İslami köşe süsü çizici
class _IslamicCornerPainter extends CustomPainter {
  final Color color;

  _IslamicCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(0, 0, size.width, 0);
    
    canvas.drawPath(path, paint);
    
    // Küçük süs
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 2, 
      Paint()..color = color.withOpacity(0.5));
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
