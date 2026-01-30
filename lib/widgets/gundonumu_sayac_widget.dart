import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/language_service.dart';
import '../services/tema_service.dart';

/// Gün Dönümü Sayaç - Elips üzerinde 24 saatlik dilim ve vakit yerleşimi
class GundonumuSayacWidget extends StatefulWidget {
  const GundonumuSayacWidget({super.key});

  @override
  State<GundonumuSayacWidget> createState() => _GundonumuSayacWidgetState();
}

class _GundonumuSayacWidgetState extends State<GundonumuSayacWidget> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  Timer? _timer;
  Map<String, String> _vakitSaatleri = {};
  Duration _kalanSure = Duration.zero;
  String _aktifVakitKey = 'imsak';
  String _sonrakiVakitKey = 'gunes';

  @override
  void initState() {
    super.initState();
    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hesaplaKalanSure();
    });
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
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
      {'key': 'imsak', 'saat': _vakitSaatleri['imsak']!},
      {'key': 'gunes', 'saat': _vakitSaatleri['gunes']!},
      {'key': 'ogle', 'saat': _vakitSaatleri['ogle']!},
      {'key': 'ikindi', 'saat': _vakitSaatleri['ikindi']!},
      {'key': 'aksam', 'saat': _vakitSaatleri['aksam']!},
      {'key': 'yatsi', 'saat': _vakitSaatleri['yatsi']!},
    ];

    final vakitSaniyeleri = vakitListesi.map((vakit) {
      final parts = (vakit['saat'] as String).split(':');
      return int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60;
    }).toList();

    int sonrakiIndex = -1;
    for (int i = 0; i < vakitSaniyeleri.length; i++) {
      if (vakitSaniyeleri[i] > nowTotalSeconds) {
        sonrakiIndex = i;
        break;
      }
    }

    DateTime sonrakiVakitZamani;
    String aktifKey;
    String sonrakiKey;

    if (sonrakiIndex == -1) {
      final yarin = now.add(const Duration(days: 1));
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(
        yarin.year,
        yarin.month,
        yarin.day,
        int.parse(imsakParts[0]),
        int.parse(imsakParts[1]),
      );
      aktifKey = 'yatsi';
      sonrakiKey = 'imsak';
    } else if (sonrakiIndex == 0) {
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(imsakParts[0]),
        int.parse(imsakParts[1]),
      );
      aktifKey = 'yatsi';
      sonrakiKey = 'imsak';
    } else {
      final parts = _vakitSaatleri[vakitListesi[sonrakiIndex]['key']!]!
          .split(':');
      sonrakiVakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      aktifKey = vakitListesi[sonrakiIndex - 1]['key'] as String;
      sonrakiKey = vakitListesi[sonrakiIndex]['key'] as String;
    }

    if (mounted) {
      setState(() {
        _aktifVakitKey = aktifKey;
        _sonrakiVakitKey = sonrakiKey;
        _kalanSure = sonrakiVakitZamani.difference(now);
      });
    }
  }

  Map<String, String> _vakitIsimleri() {
    return {
      'imsak': _languageService['imsak'] ?? 'İmsak',
      'gunes': _languageService['gunes'] ?? 'Güneş',
      'ogle': _languageService['ogle'] ?? 'Öğle',
      'ikindi': _languageService['ikindi'] ?? 'İkindi',
      'aksam': _languageService['aksam'] ?? 'Akşam',
      'yatsi': _languageService['yatsi'] ?? 'Yatsı',
    };
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final baseBg = renkler.arkaPlan;
    final surfaceBg = renkler.kartArkaPlan;
    final ringGold = renkler.vurgu;
    final ringGoldSoft = Color.lerp(renkler.vurgu, Colors.white, 0.2)!;
    final accentTeal = renkler.vurguSecondary;
    final accentTealDark = renkler.yaziPrimary;
    final textMuted = renkler.yaziSecondary;
    final dayBase = renkler.vurgu;
    final dayBright = Color.lerp(renkler.vurgu, Colors.white, 0.25)!;
    final dayDusk = Color.lerp(renkler.vurgu, Colors.black, 0.25)!;
    final nightMid = Color.lerp(renkler.arkaPlan, Colors.black, 0.35)!;
    final nightDeep = Colors.black;
    final mmToPx = (double mm) => mm * (160 / 25.4);
    final edgePadding = mmToPx(3);

    if (_vakitSaatleri.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final hours = _kalanSure.inHours.abs();
    final minutes = _kalanSure.inMinutes.remainder(60).abs();
    final seconds = _kalanSure.inSeconds.remainder(60).abs();
    final kalanText =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surfaceBg,
            baseBg,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(edgePadding),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _GundonumuPainter(
                      vakitSaatleri: _vakitSaatleri,
                      vakitIsimleri: _vakitIsimleri(),
                      aktifVakitKey: _aktifVakitKey,
                      sonrakiVakitKey: _sonrakiVakitKey,
                      now: DateTime.now(),
                      primary: ringGold,
                      secondary: accentTeal,
                      textColor: accentTealDark,
                      cardColor: surfaceBg,
                      dayBase: dayBase,
                      dayBright: dayBright,
                      dayDusk: dayDusk,
                      nightMid: nightMid,
                      nightDeep: nightDeep,
                      edgeInset: edgePadding,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceBg.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: ringGoldSoft.withValues(alpha: 0.7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _vakitIsimleri()[_sonrakiVakitKey] ??
                              _sonrakiVakitKey,
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildFixedTimeRow(
                          hours.toString().padLeft(2, '0'),
                          minutes.toString().padLeft(2, '0'),
                          seconds.toString().padLeft(2, '0'),
                          accentTealDark,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFixedTimeRow(
    String hours,
    String minutes,
    String seconds,
    Color color,
  ) {
    const digitStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            hours,
            textAlign: TextAlign.right,
            style: digitStyle.copyWith(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(':', style: digitStyle.copyWith(color: color)),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(
            minutes,
            textAlign: TextAlign.center,
            style: digitStyle.copyWith(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(':', style: digitStyle.copyWith(color: color)),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(
            seconds,
            textAlign: TextAlign.left,
            style: digitStyle.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _GundonumuPainter extends CustomPainter {
  final Map<String, String> vakitSaatleri;
  final Map<String, String> vakitIsimleri;
  final String aktifVakitKey;
  final String sonrakiVakitKey;
  final DateTime now;
  final Color primary;
  final Color secondary;
  final Color textColor;
  final Color cardColor;
  final Color dayBase;
  final Color dayBright;
  final Color dayDusk;
  final Color nightMid;
  final Color nightDeep;
  final double edgeInset;

  _GundonumuPainter({
    required this.vakitSaatleri,
    required this.vakitIsimleri,
    required this.aktifVakitKey,
    required this.sonrakiVakitKey,
    required this.now,
    required this.primary,
    required this.secondary,
    required this.textColor,
    required this.cardColor,
    required this.dayBase,
    required this.dayBright,
    required this.dayDusk,
    required this.nightMid,
    required this.nightDeep,
    required this.edgeInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = 4.2;
    final a = size.width / 2 - edgeInset;
    final b = size.height / 2 - edgeInset - 4;
    final aNarrow = (a - 8).clamp(0.0, a);

    final ovalRect = Rect.fromCenter(
      center: center,
      width: aNarrow * 2,
      height: b * 2,
    );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 5
      ..color = dayBase.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(ovalRect, glowPaint);

    _drawDayNightRing(canvas, center, aNarrow, b, stroke);

    _drawPrayerMarkers(canvas, center, aNarrow, b);
    _drawSunOrMoon(canvas, center, aNarrow, b);
  }

  void _drawDayNightRing(
    Canvas canvas,
    Offset center,
    double a,
    double b,
    double stroke,
  ) {
    final sunriseMinutes = _timeToMinutes(vakitSaatleri['gunes']!);
    final sunsetMinutes = _timeToMinutes(vakitSaatleri['aksam']!);
    final imsakMinutes = _timeToMinutes(vakitSaatleri['imsak']!);
    final yatsiMinutes = _timeToMinutes(vakitSaatleri['yatsi']!);

    final dayDuration = (sunsetMinutes - sunriseMinutes) % 1440;
    final noonMinutes = (sunriseMinutes + (dayDuration / 2).round()) % 1440;

    final steps = 240;
    for (int i = 0; i < steps; i++) {
      final minuteStart = (sunriseMinutes + (i / steps) * 1440).round() % 1440;
      final minuteEnd =
          (sunriseMinutes + ((i + 1) / steps) * 1440).round() % 1440;
      final minuteMid =
          (minuteStart + ((minuteEnd - minuteStart) % 1440) / 2).round() % 1440;

      final color = _colorForMinute(
        minuteMid,
        sunriseMinutes,
        noonMinutes,
        sunsetMinutes,
        yatsiMinutes,
        imsakMinutes,
      );

      final angleStart = _angleFromSunrise(minuteStart, sunriseMinutes);
      final angleEnd = _angleFromSunrise(minuteEnd, sunriseMinutes);

      final p1 = Offset(
        center.dx + math.cos(angleStart) * a,
        center.dy + math.sin(angleStart) * b,
      );
      final p2 = Offset(
        center.dx + math.cos(angleEnd) * a,
        center.dy + math.sin(angleEnd) * b,
      );

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, paint);
    }
  }

  Color _colorForMinute(
    int minutes,
    int sunriseMinutes,
    int noonMinutes,
    int sunsetMinutes,
    int yatsiMinutes,
    int imsakMinutes,
  ) {
    if (_isBetween(minutes, sunriseMinutes, sunsetMinutes)) {
      if (_isBetween(minutes, sunriseMinutes, noonMinutes)) {
        final t = _progressBetween(minutes, sunriseMinutes, noonMinutes);
        return Color.lerp(dayBase, dayBright, t) ?? dayBase;
      }
      final t = _progressBetween(minutes, noonMinutes, sunsetMinutes);
      return Color.lerp(dayBright, dayDusk, t) ?? dayDusk;
    }

    if (_isBetween(minutes, sunsetMinutes, yatsiMinutes)) {
      final t = _progressBetween(minutes, sunsetMinutes, yatsiMinutes);
      return Color.lerp(dayDusk, nightMid, t) ?? nightMid;
    }

    if (_isBetween(minutes, yatsiMinutes, imsakMinutes)) {
      final t = _progressBetween(minutes, yatsiMinutes, imsakMinutes);
      return Color.lerp(nightMid, nightDeep, t) ?? nightDeep;
    }

    final t = _progressBetween(minutes, imsakMinutes, sunriseMinutes);
    return Color.lerp(nightDeep, dayBase, t) ?? dayBase;
  }

  bool _isBetween(int minutes, int start, int end) {
    if (start <= end) {
      return minutes >= start && minutes <= end;
    }
    return minutes >= start || minutes <= end;
  }

  double _progressBetween(int minutes, int start, int end) {
    final duration = (end - start) % 1440;
    if (duration == 0) return 0;
    final delta = (minutes - start) % 1440;
    return (delta / duration).clamp(0.0, 1.0);
  }

  void _drawDayNightArc(Canvas canvas, Offset center, double a, double b) {
    final sunriseMinutes = _timeToMinutes(vakitSaatleri['gunes']!);
    final sunsetMinutes = _timeToMinutes(vakitSaatleri['aksam']!);

    final dayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = secondary.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final nightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = primary.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    const int steps = 120;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final minutes = (sunriseMinutes + t * ((sunsetMinutes - sunriseMinutes) % 1440)).round();
      final angle = _angleFromSunrise(minutes, sunriseMinutes);
      final p1 = Offset(
        center.dx + math.cos(angle) * a,
        center.dy + math.sin(angle) * b,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * (a - 4),
        center.dy + math.sin(angle) * (b - 4),
      );
      canvas.drawLine(p1, p2, dayPaint);
    }

    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final minutes = (sunsetMinutes + t * ((sunriseMinutes - sunsetMinutes) % 1440)).round();
      final angle = _angleFromSunrise(minutes, sunriseMinutes);
      final p1 = Offset(
        center.dx + math.cos(angle) * a,
        center.dy + math.sin(angle) * b,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * (a - 4),
        center.dy + math.sin(angle) * (b - 4),
      );
      canvas.drawLine(p1, p2, nightPaint);
    }
  }

  void _drawPrayerMarkers(Canvas canvas, Offset center, double a, double b) {
    final markerPaint = Paint()..style = PaintingStyle.fill;
    final textStyle = TextStyle(
      color: textColor,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );

    final nowMinutes = now.hour * 60 + now.minute;
    final sunriseMinutes = _timeToMinutes(vakitSaatleri['gunes']!);

    for (final entry in vakitSaatleri.entries) {
      final minutes = _timeToMinutes(entry.value);
      final angle = _angleFromSunrise(minutes, sunriseMinutes);
      final point = Offset(
        center.dx + math.cos(angle) * a,
        center.dy + math.sin(angle) * b,
      );

      final isActive = entry.key == aktifVakitKey;
        markerPaint.color =
          isActive ? secondary : primary.withValues(alpha: 0.35);
        final radius = isActive ? 6.5 : 4.0;
      canvas.drawCircle(point, radius, markerPaint);

      final label = vakitIsimleri[entry.key] ?? entry.key;
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: isActive
              ? textStyle.copyWith(fontSize: 13.5)
              : textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      var offset = Offset(
        point.dx + (math.cos(angle) >= 0 ? 8 : -textPainter.width - 8),
        point.dy + (math.sin(angle) >= 0 ? 4 : -textPainter.height - 4),
      );
      if (entry.key == 'gunes') {
        offset = offset.translate(2, 0);
      }
      final bgRect = Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      final bgPaint = Paint()
        ..color = cardColor.withValues(alpha: 0.65);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)),
        bgPaint,
      );
      textPainter.paint(canvas, offset);
    }

    // Şu anki zamanın noktasını hafif göstergesi
    final nowAngle = _angleFromSunrise(nowMinutes, sunriseMinutes);
    final nowPoint = Offset(
      center.dx + math.cos(nowAngle) * a,
      center.dy + math.sin(nowAngle) * b,
    );
    final nowPaint = Paint()..color = secondary.withValues(alpha: 0.5);
    canvas.drawCircle(nowPoint, 3, nowPaint);
  }

  void _drawSunOrMoon(Canvas canvas, Offset center, double a, double b) {
    final sunriseMinutes = _timeToMinutes(vakitSaatleri['gunes']!);
    final sunsetMinutes = _timeToMinutes(vakitSaatleri['aksam']!);
    final nowMinutes = now.hour * 60 + now.minute;
    final dayDuration = (sunsetMinutes - sunriseMinutes) % 1440;
    final noonMinutes = (sunriseMinutes + (dayDuration / 2).round()) % 1440;

    final isDay =
        nowMinutes >= sunriseMinutes && nowMinutes < sunsetMinutes;
    final angle = _angleFromSunrise(nowMinutes, sunriseMinutes);
    final point = Offset(
      center.dx + math.cos(angle) * (a - 8),
      center.dy + math.sin(angle) * (b - 8),
    );

    if (isDay) {
      final sunColor = _colorForMinute(
        nowMinutes,
        sunriseMinutes,
        noonMinutes,
        sunsetMinutes,
        _timeToMinutes(vakitSaatleri['yatsi']!),
        _timeToMinutes(vakitSaatleri['imsak']!),
      );
      _drawSun(canvas, point, 20, sunColor);
    } else {
      _drawMoon(canvas, point, 20, _moonPhase(now));
    }
  }

  void _drawSun(Canvas canvas, Offset center, double radius, Color sunColor) {
    final sunPaint = Paint()..color = sunColor;
    canvas.drawCircle(center, radius, sunPaint);

    final rayPaint = Paint()
      ..color = sunColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final start = Offset(
        center.dx + math.cos(angle) * (radius + 2),
        center.dy + math.sin(angle) * (radius + 2),
      );
      final end = Offset(
        center.dx + math.cos(angle) * (radius + 6),
        center.dy + math.sin(angle) * (radius + 6),
      );
      canvas.drawLine(start, end, rayPaint);
    }
  }

  void _drawMoon(Canvas canvas, Offset center, double radius, double phase) {
    final moonPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, moonPaint);

    final phaseDistance = (phase - 0.5).abs();
    final offsetMagnitude =
        ((1 - (phaseDistance * 2)).clamp(0.0, 1.0)) * radius * 2.2;
    final direction = phase < 0.5 ? 1.0 : -1.0;
    final phaseOffset = offsetMagnitude * direction;
    final shadowPaint = Paint()..color = nightDeep.withValues(alpha: 0.95);
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawCircle(
      Offset(center.dx + phaseOffset, center.dy),
      radius,
      shadowPaint,
    );
    canvas.restore();

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFBFC4C6);
    canvas.drawCircle(center, radius, rimPaint);
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  double _angleFromSunrise(int minutes, int sunriseMinutes) {
    final delta = (minutes - sunriseMinutes) % 1440;
    return (delta / 1440) * 2 * math.pi + math.pi;
  }

  double _moonPhase(DateTime date) {
    // Basit ay fazı hesabı
    final knownNewMoon = DateTime(2000, 1, 6, 18, 14);
    final days = date.difference(knownNewMoon).inHours / 24.0;
    final synodicMonth = 29.53058867;
    final phase = (days % synodicMonth) / synodicMonth;
    return phase;
  }

  @override
  bool shouldRepaint(covariant _GundonumuPainter oldDelegate) {
    return oldDelegate.now != now ||
        oldDelegate.aktifVakitKey != aktifVakitKey ||
        oldDelegate.sonrakiVakitKey != sonrakiVakitKey ||
        oldDelegate.vakitSaatleri != vakitSaatleri;
  }
}
