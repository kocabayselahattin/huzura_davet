import 'package:flutter/material.dart';
import 'package:flutter_weather_bg_null_safety/flutter_weather_bg.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/language_service.dart';

/// Day Cycle Countdown - modern and realistic design.
/// Real sun/moon images, moon phases, and dynamic background.
class GunDonumuSayacWidget extends StatefulWidget {
  const GunDonumuSayacWidget({super.key});

  @override
  State<GunDonumuSayacWidget> createState() => _GunDonumuSayacWidgetState();
}

class _GunDonumuSayacWidgetState extends State<GunDonumuSayacWidget>
    with TickerProviderStateMixin {
  final LanguageService _languageService = LanguageService();
  // Prayer time text color based on weather.
  Color _getVakitTextColor(String vakit, bool isAktif) {
    // Night: Yatsi, Imsak, before/after sunrise.
    final hour = _now.hour;
    if (vakit == 'Yatsi' || vakit == 'Imsak' || (hour < 6 || hour >= 22)) {
      return isAktif ? Colors.white : Colors.white70;
    }
    // Sunrise: warm yellow with darker shadows.
    if (vakit == 'Gunes') {
      return isAktif ? const Color(0xFFFFF176) : const Color(0xFFFFF9C4);
    }
    // Sunset: orange/red tones.
    if (vakit == 'Aksam') {
      return isAktif ? const Color(0xFFFF7043) : const Color(0xFFFFAB91);
    }
    // Noon/Afternoon: light blue/gray.
    if (vakit == 'Ogle' || vakit == 'Ikindi') {
      return isAktif ? const Color(0xFF1976D2) : const Color(0xFF90CAF9);
    }
    // Daytime: black or dark gray.
    if (hour >= 6 && hour < 18) {
      return isAktif ? Colors.black : Colors.black.withOpacity(0.85);
    }
    // Fallback.
    return isAktif ? Colors.white : Colors.white70;
  }

  late Timer _timer;
  late DateTime _now;
  String? _weatherMain;
  Map<String, String> _vakitler = {};

  // Animation controllers.
  late AnimationController _breathController;
  late AnimationController _floatController;

  // Weather particles.
  final List<_Particle> _particles = [];

  // Weather cache static values.
  // Fetch from API only once per app session.
  static String? _cachedWeather;
  static DateTime? _lastWeatherFetch;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    // Breathing animation (sun/moon).
    _breathController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    // Floating animation.
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
    _loadWeather(); // Load weather with cache check.
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
      final ilceId = await KonumService.getIlceId();
      if (ilceId == null || ilceId.isEmpty) {
        _setDefaultTimes();
        return;
      }

      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (mounted && vakitler != null) {
        setState(() => _vakitler = vakitler);
      } else {
        _setDefaultTimes();
      }
    } catch (e) {
      debugPrint('Failed to load prayer times: $e');
      _setDefaultTimes();
    }
  }

  void _setDefaultTimes() {
    if (!mounted) return;
    setState(() {
      _vakitler = {
        'Imsak': '05:30',
        'Gunes': '07:00',
        'Ogle': '12:30',
        'Ikindi': '15:30',
        'Aksam': '18:00',
        'Yatsi': '19:30',
      };
    });
  }

  // Province coordinates map.
  static const Map<String, List<double>> _ilKoordinatlari = {
    'Adana': [37.0, 35.32],
    'Adıyaman': [37.76, 38.28],
    'Afyonkarahisar': [38.75, 30.55],
    'Ağrı': [39.72, 43.05],
    'Amasya': [40.65, 35.83],
    'Ankara': [39.93, 32.85],
    'Antalya': [36.88, 30.70],
    'Artvin': [41.18, 41.82],
    'Aydın': [37.85, 27.85],
    'Balıkesir': [39.65, 27.88],
    'Bilecik': [40.15, 30.0],
    'Bingöl': [38.88, 40.50],
    'Bitlis': [38.40, 42.12],
    'Bolu': [40.73, 31.60],
    'Burdur': [37.72, 30.30],
    'Bursa': [40.18, 29.07],
    'Çanakkale': [40.15, 26.40],
    'Çankırı': [40.60, 33.62],
    'Çorum': [40.55, 34.95],
    'Denizli': [37.77, 29.08],
    'Diyarbakır': [37.92, 40.23],
    'Edirne': [41.68, 26.55],
    'Elazığ': [38.67, 39.22],
    'Erzincan': [39.75, 39.50],
    'Erzurum': [39.90, 41.27],
    'Eskişehir': [39.77, 30.52],
    'Gaziantep': [37.07, 37.38],
    'Giresun': [40.92, 38.38],
    'Gümüşhane': [40.45, 39.48],
    'Hakkari': [37.57, 43.75],
    'Hatay': [36.40, 36.35],
    'Isparta': [37.77, 30.55],
    'Mersin': [36.80, 34.63],
    'İstanbul': [41.02, 29.0],
    'İzmir': [38.42, 27.13],
    'Kars': [40.60, 43.10],
    'Kastamonu': [41.38, 33.77],
    'Kayseri': [38.72, 35.48],
    'Kırklareli': [41.73, 27.22],
    'Kırşehir': [39.15, 34.17],
    'Kocaeli': [40.85, 29.88],
    'Konya': [37.87, 32.48],
    'Kütahya': [39.42, 29.98],
    'Malatya': [38.35, 38.32],
    'Manisa': [38.62, 27.43],
    'Kahramanmaraş': [37.58, 36.93],
    'Mardin': [37.32, 40.73],
    'Muğla': [37.22, 28.37],
    'Muş': [38.75, 41.50],
    'Nevşehir': [38.62, 34.72],
    'Niğde': [37.97, 34.68],
    'Ordu': [40.98, 37.88],
    'Rize': [41.02, 40.52],
    'Sakarya': [40.73, 30.40],
    'Samsun': [41.28, 36.33],
    'Siirt': [37.93, 41.95],
    'Sinop': [42.02, 35.15],
    'Sivas': [39.75, 37.02],
    'Tekirdağ': [41.0, 27.52],
    'Tokat': [40.32, 36.55],
    'Trabzon': [41.0, 39.72],
    'Tunceli': [39.10, 39.55],
    'Şanlıurfa': [37.17, 38.80],
    'Uşak': [38.68, 29.40],
    'Van': [38.50, 43.38],
    'Yozgat': [39.82, 34.80],
    'Zonguldak': [41.45, 31.80],
    'Aksaray': [38.37, 34.03],
    'Bayburt': [40.25, 40.22],
    'Karaman': [37.18, 33.22],
    'Kırıkkale': [39.85, 33.52],
    'Batman': [37.88, 41.13],
    'Şırnak': [37.52, 42.45],
    'Bartın': [41.63, 32.35],
    'Ardahan': [41.12, 42.70],
    'Iğdır': [39.92, 44.05],
    'Yalova': [40.65, 29.27],
    'Karabük': [41.20, 32.62],
    'Kilis': [36.72, 37.12],
    'Osmaniye': [37.07, 36.25],
    'Düzce': [40.85, 31.17],
  };

  /// Load weather: check cache first, otherwise fetch from the API.
  /// Fetch only once per app session.
  Future<void> _loadWeather() async {
    // If cache exists and was fetched today, use it.
    if (_cachedWeather != null && _lastWeatherFetch != null) {
      final now = DateTime.now();
      final isSameDay =
          _lastWeatherFetch!.year == now.year &&
          _lastWeatherFetch!.month == now.month &&
          _lastWeatherFetch!.day == now.day;

      if (isSameDay) {
        debugPrint('🌤️ Weather loaded from cache: $_cachedWeather');
        if (mounted) setState(() => _weatherMain = _cachedWeather);
        return;
      }
    }

    // If cache is missing or stale, fetch from the API.
    await _fetchWeatherFromApi();
  }

  /// Fetch weather from the API and save to cache.
  /// Check selected coordinates first, otherwise use province/district data.
  Future<void> _fetchWeatherFromApi() async {
    try {
      double lat = 41.02; // Default Istanbul.
      double lon = 29.0;
      String konumKaynagi = 'default';

      // 1) Check selected locations first.
      final konumlar = await KonumService.getKonumlar();
      final aktifIndex = await KonumService.getAktifKonumIndex();

      if (konumlar.isNotEmpty && aktifIndex < konumlar.length) {
        final konum = konumlar[aktifIndex];

        // Get coordinates by province name.
        final ilAdi = konum.ilAdi;
        if (_ilKoordinatlari.containsKey(ilAdi)) {
          lat = _ilKoordinatlari[ilAdi]![0];
          lon = _ilKoordinatlari[ilAdi]![1];
          konumKaynagi = 'province coordinates ($ilAdi)';
        } else {
          // Handle case-insensitive match.
          for (final entry in _ilKoordinatlari.entries) {
            if (entry.key.toLowerCase() == ilAdi.toLowerCase()) {
              lat = entry.value[0];
              lon = entry.value[1];
              konumKaynagi = 'province coordinates (${entry.key})';
              break;
            }
          }
        }
      } else {
        // 4) If no location, use province/district selection.
        await KonumService.getIlceId();
        final ilAdi = await KonumService.getIl();

        if (ilAdi != null && ilAdi.isNotEmpty) {
          if (_ilKoordinatlari.containsKey(ilAdi)) {
            lat = _ilKoordinatlari[ilAdi]![0];
            lon = _ilKoordinatlari[ilAdi]![1];
            konumKaynagi = 'selected province ($ilAdi)';
          } else {
            for (final entry in _ilKoordinatlari.entries) {
              if (entry.key.toLowerCase() == ilAdi.toLowerCase()) {
                lat = entry.value[0];
                lon = entry.value[1];
                konumKaynagi = 'selected province (${entry.key})';
                break;
              }
            }
          }
        }
      }

      debugPrint(
        '🌤️ Fetching weather from API... (lat: $lat, lon: $lon, source: $konumKaynagi)',
      );

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=weather_code',
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

        // Save to cache.
        _cachedWeather = type;
        _lastWeatherFetch = DateTime.now();
        debugPrint('🌤️ Weather fetched and cached: $type');

        if (mounted) setState(() => _weatherMain = type);
      }
    } catch (e) {
      debugPrint('Weather error: $e');
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

  /// Calculate moon phase fraction (0.0-1.0).
  /// 0.0=new moon, 0.5=full moon, 1.0=new moon.
  double _getMoonPhaseFraction(DateTime date) {
    // Known new moon date: Dec 29, 2024 (updated reference).
    final reference = DateTime.utc(2024, 12, 30, 22, 27);
    const synodicMonth = 29.53058867;

    final daysDiff = date.difference(reference).inHours / 24.0;
    final phase = (daysDiff % synodicMonth) / synodicMonth;

    return phase;
  }

  /// Active prayer time.
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

  /// Next prayer time info (second precision).
  Map<String, dynamic> _getSonrakiVakit() {
    if (_vakitler.isEmpty) return {'vakit': '', 'kalan': Duration.zero};

    final nowSec = _now.hour * 3600 + _now.minute * 60 + _now.second;
    final sira = ['Imsak', 'Gunes', 'Ogle', 'Ikindi', 'Aksam', 'Yatsi'];

    for (final v in sira) {
      final t = _vakitler[v];
      if (t != null) {
        final m = _timeToMinutes(t) * 60; // Convert to seconds.
        if (m > nowSec) {
          return {
            'vakit': v,
            'kalan': Duration(seconds: m - nowSec),
          };
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

    // Time calculations.
    final sunriseMin = _timeToMinutes(_vakitler['Gunes'] ?? '06:30');
    final sunsetMin = _timeToMinutes(_vakitler['Aksam'] ?? '18:00');
    final nowMin = _now.hour * 60 + _now.minute;
    final isDay = nowMin >= sunriseMin && nowMin < sunsetMin;

    // Position on invisible ellipse (3mm ~ 12px padding).
    const padding = 12.0;
    final ellipseW = width - (padding * 2) - 60;
    final ellipseH = height * 0.45;
    final centerX = width / 2;
    final centerY = height * 0.52;

    // Sun/moon angle calculation.
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

    // Ellipse angle: day across top (left->right), night across bottom (right->left).
    final angle = isDay
        ? math.pi - (progress * math.pi)
        : -(progress * math.pi);

    final celestialX = centerX + math.cos(angle) * (ellipseW / 2);
    final celestialY = centerY - math.sin(angle) * (ellipseH / 2);

    final aktifVakit = _getAktifVakit();
    final sonraki = _getSonrakiVakit();
    final moonPhase = _getMoonPhaseFraction(_now);

    final Map<String, String> vakitIsimleri = {
      'Imsak': _languageService['imsak'] ?? 'Imsak',
      'Gunes': _languageService['gunes'] ?? 'Gunes',
      'Ogle': _languageService['ogle'] ?? 'Ogle',
      'Ikindi': _languageService['ikindi'] ?? 'Ikindi',
      'Aksam': _languageService['aksam'] ?? 'Aksam',
      'Yatsi': _languageService['yatsi'] ?? 'Yatsi',
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
            // === BACKGROUND: real sky image ===
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
                  errorBuilder: (context, error, stackTrace) => Container(
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

            // === WEATHER OVERLAY ===
            if (_weatherMain != null && _weatherMain != 'clear')
              Positioned.fill(
                child: WeatherBg(
                  weatherType: _getWeatherType(),
                  width: width,
                  height: height,
                ),
              ),

            // === NIGHT STARS ===
            if (!isDay) ..._buildStars(width, height),

            // === WEATHER PARTICLES ===
            if (_weatherMain == 'snow' || _weatherMain == 'rain')
              ..._particles.map((p) => _buildParticle(p, width, height)),

            // === HORIZON LINE (subtle) ===
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

            // === SUN OR MOON (real image) ===
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
                                errorBuilder: (context, error, stackTrace) =>
                                  _fallbackSun(),
                              )
                            : _buildMoonWithPhase(moonPhase),
                      ),
                    ),
                  ),
                );
              },
            ),

            // === PRAYER MARKERS (on invisible ellipse) ===
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

            // === BOTTOM COUNTDOWN ===
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

  /// Stars (night only).
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
          builder: (context, child) {
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

  /// Weather particles.
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

  /// Moon rendering by phase.
  Widget _buildMoonWithPhase(double phase) {
    // Simulate phase with a shadow over the moon image.
    return Stack(
      children: [
        // Base moon image.
        Image.asset(
          'assets/icon/moon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackMoon(phase),
        ),
        // Phase shadow.
        CustomPaint(
          size: const Size(64, 64),
          painter: _MoonPhasePainter(phase: phase),
        ),
      ],
    );
  }

  /// Fallback sun.
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

  /// Fallback moon.
  Widget _fallbackMoon(double phase) {
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

  /// Prayer markers - tuned layout.
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

      // Angle calculation.
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

      // Color.
      final color = _getVakitColor(vakit);

      // Marker size.
      final markerSize = isAktif ? 18.0 : 12.0;

      // Marker.
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

      // Prayer label - smart placement by position.
      double labelX = x;
      double labelY = y;

      // Custom position per prayer.
      switch (vakit) {
        case 'Imsak':
          labelX = x - 8;
          labelY = y + 16;
          break;
        case 'Gunes':
          labelX = x - 9; // 3mm left (3mm ≈ 9px)
          labelY = y - 30; // 1cm up (30px)
          break;
        case 'Ogle':
          labelX = x;
          labelY = y - 40;
          break;
        case 'Ikindi':
          labelX = x + 8; // slightly more left (4px)
          labelY = y - 32; // slightly higher (4px)
          break;
        case 'Aksam':
          labelX = x + 12 - 20; // further left (4px)
          labelY = y - 35; // same height
          break;
        case 'Yatsi':
          labelX = x + 8 - 9; // 3mm left (3mm ≈ 9px)
          labelY = y + 16;
          break;
      }

      widgets.add(
        Positioned(
          left: labelX - 32,
          top: labelY,
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Prayer name (no time).
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

  /// Simple countdown display.
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
            // Prayer name.
            Text(
              (_languageService['time_until_prayer'] ??
                      '{prayer} time in ')
                  .replaceAll('{prayer}', vakitAdi),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Countdown.
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
        return const Color(0xFF5E35B1); // Deep purple.
      case 'Gunes':
        return const Color(0xFFFF8F00); // Orange.
      case 'Ogle':
        return const Color(0xFFFFC107); // Gold.
      case 'Ikindi':
        return const Color(0xFFFF7043); // Coral.
      case 'Aksam':
        return const Color(0xFFE91E63); // Pink-red.
      case 'Yatsi':
        return const Color(0xFF3949AB); // Indigo.
      default:
        return const Color(0xFF607D8B);
    }
  }
}

/// Weather particle.
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

/// Moon phase painter - realistic look.
class _MoonPhasePainter extends CustomPainter {
  final double phase;

  _MoonPhasePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Paint the moon fully dark first.
    final darkPaint = Paint()
      ..color = const Color(0xFF0A0A15).withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, darkPaint);

    // Illumination amount from 0.0 to 1.0.
    final illumination = phase <= 0.5 ? (phase * 2) : ((1 - phase) * 2);
    if (illumination <= 0.001) {
      // New moon - keep it dark.
      return;
    }

    // If full moon, paint fully bright.
    if (illumination >= 0.999) {
      final lightPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, lightPaint);
      return;
    }

    final shadowRatio = 1 - math.pow(illumination, 0.35).toDouble();
    final isWaxing = phase < 0.5;

    final path = Path();

    if (isWaxing) {
      // Waxing moon - left dark, right bright.
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        -math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (illumination < 0.5) {
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
      // Waning moon - right dark, left bright.
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi,
        false,
      );
      final curveWidth = radius * (1 - shadowRatio * 2).abs();
      if (illumination < 0.5) {
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

    // Clip the bright area and paint it white.
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
