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

/// Volkanik/Lav temalı sayaç widget'ı
/// Sıcak renkler, akan lav efektleri ve parıldayan ateş
class VolkanikSayacWidget extends StatefulWidget {
  const VolkanikSayacWidget({super.key});

  @override
  State<VolkanikSayacWidget> createState() => _VolkanikSayacWidgetState();
}

class _VolkanikSayacWidgetState extends State<VolkanikSayacWidget>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  
  late AnimationController _lavaController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _lavaController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
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
    _lavaController.dispose();
    _glowController.dispose();
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

    for (int i = 0; i < vakitSaatleri.length; i++) {
      final parts = vakitSaatleri[i]['saat']!.split(':');
      final vakitMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

      if (vakitMinutes > nowMinutes) {
        sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        sonrakiVakitAdi = vakitSaatleri[i]['adi']!;
        mevcutVakitAdi = i > 0 ? vakitSaatleri[i - 1]['adi']! : vakitSaatleri.last['adi']!;
        break;
      }
    }

    if (sonrakiVakitZamani == null) {
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day + 1,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      mevcutVakitAdi = vakitSaatleri.last['adi']!;
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _mevcutVakit = mevcutVakitAdi;
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
    final primaryColor = kullanTemaRenkleri ? temaRenkleri.vurgu : const Color(0xFFFF6B35);
    final secondaryColor = kullanTemaRenkleri ? temaRenkleri.vurguSecondary : const Color(0xFFFF0844);
    final bgColor1 = kullanTemaRenkleri ? temaRenkleri.arkaPlan : const Color(0xFF1A0A00);
    final bgColor2 = kullanTemaRenkleri ? temaRenkleri.kartArkaPlan : const Color(0xFF2D1810);
    final textColor = kullanTemaRenkleri ? temaRenkleri.yaziPrimary : const Color(0xFFFFAA00);
    final secondaryTextColor = kullanTemaRenkleri ? temaRenkleri.yaziSecondary : const Color(0xFFFF8C00);

    return AnimatedBuilder(
      animation: Listenable.merge([_lavaController, _glowAnimation]),
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 30,
                spreadRadius: -5,
              ),
              BoxShadow(
                color: secondaryColor.withOpacity(0.2 * _glowAnimation.value),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Arka plan - Koyu volkanik
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgColor1,
                        bgColor2,
                        Color.lerp(bgColor2, primaryColor, 0.1) ?? bgColor2,
                        Color.lerp(bgColor2, primaryColor, 0.15) ?? bgColor2,
                      ],
                    ),
                  ),
                ),
                
                // Lav akış efekti
                CustomPaint(
                  size: const Size(double.infinity, 240),
                  painter: _LavaPainter(
                    progress: _lavaController.value,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                  ),
                ),
                
                // Kıvılcım parçacıkları
                ...List.generate(15, (index) {
                  final random = math.Random(index);
                  final baseY = random.nextDouble() * 240;
                  final animOffset = (_lavaController.value + random.nextDouble()) % 1.0;
                  final y = (baseY - animOffset * 100) % 240;
                  final opacity = math.sin(animOffset * math.pi) * 0.8;
                  
                  return Positioned(
                    left: random.nextDouble() * 350,
                    top: y,
                    child: Container(
                      width: random.nextDouble() * 4 + 2,
                      height: random.nextDouble() * 4 + 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                          textColor,
                          secondaryColor,
                          random.nextDouble(),
                        )?.withOpacity(opacity.clamp(0.0, 1.0)),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(opacity.clamp(0.0, 0.5)),
                            blurRadius: 6,
                          ),
                        ],
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
                      // Üst: Vakit göstergesi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: primaryColor.withOpacity(_glowAnimation.value),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.3),
                                  secondaryColor.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.5 * _glowAnimation.value),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _sonrakiVakit,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: primaryColor.withOpacity(0.8),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.local_fire_department,
                            color: primaryColor.withOpacity(_glowAnimation.value),
                            size: 22,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Sayaç - Lav efektli
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLavaTimeBox(hours.toString().padLeft(2, '0'), primaryColor, secondaryColor, bgColor2, textColor),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor.withOpacity(_glowAnimation.value),
                                  shadows: [
                                    Shadow(
                                      color: secondaryColor,
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildLavaTimeBox(minutes.toString().padLeft(2, '0'), primaryColor, secondaryColor, bgColor2, textColor),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor.withOpacity(_glowAnimation.value),
                                  shadows: [
                                    Shadow(
                                      color: secondaryColor,
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildLavaTimeBox(seconds.toString().padLeft(2, '0'), primaryColor, secondaryColor, bgColor2, textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Alt: Tarihler
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            miladiTarih,
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.whatshot,
                              size: 12,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLavaTimeBox(String value, Color primaryColor, Color secondaryColor, Color bgColor2, Color textColor) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(bgColor2, primaryColor, 0.1)!.withOpacity(0.8),
            bgColor2.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color.lerp(
            primaryColor,
            secondaryColor,
            _glowAnimation.value,
          )!.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3 * _glowAnimation.value),
            blurRadius: 15,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              textColor,
              primaryColor,
              secondaryColor,
            ],
          ).createShader(bounds);
        },
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _LavaPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _LavaPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Lav akış katmanları
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      path.moveTo(0, size.height);
      
      for (double x = 0; x <= size.width; x += 8) {
        final baseY = size.height - 40 - layer * 25;
        final waveOffset = math.sin((x / size.width * 3 * math.pi) + progress * 2 * math.pi + layer) * 15;
        final secondWave = math.sin((x / size.width * 5 * math.pi) - progress * math.pi + layer) * 8;
        path.lineTo(x, baseY + waveOffset + secondWave);
      }
      
      path.lineTo(size.width, size.height);
      path.close();

      final opacity = 0.15 - layer * 0.04;
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(opacity),
          secondaryColor.withOpacity(opacity * 0.7),
          secondaryColor.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LavaPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.primaryColor != primaryColor ||
           oldDelegate.secondaryColor != secondaryColor;
  }
}
