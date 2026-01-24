import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class GalaksiSayacWidget extends StatefulWidget {
  const GalaksiSayacWidget({super.key});

  @override
  State<GalaksiSayacWidget> createState() => _GalaksiSayacWidgetState();
}

class _GalaksiSayacWidgetState extends State<GalaksiSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};
  
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _starController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Galaksi dönüş animasyonu
    _rotationController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
    
    // Nabız animasyonu
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Yıldız parıldama animasyonu
    _starController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
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
    _rotationController.dispose();
    _pulseController.dispose();
    _starController.dispose();
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

    List<int> vakitSaniyeleri = [];
    for (final vakit in vakitListesi) {
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
      final yarin = now.add(const Duration(days: 1));
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(yarin.year, yarin.month, yarin.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      mevcutVakitAdi = _languageService['yatsi'] ?? 'Yatsı';
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      mevcutVakitAdi = _languageService['yatsi'] ?? 'Yatsı';
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds + (24 * 3600 - yatsiSaniye);
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else {
      final parts = vakitListesi[sonrakiIndex]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitListesi[sonrakiIndex]['adi']!;
      mevcutVakitAdi = sonrakiIndex > 0 ? vakitListesi[sonrakiIndex - 1]['adi']! : (_languageService['yatsi'] ?? 'Yatsı');
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
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            renkler.vurgu.withValues(alpha: 0.15),
            renkler.kartArkaPlan,
            Colors.black.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: renkler.vurgu.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Galaksi arka planı
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _GalaksiPainter(
                      rotation: _rotationController.value * 2 * math.pi,
                      vurguRenk: renkler.vurgu,
                      starBrightness: _starController.value,
                    ),
                  );
                },
              ),
            ),
            
            // Merkez içerik
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mevcut vakit
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: renkler.vurgu.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: renkler.vurgu.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            _mevcutVakit.toUpperCase(),
                            style: TextStyle(
                              color: renkler.vurgu,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Geri sayım
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              renkler.vurgu,
                              renkler.yaziPrimary,
                              renkler.vurgu,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Sonraki vakit
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getVakitIcon(_sonrakiVakit),
                              color: renkler.vurgu,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_languageService['time_to'] ?? 'vaktine'} $_sonrakiVakit ${_languageService['remaining'] ?? 'Kalan'}',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Vakit çemberleri
                        _buildVakitOrbits(renkler),
                        
                        const SizedBox(height: 12),
                        
                        // Miladi ve Hicri Takvim
                        _buildTakvimRow(renkler),
                        
                        const SizedBox(height: 12),

                        // İlerleme Barı
                        _buildProgressBar(renkler.vurgu, renkler.yaziSecondary, renkler.yaziPrimary),
                      ],
                    ),
                  );
                },
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

  Widget _buildVakitOrbits(TemaRenkleri renkler) {
    final vakitler = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: vakitler.map((vakit) {
        final aktif = vakit == _mevcutVakit;
        final sonraki = vakit == _sonrakiVakit;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: aktif ? 12 : 8,
          height: aktif ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: aktif 
                ? renkler.vurgu 
                : sonraki 
                    ? Colors.orange 
                    : renkler.yaziSecondary.withValues(alpha: 0.3),
            boxShadow: aktif ? [
              BoxShadow(
                color: renkler.vurgu.withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ] : null,
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildTakvimRow(TemaRenkleri renkler) {
    final now = DateTime.now();
    final miladiTarih = DateFormat('dd MMM yyyy', 'tr_TR').format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Miladi
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14, color: renkler.yaziSecondary.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              miladiTarih,
              style: TextStyle(
                color: renkler.yaziSecondary.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('•', style: TextStyle(color: renkler.vurgu.withValues(alpha: 0.6), fontSize: 12)),
        ),
        // Hicri
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.brightness_3, size: 14, color: renkler.vurgu.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              hicriTarih,
              style: TextStyle(
                color: renkler.vurgu.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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

  IconData _getVakitIcon(String vakit) {
    switch (vakit) {
      case 'İmsak': return Icons.dark_mode;
      case 'Güneş': return Icons.wb_sunny;
      case 'Öğle': return Icons.light_mode;
      case 'İkindi': return Icons.wb_twilight;
      case 'Akşam': return Icons.nights_stay;
      case 'Yatsı': return Icons.bedtime;
      default: return Icons.access_time;
    }
  }
}

class _GalaksiPainter extends CustomPainter {
  final double rotation;
  final Color vurguRenk;
  final double starBrightness;

  _GalaksiPainter({
    required this.rotation,
    required this.vurguRenk,
    required this.starBrightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.5;
    final random = math.Random(42);

    // Spiral galaksi kolları
    for (int arm = 0; arm < 3; arm++) {
      final armOffset = arm * (2 * math.pi / 3);
      
      for (int i = 0; i < 80; i++) {
        final t = i / 80.0;
        final spiralAngle = rotation + armOffset + t * 4 * math.pi;
        final radius = t * maxRadius * 0.9;
        
        final x = center.dx + radius * math.cos(spiralAngle);
        final y = center.dy + radius * math.sin(spiralAngle);
        
        final starSize = (1 - t) * 2.5 + random.nextDouble() * 1.5;
        final alpha = (1 - t * 0.7) * (0.3 + starBrightness * 0.4);
        
        final paint = Paint()
          ..color = Color.lerp(
            vurguRenk,
            Colors.white,
            random.nextDouble() * 0.5,
          )!.withValues(alpha: alpha);
        
        canvas.drawCircle(Offset(x, y), starSize, paint);
      }
    }

    // Rastgele yıldızlar
    for (int i = 0; i < 60; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final radius = random.nextDouble() * maxRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      final brightness = 0.2 + random.nextDouble() * 0.5 * starBrightness;
      final starSize = random.nextDouble() * 1.5 + 0.5;
      
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: brightness);
      
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }

    // Merkez parlaklık
    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          vurguRenk.withValues(alpha: 0.3),
          vurguRenk.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.4));
    
    canvas.drawCircle(center, maxRadius * 0.4, centerGlow);
  }

  @override
  bool shouldRepaint(covariant _GalaksiPainter oldDelegate) =>
      rotation != oldDelegate.rotation || starBrightness != oldDelegate.starBrightness;
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
