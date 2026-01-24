import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Aurora (Kuzey Işıkları) temalı sayaç widget'ı
/// Mor, yeşil, mavi renk geçişleri ve dalgalanan efektler
class AuroraSayacWidget extends StatefulWidget {
  const AuroraSayacWidget({super.key});

  @override
  State<AuroraSayacWidget> createState() => _AuroraSayacWidgetState();
}

class _AuroraSayacWidgetState extends State<AuroraSayacWidget>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  
  late AnimationController _waveController;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    
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
    _waveController.dispose();
    _shimmerController.dispose();
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
    final primaryColor = kullanTemaRenkleri ? temaRenkleri.vurgu : const Color(0xFF00D4AA);
    final secondaryColor = kullanTemaRenkleri ? temaRenkleri.vurguSecondary : const Color(0xFF8B5CF6);
    final bgColor1 = kullanTemaRenkleri ? temaRenkleri.arkaPlan : const Color(0xFF0A0A1A);
    final bgColor2 = kullanTemaRenkleri ? temaRenkleri.kartArkaPlan : const Color(0xFF0D1B2A);
    final textColor = kullanTemaRenkleri ? temaRenkleri.yaziPrimary : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: -5,
          ),
          BoxShadow(
            color: secondaryColor.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(10, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Arka plan - Koyu gece
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor1,
                    bgColor2,
                    kullanTemaRenkleri ? temaRenkleri.ayirac : const Color(0xFF1B263B),
                  ],
                ),
              ),
            ),
            
            // Aurora dalgaları
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 240),
                  painter: _AuroraPainter(
                    progress: _waveController.value,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                  ),
                );
              },
            ),
            
            // Yıldızlar
            ...List.generate(20, (index) {
              final random = math.Random(index);
              return Positioned(
                left: random.nextDouble() * 350,
                top: random.nextDouble() * 200,
                child: Container(
                  width: random.nextDouble() * 2 + 1,
                  height: random.nextDouble() * 2 + 1,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(random.nextDouble() * 0.5 + 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
            
            // İçerik
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Üst: Vakit bilgisi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mevcutVakit,
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Şu an',
                            style: TextStyle(
                              color: textColor.withOpacity(0.4),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.3),
                              secondaryColor.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _sonrakiVakit,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Sayaç
                  AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, child) {
                      return ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor,
                              kullanTemaRenkleri ? temaRenkleri.vurgu : const Color(0xFF00FF88),
                              secondaryColor,
                              kullanTemaRenkleri ? temaRenkleri.vurguSecondary : const Color(0xFFFF6B9D),
                              primaryColor,
                            ],
                            stops: [
                              0.0,
                              _shimmerAnimation.value.clamp(0.0, 1.0),
                              (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                              (_shimmerAnimation.value + 0.6).clamp(0.0, 1.0),
                              1.0,
                            ],
                          ).createShader(bounds);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTimeBox(hours.toString().padLeft(2, '0'), textColor),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w300,
                                  color: textColor,
                                ),
                              ),
                            ),
                            _buildTimeBox(minutes.toString().padLeft(2, '0'), textColor),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w300,
                                  color: textColor,
                                ),
                              ),
                            ),
                            _buildTimeBox(seconds.toString().padLeft(2, '0'), textColor),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Alt: Tarihler
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        miladiTarih,
                        style: TextStyle(
                          color: textColor.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 1,
                        height: 12,
                        color: textColor.withOpacity(0.3),
                      ),
                      Text(
                        hicriTarih,
                        style: TextStyle(
                          color: textColor.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // İlerleme Barı
                  _buildProgressBar(primaryColor, secondaryColor, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color primaryColor, Color secondaryColor, Color textColor) {
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
          // Arka plan çizgileri
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _ProgressBarLinesPainter(
                lineColor: textColor.withOpacity(0.08),
              ),
            ),
          ),
          // Dolu kısım - tema renkleriyle gradient
          FractionallySizedBox(
            widthFactor: _ilerlemeOrani.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.7),
                    primaryColor,
                    secondaryColor,
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

  Widget _buildTimeBox(String value, Color textColor) {
    return Container(
      width: 80,
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w300,
          color: textColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _AuroraPainter({required this.progress, required this.primaryColor, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    // Aurora 1 - Yeşil
    final path1 = Path();
    path1.moveTo(0, size.height * 0.5);
    for (double x = 0; x <= size.width; x += 10) {
      final y = size.height * 0.4 +
          math.sin((x / size.width * 4 * math.pi) + progress * 2 * math.pi) * 30 +
          math.sin((x / size.width * 2 * math.pi) + progress * math.pi) * 20;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, 0);
    path1.lineTo(0, 0);
    path1.close();

    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor.withOpacity(0.0),
        primaryColor.withOpacity(0.3),
        primaryColor.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path1, paint);

    // Aurora 2 - Mor
    final path2 = Path();
    path2.moveTo(0, size.height * 0.6);
    for (double x = 0; x <= size.width; x += 10) {
      final y = size.height * 0.5 +
          math.sin((x / size.width * 3 * math.pi) - progress * 2 * math.pi) * 25 +
          math.cos((x / size.width * 5 * math.pi) + progress * math.pi) * 15;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.close();

    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        secondaryColor.withOpacity(0.0),
        secondaryColor.withOpacity(0.25),
        secondaryColor.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.primaryColor != primaryColor || 
           oldDelegate.secondaryColor != secondaryColor;
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
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarLinesPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
