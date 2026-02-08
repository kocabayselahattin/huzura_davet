import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Night/Moon themed countdown widget.
/// Deep blue night sky with moon and stars.
class GeceSayacWidget extends StatefulWidget {
  final bool shouldLoadData;
  const GeceSayacWidget({super.key, this.shouldLoadData = true});

  @override
  State<GeceSayacWidget> createState() => _GeceSayacWidgetState();
}

class _GeceSayacWidgetState extends State<GeceSayacWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  late AnimationController _twinkleController;

  @override
  void initState() {
    super.initState();

    _twinkleController = AnimationController(
      duration: const Duration(seconds: 2),
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
    _twinkleController.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId == null) {
      _varsayilanVakitleriKullan();
      return;
    }

    try {
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (vakitler != null) {
        setState(() {
          _vakitSaatleri = vakitler;
        });
        _hesaplaKalanSure();
      } else {
        _varsayilanVakitleriKullan();
      }
    } catch (e) {
      _varsayilanVakitleriKullan();
    }
  }

  void _varsayilanVakitleriKullan() {
    setState(() {
      _vakitSaatleri = {
        'Imsak': '05:30',
        'Gunes': '07:00',
        'Ogle': '12:30',
        'Ikindi': '15:30',
        'Aksam': '18:00',
        'Yatsi': '19:30',
      };
    });
    _hesaplaKalanSure();
  }

  void _hesaplaKalanSure() {
    if (_vakitSaatleri.isEmpty) return;

    final now = DateTime.now();
    final nowTotalSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    final vakitSaatleri = [
      {
        'adi': _languageService['imsak'] ?? '',
        'saat': _vakitSaatleri['Imsak']!,
      },
      {
        'adi': _languageService['gunes'] ?? '',
        'saat': _vakitSaatleri['Gunes']!,
      },
      {
        'adi': _languageService['ogle'] ?? '',
        'saat': _vakitSaatleri['Ogle']!,
      },
      {
        'adi': _languageService['ikindi'] ?? '',
        'saat': _vakitSaatleri['Ikindi']!,
      },
      {
        'adi': _languageService['aksam'] ?? '',
        'saat': _vakitSaatleri['Aksam']!,
      },
      {
        'adi': _languageService['yatsi'] ?? '',
        'saat': _vakitSaatleri['Yatsi']!,
      },
    ];

    final vakitSaniyeleri = <int>[];
    for (final vakit in vakitSaatleri) {
      final parts = vakit['saat']!.split(':');
      vakitSaniyeleri.add(
        int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60,
      );
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
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(
        now.year,
        now.month,
        now.day + 1,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds + (24 * 3600 - yatsiSaniye);
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else {
      final parts = vakitSaatleri[sonrakiIndex]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      sonrakiVakitAdi = vakitSaatleri[sonrakiIndex]['adi']!;
      final toplamSure =
          vakitSaniyeleri[sonrakiIndex] - vakitSaniyeleri[sonrakiIndex - 1];
      final gecenSure = nowTotalSeconds - vakitSaniyeleri[sonrakiIndex - 1];
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _ilerlemeOrani = oran;
    });
  }

  String _getHicriAyAdi(int ay) {
    if (ay < 1 || ay > 12) return '';
    return _languageService['hijri_month_$ay'] ?? '';
  }

  String _getLocale() {
    switch (_languageService.currentLanguage) {
      case 'tr':
        return 'tr_TR';
      case 'en':
        return 'en_US';
      case 'de':
        return 'de_DE';
      case 'fr':
        return 'fr_FR';
      case 'ar':
        return 'ar_SA';
      case 'fa':
        return 'fa_IR';
      default:
        return 'tr_TR';
    }
  }

  /// Calculate moon phase fraction (0.0-1.0) - same as gun_donumu_sayac_widget.dart.
  /// 0.0=new moon, 0.5=full moon, 1.0=new moon.
  double _getMoonPhaseFraction(DateTime date) {
    // Known new moon date: Dec 29, 2024 (updated reference).
    final reference = DateTime.utc(2024, 12, 30, 22, 27);
    const synodicMonth = 29.53058867;

    final daysDiff = date.difference(reference).inHours / 24.0;
    final phase = (daysDiff % synodicMonth) / synodicMonth;

    return phase;
  }

  /// Moon rendering by phase - same as gun_donumu_sayac_widget.dart.
  Widget _buildMoonWithPhase(double phase) {
    // Simulate phase with a shadow over the moon image.
    return Stack(
      children: [
        // Base moon image.
        Image.asset(
          'assets/icon/moon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackMoon(phase),
        ),
        // Phase shadow.
        CustomPaint(
          size: const Size(50, 50),
          painter: _MoonPhasePainter(phase: phase),
        ),
      ],
    );
  }

  /// Fallback moon - same as gun_donumu_sayac_widget.dart.
  Widget _fallbackMoon(double phase) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFF5F5F5),
            const Color(0xFFE0E0E0),
            const Color(0xFFBDBDBD).withOpacity(0.8),
          ],
        ),
      ),
      child: CustomPaint(
        size: const Size(50, 50),
        painter: _MoonPhasePainter(phase: phase),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes % 60;
    final seconds = _kalanSure.inSeconds % 60;

    final now = DateTime.now();
    final hicri = HijriCalendar.now();
    final hicriTarih =
        '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';
    final miladiTarih = DateFormat('dd MMMM yyyy', _getLocale()).format(now);

    // Theme toggle: use original palette or theme colors.
    final kullanTemaRenkleri = !_temaService.sayacTemasiKullan;
    final temaRenkleri = _temaService.renkler;

    // Original colors or theme colors.
    final primaryColor = kullanTemaRenkleri
        ? temaRenkleri.vurgu
        : const Color(0xFFFFF8DC);
    final bgColor1 = kullanTemaRenkleri
        ? temaRenkleri.arkaPlan
        : const Color(0xFF0A1628);
    final bgColor2 = kullanTemaRenkleri
        ? temaRenkleri.kartArkaPlan
        : const Color(0xFF1E3A5F);
    final textColor = kullanTemaRenkleri
        ? temaRenkleri.yaziPrimary
        : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: bgColor2.withOpacity(0.5),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background - night sky.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgColor1, bgColor2, bgColor2.withOpacity(0.8)],
                ),
              ),
            ),

            // Stars.
            AnimatedBuilder(
              animation: _twinkleController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 240),
                  painter: _StarsPainter(
                    twinkle: _twinkleController.value,
                    starColor: textColor,
                  ),
                );
              },
            ),

            // Crescent moon - same as gun_donumu_sayac_widget.dart.
            Positioned(
              right: 30,
              top: 25,
              child: SizedBox(
                width: 50,
                height: 50,
                child: _buildMoonWithPhase(_getMoonPhaseFraction(DateTime.now())),
              ),
            ),

            // Content.
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top: prayer time info.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.nightlight_round,
                        color: primaryColor.withOpacity(0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sonrakiVakit,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              color: primaryColor.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.nightlight_round,
                        color: primaryColor.withOpacity(0.8),
                        size: 18,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Countdown.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNightTimeUnit(
                        hours.toString().padLeft(2, '0'),
                        textColor,
                        primaryColor,
                      ),
                      Text(
                        ' : ',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          color: primaryColor.withOpacity(0.6),
                        ),
                      ),
                      _buildNightTimeUnit(
                        minutes.toString().padLeft(2, '0'),
                        textColor,
                        primaryColor,
                      ),
                      Text(
                        ' : ',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          color: primaryColor.withOpacity(0.6),
                        ),
                      ),
                      _buildNightTimeUnit(
                        seconds.toString().padLeft(2, '0'),
                        textColor,
                        primaryColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Bottom: dates.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          miladiTarih,
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.star,
                            size: 8,
                            color: primaryColor.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          hicriTarih,
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Progress bar.
                  _buildProgressBar(primaryColor, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color primaryColor, Color textColor) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: textColor.withOpacity(0.15),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _ProgressBarLinesPainter(
                lineColor: textColor.withOpacity(0.08),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: FractionallySizedBox(
              widthFactor: _ilerlemeOrani.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.7),
                      primaryColor,
                      Color.lerp(primaryColor, Colors.white, 0.2)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNightTimeUnit(String value, Color textColor, Color shadowColor) {
    return SizedBox(
      width: 65,
      child: Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w200,
          color: textColor,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [
            Shadow(color: shadowColor.withOpacity(0.3), blurRadius: 15),
          ],
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  final double twinkle;
  final Color starColor;

  _StarsPainter({required this.twinkle, required this.starColor});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final baseSize = random.nextDouble() * 2 + 0.5;
      final twinkleFactor = random.nextDouble();

      final currentSize = baseSize * (0.5 + twinkle * twinkleFactor * 0.5);
      final opacity = 0.3 + twinkle * twinkleFactor * 0.7;

      paint.color = starColor.withOpacity(opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) {
    return oldDelegate.twinkle != twinkle || oldDelegate.starColor != starColor;
  }
}

class _ProgressBarLinesPainter extends CustomPainter {
  final Color lineColor;

  _ProgressBarLinesPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (double x = 0; x < size.width; x += 8) {
      final dx = x + 0.5;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarLinesPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

/// Moon phase painter - same as gun_donumu_sayac_widget.dart.
class _MoonPhasePainter extends CustomPainter {
  final double phase;

  _MoonPhasePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Paint the moon fully dark first.
    final darkPaint = Paint()
      ..color = const Color(0xFF0A0A15).withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, darkPaint);

    // Illumination amount from 0.0 to 1.0.
    final illumination = phase <= 0.5 ? (phase * 2) : ((1 - phase) * 2);
    if (illumination <= 0.001) {
      // New moon - keep it dark.
      return;
    }

    // If full moon, paint fully bright.
    if (illumination >= 0.999) {
      final lightPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, lightPaint);
      return;
    }

    final shadowRatio = 1 - math.pow(illumination, 0.35).toDouble();
    final isWaxing = phase < 0.5;

    final path = Path();

    if (isWaxing) {
      // Waxing moon - left dark, right bright.
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        -math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (illumination < 0.5) {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          -math.pi / 2,
          -math.pi,
          false,
        );
      } else {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          -math.pi / 2,
          math.pi,
          false,
        );
      }
    } else {
      // Waning moon - right dark, left bright.
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (illumination < 0.5) {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          math.pi / 2,
          -math.pi,
          false,
        );
      } else {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          math.pi / 2,
          math.pi,
          false,
        );
      }
    }

    // Clip the bright area and paint it white.
    canvas.save();
    canvas.clipPath(path);
    final lightPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, lightPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MoonPhasePainter oldDelegate) =>
      oldDelegate.phase != phase;
}
