import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Okyanus/Su temalı sayaç widget'ı
/// Dalga animasyonları, su damlaları ve ay ışığı efektleri
class OkyanusSayacWidget extends StatefulWidget {
  final bool shouldLoadData;
  const OkyanusSayacWidget({super.key, this.shouldLoadData = true});

  @override
  State<OkyanusSayacWidget> createState() => _OkyanusSayacWidgetState();
}

class _OkyanusSayacWidgetState extends State<OkyanusSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};
  
  late AnimationController _waveController1;
  late AnimationController _waveController2;
  late AnimationController _bubbleController;
  late AnimationController _moonGlowController;
  late Animation<double> _moonGlowAnimation;
  
  final List<_Bubble> _bubbles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    
    // Dalga animasyonları - farklı hızlarda
    _waveController1 = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    _waveController2 = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    // Kabarcık animasyonu
    _bubbleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    // Ay parlaması
    _moonGlowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    
    _moonGlowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _moonGlowController, curve: Curves.easeInOut),
    );
    
    // Kabarcıkları oluştur
    _generateBubbles();
    
    if (widget.shouldLoadData) {
      _vakitleriYukle();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _hesaplaKalanSure();
      });
    }
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }
  
  void _generateBubbles() {
    for (int i = 0; i < 15; i++) {
      _bubbles.add(_Bubble(
        x: _random.nextDouble(),
        startY: 0.7 + _random.nextDouble() * 0.3,
        size: 2 + _random.nextDouble() * 4,
        speed: 0.3 + _random.nextDouble() * 0.5,
        delay: _random.nextDouble(),
      ));
    }
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController1.dispose();
    _waveController2.dispose();
    _bubbleController.dispose();
    _moonGlowController.dispose();
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
      {'adi': _languageService['imsak'], 'saat': _vakitSaatleri['imsak']!},
      {'adi': _languageService['gunes'], 'saat': _vakitSaatleri['gunes']!},
      {'adi': _languageService['ogle'], 'saat': _vakitSaatleri['ogle']!},
      {'adi': _languageService['ikindi'], 'saat': _vakitSaatleri['ikindi']!},
      {'adi': _languageService['aksam'], 'saat': _vakitSaatleri['aksam']!},
      {'adi': _languageService['yatsi'], 'saat': _vakitSaatleri['yatsi']!},
    ];

    // Vakit saniyelerini hesapla
    List<int> vakitSaniyeleri = [];
    for (final vakit in vakitListesi) {
      final parts = vakit['saat']!.split(':');
      vakitSaniyeleri.add(int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60);
    }

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';
    String mevcutVakitAdi = '';
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
      sonrakiVakitAdi = _languageService['imsak'];
      mevcutVakitAdi = _languageService['yatsi'];
      
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
      sonrakiVakitAdi = _languageService['imsak'];
      mevcutVakitAdi = _languageService['yatsi'];
      
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
      mevcutVakitAdi = vakitListesi[sonrakiIndex - 1]['adi']!;
      
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

    // Okyanus renkleri
    final oceanBlue = const Color(0xFF1B263B);
    final waveColor = renkler.vurgu.withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1B2A),
            oceanBlue,
            const Color(0xFF1B4965),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4965).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Dalgalar
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_waveController1, _waveController2]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: _OceanWavePainter(
                      waveValue1: _waveController1.value,
                      waveValue2: _waveController2.value,
                      waveColor: waveColor,
                      vurguColor: renkler.vurgu,
                    ),
                  );
                },
              ),
            ),
            
            // Kabarcıklar
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bubbleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _BubblePainter(
                      bubbles: _bubbles,
                      animationValue: _bubbleController.value,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  );
                },
              ),
            ),
            
            // Ay
            Positioned(
              top: 15,
              right: 25,
              child: AnimatedBuilder(
                animation: _moonGlowAnimation,
                builder: (context, child) {
                  return Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.9 * _moonGlowAnimation.value),
                          Colors.white.withValues(alpha: 0.3 * _moonGlowAnimation.value),
                          Colors.transparent,
                        ],
                        stops: const [0.3, 0.7, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3 * _moonGlowAnimation.value),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Yıldızlar
            ..._buildStars(renkler),
            
            // Ana içerik
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mevcut vakit
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getVakitIcon(_mevcutVakit),
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _mevcutVakit.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Geri sayım - Su efektli
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        renkler.vurgu.withValues(alpha: 0.8),
                        const Color(0xFF5BC0BE),
                      ],
                    ).createShader(bounds),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          hours.toString().padLeft(2, '0'),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Color(0xFF5BC0BE),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 20,
                        child: Text(
                          ':',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Color(0xFF5BC0BE),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          minutes.toString().padLeft(2, '0'),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Color(0xFF5BC0BE),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 20,
                        child: Text(
                          ':',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Color(0xFF5BC0BE),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          seconds.toString().padLeft(2, '0'),
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Color(0xFF5BC0BE),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                  
                  const SizedBox(height: 10),
                  
                  // Sonraki vakit
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          renkler.vurgu.withValues(alpha: 0.2),
                          const Color(0xFF5BC0BE).withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.water_drop,
                          color: Color(0xFF5BC0BE),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_sonrakiVakit ${_languageService['time_to']}',
                          style: const TextStyle(
                            color: Color(0xFF5BC0BE),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Dalga şeklinde vakit göstergesi
                  _buildWaveIndicator(renkler),
                  
                  const SizedBox(height: 10),
                  
                  // Miladi ve Hicri Takvim
                  _buildTakvimRow(renkler),
                  
                  const SizedBox(height: 12),
                  
                  // İlerleme barı
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: _buildProgressBar(renkler.vurgu, Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildStars(TemaRenkleri renkler) {
    final stars = <Widget>[];
    final random = math.Random(42);
    
    for (int i = 0; i < 12; i++) {
      stars.add(
        Positioned(
          left: random.nextDouble() * 300 + 20,
          top: random.nextDouble() * 60 + 10,
          child: AnimatedBuilder(
            animation: _moonGlowAnimation,
            builder: (context, child) {
              final twinkle = math.sin(_moonGlowAnimation.value * math.pi * 2 + i) * 0.5 + 0.5;
              return Container(
                width: 2 + random.nextDouble() * 2,
                height: 2 + random.nextDouble() * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.3 + twinkle * 0.4),
                ),
              );
            },
          ),
        ),
      );
    }
    return stars;
  }
  
  Widget _buildWaveIndicator(TemaRenkleri renkler) {
    final vakitler = [
      _languageService['imsak'],
      _languageService['gunes'],
      _languageService['ogle'],
      _languageService['ikindi'],
      _languageService['aksam'],
      _languageService['yatsi'],
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: vakitler.asMap().entries.map((entry) {
        final index = entry.key;
        final vakit = entry.value;
        final aktif = vakit == _mevcutVakit;
        final sonraki = vakit == _sonrakiVakit;
        
        // Dalga efekti için y offset
        final waveOffset = math.sin(index * 0.8 + _waveController1.value * math.pi * 2) * 3;
        
        return AnimatedBuilder(
          animation: _waveController1,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, waveOffset),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: aktif ? 12 : sonraki ? 10 : 6,
                height: aktif ? 12 : sonraki ? 10 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: aktif ? RadialGradient(
                    colors: [
                      Colors.white,
                      const Color(0xFF5BC0BE),
                    ],
                  ) : null,
                  color: !aktif ? (sonraki 
                      ? const Color(0xFF5BC0BE).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.3)) : null,
                  boxShadow: aktif ? [
                    BoxShadow(
                      color: const Color(0xFF5BC0BE).withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
              ),
            );
          },
        );
      }).toList(),
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
    final miladiTarih = DateFormat('dd MMM yyyy', _getLocale()).format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 10, color: Colors.white.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              miladiTarih,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('~', style: TextStyle(color: const Color(0xFF5BC0BE).withValues(alpha: 0.7), fontSize: 10)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.brightness_3, size: 10, color: const Color(0xFF5BC0BE).withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              hicriTarih,
              style: TextStyle(
                color: const Color(0xFF5BC0BE).withValues(alpha: 0.9),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  String _getHicriAyAdi(int ay) {
    if (ay < 1 || ay > 12) return '';
    return _languageService['hijri_month_$ay'] ?? '';
  }

  IconData _getVakitIcon(String vakit) {
    if (vakit == _languageService['imsak']) return Icons.dark_mode;
    if (vakit == _languageService['gunes']) return Icons.wb_sunny;
    if (vakit == _languageService['ogle']) return Icons.light_mode;
    if (vakit == _languageService['ikindi']) return Icons.wb_twilight;
    if (vakit == _languageService['aksam']) return Icons.nights_stay;
    if (vakit == _languageService['yatsi']) return Icons.bedtime;
    return Icons.access_time;
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
}

class _Bubble {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double delay;
  
  _Bubble({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.delay,
  });
}

class _OceanWavePainter extends CustomPainter {
  final double waveValue1;
  final double waveValue2;
  final Color waveColor;
  final Color vurguColor;

  _OceanWavePainter({
    required this.waveValue1,
    required this.waveValue2,
    required this.waveColor,
    required this.vurguColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // İlk dalga (arkada)
    final paint1 = Paint()
      ..color = waveColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    
    final path1 = Path();
    path1.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.75 + 
          math.sin((x / size.width * 4 * math.pi) + waveValue1 * 2 * math.pi) * 15 +
          math.sin((x / size.width * 2 * math.pi) + waveValue1 * math.pi) * 8;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);
    
    // İkinci dalga (önde)
    final paint2 = Paint()
      ..color = vurguColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    
    final path2 = Path();
    path2.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.8 + 
          math.sin((x / size.width * 3 * math.pi) + waveValue2 * 2 * math.pi + 1) * 12 +
          math.cos((x / size.width * 5 * math.pi) + waveValue2 * math.pi) * 5;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
    
    // Üçüncü dalga (en önde, parlak)
    final paint3 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF5BC0BE).withValues(alpha: 0.1),
          const Color(0xFF5BC0BE).withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    final path3 = Path();
    path3.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.85 + 
          math.sin((x / size.width * 2 * math.pi) + waveValue1 * 2 * math.pi + 2) * 8;
      path3.lineTo(x, y);
    }
    path3.lineTo(size.width, size.height);
    path3.close();
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant _OceanWavePainter oldDelegate) =>
      waveValue1 != oldDelegate.waveValue1 || waveValue2 != oldDelegate.waveValue2;
}

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final double animationValue;
  final Color color;

  _BubblePainter({
    required this.bubbles,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    for (final bubble in bubbles) {
      final progress = (animationValue + bubble.delay) % 1.0;
      final y = size.height * (bubble.startY - progress * bubble.speed);
      final x = size.width * bubble.x + math.sin(progress * math.pi * 4) * 5;
      
      if (y > 0 && y < size.height) {
        final alpha = (1 - progress) * 0.6;
        paint.color = color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), bubble.size, paint);
        
        // Kabarcık parlaması
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.5)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(x - bubble.size * 0.3, y - bubble.size * 0.3), 
          bubble.size * 0.3, 
          highlightPaint
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
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
