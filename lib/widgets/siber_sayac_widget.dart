import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Siber/Cyberpunk temalı sayaç widget'ı
/// Neon pembe-mavi, glitch efektleri, fütüristik tasarım
class SiberSayacWidget extends StatefulWidget {
  final bool shouldLoadData;
  const SiberSayacWidget({super.key, this.shouldLoadData = true});

  @override
  State<SiberSayacWidget> createState() => _SiberSayacWidgetState();
}

class _SiberSayacWidgetState extends State<SiberSayacWidget>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  double _ilerlemeOrani = 0.0;
  
  late AnimationController _scanController;
  late AnimationController _glitchController;
  
  final math.Random _random = math.Random();
  double _glitchOffset = 0;

  @override
  void initState() {
    super.initState();
    
    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _glitchController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    // Random glitch efekti
    Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _random.nextDouble() > 0.7) {
        _glitchOffset = (_random.nextDouble() - 0.5) * 4;
        _glitchController.forward().then((_) {
          _glitchOffset = 0;
          _glitchController.reverse();
        });
      }
    });
    
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
    _scanController.dispose();
    _glitchController.dispose();
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
      {'adi': _languageService['imsak'], 'saat': _vakitSaatleri['Imsak']!},
      {'adi': _languageService['gunes'], 'saat': _vakitSaatleri['Gunes']!},
      {'adi': _languageService['ogle'], 'saat': _vakitSaatleri['Ogle']!},
      {'adi': _languageService['ikindi'], 'saat': _vakitSaatleri['Ikindi']!},
      {'adi': _languageService['aksam'], 'saat': _vakitSaatleri['Aksam']!},
      {'adi': _languageService['yatsi'], 'saat': _vakitSaatleri['Yatsi']!},
    ];

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';
    int oncekiVakitSeconds = 0;
    int sonrakiVakitSeconds = 0;

    for (int i = 0; i < vakitSaatleri.length; i++) {
      final parts = vakitSaatleri[i]['saat']!.split(':');
      final vakitSeconds = int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60;

      if (vakitSeconds > nowTotalSeconds) {
        sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        sonrakiVakitAdi = vakitSaatleri[i]['adi']!;
        sonrakiVakitSeconds = vakitSeconds;
        if (i > 0) {
          final oncekiParts = vakitSaatleri[i - 1]['saat']!.split(':');
          oncekiVakitSeconds = int.parse(oncekiParts[0]) * 3600 + int.parse(oncekiParts[1]) * 60;
        } else {
          // Yatsıdan sonra gece yarısı öncesi - yatsı vakti
          final yatsiParts = vakitSaatleri.last['saat']!.split(':');
          oncekiVakitSeconds = int.parse(yatsiParts[0]) * 3600 + int.parse(yatsiParts[1]) * 60 - 86400;
        }
        break;
      }
    }

    if (sonrakiVakitZamani == null) {
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day + 1,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      // Yatsıdan sonra, sonraki gün imsak'a kadar
      final yatsiParts = vakitSaatleri.last['saat']!.split(':');
      oncekiVakitSeconds = int.parse(yatsiParts[0]) * 3600 + int.parse(yatsiParts[1]) * 60;
      sonrakiVakitSeconds = int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + 86400;
    }

    // İlerleme oranını hesapla
    double ilerleme = 0.0;
    final toplamSure = sonrakiVakitSeconds - oncekiVakitSeconds;
    if (toplamSure > 0) {
      final gecenSure = nowTotalSeconds - oncekiVakitSeconds;
      ilerleme = (gecenSure / toplamSure).clamp(0.0, 1.0);
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _ilerlemeOrani = ilerleme;
    });
  }

  String _getHicriAyAdi(int ay) {
    if (ay < 1 || ay > 12) return '';
    return _languageService['hijri_month_$ay'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes % 60;
    final seconds = _kalanSure.inSeconds % 60;

    final now = DateTime.now();
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';
    final miladiTarih = DateFormat('dd MMMM yyyy', _getLocale()).format(now);

    // Tema kontrolü: Varsayılansa orijinal, değilse tema renkleri
    final kullanTemaRenkleri = !_temaService.sayacTemasiKullan;
    final temaRenkleri = _temaService.renkler;

    // Orijinal renkler veya tema renkleri
    final primaryColor = kullanTemaRenkleri ? temaRenkleri.vurgu : const Color(0xFFFF00FF);
    final secondaryColor = kullanTemaRenkleri ? temaRenkleri.vurguSecondary : const Color(0xFF00FFFF);
    final bgColor1 = kullanTemaRenkleri ? temaRenkleri.arkaPlan : const Color(0xFF0D0221);
    final bgColor2 = kullanTemaRenkleri ? temaRenkleri.kartArkaPlan : const Color(0xFF1A0533);
    final textColor = kullanTemaRenkleri ? temaRenkleri.yaziPrimary : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
          BoxShadow(
            color: secondaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Arka plan - Koyu mor
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bgColor1,
                    bgColor2,
                    bgColor2.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            
            // Grid çizgileri
            CustomPaint(
              size: const Size(double.infinity, 240),
              painter: _CyberGridPainter(gridColor: secondaryColor),
            ),
            
            // Tarama çizgisi
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Positioned(
                  top: _scanController.value * 240,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          secondaryColor.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // İçerik
            AnimatedBuilder(
              animation: _glitchController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_glitchOffset, 0),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Üst: Durum göstergesi
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF00),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FF00).withOpacity(0.8),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ONLINE',
                                  style: TextStyle(
                                    color: const Color(0xFF00FF00),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    letterSpacing: 2,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFF00FF00).withOpacity(0.8),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: primaryColor,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _sonrakiVakit.toUpperCase(),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: primaryColor.withOpacity(0.8),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Sayaç - Siber stil
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCyberTimeUnit(hours.toString().padLeft(2, '0'), primaryColor, secondaryColor, textColor),
                            _buildCyberSeparator(primaryColor),
                            _buildCyberTimeUnit(minutes.toString().padLeft(2, '0'), primaryColor, secondaryColor, textColor),
                            _buildCyberSeparator(primaryColor),
                            _buildCyberTimeUnit(seconds.toString().padLeft(2, '0'), primaryColor, secondaryColor, textColor),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Alt: Tarihler
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '[ $miladiTarih ]',
                              style: TextStyle(
                                color: secondaryColor.withOpacity(0.7),
                                fontSize: 10,
                                fontFamily: 'monospace',
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '[ $hicriTarih ]',
                              style: TextStyle(
                                color: primaryColor.withOpacity(0.7),
                                fontSize: 10,
                                fontFamily: 'monospace',
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // İlerleme çubuğu
                        _buildProgressBar(primaryColor, textColor),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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

  Widget _buildCyberTimeUnit(String value, Color primaryColor, Color secondaryColor, Color textColor) {
    return SizedBox(
      width: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glitch efekti - Primary
          Transform.translate(
            offset: const Offset(-2, 0),
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: primaryColor.withOpacity(0.3),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Glitch efekti - Secondary
          Transform.translate(
            offset: const Offset(2, 0),
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: secondaryColor.withOpacity(0.3),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Ana metin
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                Shadow(
                  color: primaryColor.withOpacity(0.8),
                  blurRadius: 10,
                ),
                Shadow(
                  color: secondaryColor.withOpacity(0.8),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberSeparator(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: primaryColor,
          shadows: [
            Shadow(
              color: primaryColor.withOpacity(0.8),
              blurRadius: 15,
            ),
          ],
        ),
      ),
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

class _CyberGridPainter extends CustomPainter {
  final Color gridColor;

  _CyberGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // Yatay çizgiler
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Dikey çizgiler
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) => oldDelegate.gridColor != gridColor;
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
