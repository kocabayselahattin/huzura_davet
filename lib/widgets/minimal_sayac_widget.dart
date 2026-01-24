import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Minimal tasarımlı sayaç widget'ı
/// Sade, temiz ve modern görünüm
class MinimalSayacWidget extends StatefulWidget {
  const MinimalSayacWidget({super.key});

  @override
  State<MinimalSayacWidget> createState() => _MinimalSayacWidgetState();
}

class _MinimalSayacWidgetState extends State<MinimalSayacWidget> {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
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
    String mevcutVakitAdi = '';
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
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day + 1,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      mevcutVakitAdi = vakitSaatleri.last['adi']!;
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      mevcutVakitAdi = vakitSaatleri.last['adi']!;
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds + (24 * 3600 - yatsiSaniye);
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else {
      final parts = vakitSaatleri[sonrakiIndex]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[sonrakiIndex]['adi']!;
      mevcutVakitAdi = sonrakiIndex > 0 ? vakitSaatleri[sonrakiIndex - 1]['adi']! : vakitSaatleri.last['adi']!;
      final toplamSure = vakitSaniyeleri[sonrakiIndex] - vakitSaniyeleri[sonrakiIndex - 1];
      final gecenSure = nowTotalSeconds - vakitSaniyeleri[sonrakiIndex - 1];
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _mevcutVakit = mevcutVakitAdi;
      _ilerlemeOrani = oran;
    });
  }

  String _getLocale() {
    switch (_languageService.currentLanguage) {
      case 'tr': return 'tr_TR';
      case 'en': return 'en_US';
      case 'de': return 'de_DE';
      case 'fr': return 'fr_FR';
      case 'ar': return 'ar_SA';
      case 'fa': return 'fa_IR';
      default: return 'tr_TR';
    }
  }

  String _getHicriAyAdi(int ay) {
    final aylar = [
      '', 'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir',
      'Cemaziyelevvel', 'Cemaziyelahir', 'Recep', 'Şaban', 'Ramazan',
      'Şevval', 'Zilkade', 'Zilhicce'
    ];
    return aylar[ay];
  }

  @override
  Widget build(BuildContext context) {
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes % 60;
    final seconds = _kalanSure.inSeconds % 60;

    final now = DateTime.now();
    final locale = _getLocale();
    final miladiTarih = DateFormat('dd MMM yyyy', locale).format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)}';

    // Tema kontrolü: Varsayılansa orijinal, değilse tema renkleri
    final kullanTemaRenkleri = !_temaService.sayacTemasiKullan;
    final temaRenkleri = _temaService.renkler;
    
    // Orijinal renkler
    final bgColor = kullanTemaRenkleri ? temaRenkleri.kartArkaPlan : Colors.white;
    final textColor = kullanTemaRenkleri ? temaRenkleri.yaziPrimary : Colors.black87;
    final secondaryTextColor = kullanTemaRenkleri ? temaRenkleri.yaziSecondary : Colors.grey[600];
    final accentColor = kullanTemaRenkleri ? temaRenkleri.vurgu : Colors.black;
    final mutedColor = kullanTemaRenkleri ? temaRenkleri.yaziSecondary.withOpacity(0.5) : Colors.grey[400];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Üst: Mevcut ve Sonraki Vakit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mevcutVakit.toUpperCase(),
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_languageService['current_prayer'] ?? 'Şu an'}',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _sonrakiVakit,
                  style: TextStyle(
                    color: kullanTemaRenkleri ? temaRenkleri.yaziPrimary : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Orta: Sayaç
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _buildTimeUnit(hours.toString().padLeft(2, '0'), 'h', textColor, mutedColor),
                Text(' : ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w200, color: textColor)),
                _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'm', textColor, mutedColor),
                Text(' : ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w200, color: textColor)),
                _buildTimeUnit(seconds.toString().padLeft(2, '0'), 's', textColor, mutedColor),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Alt: Tarihler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                miladiTarih,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedColor,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                hicriTarih,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // İlerleme Barı
          _buildProgressBar(accentColor, textColor),
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

  Widget _buildTimeUnit(String value, String unit, Color textColor, Color? unitColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 65,
          child: Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: unitColor,
          ),
        ),
      ],
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
  bool shouldRepaint(covariant _ProgressBarLinesPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
