import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Retro/Vintage LCD tarzı sayaç widget'ı
/// Eski dijital saat görünümü, nostaljik
class RetroSayacWidget extends StatefulWidget {
  const RetroSayacWidget({super.key});

  @override
  State<RetroSayacWidget> createState() => _RetroSayacWidgetState();
}

class _RetroSayacWidgetState extends State<RetroSayacWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  double _ilerlemeOrani = 0.0;
  
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_blinkController);
    
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
    _blinkController.dispose();
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
      // Yatsıdan sonra - yarın imsaka
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day + 1, int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      mevcutVakitAdi = vakitSaatleri.last['adi']!;
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      // Gece yarısından sonra imsak öncesi
      final parts = vakitSaatleri[0]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitSaatleri[0]['adi']!;
      mevcutVakitAdi = vakitSaatleri.last['adi']!;
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds + (24 * 3600 - yatsiSaniye);
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else {
      // Normal gün içi vakitler
      final parts = vakitSaatleri[sonrakiIndex]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
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
    final miladiTarih = DateFormat('dd.MM.yyyy').format(now);

    // Tema kontrolü: Varsayılansa orijinal, değilse tema renkleri
    final kullanTemaRenkleri = !_temaService.sayacTemasiKullan;
    final temaRenkleri = _temaService.renkler;
    
    // Orijinal renkler veya tema renkleri
    final lcdGreen = kullanTemaRenkleri ? temaRenkleri.vurgu : const Color(0xFF00FF41);
    final lcdBackground = kullanTemaRenkleri ? temaRenkleri.kartArkaPlan : const Color(0xFF0D1F0D);
    final lcdDark = kullanTemaRenkleri ? temaRenkleri.arkaPlan : const Color(0xFF061006);
    final borderColor = kullanTemaRenkleri ? temaRenkleri.ayirac : const Color(0xFF1A3A1A);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: lcdDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: lcdGreen.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                lcdBackground,
                lcdDark,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Üst: Vakit bilgisi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '◄ $_mevcutVakit',
                    style: TextStyle(
                      color: lcdGreen.withOpacity(0.7),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    '$_sonrakiVakit ►',
                    style: TextStyle(
                      color: lcdGreen,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // LCD Ekran çerçevesi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A180A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kullanTemaRenkleri ? temaRenkleri.ayirac : const Color(0xFF153015), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: lcdGreen.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: -2,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sayaç
                    AnimatedBuilder(
                      animation: _blinkAnimation,
                      builder: (context, child) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 25),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLCDDigit(hours.toString().padLeft(2, '0'), lcdGreen),
                              Opacity(
                                opacity: _blinkAnimation.value,
                                child: Text(
                                  ':',
                                  style: TextStyle(
                                    color: lcdGreen,
                                    fontSize: 46,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(color: lcdGreen, blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ),
                              _buildLCDDigit(minutes.toString().padLeft(2, '0'), lcdGreen),
                              Opacity(
                                opacity: _blinkAnimation.value,
                                child: Text(
                                  ':',
                                  style: TextStyle(
                                    color: lcdGreen,
                                    fontSize: 46,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(color: lcdGreen, blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ),
                              _buildLCDDigit(seconds.toString().padLeft(2, '0'), lcdGreen),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Alt bilgi satırı
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          miladiTarih,
                          style: TextStyle(
                            color: lcdGreen.withOpacity(0.6),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: lcdGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: lcdGreen.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: lcdGreen.withOpacity(0.8),
                                fontSize: 8,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Alt: Hicri tarih
              Text(
                '☪ $hicriTarih',
                style: TextStyle(
                  color: lcdGreen.withOpacity(0.7),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),

              const SizedBox(height: 12),

              // İlerleme çubuğu
              _buildProgressBar(lcdGreen, lcdGreen),
            ],
          ),
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

  Widget _buildLCDDigit(String value, Color lcdGreen) {
    return SizedBox(
      width: 62,
      child: Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: lcdGreen,
          fontSize: 46,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [
            Shadow(color: lcdGreen, blurRadius: 15),
            Shadow(color: lcdGreen, blurRadius: 30),
          ],
        ),
      ),
    );
  }
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
