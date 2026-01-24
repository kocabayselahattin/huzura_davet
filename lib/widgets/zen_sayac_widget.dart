import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Zen temalı sayaç widget'ı
/// Japon bahçesi esintisi, huzurlu renkler, bambu ve su efektleri
class ZenSayacWidget extends StatefulWidget {
  const ZenSayacWidget({super.key});

  @override
  State<ZenSayacWidget> createState() => _ZenSayacWidgetState();
}

class _ZenSayacWidgetState extends State<ZenSayacWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  double _ilerlemeOrani = 0.0;
  
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    
    _rippleController = AnimationController(
      duration: const Duration(seconds: 4),
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
    _rippleController.dispose();
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
    final nowMinutes = now.hour * 60 + now.minute;
    final nowTotalSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    final vakitSaatleri = [
      {'adi': _languageService['imsak'] ?? 'İmsak', 'saat': _vakitSaatleri['Imsak']!},
      {'adi': _languageService['gunes'] ?? 'Güneş', 'saat': _vakitSaatleri['Gunes']!},
      {'adi': _languageService['ogle'] ?? 'Öğle', 'saat': _vakitSaatleri['Ogle']!},
      {'adi': _languageService['ikindi'] ?? 'İkindi', 'saat': _vakitSaatleri['Ikindi']!},
      {'adi': _languageService['aksam'] ?? 'Akşam', 'saat': _vakitSaatleri['Aksam']!},
      {'adi': _languageService['yatsi'] ?? 'Yatsı', 'saat': _vakitSaatleri['Yatsi']!},
    ];

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';
    String mevcutVakitAdi = '';
    int mevcutVakitIndex = -1;

    for (int i = 0; i < vakitSaatleri.length; i++) {
      final parts = vakitSaatleri[i]['saat']!.split(':');
      final vakitMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

      if (vakitMinutes > nowMinutes) {
        sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        sonrakiVakitAdi = vakitSaatleri[i]['adi']!;
        mevcutVakitAdi = i > 0 ? vakitSaatleri[i - 1]['adi']! : vakitSaatleri.last['adi']!;
        mevcutVakitIndex = i > 0 ? i - 1 : vakitSaatleri.length - 1;
        break;
      }
    }

    if (sonrakiVakitZamani == null) {
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day + 1,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      mevcutVakitAdi = vakitSaatleri.last['adi']!;
      mevcutVakitIndex = vakitSaatleri.length - 1;
    }

    // İlerleme oranı hesapla
    double ilerlemeOrani = 0.0;
    if (mevcutVakitIndex >= 0) {
      final mevcutParts = vakitSaatleri[mevcutVakitIndex]['saat']!.split(':');
      final mevcutVakitSeconds = int.parse(mevcutParts[0]) * 3600 + int.parse(mevcutParts[1]) * 60;
      
      int sonrakiVakitSeconds;
      if (mevcutVakitIndex == vakitSaatleri.length - 1) {
        // Yatsıdan sonra - gece yarısından sonra imsak öncesi veya normal gündüz vakitleri
        final imsakParts = vakitSaatleri[0]['saat']!.split(':');
        final imsakSeconds = int.parse(imsakParts[0]) * 3600 + int.parse(imsakParts[1]) * 60;
        
        if (nowTotalSeconds < imsakSeconds) {
          // Gece yarısından sonra, imsak öncesi
          final toplamSure = imsakSeconds;
          final gecenSure = nowTotalSeconds;
          ilerlemeOrani = (gecenSure / toplamSure).clamp(0.0, 1.0);
        } else {
          // Yatsıdan gece yarısına kadar
          final toplamSure = (24 * 3600 - mevcutVakitSeconds) + imsakSeconds;
          final gecenSure = nowTotalSeconds - mevcutVakitSeconds;
          ilerlemeOrani = (gecenSure / toplamSure).clamp(0.0, 1.0);
        }
      } else {
        // Normal gündüz vakitleri
        final sonrakiParts = vakitSaatleri[mevcutVakitIndex + 1]['saat']!.split(':');
        sonrakiVakitSeconds = int.parse(sonrakiParts[0]) * 3600 + int.parse(sonrakiParts[1]) * 60;
        
        final toplamSure = sonrakiVakitSeconds - mevcutVakitSeconds;
        final gecenSure = nowTotalSeconds - mevcutVakitSeconds;
        ilerlemeOrani = (gecenSure / toplamSure).clamp(0.0, 1.0);
      }
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _mevcutVakit = mevcutVakitAdi;
      _ilerlemeOrani = ilerlemeOrani;
    });
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
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';
    final miladiTarih = DateFormat('dd MMMM yyyy', 'tr_TR').format(now);

    // Tema kontrolü: Varsayılansa orijinal, değilse tema renkleri
    final kullanTemaRenkleri = !_temaService.sayacTemasiKullan;
    final temaRenkleri = _temaService.renkler;

    // Orijinal renkler veya tema renkleri
    final primaryColor = kullanTemaRenkleri ? temaRenkleri.vurgu : const Color(0xFF4A6741);
    final secondaryColor = kullanTemaRenkleri ? temaRenkleri.vurguSecondary : const Color(0xFF6B8E5F);
    final bgColor1 = kullanTemaRenkleri ? temaRenkleri.kartArkaPlan : const Color(0xFFF5F5DC);
    final bgColor2 = kullanTemaRenkleri ? temaRenkleri.arkaPlan : const Color(0xFFE8E4D9);
    final textColor = kullanTemaRenkleri ? temaRenkleri.yaziPrimary : const Color(0xFF2D3A29);
    final secondaryTextColor = kullanTemaRenkleri ? temaRenkleri.yaziSecondary : const Color(0xFF5C6B54);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Arka plan - Doğal yeşil gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bgColor1,
                    bgColor2,
                    bgColor2.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            
            // Su dalgası efekti
            AnimatedBuilder(
              animation: _rippleController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 240),
                  painter: _ZenRipplePainter(progress: _rippleController.value, color: primaryColor),
                );
              },
            ),
            
            // Bambu dekorasyonu
            Positioned(
              right: 20,
              top: 20,
              bottom: 20,
              child: CustomPaint(
                size: const Size(30, 200),
                painter: _BambooPainter(color: primaryColor),
              ),
            ),
            
            // İçerik
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst: Vakit bilgisi
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sonrakiVakit,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'vaktine kalan',
                            style: TextStyle(
                              color: primaryColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Sayaç
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildZenTimeUnit(hours.toString().padLeft(2, '0'), '時', primaryColor, textColor),
                          const SizedBox(width: 16),
                          _buildZenTimeUnit(minutes.toString().padLeft(2, '0'), '分', primaryColor, textColor),
                          const SizedBox(width: 16),
                          _buildZenTimeUnit(seconds.toString().padLeft(2, '0'), '秒', primaryColor, textColor),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Alt: Tarihler
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$miladiTarih  •  $hicriTarih',
                        style: TextStyle(
                          color: primaryColor.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // İlerleme barı
                  _buildProgressBar(primaryColor, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZenTimeUnit(String value, String kanji, Color primaryColor, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 65,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.2),
            ),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w300,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          kanji,
          style: TextStyle(
            fontSize: 14,
            color: primaryColor.withOpacity(0.6),
          ),
        ),
      ],
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

class _ZenRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ZenRipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width * 0.3, size.height * 0.7);
    
    for (int i = 0; i < 3; i++) {
      final radius = 20 + (progress + i * 0.3) % 1.0 * 60;
      final opacity = (1 - ((progress + i * 0.3) % 1.0)) * 0.3;
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZenRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _BambooPainter extends CustomPainter {
  final Color color;

  _BambooPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Bambu gövdesi
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Bambu boğumları
    paint.strokeWidth = 1;
    for (double y = 30; y < size.height; y += 50) {
      canvas.drawLine(
        Offset(size.width / 2 - 8, y),
        Offset(size.width / 2 + 8, y),
        paint,
      );
    }

    // Yapraklar
    paint.style = PaintingStyle.fill;
    paint.color = color.withOpacity(0.2);
    
    final leafPath = Path();
    leafPath.moveTo(size.width / 2, 40);
    leafPath.quadraticBezierTo(size.width / 2 + 20, 50, size.width / 2 + 25, 70);
    leafPath.quadraticBezierTo(size.width / 2 + 10, 60, size.width / 2, 40);
    canvas.drawPath(leafPath, paint);
  }

  @override
  bool shouldRepaint(covariant _BambooPainter oldDelegate) => oldDelegate.color != color;
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
