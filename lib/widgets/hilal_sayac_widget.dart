import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

class HilalSayacWidget extends StatefulWidget {
  const HilalSayacWidget({super.key});

  @override
  State<HilalSayacWidget> createState() => _HilalSayacWidgetState();
}

class _HilalSayacWidgetState extends State<HilalSayacWidget>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  Timer? _timer;
  String _gelecekVakit = "Öğle";
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
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _starController.dispose();
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
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);

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
        gelecekVakitIsmi = 'İmsak';
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

    final hijriNow = HijriCalendar.now();
    final miladi = DateFormat('d MMM yyyy', 'tr_TR').format(DateTime.now());
    final hicri =
        '${hijriNow.hDay} ${_getHijriMonth(hijriNow.hMonth)} ${hijriNow.hYear}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF415A77).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Yıldızlar
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
          // Hilal - Ay fazı görseli (gun_donumu_sayac_widget.dart ile aynı)
          Positioned(
            right: 25,
            top: 25,
            child: SizedBox(
              width: 50,
              height: 50,
              child: _buildMoonWithPhase(_getMoonPhaseIndex(DateTime.now())),
            ),
          ),
          // İçerik
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarih satırı (kompakt)
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
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Vakit
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
                    'Sonraki: $_gelecekVakit',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Kalan süre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeBox(hours.toString().padLeft(2, '0'), 'S'),
                    const SizedBox(width: 8),
                    _buildTimeBox(minutes.toString().padLeft(2, '0'), 'D'),
                    const SizedBox(width: 8),
                    _buildTimeBox(seconds.toString().padLeft(2, '0'), 'Sn'),
                  ],
                ),
                const SizedBox(height: 18),
                // Ecir barı
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amber,
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
    const months = [
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
    return months[month - 1];
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
          size: const Size(64, 64),
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
        size: const Size(64, 64),
        painter: _MoonPhasePainter(phase: phase),
      ),
    );
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
      // Büyüyen ay - SAĞ karanlık, SOL aydınlık (GÜN DÖNÜMÜ İLE AYNI YÖN)
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi,
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
          math.pi / 2,
          math.pi,
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
          -math.pi,
          false,
        );
      }
    } else {
      // Küçülen ay - SOL karanlık, SAĞ aydınlık (GÜN DÖNÜMÜ İLE AYNI YÖN)
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        -math.pi,
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
          -math.pi / 2,
          math.pi,
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
          -math.pi,
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
