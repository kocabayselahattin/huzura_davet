import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class PremiumSayacWidget extends StatefulWidget {
  final bool shouldLoadData;
  const PremiumSayacWidget({super.key, this.shouldLoadData = true});

  @override
  State<PremiumSayacWidget> createState() => _PremiumSayacWidgetState();
}

class _PremiumSayacWidgetState extends State<PremiumSayacWidget>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  double _ilerlemeYuzdesi = 0.0;
  Map<String, String> _vakitSaatleri = {};

  late AnimationController _breathController;
  late AnimationController _rotateController;
  late Animation<double> _breathAnimation;
  late Animation<double> _rotateAnimation;

  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  final List<String> _vakitSirasi = [
    'Imsak',
    'Gunes',
    'Ogle',
    'Ikindi',
    'Aksam',
    'Yatsi',
  ];

  Map<String, String> get _vakitAdlari => {
    'Imsak': _languageService['imsak'].toUpperCase(),
    'Gunes': _languageService['gunes'].toUpperCase(),
    'Ogle': _languageService['ogle'].toUpperCase(),
    'Ikindi': _languageService['ikindi'].toUpperCase(),
    'Aksam': _languageService['aksam'].toUpperCase(),
    'Yatsi': _languageService['yatsi'].toUpperCase(),
  };

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

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
    _breathController.dispose();
    _rotateController.dispose();
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
      final data = await DiyanetApiService.getVakitler(ilceId);
      if (data != null && data.containsKey('vakitler')) {
        final vakitler = data['vakitler'] as List;
        if (vakitler.isNotEmpty) {
          final bugun = DateTime.now();
          final bugunVakit =
              vakitler.firstWhere(
                    (v) {
                      final tarih = v['MiladiTarihKisa'] ?? '';
                      try {
                        final parts = tarih.split('.');
                        if (parts.length == 3) {
                          final gun = int.parse(parts[0]);
                          final ay = int.parse(parts[1]);
                          final yil = int.parse(parts[2]);
                          return gun == bugun.day &&
                              ay == bugun.month &&
                              yil == bugun.year;
                        }
                      } catch (e) {
                        // Tarih parse hatası - varsayılan değer kullanılacak
                      }
                      return false;
                    },
                    orElse: () => vakitler.isNotEmpty
                        ? Map<String, dynamic>.from(vakitler[0])
                        : <String, dynamic>{},
                  )
                  as Map<String, dynamic>;

          setState(() {
            _vakitSaatleri = {
              'Imsak': bugunVakit['Imsak'] ?? '05:30',
              'Gunes': bugunVakit['Gunes'] ?? '07:00',
              'Ogle': bugunVakit['Ogle'] ?? '12:30',
              'Ikindi': bugunVakit['Ikindi'] ?? '15:30',
              'Aksam': bugunVakit['Aksam'] ?? '18:00',
              'Yatsi': bugunVakit['Yatsi'] ?? '19:30',
            };
          });
          _hesaplaKalanSure();
        }
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
    final nowMinutes = now.hour * 60 + now.minute;

    DateTime? sonrakiVakitZamani;
    DateTime? mevcutVakitZamani;
    String sonrakiVakitKey = '';
    String mevcutVakitKey = '';

    for (int i = 0; i < _vakitSirasi.length; i++) {
      final key = _vakitSirasi[i];
      final saat = _vakitSaatleri[key]!;
      try {
        final parts = saat.split(':');
        final vakitMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

        if (vakitMinutes > nowMinutes) {
          sonrakiVakitZamani = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          sonrakiVakitKey = key;

          if (i > 0) {
            final oncekiKey = _vakitSirasi[i - 1];
            final oncekiSaat = _vakitSaatleri[oncekiKey]!;
            final oncekiParts = oncekiSaat.split(':');
            mevcutVakitZamani = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(oncekiParts[0]),
              int.parse(oncekiParts[1]),
            );
            mevcutVakitKey = oncekiKey;
          } else {
            final yatsiSaat = _vakitSaatleri['Yatsi']!;
            final yatsiParts = yatsiSaat.split(':');
            mevcutVakitZamani = DateTime(
              now.year,
              now.month,
              now.day - 1,
              int.parse(yatsiParts[0]),
              int.parse(yatsiParts[1]),
            );
            mevcutVakitKey = 'Yatsi';
          }
          break;
        }
      } catch (e) {
        // Vakit parse hatası - atla
      }
    }

    if (sonrakiVakitZamani == null) {
      final yarin = now.add(const Duration(days: 1));
      final imsakSaat = _vakitSaatleri['Imsak']!.split(':');
      sonrakiVakitZamani = DateTime(
        yarin.year,
        yarin.month,
        yarin.day,
        int.parse(imsakSaat[0]),
        int.parse(imsakSaat[1]),
      );
      sonrakiVakitKey = 'Imsak';

      final yatsiSaat = _vakitSaatleri['Yatsi']!.split(':');
      mevcutVakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(yatsiSaat[0]),
        int.parse(yatsiSaat[1]),
      );
      mevcutVakitKey = 'Yatsi';
    }

    double ilerleme = 0.0;
    if (mevcutVakitZamani != null) {
      final toplamSure = sonrakiVakitZamani
          .difference(mevcutVakitZamani)
          .inSeconds;
      final gecenSure = now.difference(mevcutVakitZamani).inSeconds;
      if (toplamSure > 0) {
        ilerleme = gecenSure / toplamSure;
        ilerleme = ilerleme.clamp(0.0, 1.0);
      }
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = _vakitAdlari[sonrakiVakitKey] ?? sonrakiVakitKey;
      _mevcutVakit = _vakitAdlari[mevcutVakitKey] ?? mevcutVakitKey;
      _ilerlemeYuzdesi = ilerleme;
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Card(
      color: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(10),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              renkler.kartArkaPlan,
              renkler.arkaPlan.withValues(alpha: 0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: renkler.vurgu.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathAnimation, _rotateAnimation]),
          builder: (context, child) {
            return Stack(
              children: [
                // Arka plan parçacıkları
                ...List.generate(8, (index) {
                  final angle =
                      (index * math.pi / 4) + _rotateAnimation.value * 0.3;
                  final radius =
                      80 +
                      math.sin(_breathAnimation.value * math.pi + index) * 10;
                  return Positioned(
                    left:
                        MediaQuery.of(context).size.width / 2 -
                        30 +
                        math.cos(angle) * radius,
                    top: 110 + math.sin(angle) * radius * 0.6,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: renkler.vurgu.withValues(
                          alpha: 0.3 + _breathAnimation.value * 0.2,
                        ),
                      ),
                    ),
                  );
                }),

                // Ana içerik
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mevcut vakit badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: renkler.vurgu.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: renkler.vurgu.withValues(
                              alpha: 0.3 + _breathAnimation.value * 0.2,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getVakitIcon(_mevcutVakit),
                              color: renkler.vurgu,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _mevcutVakit.isNotEmpty
                                  ? _mevcutVakit
                                  : _languageService['loading'].toUpperCase(),
                              style: TextStyle(
                                color: renkler.vurgu,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Sayaç container
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              renkler.vurgu.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            // Ana sayaç
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [renkler.yaziPrimary, renkler.vurgu],
                              ).createShader(bounds),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      _kalanSure.inHours.toString().padLeft(
                                        2,
                                        '0',
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 46,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                        shadows: [
                                          Shadow(
                                            color: Colors.white,
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 25,
                                    child: Text(
                                      ':',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 46,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                        shadows: [
                                          Shadow(
                                            color: Colors.white,
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      (_kalanSure.inMinutes % 60)
                                          .toString()
                                          .padLeft(2, '0'),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 46,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                        shadows: [
                                          Shadow(
                                            color: Colors.white,
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 25,
                                    child: Text(
                                      ':',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 46,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                        shadows: [
                                          Shadow(
                                            color: Colors.white,
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      (_kalanSure.inSeconds % 60)
                                          .toString()
                                          .padLeft(2, '0'),
                                      textAlign: TextAlign.left,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 46,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                        shadows: [
                                          Shadow(
                                            color: Colors.white,
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // İlerleme çubuğu
                            SizedBox(
                              width: 200,
                              child: _buildProgressBar(
                                renkler.vurgu,
                                renkler.yaziPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Sonraki vakit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_forward_ios,
                            color: renkler.yaziSecondary,
                            size: 10,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_languageService['next_prayer']}: ',
                            style: TextStyle(
                              color: renkler.yaziSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _sonrakiVakit,
                            style: TextStyle(
                              color: renkler.vurgu,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_vakitSaatleri.isNotEmpty) ...[
                            Text(
                              ' • ',
                              style: TextStyle(color: renkler.yaziSecondary),
                            ),
                            Text(
                              _vakitSaatleri[_sonrakiVakitKey()] ?? '',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Miladi ve Hicri Takvim
                      _buildTakvimRow(renkler),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTakvimRow(TemaRenkleri renkler) {
    final now = DateTime.now();
    final miladiTarih = DateFormat('dd MMM yyyy', _getLocale()).format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih =
        '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Miladi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: renkler.vurgu.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color: renkler.yaziSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                miladiTarih,
                style: TextStyle(color: renkler.yaziSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Hicri
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: renkler.vurgu.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.brightness_3, size: 12, color: renkler.vurgu),
              const SizedBox(width: 4),
              Text(
                hicriTarih,
                style: TextStyle(
                  color: renkler.vurgu,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getHicriAyAdi(int ay) {
    if (ay < 1 || ay > 12) return '';
    return _languageService['hijri_month_$ay'] ?? '';
  }

  String _sonrakiVakitKey() {
    for (final key in _vakitSirasi) {
      if (_vakitAdlari[key] == _sonrakiVakit) return key;
    }
    return '';
  }

  IconData _getVakitIcon(String vakit) {
    final imsak = _languageService['imsak'].toUpperCase();
    final gunes = _languageService['gunes'].toUpperCase();
    final ogle = _languageService['ogle'].toUpperCase();
    final ikindi = _languageService['ikindi'].toUpperCase();
    final aksam = _languageService['aksam'].toUpperCase();
    final yatsi = _languageService['yatsi'].toUpperCase();

    if (vakit == imsak) return Icons.dark_mode_outlined;
    if (vakit == gunes) return Icons.wb_sunny_outlined;
    if (vakit == ogle) return Icons.light_mode;
    if (vakit == ikindi) return Icons.wb_twilight;
    if (vakit == aksam) return Icons.nights_stay_outlined;
    if (vakit == yatsi) return Icons.bedtime_outlined;
    return Icons.schedule;
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
              painter: _ProgressBarLinesPainter(
                lineColor: textColor.withOpacity(0.08),
              ),
            ),
          ),
          FractionallySizedBox(
            widthFactor: _ilerlemeYuzdesi.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
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
        ],
      ),
    );
  }
}

class _ProgressBarLinesPainter extends CustomPainter {
  final Color lineColor;
  _ProgressBarLinesPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarLinesPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
