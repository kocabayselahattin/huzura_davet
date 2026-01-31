import 'package:flutter/material.dart';
import 'package:flutter_weather_bg_null_safety/flutter_weather_bg.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';

/// Gün Dönümü Sayacı - Modern ve Gerçekçi Tasarım
/// Gerçek güneş/ay resimleri, ay evreleri ve dinamik arka plan
class GunDonumuSayacWidget extends StatefulWidget {
  const GunDonumuSayacWidget({super.key});

  @override
  State<GunDonumuSayacWidget> createState() => _GunDonumuSayacWidgetState();
}

class _GunDonumuSayacWidgetState extends State<GunDonumuSayacWidget>
    with TickerProviderStateMixin {
  // Hava durumuna göre vakit yazı rengi
  Color _getVakitTextColor(String vakit, bool isAktif) {
    // Gece: Yatsı, İmsak, Güneşten önce/sonra
    final hour = _now.hour;
    if (vakit == 'Yatsi' || vakit == 'Imsak' || (hour < 6 || hour >= 22)) {
      return isAktif ? Colors.white : Colors.white70;
    }
    // Güneş: Sarımsı ve koyu gölgeli
    if (vakit == 'Gunes') {
      return isAktif ? const Color(0xFFFFF176) : const Color(0xFFFFF9C4);
    }
    // Akşam: Turuncu/kızıl tonlar
    if (vakit == 'Aksam') {
      return isAktif ? const Color(0xFFFF7043) : const Color(0xFFFFAB91);
    }
    // Öğle/İkindi: Açık mavi/gri
    if (vakit == 'Ogle' || vakit == 'Ikindi') {
      return isAktif ? const Color(0xFF1976D2) : const Color(0xFF90CAF9);
    }
    // Gündüz: Siyah veya koyu gri
    if (hour >= 6 && hour < 18) {
      return isAktif ? Colors.black : Colors.black.withOpacity(0.85);
    }
    // Varsayılan
    return isAktif ? Colors.white : Colors.white70;
  }

  late Timer _timer;
  late DateTime _now;
  String? _weatherMain;
  Map<String, String> _vakitler = {};

  // Animasyon controller'ları
  late AnimationController _breathController;
  late AnimationController _floatController;

  // Hava parçacıkları
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    // Nefes animasyonu (güneş/ay için)
    _breathController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    // Yüzme animasyonu
    _floatController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
        _updateParticles();
      }
    });

    _vakitleriYukle();
    _fetchWeather();
    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    final random = math.Random();
    for (int i = 0; i < 80; i++) {
      _particles.add(
        _Particle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: 1 + random.nextDouble() * 3,
          speed: 0.001 + random.nextDouble() * 0.003,
          opacity: 0.3 + random.nextDouble() * 0.5,
          drift: (random.nextDouble() - 0.5) * 0.002,
        ),
      );
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.update(_weatherMain);
    }
  }

  Future<void> _vakitleriYukle() async {
    try {
      final konumlar = await KonumService.getKonumlar();
      final aktifIndex = await KonumService.getAktifKonumIndex();

      if (konumlar.isEmpty || aktifIndex >= konumlar.length) return;

      final konum = konumlar[aktifIndex];
      final vakitler = await DiyanetApiService.getBugunVakitler(konum.ilceId);

      if (mounted && vakitler != null) {
        setState(() => _vakitler = vakitler);
      }
    } catch (e) {
      debugPrint('Vakitler yüklenemedi: $e');
    }
  }

  Future<void> _fetchWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=weather_code',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final code = data['current']['weather_code'] ?? 0;

        String type = 'clear';
        if (code >= 45 && code <= 48) {
          type = 'foggy';
        } else if (code >= 51 && code <= 67 || code >= 80 && code <= 82) {
          type = 'rain';
        } else if (code >= 71 && code <= 77 || code >= 85 && code <= 86) {
          type = 'snow';
        } else if (code >= 95) {
          type = 'thunder';
        } else if (code >= 2 && code <= 3) {
          type = 'cloudy';
        }

        if (mounted) setState(() => _weatherMain = type);
      }
    } catch (e) {
      debugPrint('Hava durumu hatası: $e');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _breathController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Ay fazını hesapla (0-7 arası 8 faz)
  /// 0=Yeni Ay, 1=Hilal (büyüyen), 2=İlk Dördün, 3=Dolmak Üzere
  /// 4=Dolunay, 5=Küçülmeye Başlayan, 6=Son Dördün, 7=Hilal (küçülen)
  int _getMoonPhaseIndex(DateTime date) {
    // Bilinen yeni ay tarihi: 29 Aralık 2024 (daha güncel referans)
    final reference = DateTime.utc(2024, 12, 30, 22, 27);
    const synodicMonth = 29.53058867;

    final daysDiff = date.difference(reference).inHours / 24.0;
    final phase = (daysDiff % synodicMonth) / synodicMonth;

    // 0-1 arasındaki değeri 0-7 faz indeksine çevir
    return ((phase * 8) % 8).floor();
  }

  /// Aktif vakit
  String _getAktifVakit() {
    if (_vakitler.isEmpty) return 'Ogle';
    final now = _now.hour * 60 + _now.minute;
    final sira = ['Imsak', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];

    for (int i = sira.length - 1; i >= 0; i--) {
      final t = _vakitler[sira[i]];
      if (t != null && now >= _timeToMinutes(t)) return sira[i];
    }
    return 'Yatsi';
  }

  /// Sonraki vakit bilgisi (saniye hassasiyetli)
  Map<String, dynamic> _getSonrakiVakit() {
    if (_vakitler.isEmpty) return {'vakit': '', 'kalan': Duration.zero};

    final nowSec = _now.hour * 3600 + _now.minute * 60 + _now.second;
    final sira = ['Imsak', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];

    for (final v in sira) {
      final t = _vakitler[v];
      if (t != null) {
        final m = _timeToMinutes(t) * 60; // Saniyeye çevir
        if (m > nowSec) {
          return {'vakit': v, 'kalan': Duration(seconds: m - nowSec)};
        }
      }
    }

    final imsak = _vakitler['Imsak'];
    if (imsak != null) {
      final m = _timeToMinutes(imsak) * 60;
      return {
        'vakit': 'Imsak',
        'kalan': Duration(seconds: (86400 - nowSec) + m),
      };
    }
    return {'vakit': '', 'kalan': Duration.zero};
  }

  WeatherType _getWeatherType() {
    switch (_weatherMain) {
      case 'rain':
        return WeatherType.heavyRainy;
      case 'snow':
        return WeatherType.middleSnow;
      case 'thunder':
        return WeatherType.thunder;
      case 'foggy':
        return WeatherType.foggy;
      case 'cloudy':
        return WeatherType.cloudy;
      default:
        return WeatherType.sunny;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    const height = 240.0;

    // Zaman hesaplamaları
    final sunriseMin = _timeToMinutes(_vakitler['Gunes'] ?? '06:30');
    final sunsetMin = _timeToMinutes(_vakitler['Aksam'] ?? '18:00');
    final nowMin = _now.hour * 60 + _now.minute;
    final isDay = nowMin >= sunriseMin && nowMin < sunsetMin;

    // Görünmez elips üzerinde konum (3mm = ~12px kenar boşluğu)
    const padding = 12.0;
    final ellipseW = width - (padding * 2) - 60;
    final ellipseH = height * 0.45;
    final centerX = width / 2;
    final centerY = height * 0.52;

    // Güneş/Ay açısı hesaplama
    double progress;
    if (isDay) {
      progress = (nowMin - sunriseMin) / (sunsetMin - sunriseMin);
    } else {
      final nightLen = sunriseMin + (1440 - sunsetMin);
      if (nowMin >= sunsetMin) {
        progress = (nowMin - sunsetMin) / nightLen;
      } else {
        progress = (1440 - sunsetMin + nowMin) / nightLen;
      }
    }

    // Elips üzerinde açı: gündüz üstte (sol->sağ), gece altta (sağ->sol)
    final angle = isDay
        ? math.pi - (progress * math.pi)
        : -(progress * math.pi);

    final celestialX = centerX + math.cos(angle) * (ellipseW / 2);
    final celestialY = centerY - math.sin(angle) * (ellipseH / 2);

    final aktifVakit = _getAktifVakit();
    final sonraki = _getSonrakiVakit();
    final moonPhase = _getMoonPhaseIndex(_now);

    final vakitIsimleri = {
      'Imsak': 'İmsak',
      'Gunes': 'Güneş',
      'Ogle': 'Öğle',
      'Ikindi': 'İkindi',
      'Aksam': 'Akşam',
      'Yatsi': 'Yatsı',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // === ARKA PLAN: Gerçek gökyüzü resmi ===
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                child: Image.asset(
                  isDay
                      ? 'assets/icon/sky_day.png'
                      : 'assets/icon/sky_night.png',
                  key: ValueKey(isDay),
                  fit: BoxFit.cover,
                  width: width,
                  height: height,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDay
                            ? [const Color(0xFF87CEEB), const Color(0xFFE0F4FF)]
                            : [
                                const Color(0xFF0A1628),
                                const Color(0xFF1A2847),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // === HAVA DURUMU OVERLAY ===
            if (_weatherMain != null && _weatherMain != 'clear')
              Positioned.fill(
                child: WeatherBg(
                  weatherType: _getWeatherType(),
                  width: width,
                  height: height,
                ),
              ),

            // === GECE YILDIZLARI ===
            if (!isDay) ..._buildStars(width, height),

            // === HAVA PARÇACIKLARI ===
            if (_weatherMain == 'snow' || _weatherMain == 'rain')
              ..._particles.map((p) => _buildParticle(p, width, height)),

            // === UFUK ÇİZGİSİ (Subtle) ===
            Positioned(
              bottom: height * 0.25,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (isDay ? Colors.orange : Colors.indigo).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // === GÜNEŞ VEYA AY (Gerçek Resim) ===
            AnimatedBuilder(
              animation: Listenable.merge([
                _breathController,
                _floatController,
              ]),
              builder: (context, child) {
                final breathScale = 1.0 + (_breathController.value * 0.08);
                final floatY =
                    math.sin(_floatController.value * math.pi * 2) * 3;

                return Positioned(
                  left: celestialX - 32,
                  top: celestialY - 32 + floatY,
                  child: Transform.scale(
                    scale: breathScale,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isDay
                                        ? const Color(0xFFFFD700)
                                        : const Color(0xFFE8E8E8))
                                    .withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: isDay
                            ? Image.asset(
                                'assets/icon/sun.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _fallbackSun(),
                              )
                            : _buildMoonWithPhase(8 - moonPhase),
                      ),
                    ),
                  ),
                );
              },
            ),

            // === VAKİT İŞARETÇİLERİ (Görünmez elips üzerinde) ===
            ..._buildVakitIndicators(
              centerX,
              centerY,
              ellipseW,
              ellipseH,
              sunriseMin,
              sunsetMin,
              aktifVakit,
              vakitIsimleri,
              isDay,
            ),

            // === ALT GERİ SAYIM ===
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: _buildSimpleCountdown(sonraki, vakitIsimleri),
            ),
          ],
        ),
      ),
    );
  }

  /// Yıldızlar (gece için)
  List<Widget> _buildStars(double width, double height) {
    final random = math.Random(42);
    return List.generate(30, (i) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height * 0.6;
      final size = 1.0 + random.nextDouble() * 2;
      final opacity = 0.4 + random.nextDouble() * 0.6;

      return Positioned(
        left: x,
        top: y,
        child: AnimatedBuilder(
          animation: _breathController,
          builder: (_, __) {
            final twinkle = 0.5 + (_breathController.value * 0.5);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity * twinkle),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: size * 2,
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  /// Hava parçacıkları
  Widget _buildParticle(_Particle p, double width, double height) {
    if (_weatherMain == 'snow') {
      return Positioned(
        left: p.x * width,
        top: p.y * height,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(p.opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 3),
            ],
          ),
        ),
      );
    } else if (_weatherMain == 'rain') {
      return Positioned(
        left: p.x * width,
        top: p.y * height,
        child: Container(
          width: 1.5,
          height: p.size * 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.lightBlue.withOpacity(0),
                Colors.lightBlue.withOpacity(p.opacity * 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Ay fazına göre ay görseli
  Widget _buildMoonWithPhase(int phase) {
    // Gerçek ay resmi üzerine gölge ile faz simülasyonu
    return Stack(
      children: [
        // Ana ay resmi
        Image.asset(
          'assets/icon/moon.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackMoon(phase),
        ),
        // Faz gölgesi
        CustomPaint(
          size: const Size(64, 64),
          painter: _MoonPhasePainter(phase: phase),
        ),
      ],
    );
  }

  /// Fallback güneş
  Widget _fallbackSun() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  /// Fallback ay
  Widget _fallbackMoon(int phase) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFF5F5F5),
            const Color(0xFFE0E0E0),
            const Color(0xFFBDBDBD).withOpacity(0.8),
          ],
        ),
      ),
      child: CustomPaint(
        size: const Size(64, 64),
        painter: _MoonPhasePainter(phase: phase),
      ),
    );
  }

  /// Vakit işaretçileri - profesyonel dizilim
  List<Widget> _buildVakitIndicators(
    double centerX,
    double centerY,
    double ellipseW,
    double ellipseH,
    int sunriseMin,
    int sunsetMin,
    String aktifVakit,
    Map<String, String> vakitIsimleri,
    bool isDay,
  ) {
    final widgets = <Widget>[];
    final sira = ['Imsak', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];

    for (final vakit in sira) {
      final t = _vakitler[vakit];
      if (t == null) continue;

      final vakitMin = _timeToMinutes(t);
      final isAktif = vakit == aktifVakit;
      final isGunduzVakit = vakitMin >= sunriseMin && vakitMin < sunsetMin;

      // Açı hesapla
      double angle;
      if (isGunduzVakit) {
        final prog = (vakitMin - sunriseMin) / (sunsetMin - sunriseMin);
        angle = math.pi - (prog * math.pi);
      } else {
        final nightLen = sunriseMin + (1440 - sunsetMin);
        double prog;
        if (vakitMin >= sunsetMin) {
          prog = (vakitMin - sunsetMin) / nightLen;
        } else {
          prog = (1440 - sunsetMin + vakitMin) / nightLen;
        }
        angle = -(prog * math.pi);
      }

      final x = centerX + math.cos(angle) * (ellipseW / 2);
      final y = centerY - math.sin(angle) * (ellipseH / 2);

      // Renk
      final color = _getVakitColor(vakit);

      // İşaretçi boyutu
      final markerSize = isAktif ? 18.0 : 12.0;

      // İşaretçi
      widgets.add(
        Positioned(
          left: x - markerSize / 2,
          top: y - markerSize / 2,
          child: Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isAktif ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: isAktif ? 12 : 6,
                  spreadRadius: isAktif ? 2 : 0,
                ),
              ],
            ),
          ),
        ),
      );

      // Vakit etiketi - pozisyona göre akıllı yerleşim
      double labelX = x;
      double labelY = y;

      // Her vakit için özel pozisyon
      switch (vakit) {
        case 'Imsak':
          labelX = x - 8;
          labelY = y + 16;
          break;
        case 'Gunes':
          labelX = x - 9; // 3mm sol (3mm ≈ 9px)
          labelY = y - 30; // 1cm yukarı (30px)
          break;
        case 'Ogle':
          labelX = x;
          labelY = y - 40;
          break;
        case 'Ikindi':
          labelX = x + 8; // bir tık daha sola (4px sola)
          labelY = y - 32; // biraz daha yukarı (4px yukarı)
          break;
        case 'Aksam':
          labelX = x + 12 - 20; // daha sola (4px daha sola)
          labelY = y - 35; // aynı yükseklik
          break;
        case 'Yatsi':
          labelX = x + 8 - 9; // 3mm sola (3mm ≈ 9px)
          labelY = y + 16;
          break;
      }

      widgets.add(
        Positioned(
          left: labelX - 32,
          top: labelY,
          child: Container(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Vakit adı (saat yok)
                Text(
                  vakitIsimleri[vakit] ?? vakit,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _getVakitTextColor(vakit, isAktif),
                    fontSize: isAktif ? 18 : 15,
                    fontWeight: isAktif ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  /// Basit geri sayım göstergesi
  Widget _buildSimpleCountdown(
    Map<String, dynamic> sonraki,
    Map<String, String> vakitIsimleri,
  ) {
    final vakit = sonraki['vakit'] as String;
    final kalan = sonraki['kalan'] as Duration;

    final h = kalan.inHours.toString().padLeft(2, '0');
    final m = kalan.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = kalan.inSeconds.remainder(60).toString().padLeft(2, '0');

    final vakitAdi = vakitIsimleri[vakit] ?? vakit;
    final color = _getVakitColor(vakit);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vakit adı
            Text(
              '$vakitAdi vaktine ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Geri sayım
            Text(
              '$h:$m:$s',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getVakitColor(String vakit) {
    switch (vakit) {
      case 'Imsak':
        return const Color(0xFF5E35B1); // Derin mor
      case 'Gunes':
        return const Color(0xFFFF8F00); // Turuncu
      case 'Ogle':
        return const Color(0xFFFFC107); // Altın
      case 'Ikindi':
        return const Color(0xFFFF7043); // Mercan
      case 'Aksam':
        return const Color(0xFFE91E63); // Pembe-kırmızı
      case 'Yatsi':
        return const Color(0xFF3949AB); // İndigo
      default:
        return const Color(0xFF607D8B);
    }
  }
}

/// Hava parçacığı
class _Particle {
  double x, y, size, speed, opacity, drift;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
  });

  void update(String? weather) {
    if (weather == 'snow') {
      y += speed;
      x += drift;
    } else if (weather == 'rain') {
      y += speed * 4;
    }

    if (y > 1) {
      y = 0;
      x = math.Random().nextDouble();
    }
    if (x > 1) x = 0;
    if (x < 0) x = 1;
  }
}

/// Ay fazı çizici - gerçekçi görünüm
class _MoonPhasePainter extends CustomPainter {
  final int phase;

  _MoonPhasePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Önce tüm ayı karanlık (siyah) boya
    final darkPaint = Paint()
      ..color = const Color(0xFF0A0A15).withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, darkPaint);

    // Dolunay ise tamamen aydınlık (beyaz) boya
    if (phase == 4) {
      final lightPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, lightPaint);
      return;
    }

    // Faz değerine göre aydınlık bölgenin genişliği
    final illumination = (phase <= 4) ? phase / 4.0 : (8 - phase) / 4.0;
    final shadowRatio = 1 - math.pow(illumination, 0.35).toDouble();

    final path = Path();

    if (phase == 0 || phase == 8) {
      // Yeni ay - hiç aydınlık yok, sadece siyah kalacak
      return;
    } else if (phase < 4) {
      // Büyüyen ay - SOL karanlık, SAĞ aydınlık
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        -math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (phase < 2) {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          -math.pi / 2,
          -math.pi,
          false,
        );
      } else {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          -math.pi / 2,
          math.pi,
          false,
        );
      }
    } else {
      // Küçülen ay - SAĞ karanlık, SOL aydınlık
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (phase > 6) {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          math.pi / 2,
          -math.pi,
          false,
        );
      } else {
        path.arcTo(
          Rect.fromLTRB(
            center.dx - curveWidth,
            center.dy - radius,
            center.dx + curveWidth,
            center.dy + radius,
          ),
          math.pi / 2,
          math.pi,
          false,
        );
      }
    }

    // Aydınlık kısmı clip et ve beyaz boya
    canvas.save();
    canvas.clipPath(path);
    final lightPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, lightPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MoonPhasePainter oldDelegate) =>
      oldDelegate.phase != phase;
}
