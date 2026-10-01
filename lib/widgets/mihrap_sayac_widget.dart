import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import 'package:intl/intl.dart';
import '../services/ozel_gunler_service.dart';

class MihrapSayacWidget extends StatefulWidget {
  const MihrapSayacWidget({super.key});

  @override
  State<MihrapSayacWidget> createState() => _MihrapSayacWidgetState();
}

class _MihrapSayacWidgetState extends State<MihrapSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();

  // Counter theme: original palette; manual theme: app theme colors.
  bool get _temaRenkleriKullan => !_temaService.sayacTemasiKullan;

  List<Color> get _arkaPlanRenkleri {
    if (!_temaRenkleriKullan) {
      return const [Color(0xFF2C1810), Color(0xFF5D4037), Color(0xFF8D6E63)];
    }
    final r = _temaService.renkler;
    return [
      r.arkaPlan,
      r.kartArkaPlan,
      Color.lerp(r.kartArkaPlan, r.vurgu, 0.35)!,
    ];
  }

  Color get _golgeRengi =>
      _temaRenkleriKullan ? _temaService.renkler.vurgu : const Color(0xFF5D4037);

  Color get _vurguRengi =>
      _temaRenkleriKullan ? _temaService.renkler.vurgu : Colors.amber;

  Color get _ikincilVurgu => _temaRenkleriKullan
      ? _temaService.renkler.vurguSecondary
      : Colors.orange;

  Color get _ucuncuVurgu => _temaRenkleriKullan
      ? _temaService.renkler.vurguSecondary
      : Colors.deepOrange;
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  String _gelecekVakit = '';
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
    _languageService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _archController.dispose();
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
    final miladi = DateFormat('d MMM yyyy', _getLocale()).format(DateTime.now());
    final hicri =
      '${hijriNow.hDay} ${_getHijriMonth(hijriNow.hMonth)} ${hijriNow.hYear}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white60,
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      miladi,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: Colors.white38)),
                    Icon(Icons.mosque, color: _vurguRengi, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      hicri,
                      style: TextStyle(color: _vurguRengi, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Vakit bilgisi
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _vurguRengi.withOpacity(0.3)),
                  ),
                  child: Text(
                    _gelecekVakit.toUpperCase(),
                    style: TextStyle(
                      color: _vurguRengi,
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
                    _buildTimePillar(
                      hours.toString().padLeft(2, '0'),
                      _languageService['hour_short'].toUpperCase(),
                    ),
                    const SizedBox(width: 10),
                    _buildTimePillar(
                      minutes.toString().padLeft(2, '0'),
                      _languageService['minute_short'].toUpperCase(),
                    ),
                    const SizedBox(width: 10),
                    _buildTimePillar(
                      seconds.toString().padLeft(2, '0'),
                      _languageService['second_short'].toUpperCase(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _vurguRengi.withOpacity(0.3),
                _vurguRengi.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _vurguRengi.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(color: _vurguRengi.withOpacity(0.2), blurRadius: 8),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
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
                  gradient: LinearGradient(
                    colors: [_vurguRengi, _ikincilVurgu, _ucuncuVurgu],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: _vurguRengi.withOpacity(0.6),
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
