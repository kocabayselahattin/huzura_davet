import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import 'package:intl/intl.dart';
import '../services/ozel_gunler_service.dart';

class HilalSayacWidget extends StatefulWidget {
  const HilalSayacWidget({super.key});

  @override
  State<HilalSayacWidget> createState() => _HilalSayacWidgetState();
}

class _HilalSayacWidgetState extends State<HilalSayacWidget>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();

  // Counter theme: original palette; manual theme: app theme colors.
  bool get _temaRenkleriKullan => !_temaService.sayacTemasiKullan;

  List<Color> get _arkaPlanRenkleri {
    if (!_temaRenkleriKullan) {
      return const [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)];
    }
    final r = _temaService.renkler;
    return [
      r.arkaPlan,
      r.kartArkaPlan,
      Color.lerp(r.kartArkaPlan, r.vurgu, 0.35)!,
    ];
  }

  Color get _golgeRengi =>
      _temaRenkleriKullan ? _temaService.renkler.vurgu : const Color(0xFF415A77);

  Color get _vurguRengi =>
      _temaRenkleriKullan ? _temaService.renkler.vurgu : Colors.amber;
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  String _gelecekVakit = '';
  Duration _kalanSure = const Duration();
  Map<String, String> _vakitler = {};
  double _ecirOrani = 0.0;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _vakitHesapla();
      }
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
    _starController.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId == null || ilceId.isEmpty) {
      _setDefaultTimes();
      return;
    }

    try {
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);

      if (mounted && vakitler != null) {
        setState(() {
          _vakitler = vakitler;
        });
        _vakitHesapla();
      } else {
        _setDefaultTimes();
      }
    } catch (e) {
      debugPrint('Failed to load prayer times: $e');
      _setDefaultTimes();
    }
  }

  void _setDefaultTimes() {
    if (!mounted) return;
    setState(() {
      _vakitler = {
        'Imsak': '05:30',
        'Gunes': '07:00',
        'Ogle': '12:30',
        'Ikindi': '15:30',
        'Aksam': '18:00',
        'Yatsi': '19:30',
      };
    });
    _vakitHesapla();
  }

  void _vakitHesapla() {
    if (_vakitler.isEmpty) return;

    final now = DateTime.now();
    final vakitSirasi = ['Imsak', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];
    final vakitIsimleri = {
      'Imsak': _languageService['imsak'],
      'Gunes': _languageService['gunes'],
      'Ogle': _languageService['ogle'],
      'Ikindi': _languageService['ikindi'],
      'Aksam': _languageService['aksam'],
      'Yatsi': _languageService['yatsi'],
    };

    DateTime? gelecekVakitZamani;
    String? gelecekVakitIsmi;
    String? gelecekVakitKey;
    final vakitTimes = <String, DateTime>{};

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

      vakitTimes[vakit] = vakitZamani;

      if (gelecekVakitZamani == null && vakitZamani.isAfter(now)) {
        gelecekVakitZamani = vakitZamani;
        gelecekVakitIsmi = vakitIsimleri[vakit];
        gelecekVakitKey = vakit;
      }
    }

    if (gelecekVakitZamani == null) {
      final imsakZamani = vakitTimes['Imsak'];
      if (imsakZamani != null) {
        gelecekVakitZamani = imsakZamani.add(const Duration(days: 1));
        gelecekVakitIsmi = _languageService['imsak'];
        gelecekVakitKey = 'Imsak';
      }
    }

    if (gelecekVakitZamani != null &&
        gelecekVakitIsmi != null &&
        gelecekVakitKey != null) {
      final kalan = gelecekVakitZamani.difference(now);

      final imsakToday = vakitTimes['Imsak'];
      final yatsiToday = vakitTimes['Yatsi'];
      DateTime? onceVakitZamani;

      if (gelecekVakitKey == 'Imsak' &&
          imsakToday != null &&
          now.isBefore(imsakToday) &&
          yatsiToday != null) {
        onceVakitZamani = yatsiToday.subtract(const Duration(days: 1));
      } else {
        final nextIndex = vakitSirasi.indexOf(gelecekVakitKey);
        if (nextIndex != -1) {
          final prevKey =
              vakitSirasi[(nextIndex - 1 + vakitSirasi.length) %
                  vakitSirasi.length];
          onceVakitZamani = vakitTimes[prevKey];
        }
        onceVakitZamani ??= yatsiToday;
      }

      onceVakitZamani ??= now;
      final toplamSure = gelecekVakitZamani
          .difference(onceVakitZamani)
          .inSeconds;
      final gecenSure = now.difference(onceVakitZamani).inSeconds;
      final oran = toplamSure <= 0
          ? 0.0
          : (gecenSure / toplamSure).clamp(0.0, 1.0);

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

    final hijriNow = OzelGunlerService.hijriNowTR();
    final miladi = DateFormat(
      'd MMM yyyy',
      _getLocale(),
    ).format(DateTime.now());
    final hicri =
        '${hijriNow.hDay} ${_getHijriMonth(hijriNow.hMonth)} ${hijriNow.hYear}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: _arkaPlanRenkleri,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _golgeRengi.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Stars
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _StarPainter(_starController.value),
                );
              },
            ),
          ),
          // Crescent - moon phase visual (same as gun_donumu_sayac_widget.dart)
          Positioned(
            right: 25,
            top: 25,
            child: SizedBox(
              width: 50,
              height: 50,
              child: _buildMoonWithPhase(_getMoonPhaseFraction(DateTime.now())),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date row (compact)
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
                      style: TextStyle(color: _vurguRengi, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Prayer time
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${_languageService['next_prayer']}: $_gelecekVakit',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Remaining time
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeBox(
                      hours.toString().padLeft(2, '0'),
                      _languageService['hour_short'] ?? '',
                    ),
                    const SizedBox(width: 8),
                    _buildTimeBox(
                      minutes.toString().padLeft(2, '0'),
                      _languageService['minute_short'] ?? '',
                    ),
                    const SizedBox(width: 8),
                    _buildTimeBox(
                      seconds.toString().padLeft(2, '0'),
                      _languageService['second_short'] ?? '',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Reward bar
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _ecirOrani,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _vurguRengi,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Container(
      width: 65,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  String _getHijriMonth(int month) {
    if (month < 1 || month > 12) return '';
    return _languageService['hijri_month_$month'] ?? '';
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
  /// 0.0=New Moon, 0.5=Full Moon, 1.0=New Moon
  double _getMoonPhaseFraction(DateTime date) {
    // Known new moon date in UTC.
    final reference = DateTime.utc(2024, 12, 30, 22, 27);
    const synodicMonth = 29.53058867;

    final daysDiff = date.difference(reference).inHours / 24.0;
    var cycleDay = daysDiff % synodicMonth;
    if (cycleDay < 0) {
      cycleDay += synodicMonth;
    }
    final phase = cycleDay / synodicMonth;

    return phase;
  }

  /// Moon visual by phase - identical to gun_donumu_sayac_widget.dart
  Widget _buildMoonWithPhase(double phase) {
    // Phase simulation with shadow over the real moon image
    return Stack(
      children: [
        // Base moon image
        Image.asset(
          'assets/icon/moon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackMoon(phase),
        ),
        // Phase shadow
        CustomPaint(
          size: const Size(64, 64),
          painter: _MoonPhasePainter(phase: phase),
        ),
      ],
    );
  }

  /// Fallback moon - identical to gun_donumu_sayac_widget.dart
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
        size: const Size(64, 64),
        painter: _MoonPhasePainter(phase: phase),
      ),
    );
  }
}

/// Moon phase painter - identical to gun_donumu_sayac_widget.dart
class _MoonPhasePainter extends CustomPainter {
  final double phase;

  _MoonPhasePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final phaseNorm = ((phase % 1.0) + 1.0) % 1.0;

    // Paint the full moon dark first
    final darkPaint = Paint()
      ..color = const Color(0xFF0A0A15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, darkPaint);

    // Physical illuminated fraction: 0=new, 0.5=full, 1=new.
    final illumination = 0.5 * (1 - math.cos(2 * math.pi * phaseNorm));
    if (illumination <= 0.001) {
      // New moon - no illumination
      return;
    }

    // If full moon, paint fully bright
    if (illumination >= 0.999) {
      final lightPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, lightPaint);
      return;
    }

    // k controls the terminator curvature across the cycle.
    final k = math.cos(2 * math.pi * phaseNorm);
    final isWaxing = phaseNorm < 0.5;
    const steps = 96;
    final path = Path();

    // Traverse the illuminated limb (outer edge).
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final y = -radius + (2 * radius * t);
      final xOuter = math.sqrt(math.max(0.0, radius * radius - y * y));
      final x = isWaxing ? xOuter : -xOuter;
      final point = Offset(center.dx + x, center.dy + y);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    // Return over the terminator curve.
    for (int i = steps; i >= 0; i--) {
      final t = i / steps;
      final y = -radius + (2 * radius * t);
      final xOuter = math.sqrt(math.max(0.0, radius * radius - y * y));
      final xTerm = isWaxing ? (k * xOuter) : (-k * xOuter);
      path.lineTo(center.dx + xTerm, center.dy + y);
    }
    path.close();

    // Clip the illuminated area and paint white
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

class _StarPainter extends CustomPainter {
  final double progress;

  _StarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = (math.sin(progress * 2 * math.pi + i) + 1) / 2;
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => true;
}
