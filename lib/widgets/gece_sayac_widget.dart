import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Gece/Ay temalı sayaç widget'ı
/// Koyu mavi gece gökyüzü, ay ve yıldızlar
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
        'adi': _languageService['imsak'] ?? 'İmsak',
        'saat': _vakitSaatleri['Imsak']!,
      },
      {
        'adi': _languageService['gunes'] ?? 'Güneş',
        'saat': _vakitSaatleri['Gunes']!,
      },
      {
        'adi': _languageService['ogle'] ?? 'Öğle',
        'saat': _vakitSaatleri['Ogle']!,
      },
      {
        'adi': _languageService['ikindi'] ?? 'İkindi',
        'saat': _vakitSaatleri['Ikindi']!,
      },
      {
        'adi': _languageService['aksam'] ?? 'Akşam',
        'saat': _vakitSaatleri['Aksam']!,
      },
      {
        'adi': _languageService['yatsi'] ?? 'Yatsı',
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
    final aylar = [
      '',
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
    return aylar[ay];
  }

  /// Ay fazını hesapla (0-7 arası 8 faz) - gun_donumu_sayac_widget.dart ile birebir aynı
  /// 0=Yeni Ay, 1=Hilal (büyüyen), 2=İlk Dördün, 3=Dolmak Üzere
  /// 4=Dolunay, 5=Küçülmeye Başlayan, 6=Son Dördün, 7=Hilal (küçülen)
  int _getMoonPhaseIndex(DateTime date) {
    // Bilinen yeni ay tarihi: 29 Aralık 2024 (daha güncel referans)
    final reference = DateTime.utc(2024, 12, 30, 22, 27);
    const synodicMonth = 29.53058867;

    final daysDiff = date.difference(reference).inHours / 24.0;
    final phase = (daysDiff % synodicMonth) / synodicMonth;

    // 0-1 arasındaki değeri 0-7 faz indeksine çevir
    return ((phase * 8) % 8).floor();
  }

  /// Ay fazına göre ay görseli - gun_donumu_sayac_widget.dart ile birebir aynı
  Widget _buildMoonWithPhase(int phase) {
    // Gerçek ay resmi üzerine gölge ile faz simülasyonu
    return Stack(
      children: [
        // Ana ay resmi
        Image.asset(
          'assets/icon/moon.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, __) => _fallbackMoon(phase),
        ),
        // Faz gölgesi
        CustomPaint(
          size: const Size(50, 50),
          painter: _MoonPhasePainter(phase: phase),
        ),
      ],
    );
  }

  /// Fallback ay - gun_donumu_sayac_widget.dart ile birebir aynı
  Widget _fallbackMoon(int phase) {
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
    final miladiTarih = DateFormat('dd MMMM yyyy', 'tr_TR').format(now);

    // Tema kontrolü: Varsayılansa orijinal, değilse tema renkleri
    final kullanTemaRenkleri = !_temaService.sayacTemasiKullan;
    final temaRenkleri = _temaService.renkler;

    // Orijinal renkler veya tema renkleri
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
            // Arka plan - Gece gökyüzü
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgColor1, bgColor2, bgColor2.withOpacity(0.8)],
                ),
              ),
            ),

            // Yıldızlar
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

            // Hilal Ay - gun_donumu_sayac_widget.dart ile aynı
            Positioned(
              right: 30,
              top: 25,
              child: SizedBox(
                width: 50,
                height: 50,
                child: _buildMoonWithPhase(_getMoonPhaseIndex(DateTime.now())),
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Üst: Vakit bilgisi
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

                  // Sayaç
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

                  // Alt: Tarihler
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

                  // İlerleme Barı
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

/// Ay fazı çizici - gun_donumu_sayac_widget.dart ile birebir aynı
class _MoonPhasePainter extends CustomPainter {
  final int phase;

  _MoonPhasePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Önce tüm ayı karanlık (siyah) boya
    final darkPaint = Paint()
      ..color = const Color(0xFF0A0A15).withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, darkPaint);

    // Dolunay ise tamamen aydınlık (beyaz) boya
    if (phase == 4) {
      final lightPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, lightPaint);
      return;
    }

    // Faz değerine göre aydınlık bölgenin genişliği
    final illumination = (phase <= 4) ? phase / 4.0 : (8 - phase) / 4.0;
    final shadowRatio = 1 - math.pow(illumination, 0.35).toDouble();

    final path = Path();

    if (phase == 0 || phase == 8) {
      // Yeni ay - hiç aydınlık yok, sadece siyah kalacak
      return;
    } else if (phase < 4) {
      // Büyüyen ay - SOL karanlık, SAĞ aydınlık
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        -math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (phase < 2) {
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
      // Küçülen ay - SAĞ karanlık, SOL aydınlık
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (phase > 6) {
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

    // Aydınlık kısmı clip et ve beyaz boya
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
