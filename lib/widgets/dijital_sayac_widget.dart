import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class DijitalSayacWidget extends StatefulWidget {
  const DijitalSayacWidget({super.key});

  @override
  State<DijitalSayacWidget> createState() => _DijitalSayacWidgetState();
}

class _DijitalSayacWidgetState extends State<DijitalSayacWidget> {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

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

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      {'adi': _languageService['imsak'] ?? 'İmsak', 'saat': _vakitSaatleri['Imsak']!},
      {'adi': _languageService['gunes'] ?? 'Güneş', 'saat': _vakitSaatleri['Gunes']!},
      {'adi': _languageService['ogle'] ?? 'Öğle', 'saat': _vakitSaatleri['Ogle']!},
      {'adi': _languageService['ikindi'] ?? 'İkindi', 'saat': _vakitSaatleri['Ikindi']!},
      {'adi': _languageService['aksam'] ?? 'Akşam', 'saat': _vakitSaatleri['Aksam']!},
      {'adi': _languageService['yatsi'] ?? 'Yatsı', 'saat': _vakitSaatleri['Yatsi']!},
    ];

    List<int> vakitSaniyeleri = [];
    for (final vakit in vakitSaatleri) {
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
      final imsakSaat = _vakitSaatleri['Imsak']!.split(':');
      sonrakiVakitZamani = DateTime(
        yarin.year,
        yarin.month,
        yarin.day,
        int.parse(imsakSaat[0]),
        int.parse(imsakSaat[1]),
      );
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      final imsakSaat = _vakitSaatleri['Imsak']!.split(':');
      sonrakiVakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(imsakSaat[0]),
        int.parse(imsakSaat[1]),
      );
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
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
      final toplamSure = vakitSaniyeleri[sonrakiIndex] - vakitSaniyeleri[sonrakiIndex - 1];
      final gecenSure = nowTotalSeconds - vakitSaniyeleri[sonrakiIndex - 1];
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _ilerlemeOrani = oran;
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes % 60;
    final seconds = _kalanSure.inSeconds % 60;

    final now = DateTime.now();
    final locale = _getLocale();
    final miladiTarih = DateFormat('dd MMMM yyyy, EEEE', locale).format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih =
        '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            renkler.kartArkaPlan,
            renkler.kartArkaPlan.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_sonrakiVakit ${_languageService['time_to'] ?? 'Vaktine'}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: renkler.vurgu,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: renkler.vurgu.withValues(alpha: 0.5),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  hours.toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.bold,
                    color: renkler.yaziPrimary,
                    fontFamily: 'Digital-7',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  ':',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.bold,
                    color: renkler.yaziPrimary,
                    fontFamily: 'Digital-7',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  minutes.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.bold,
                    color: renkler.yaziPrimary,
                    fontFamily: 'Digital-7',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  ':',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.bold,
                    color: renkler.yaziPrimary,
                    fontFamily: 'Digital-7',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  seconds.toString().padLeft(2, '0'),
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.bold,
                    color: renkler.yaziPrimary,
                    fontFamily: 'Digital-7',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _languageService['gregorian_date'] ?? 'Miladi',
                      style: TextStyle(
                        color: renkler.yaziSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      miladiTarih,
                      style: TextStyle(
                        color: renkler.yaziSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _languageService['hijri_date'] ?? 'Hicri',
                      style: TextStyle(
                        color: renkler.yaziSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hicriTarih,
                      style: TextStyle(
                        color: renkler.yaziSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressBar(renkler.vurgu, renkler.yaziSecondary),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Color primaryColor, Color textColor) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: textColor.withOpacity(0.15),
        border: Border.all(
          color: textColor.withOpacity(0.1),
          width: 0.5,
        ),
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
            widthFactor: _ilerlemeOrani.clamp(0.0, 1.0),
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

  String _getLocale() {
    final lang = _languageService.currentLanguage;
    switch (lang) {
      case 'tr':
        return 'tr_TR';
      case 'en':
        return 'en_US';
      case 'de':
        return 'de_DE';
      case 'fr':
        return 'fr_FR';
      default:
        return 'tr_TR';
    }
  }

  String _getHicriAyAdi(int ay) {
    const aylar = [
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
  bool shouldRepaint(covariant _ProgressBarLinesPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
