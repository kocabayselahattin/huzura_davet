import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class NeonSayacWidget extends StatefulWidget {
  const NeonSayacWidget({super.key});

  @override
  State<NeonSayacWidget> createState() => _NeonSayacWidgetState();
}

class _NeonSayacWidgetState extends State<NeonSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};
  
  late AnimationController _glowController;
  late AnimationController _waveController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
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
    _glowController.dispose();
    _waveController.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId != null) {
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (vakitler != null && mounted) {
        setState(() {
          _vakitSaatleri = {
            'imsak': vakitler['Imsak'] ?? '05:30',
            'gunes': vakitler['Gunes'] ?? '07:00',
            'ogle': vakitler['Ogle'] ?? '12:30',
            'ikindi': vakitler['Ikindi'] ?? '15:45',
            'aksam': vakitler['Aksam'] ?? '18:15',
            'yatsi': vakitler['Yatsi'] ?? '19:45',
          };
        });
        _hesaplaKalanSure();
      }
    }
  }

  void _hesaplaKalanSure() {
    if (_vakitSaatleri.isEmpty) return;
    
    final now = DateTime.now();
    final nowTotalSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    final vakitListesi = [
      {'adi': _languageService['imsak'] ?? 'İmsak', 'saat': _vakitSaatleri['imsak']!},
      {'adi': _languageService['gunes'] ?? 'Güneş', 'saat': _vakitSaatleri['gunes']!},
      {'adi': _languageService['ogle'] ?? 'Öğle', 'saat': _vakitSaatleri['ogle']!},
      {'adi': _languageService['ikindi'] ?? 'İkindi', 'saat': _vakitSaatleri['ikindi']!},
      {'adi': _languageService['aksam'] ?? 'Akşam', 'saat': _vakitSaatleri['aksam']!},
      {'adi': _languageService['yatsi'] ?? 'Yatsı', 'saat': _vakitSaatleri['yatsi']!},
    ];

    // Vakit saniyelerini hesapla
    List<int> vakitSaniyeleri = [];
    for (final vakit in vakitListesi) {
      final parts = vakit['saat']!.split(':');
      vakitSaniyeleri.add(int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60);
    }

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';
    double oran = 0.0;

    // Sonraki vakti bul
    int sonrakiIndex = -1;
    for (int i = 0; i < vakitSaniyeleri.length; i++) {
      if (vakitSaniyeleri[i] > nowTotalSeconds) {
        sonrakiIndex = i;
        break;
      }
    }

    if (sonrakiIndex == -1) {
      // Tüm vakitler geçmiş, yarın imsak
      final yarin = now.add(const Duration(days: 1));
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(yarin.year, yarin.month, yarin.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      
      // Yatsıdan yarın imsaka kadar ilerleme
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      // İmsak henüz olmadı (gece yarısından sonra, imsak öncesi)
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      
      // Dün yatsıdan bugün imsaka kadar ilerleme
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds + (24 * 3600 - yatsiSaniye);
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else {
      // Normal durum: gündüz vakitleri
      final parts = vakitListesi[sonrakiIndex]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitListesi[sonrakiIndex]['adi']!;
      
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.black,
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Neon grid arka plan
            Positioned.fill(
              child: CustomPaint(
                painter: _NeonGridPainter(
                  vurguRenk: renkler.vurgu,
                  waveValue: _waveController.value,
                ),
              ),
            ),
            
            // Ana içerik
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Üst neon bar
                      _buildNeonBar(renkler),
                      
                      const SizedBox(height: 10),
                      
                      // Dijital saat
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNeonDigit(hours.toString().padLeft(2, '0'), renkler),
                          _buildNeonColon(renkler),
                          _buildNeonDigit(minutes.toString().padLeft(2, '0'), renkler),
                          _buildNeonColon(renkler),
                          _buildNeonDigit(seconds.toString().padLeft(2, '0'), renkler),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Vakit bilgisi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: renkler.vurgu.withValues(alpha: _glowAnimation.value),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: renkler.vurgu.withValues(alpha: 0.3 * _glowAnimation.value),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          '$_sonrakiVakit ${(_languageService['time_to'] ?? 'VAKTİNE').toUpperCase()}',
                          style: TextStyle(
                            color: renkler.vurgu,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: renkler.vurgu,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // İlerleme çubuğu
                      _buildProgressBar(renkler.vurgu, renkler.yaziPrimary),
                      
                      const SizedBox(height: 8),
                      
                      // Miladi ve Hicri Takvim
                      _buildTakvimRow(renkler),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonBar(TemaRenkleri renkler) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            renkler.vurgu.withValues(alpha: _glowAnimation.value),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: renkler.vurgu.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildNeonDigit(String digit, TemaRenkleri renkler) {
    return Container(
      width: 70,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        digit,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w300,
          color: renkler.vurgu,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [
            Shadow(
              color: renkler.vurgu,
              blurRadius: 15 * _glowAnimation.value,
            ),
            Shadow(
              color: renkler.vurgu.withValues(alpha: 0.5),
              blurRadius: 30 * _glowAnimation.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonColon(TemaRenkleri renkler) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w300,
          color: renkler.vurgu.withValues(alpha: _glowAnimation.value),
          shadows: [
            Shadow(
              color: renkler.vurgu,
              blurRadius: 10,
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

  Widget _buildTakvimRow(TemaRenkleri renkler) {
    final now = DateTime.now();
    final miladiTarih = DateFormat('dd MMM yyyy', 'tr_TR').format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Miladi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: renkler.vurgu.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            miladiTarih,
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 9,
              letterSpacing: 1,
              shadows: [
                Shadow(color: renkler.vurgu.withValues(alpha: 0.3), blurRadius: 4),
              ],
            ),
          ),
        ),
        // Hicri
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: renkler.vurgu.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: renkler.vurgu.withValues(alpha: 0.2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            hicriTarih,
            style: TextStyle(
              color: renkler.vurgu,
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(color: renkler.vurgu, blurRadius: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  String _getHicriAyAdi(int ay) {
    const aylar = ['', 'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 
      'Cemaziyelevvel', 'Cemaziyelahir', 'Recep', 'Şaban', 'Ramazan', 
      'Şevval', 'Zilkade', 'Zilhicce'];
    return aylar[ay];
  }
}

class _NeonGridPainter extends CustomPainter {
  final Color vurguRenk;
  final double waveValue;

  _NeonGridPainter({required this.vurguRenk, required this.waveValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = vurguRenk.withValues(alpha: 0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Yatay çizgiler
    for (int i = 0; i < 15; i++) {
      final y = (size.height / 15) * i;
      final waveOffset = math.sin(waveValue * 2 * math.pi + i * 0.3) * 2;
      
      final path = Path();
      path.moveTo(0, y + waveOffset);
      
      for (double x = 0; x < size.width; x += 5) {
        final localWave = math.sin(waveValue * 2 * math.pi + x * 0.02 + i * 0.3) * 2;
        path.lineTo(x, y + localWave);
      }
      
      canvas.drawPath(path, paint);
    }

    // Dikey çizgiler
    for (int i = 0; i < 20; i++) {
      final x = (size.width / 20) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonGridPainter oldDelegate) =>
      waveValue != oldDelegate.waveValue;
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
