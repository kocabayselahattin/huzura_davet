import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';

class KozmikPusulaSayac extends StatefulWidget {
  const KozmikPusulaSayac({super.key});

  @override
  State<KozmikPusulaSayac> createState() => _KozmikPusulaSayacState();
}

class _KozmikPusulaSayacState extends State<KozmikPusulaSayac>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _mevcutVakit = '';
  double _ilerlemeYuzdesi = 0.0;
  Map<String, String> _vakitSaatleri = {};
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  final TemaService _temaService = TemaService();

  @override
  void initState() {
    super.initState();
    
    // Yıldız rotasyonu için
    _rotationController = AnimationController(
      duration: const Duration(seconds: 120),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    
    // Nabız efekti için
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hesaplaKalanSure();
    });
    
    _temaService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId == null) {
      _varsayilanVakitleriKullan();
      return;
    }

    try {
      final data = await DiyanetApiService.getVakitler(ilceId);
      if (data != null && data.containsKey('vakitler')) {
        final vakitler = data['vakitler'] as List;
        if (vakitler.isNotEmpty) {
          final bugun = DateTime.now();
          final bugunVakit = vakitler.firstWhere((v) {
            final tarih = v['MiladiTarihKisa'] ?? '';
            try {
              final parts = tarih.split('.');
              if (parts.length == 3) {
                final gun = int.parse(parts[0]);
                final ay = int.parse(parts[1]);
                final yil = int.parse(parts[2]);
                return gun == bugun.day && ay == bugun.month && yil == bugun.year;
              }
            } catch (e) {
              // Parse error
            }
            return false;
          }, orElse: () => vakitler.isNotEmpty 
              ? Map<String, dynamic>.from(vakitler[0]) 
              : <String, dynamic>{}) as Map<String, dynamic>;

          setState(() {
            _vakitSaatleri = {
              'Imsak': bugunVakit['Imsak'] ?? '06:12',
              'Gunes': bugunVakit['Gunes'] ?? '07:45',
              'Ogle': bugunVakit['Ogle'] ?? '13:22',
              'Ikindi': bugunVakit['Ikindi'] ?? '15:58',
              'Aksam': bugunVakit['Aksam'] ?? '18:25',
              'Yatsi': bugunVakit['Yatsi'] ?? '19:50',
            };
          });
          _hesaplaKalanSure();
        }
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
        'Imsak': '06:12',
        'Gunes': '07:45',
        'Ogle': '13:22',
        'Ikindi': '15:58',
        'Aksam': '18:25',
        'Yatsi': '19:50',
      };
    });
    _hesaplaKalanSure();
  }

  void _hesaplaKalanSure() {
    if (_vakitSaatleri.isEmpty) return;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final vakitListesi = [
      {'adi': 'İmsak', 'key': 'Imsak'},
      {'adi': 'Güneş', 'key': 'Gunes'},
      {'adi': 'Öğle', 'key': 'Ogle'},
      {'adi': 'İkindi', 'key': 'Ikindi'},
      {'adi': 'Akşam', 'key': 'Aksam'},
      {'adi': 'Yatsı', 'key': 'Yatsi'},
    ];

    DateTime? sonrakiVakitZamani;
    DateTime? mevcutVakitZamani;
    String sonrakiVakitAdi = '';
    String mevcutVakitAdi = '';

    for (int i = 0; i < vakitListesi.length; i++) {
      final vakit = vakitListesi[i];
      final saat = _vakitSaatleri[vakit['key']]!;
      try {
        final parts = saat.split(':');
        final vakitMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

        if (vakitMinutes > nowMinutes) {
          sonrakiVakitZamani = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          sonrakiVakitAdi = vakit['adi']!;

          // Mevcut vakti bul (önceki vakit)
          if (i > 0) {
            final oncekiVakit = vakitListesi[i - 1];
            final oncekiSaat = _vakitSaatleri[oncekiVakit['key']]!;
            final oncekiParts = oncekiSaat.split(':');
            mevcutVakitZamani = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(oncekiParts[0]),
              int.parse(oncekiParts[1]),
            );
            mevcutVakitAdi = oncekiVakit['adi']!;
          } else {
            // Gece vakti (yatsıdan sonra)
            final yatsiSaat = _vakitSaatleri['Yatsi']!;
            final yatsiParts = yatsiSaat.split(':');
            mevcutVakitZamani = DateTime(
              now.year,
              now.month,
              now.day - 1,
              int.parse(yatsiParts[0]),
              int.parse(yatsiParts[1]),
            );
            mevcutVakitAdi = 'Yatsı';
          }
          break;
        }
      } catch (e) {
        // Parse error
      }
    }

    // Eğer bugün için vakit kalmadıysa, yarının ilk vakti
    if (sonrakiVakitZamani == null) {
      final yarin = now.add(const Duration(days: 1));
      final imsakSaat = _vakitSaatleri['Imsak']!.split(':');
      sonrakiVakitZamani = DateTime(
        yarin.year,
        yarin.month,
        yarin.day,
        int.parse(imsakSaat[0]),
        int.parse(imsakSaat[1]),
      );
      sonrakiVakitAdi = 'İmsak';
      
      final yatsiSaat = _vakitSaatleri['Yatsi']!.split(':');
      mevcutVakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(yatsiSaat[0]),
        int.parse(yatsiSaat[1]),
      );
      mevcutVakitAdi = 'Yatsı';
    }

    // İlerleme yüzdesini hesapla
    double ilerleme = 0.0;
    if (mevcutVakitZamani != null && sonrakiVakitZamani != null) {
      final toplamSure = sonrakiVakitZamani.difference(mevcutVakitZamani).inSeconds;
      final gecenSure = now.difference(mevcutVakitZamani).inSeconds;
      if (toplamSure > 0) {
        ilerleme = gecenSure / toplamSure;
        ilerleme = ilerleme.clamp(0.0, 1.0);
      }
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _mevcutVakit = mevcutVakitAdi;
      _ilerlemeYuzdesi = ilerleme;
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    
    return Card(
      color: renkler.kartArkaPlan,
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              renkler.kartArkaPlan,
              renkler.arkaPlan.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedBuilder(
            animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
            builder: (context, child) {
              return CustomPaint(
                painter: _KozmikPusulaPainter(
                  ilerlemeYuzdesi: _ilerlemeYuzdesi,
                  rotasyonAcisi: _rotationAnimation.value,
                  pulseValue: _pulseAnimation.value,
                  vurgaRengi: renkler.vurgu,
                ),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mevcut vakit etiketi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: renkler.vurgu.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: renkler.vurgu.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _mevcutVakit.isNotEmpty ? _mevcutVakit.toUpperCase() : 'YÜKLENİYOR...',
                          style: TextStyle(
                            color: renkler.vurgu,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Kalan süre
                      Text(
                        _formatDuration(_kalanSure),
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: renkler.vurgu.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Sonraki vakit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            color: renkler.vurgu.withValues(alpha: 0.7),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sonraki: $_sonrakiVakit',
                            style: TextStyle(
                              color: renkler.yaziSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KozmikPusulaPainter extends CustomPainter {
  final double ilerlemeYuzdesi;
  final double rotasyonAcisi;
  final double pulseValue;
  final Color vurgaRengi;

  _KozmikPusulaPainter({
    required this.ilerlemeYuzdesi,
    required this.rotasyonAcisi,
    required this.pulseValue,
    required this.vurgaRengi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    // Kozmik arka plan efekti
    final cosmicPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          vurgaRengi.withValues(alpha: 0.05 * pulseValue),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 30))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 30, cosmicPaint);

    // Dış halka - kozmik efekt
    final outerRingPaint = Paint()
      ..color = vurgaRengi.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius + 12, outerRingPaint);

    // Yıldız partikülleri - farklı boyutlarda
    for (int i = 0; i < 20; i++) {
      final angle = (i * 18 * math.pi / 180) + rotasyonAcisi * 0.05;
      final starRadius = radius + 8 + (i % 3) * 4;
      final starX = center.dx + starRadius * math.cos(angle);
      final starY = center.dy + starRadius * math.sin(angle);
      final starSize = 1.0 + (i % 3) * 0.5;
      final starOpacity = 0.3 + (math.sin(rotasyonAcisi + i) + 1) * 0.2;
      
      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: starOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(starX, starY), starSize, starPaint);
    }

    // Ana arka plan halkası
    final backgroundPaint = Paint()
      ..color = vurgaRengi.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, backgroundPaint);

    // İlerleme halkası - dinamik gradient
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          vurgaRengi,
          vurgaRengi.withValues(alpha: 0.7),
          vurgaRengi,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * ilerlemeYuzdesi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Vakit işaretleri (6 ana vakit)
    final vakitIsimleri = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 * math.pi / 180) - math.pi / 2;
      final innerRadius = radius - 28;
      final outerTickRadius = radius - 20;
      
      // Ana çizgi
      final tickPaint = Paint()
        ..color = vurgaRengi.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      final startX = center.dx + innerRadius * math.cos(angle);
      final startY = center.dy + innerRadius * math.sin(angle);
      final endX = center.dx + outerTickRadius * math.cos(angle);
      final endY = center.dy + outerTickRadius * math.sin(angle);
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }

    // Ara çizgiler (daha ince)
    for (int i = 0; i < 24; i++) {
      if (i % 4 == 0) continue; // Ana vakitleri atla
      final angle = (i * 15 * math.pi / 180) - math.pi / 2;
      final innerRadius = radius - 24;
      final outerTickRadius = radius - 20;
      
      final tickPaint = Paint()
        ..color = vurgaRengi.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      final startX = center.dx + innerRadius * math.cos(angle);
      final startY = center.dy + innerRadius * math.sin(angle);
      final endX = center.dx + outerTickRadius * math.cos(angle);
      final endY = center.dy + outerTickRadius * math.sin(angle);
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }

    // Mevcut konum göstergesi (parlayan nokta)
    final needleAngle = -math.pi / 2 + sweepAngle;
    final needleX = center.dx + radius * math.cos(needleAngle);
    final needleY = center.dy + radius * math.sin(needleAngle);
    
    // Dış parıltı
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          vurgaRengi.withValues(alpha: 0.8 * pulseValue),
          vurgaRengi.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(needleX, needleY), radius: 15))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, needleY), 15, glowPaint);
    
    // İç nokta
    final needlePaint = Paint()
      ..color = vurgaRengi
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, needleY), 7, needlePaint);
    
    // Merkez noktası
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, needleY), 3, centerPaint);

    // İç parlama efekti
    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          vurgaRengi.withValues(alpha: 0.08 * pulseValue),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 35))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 35, innerGlowPaint);
  }

  @override
  bool shouldRepaint(covariant _KozmikPusulaPainter oldDelegate) {
    return oldDelegate.ilerlemeYuzdesi != ilerlemeYuzdesi ||
        oldDelegate.rotasyonAcisi != rotasyonAcisi ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.vurgaRengi != vurgaRengi;
  }
}
