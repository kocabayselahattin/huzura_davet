import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geomag/geomag.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/vibration_service.dart';
import '../services/konum_service.dart';

/// Pusula stilleri enum
enum PusulaStili {
  modern,      // Varsayılan modern stil
  klasik,      // Klasik pusula görünümü
  islami,      // İslami motifli
  minimal,     // Minimalist tasarım
  luks,        // Lüks altın tasarım
  dijital,     // Dijital/Siber tasarım
}

class KibleSayfa extends StatefulWidget {
  const KibleSayfa({super.key});

  @override
  State<KibleSayfa> createState() => _KibleSayfaState();
}

class _KibleSayfaState extends State<KibleSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  double? _kibleDerece;
  bool _yukleniyor = true;
  String? _hata;
  VoidCallback? _hataAksiyon;
  String? _hataAksiyonLabel;
  Position? _konum;
  StreamSubscription<CompassEvent>? _compassSub;
  double? _heading;
  double? _declination;
  bool _pusulaDestegi = true;

  // Pusula stili
  PusulaStili _pusulaStili = PusulaStili.modern;

  // Doğru yön geri bildirimi için
  bool _wasCorrectDirection = false;
  AudioPlayer? _audioPlayer;
  DateTime? _lastFeedbackTime;

  // Kabe koordinatları
  static const double kabeEnlem = 21.4225;
  static const double kabeBoylam = 39.8262;

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
    _audioPlayer = AudioPlayer();
    _pusulaStiliniYukle();
    _startCompass();
    _konumuAl();
  }

  Future<void> _pusulaStiliniYukle() async {
    final styleIndex = await KonumService.getPusulaStili();
    if (mounted && styleIndex < PusulaStili.values.length) {
      setState(() {
        _pusulaStili = PusulaStili.values[styleIndex];
      });
    }
  }

  Future<void> _pusulaStiliniKaydet(PusulaStili stil) async {
    await KonumService.setPusulaStili(stil.index);
    setState(() {
      _pusulaStili = stil;
    });
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    _compassSub?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _startCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) {
      setState(() {
        _pusulaDestegi = false;
      });
      return;
    }

    _compassSub = stream.listen(
      (event) {
        if (!mounted) return;
        final heading = event.heading;
        if (heading == null) return;
        setState(() {
          _heading = heading;
        });

        // Doğru yön kontrolü ve geri bildirim
        _checkCorrectDirection();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _pusulaDestegi = false;
        });
      },
    );
  }

  /// Doğru yönde olup olmadığını kontrol et ve geri bildirim ver
  void _checkCorrectDirection() {
    if (_kibleDerece == null || _heading == null || _declination == null)
      return;

    final trueHeading = _normalizeAngle(
      (_heading ?? 0).toDouble() + (_declination ?? 0),
    );
    final relative = _normalizeAngle(_kibleDerece! - trueHeading);
    final isCorrectDirection = relative.abs() < 3 || (360 - relative).abs() < 3;

    // Yeni doğru yöne girdiğinde ses ve titreşim
    if (isCorrectDirection && !_wasCorrectDirection) {
      _playDirectionFeedback();
    }

    _wasCorrectDirection = isCorrectDirection;
  }

  /// Doğru yönde olunca ses çal ve titret
  Future<void> _playDirectionFeedback() async {
    // Rate limiting - en az 2 saniye arayla çalsın
    final now = DateTime.now();
    if (_lastFeedbackTime != null &&
        now.difference(_lastFeedbackTime!).inMilliseconds < 2000) {
      return;
    }
    _lastFeedbackTime = now;

    try {
      // Güçlü titreşim pattern'i
      await VibrationService.vibratePattern([0, 150, 100, 150, 100, 200]);

      // Ses efekti
      await _audioPlayer?.play(AssetSource('sounds/ding_dong.mp3'));
    } catch (e) {
      print('⚠️ Kıble geri bildirim hatası: $e');
    }
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _konumuAl() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _hataAksiyon = null;
      _hataAksiyonLabel = null;
    });

    try {
      // Konum izni kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _hata =
                _languageService['location_permission_denied'] ??
                'Konum izni reddedildi';
            _hataAksiyon = Geolocator.openAppSettings;
            _hataAksiyonLabel =
                _languageService['go_to_settings'] ?? 'Ayarlara Git';
            _yukleniyor = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _hata =
              _languageService['location_permission_denied_forever'] ??
              'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.';
          _hataAksiyon = Geolocator.openAppSettings;
          _hataAksiyonLabel =
              _languageService['go_to_settings'] ?? 'Ayarlara Git';
          _yukleniyor = false;
        });
        return;
      }

      // Konum servisinin açık olup olmadığını kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _hata =
              _languageService['location_service_disabled'] ??
              'Konum servisi kapalı. Lütfen açın.';
          _hataAksiyon = Geolocator.openLocationSettings;
          _hataAksiyonLabel =
              _languageService['location_settings'] ?? 'Konum Ayarları';
          _yukleniyor = false;
        });
        return;
      }

      // Önce son bilinen konumu al (hızlı başlangıç için)
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      Position? position;

      try {
        // Konum al (30 saniye timeout)
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );
      } catch (e) {
        // getCurrentPosition başarısızsa son bilinen konumu kullan
        if (lastKnown != null) {
          position = lastKnown;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _languageService['last_known_location_used'] ??
                      'Canlı konum alınamadı, son bilinen konum kullanıldı.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            _hata =
                '${_languageService['location_error_gps'] ?? 'Konum alınamadı. Lütfen GPS\'i açık alanda tekrar deneyin.'}\n${_languageService['error'] ?? 'Hata'}: $e';
            _hataAksiyon = _konumuAl;
            _hataAksiyonLabel = _languageService['try_again'] ?? 'Tekrar Dene';
            _yukleniyor = false;
          });
          return;
        }
      }

      if (position == null) {
        setState(() {
          _hata =
              _languageService['location_not_available'] ??
              'Konum bilgisi alınamadı.';
          _hataAksiyon = _konumuAl;
          _hataAksiyonLabel = _languageService['try_again'] ?? 'Tekrar Dene';
          _yukleniyor = false;
        });
        return;
      }

      // Kıble açısını hesapla
      final kibleAcisi = _kibleHesapla(position.latitude, position.longitude);

      final declination = _hesaplaManyetikSapma(
        position.latitude,
        position.longitude,
        position.altitude,
      );

      setState(() {
        _konum = position;
        _kibleDerece = kibleAcisi;
        _declination = declination;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _hata =
            '${_languageService['location_error'] ?? 'Konum alınamadı'}: $e';
        _hataAksiyon = _konumuAl;
        _hataAksiyonLabel = _languageService['try_again'] ?? 'Tekrar Dene';
        _yukleniyor = false;
      });
    }
  }

  double _kibleHesapla(double enlem, double boylam) {
    // Dereceyi radyana çevir
    final lat1 = _toRadians(enlem);
    final lon1 = _toRadians(boylam);
    final lat2 = _toRadians(kabeEnlem);
    final lon2 = _toRadians(kabeBoylam);

    // Standart bearing formülü (Great Circle)
    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double derece = _toDegrees(math.atan2(y, x));

    // 0-360 aralığına normalize et
    derece = (derece + 360) % 360;

    return derece;
  }

  double _toRadians(double derece) {
    return derece * math.pi / 180;
  }

  double _toDegrees(double radyan) {
    return radyan * 180 / math.pi;
  }

  double _hesaplaManyetikSapma(double lat, double lon, double? alt) {
    try {
      final geoMag = GeoMag();
      final altitudeFeet = (alt ?? 0) * 3.28084;
      final result = geoMag.calculate(lat, lon, altitudeFeet, DateTime.now());
      return result.dec.toDouble();
    } catch (_) {
      return 0;
    }
  }

  double _normalizeAngle(double derece) {
    var normalized = derece % 360;
    if (normalized < 0) normalized += 360;
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _languageService['qibla_direction'] ?? 'Kıble Yönü',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _pusulaStiliSec,
            tooltip: _languageService['compass_style'] ?? 'Pusula Stili',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _konumuAl,
            tooltip: _languageService['refresh_location'] ?? 'Konumu yenile',
          ),
        ],
      ),
      body: _yukleniyor
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: renkler.vurgu),
                  const SizedBox(height: 16),
                  Text(
                    _languageService['getting_location'] ?? 'Konum alınıyor...',
                    style: TextStyle(
                      color: renkler.yaziSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _hata != null
          ? _hataMesaji(renkler)
          : _pusulaGoster(renkler),
    );
  }

  Widget _hataMesaji(TemaRenkleri renkler) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            Text(
              _hata!,
              textAlign: TextAlign.center,
              style: TextStyle(color: renkler.yaziPrimary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _hataAksiyon ?? _konumuAl,
              icon: const Icon(Icons.settings),
              label: Text(
                _hataAksiyonLabel ??
                    (_languageService['try_again'] ?? 'Tekrar Dene'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: renkler.vurgu,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pusulaGoster(TemaRenkleri renkler) {
    if (!_pusulaDestegi) {
      return _pusulaDestekYok(renkler);
    }

    final heading = _heading;
    final hasHeading = heading != null;
    final qibla = _kibleDerece ?? 0;
    final double? trueHeading = hasHeading
        ? _normalizeAngle(
            (heading ?? 0).toDouble() + (_declination ?? 0),
          ).toDouble()
        : null;
    final double? relative = trueHeading != null
        ? _normalizeAngle(qibla - trueHeading)
        : null;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          _konumBilgisi(renkler),
          const SizedBox(height: 24),
          _seciliPusula(renkler, relative, trueHeading),
          const SizedBox(height: 24),
          _kibleAcisiGoster(renkler),
          const SizedBox(height: 16),
          _bilgiNotu(renkler, hasHeading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Seçili pusula stiline göre uygun pusulayı döndürür
  Widget _seciliPusula(TemaRenkleri renkler, double? relative, double? trueHeading) {
    switch (_pusulaStili) {
      case PusulaStili.modern:
        return _modernPusula(renkler, relative, trueHeading);
      case PusulaStili.klasik:
        return _klasikPusula(renkler, relative, trueHeading);
      case PusulaStili.islami:
        return _islamiPusula(renkler, relative, trueHeading);
      case PusulaStili.minimal:
        return _minimalPusula(renkler, relative, trueHeading);
      case PusulaStili.luks:
        return _luksPusula(renkler, relative, trueHeading);
      case PusulaStili.dijital:
        return _dijitalPusula(renkler, relative, trueHeading);
    }
  }

  /// Pusula stili seçme dialog'u
  void _pusulaStiliSec() {
    final renkler = _temaService.renkler;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: renkler.kartArkaPlan,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette, color: renkler.vurgu),
                  const SizedBox(width: 12),
                  Text(
                    _languageService['compass_style'] ?? 'Pusula Stili',
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: PusulaStili.values.map((stil) {
                    final isSelected = _pusulaStili == stil;
                    return _pusulaStiliKarti(renkler, stil, isSelected);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _pusulaStiliKarti(TemaRenkleri renkler, PusulaStili stil, bool isSelected) {
    final stilBilgisi = _getPusulaStilBilgisi(stil);
    
    return GestureDetector(
      onTap: () {
        _pusulaStiliniKaydet(stil);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? renkler.vurgu.withOpacity(0.2) 
              : renkler.arkaPlan.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? renkler.vurgu : renkler.ayirac,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: stilBilgisi['gradient'] as Gradient?,
                color: stilBilgisi['gradient'] == null 
                    ? stilBilgisi['color'] as Color 
                    : null,
                border: Border.all(
                  color: stilBilgisi['borderColor'] as Color,
                  width: 2,
                ),
              ),
              child: Icon(
                stilBilgisi['icon'] as IconData,
                color: stilBilgisi['iconColor'] as Color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stilBilgisi['name'] as String,
              style: TextStyle(
                color: isSelected ? renkler.vurgu : renkler.yaziPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getPusulaStilBilgisi(PusulaStili stil) {
    switch (stil) {
      case PusulaStili.modern:
        return {
          'name': _languageService['compass_modern'] ?? 'Modern',
          'icon': Icons.explore,
          'iconColor': Colors.white,
          'borderColor': const Color(0xFF2196F3),
          'gradient': const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2196F3)],
          ),
        };
      case PusulaStili.klasik:
        return {
          'name': _languageService['compass_classic'] ?? 'Klasik',
          'icon': Icons.navigation,
          'iconColor': const Color(0xFF8B4513),
          'borderColor': const Color(0xFFD4A574),
          'gradient': const LinearGradient(
            colors: [Color(0xFFF5DEB3), Color(0xFFD4A574)],
          ),
        };
      case PusulaStili.islami:
        return {
          'name': _languageService['compass_islamic'] ?? 'İslami',
          'icon': Icons.mosque,
          'iconColor': Colors.white,
          'borderColor': const Color(0xFF00695C),
          'gradient': const LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF00897B)],
          ),
        };
      case PusulaStili.minimal:
        return {
          'name': _languageService['compass_minimal'] ?? 'Minimal',
          'icon': Icons.circle_outlined,
          'iconColor': Colors.black87,
          'borderColor': Colors.grey.shade400,
          'color': Colors.white,
          'gradient': null,
        };
      case PusulaStili.luks:
        return {
          'name': _languageService['compass_luxury'] ?? 'Lüks',
          'icon': Icons.star,
          'iconColor': Colors.white,
          'borderColor': const Color(0xFFFFD700),
          'gradient': const LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        };
      case PusulaStili.dijital:
        return {
          'name': _languageService['compass_digital'] ?? 'Dijital',
          'icon': Icons.memory,
          'iconColor': const Color(0xFF00FF00),
          'borderColor': const Color(0xFF00FF00),
          'gradient': const LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
          ),
        };
    }
  }

  Widget _konumBilgisi(TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renkler.ayirac.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: renkler.vurgu, size: 20),
              const SizedBox(width: 8),
              Text(
                _languageService['current_location'] ?? 'Mevcut Konum',
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_konum != null) ...[
            Text(
              '${_languageService['latitude'] ?? 'Enlem'}: ${_konum!.latitude.toStringAsFixed(4)}°',
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${_languageService['longitude'] ?? 'Boylam'}: ${_konum!.longitude.toStringAsFixed(4)}°',
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modernPusula(
    TemaRenkleri renkler,
    double? relativeAngle,
    double? trueHeading,
  ) {
    final headingText = trueHeading == null
        ? '--'
        : '${trueHeading.toStringAsFixed(0)}° ${_getYonKisaltma(trueHeading)}';
    final qiblaText = _kibleDerece == null
        ? '--'
        : '${_kibleDerece!.toStringAsFixed(0)}°';
    final isCorrectDirection = relativeAngle != null && relativeAngle.abs() < 3;
    // Kabe simgesi için açı (kıble açısı - cihaz yönü)
    final double kabeAngle = (_kibleDerece ?? 0) - (trueHeading ?? 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          Text(
            headingText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pusula halkası cihaz yönüne göre döner
                AnimatedRotation(
                  turns: -(trueHeading ?? 0) / 360,
                  duration: const Duration(milliseconds: 300),
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _CompassDialPainter(
                      directions: [
                        _languageService['compass_n'] ?? 'N',
                        _languageService['compass_e'] ?? 'E',
                        _languageService['compass_s'] ?? 'S',
                        _languageService['compass_w'] ?? 'W',
                      ],
                    ),
                  ),
                ),
                // Kabe simgesi pusula üzerinde kıble açısına göre döner
                Transform.rotate(
                  angle: _toRadians(kabeAngle),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🕋', style: TextStyle(fontSize: 38)),
                        const SizedBox(height: 4),
                        Text(
                          _languageService['kabe'] ?? 'Kabe',
                          style: const TextStyle(
                            color: Colors.brown,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Ok sabit, her zaman yukarıyı gösterir
                _northTriangle(),
                _qiblaArrow(),
                // Doğru yön efekti
                if (isCorrectDirection)
                  Positioned(
                    bottom: 32,
                    child: AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['correct_direction'] ??
                                  'Doğru Yön',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Kalibrasyon göstergesi
                if (relativeAngle == null)
                  Positioned(
                    bottom: 60,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _languageService['calibrating_compass'] ??
                              'Pusula kalibre ediliyor...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Klasik Pusula - Vintage/Antika tarzı
  Widget _klasikPusula(
    TemaRenkleri renkler,
    double? relativeAngle,
    double? trueHeading,
  ) {
    final isCorrectDirection = relativeAngle != null && relativeAngle.abs() < 3;
    final double kabeAngle = (_kibleDerece ?? 0) - (trueHeading ?? 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: -(trueHeading ?? 0) / 360,
                  duration: const Duration(milliseconds: 300),
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _KlasikCompassPainter(
                      directions: [
                        _languageService['compass_n'] ?? 'N',
                        _languageService['compass_e'] ?? 'E',
                        _languageService['compass_s'] ?? 'S',
                        _languageService['compass_w'] ?? 'W',
                      ],
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _toRadians(kabeAngle),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 25),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B4513),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFD4A574), width: 2),
                            ),
                            child: const Text('🕋', style: TextStyle(fontSize: 24)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Yön oku - kullanıcının baktığı yön
                _directionArrow(color: const Color(0xFF8B4513)),
                // Merkez klasik iğne
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8B4513),
                    border: Border.all(color: const Color(0xFFD4A574), width: 2),
                  ),
                ),
                if (isCorrectDirection) _correctDirectionBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// İslami Pusula - Yeşil tonlar ve motifler
  Widget _islamiPusula(
    TemaRenkleri renkler,
    double? relativeAngle,
    double? trueHeading,
  ) {
    final isCorrectDirection = relativeAngle != null && relativeAngle.abs() < 3;
    final double kabeAngle = (_kibleDerece ?? 0) - (trueHeading ?? 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: -(trueHeading ?? 0) / 360,
                  duration: const Duration(milliseconds: 300),
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _IslamiCompassPainter(
                      directions: [
                        _languageService['compass_n'] ?? 'N',
                        _languageService['compass_e'] ?? 'E',
                        _languageService['compass_s'] ?? 'S',
                        _languageService['compass_w'] ?? 'W',
                      ],
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _toRadians(kabeAngle),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withOpacity(0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Text('🕋', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ),
                // Yön oku - kullanıcının baktığı yön
                _directionArrow(color: const Color(0xFF00695C)),
                // Merkez hilal
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF004D40),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                  ),
                  child: const Center(
                    child: Text('☪', style: TextStyle(fontSize: 20, color: Color(0xFFD4AF37))),
                  ),
                ),
                if (isCorrectDirection) _correctDirectionBadge(color: const Color(0xFF00695C)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Minimal Pusula - Sade ve temiz
  Widget _minimalPusula(
    TemaRenkleri renkler,
    double? relativeAngle,
    double? trueHeading,
  ) {
    final isCorrectDirection = relativeAngle != null && relativeAngle.abs() < 3;
    final double kabeAngle = (_kibleDerece ?? 0) - (trueHeading ?? 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: -(trueHeading ?? 0) / 360,
                  duration: const Duration(milliseconds: 300),
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _MinimalCompassPainter(
                      directions: [
                        _languageService['compass_n'] ?? 'N',
                        _languageService['compass_e'] ?? 'E',
                        _languageService['compass_s'] ?? 'S',
                        _languageService['compass_w'] ?? 'W',
                      ],
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _toRadians(kabeAngle),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: const Text('🕋', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ),
                // Yön oku - kullanıcının baktığı yön
                _directionArrow(color: Colors.grey.shade700),
                if (isCorrectDirection) _correctDirectionBadge(color: Colors.grey.shade600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lüks Pusula - Altın premium tasarım
  Widget _luksPusula(
    TemaRenkleri renkler,
    double? relativeAngle,
    double? trueHeading,
  ) {
    final isCorrectDirection = relativeAngle != null && relativeAngle.abs() < 3;
    final double kabeAngle = (_kibleDerece ?? 0) - (trueHeading ?? 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 310,
            height: 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: -(trueHeading ?? 0) / 360,
                  duration: const Duration(milliseconds: 300),
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _LuksCompassPainter(
                      directions: [
                        _languageService['compass_n'] ?? 'N',
                        _languageService['compass_e'] ?? 'E',
                        _languageService['compass_s'] ?? 'S',
                        _languageService['compass_w'] ?? 'W',
                      ],
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _toRadians(kabeAngle),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 25),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.6),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Text('🕋', style: TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
                ),
                // Merkez elmas
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
                    ),
                  ),
                ),
                // Yön oku - kullanıcının baktığı yön
                _directionArrow(color: const Color(0xFFFFD700)),
                if (isCorrectDirection) _correctDirectionBadge(color: const Color(0xFFFFD700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dijital Pusula - Siber/Matrix tarzı
  Widget _dijitalPusula(
    TemaRenkleri renkler,
    double? relativeAngle,
    double? trueHeading,
  ) {
    final isCorrectDirection = relativeAngle != null && relativeAngle.abs() < 3;
    final double kabeAngle = (_kibleDerece ?? 0) - (trueHeading ?? 0);
    final headingText = trueHeading == null
        ? '---'
        : trueHeading.toStringAsFixed(0).padLeft(3, '0');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Dijital heading göstergesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00FF00)),
            ),
            child: Text(
              'HDG: $headingText°',
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontSize: 18,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Color(0xFF00FF00), blurRadius: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 310,
            height: 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF00).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: -(trueHeading ?? 0) / 360,
                  duration: const Duration(milliseconds: 300),
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _DijitalCompassPainter(
                      directions: [
                        _languageService['compass_n'] ?? 'N',
                        _languageService['compass_e'] ?? 'E',
                        _languageService['compass_s'] ?? 'S',
                        _languageService['compass_w'] ?? 'W',
                      ],
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _toRadians(kabeAngle),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 25),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D0D),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00FF00), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF00).withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Text('🕋', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
                ),
                // Yön oku - kullanıcının baktığı yön
                _directionArrow(color: const Color(0xFF00FF00)),
                if (isCorrectDirection) _correctDirectionBadge(color: const Color(0xFF00FF00)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Doğru yön badge'i - tüm pusulalar için ortak
  Widget _correctDirectionBadge({Color color = Colors.green}) {
    return Positioned(
      bottom: 32,
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 400),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                _languageService['correct_direction'] ?? 'Doğru Yön',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _northTriangle() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        child: CustomPaint(
          size: const Size(18, 14),
          painter: _TrianglePainter(color: Colors.white),
        ),
      ),
    );
  }

  /// Yön oku - kullanıcının baktığı yönü gösterir
  Widget _directionArrow({required Color color}) {
    return Positioned(
      top: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(20, 16),
              painter: _TrianglePainter(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              _languageService['your_direction'] ?? 'Yönünüz',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qiblaArrow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(26, 22),
          painter: _TrianglePainter(color: const Color(0xFF45D06E)),
        ),
        const SizedBox(height: 4),
        const Icon(Icons.mosque, color: Colors.black, size: 18),
      ],
    );
  }

  Widget _centerDegreeBadge(String text) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2F7DE1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mosque, color: Colors.black, size: 16),
          const SizedBox(height: 2),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _getYonKisaltma(double derece) {
    if (derece >= 337.5 || derece < 22.5)
      return _languageService['compass_n'] ?? 'K';
    if (derece >= 22.5 && derece < 67.5)
      return _languageService['compass_ne'] ?? 'KD';
    if (derece >= 67.5 && derece < 112.5)
      return _languageService['compass_e'] ?? 'D';
    if (derece >= 112.5 && derece < 157.5)
      return _languageService['compass_se'] ?? 'GD';
    if (derece >= 157.5 && derece < 202.5)
      return _languageService['compass_s'] ?? 'G';
    if (derece >= 202.5 && derece < 247.5)
      return _languageService['compass_sw'] ?? 'GB';
    if (derece >= 247.5 && derece < 292.5)
      return _languageService['compass_w'] ?? 'B';
    return _languageService['compass_nw'] ?? 'KB';
  }

  Widget _compassFace(TemaRenkleri renkler) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _orbitDots(renkler),
        for (int i = 0; i < 72; i++)
          Transform.rotate(
            angle: _toRadians(i * 5.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: i % 6 == 0 ? 3 : 1,
                height: i % 6 == 0 ? 18 : 10,
                decoration: BoxDecoration(
                  color: i % 18 == 0
                      ? renkler.vurgu.withValues(alpha: 0.9)
                      : renkler.ayirac.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        for (int i = 0; i < 4; i++)
          Transform.rotate(
            angle: _toRadians(i * 90.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: renkler.kartArkaPlan.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: renkler.ayirac.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    ['K', 'D', 'G', 'B'][i],
                    style: TextStyle(
                      color: i == 0 ? Colors.redAccent : renkler.yaziPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
      ],
    );
  }

  Widget _qiblaNeedle(TemaRenkleri renkler) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.greenAccent.shade200, Colors.green.shade600],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _centerDot(TemaRenkleri renkler) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: renkler.vurgu,
        boxShadow: [
          BoxShadow(
            color: renkler.vurgu.withValues(alpha: 0.7),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _glowRing(TemaRenkleri renkler) {
    return IgnorePointer(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: renkler.vurgu.withValues(alpha: 0.12),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassRing(TemaRenkleri renkler) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            renkler.vurgu.withValues(alpha: 0.10),
            Colors.transparent,
            renkler.vurgu.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: renkler.ayirac.withValues(alpha: 0.25)),
      ),
    );
  }

  Widget _orbitDots(TemaRenkleri renkler) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        children: List.generate(8, (index) {
          final angle = _toRadians(index * 45.0);
          return Align(
            alignment: Alignment(math.cos(angle), math.sin(angle)),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: renkler.vurgu.withValues(alpha: 0.5),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _qiblaHalo(TemaRenkleri renkler, double? relativeAngle) {
    if (relativeAngle == null) return const SizedBox.shrink();
    return AnimatedRotation(
      turns: relativeAngle / 360,
      duration: const Duration(milliseconds: 140),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 120,
          height: 120,
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.greenAccent.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(
    TemaRenkleri renkler,
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: renkler.arkaPlan.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renkler.ayirac.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: renkler.vurgu),
          const SizedBox(width: 6),
          Text(
            '$title: ',
            style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pusulaDestekYok(TemaRenkleri renkler) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off,
              size: 80,
              color: renkler.yaziSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            Text(
              _languageService['compass_not_found'] ??
                  'Cihazda pusula sensörü bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: renkler.yaziPrimary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kibleAcisiGoster(TemaRenkleri renkler) {
    final kibleText = _kibleDerece == null
        ? '--'
        : '${_kibleDerece!.toStringAsFixed(1)}°';
    final yonText = _kibleDerece == null ? '-' : _getYonAdi(_kibleDerece!);
    final headingText = _heading == null
        ? '--'
        : '${_normalizeAngle(_heading!.toDouble() + (_declination ?? 0)).toStringAsFixed(0)}°';
    final declinationText = _declination == null
        ? '--'
        : '${_declination!.toStringAsFixed(1)}°';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            renkler.vurgu.withValues(alpha: 0.2),
            renkler.vurgu.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renkler.vurgu.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            _languageService['qibla_angle'] ?? 'Kıble Açısı',
            style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            kibleText,
            style: TextStyle(
              color: renkler.vurgu,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            yonText,
            style: TextStyle(color: renkler.yaziPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${_languageService['compass_heading'] ?? 'Pusula'}: $headingText',
            style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${_languageService['magnetic_declination'] ?? 'Manyetik sapma'}: $declinationText',
            style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getYonAdi(double derece) {
    if (derece >= 337.5 || derece < 22.5)
      return _languageService['direction_north'] ?? 'Kuzey';
    if (derece >= 22.5 && derece < 67.5)
      return _languageService['direction_northeast'] ?? 'Kuzeydoğu';
    if (derece >= 67.5 && derece < 112.5)
      return _languageService['direction_east'] ?? 'Doğu';
    if (derece >= 112.5 && derece < 157.5)
      return _languageService['direction_southeast'] ?? 'Güneydoğu';
    if (derece >= 157.5 && derece < 202.5)
      return _languageService['direction_south'] ?? 'Güney';
    if (derece >= 202.5 && derece < 247.5)
      return _languageService['direction_southwest'] ?? 'Güneybatı';
    if (derece >= 247.5 && derece < 292.5)
      return _languageService['direction_west'] ?? 'Batı';
    return _languageService['direction_northwest'] ?? 'Kuzeybatı';
  }

  Widget _bilgiNotu(TemaRenkleri renkler, bool hasHeading) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasHeading
                  ? (_languageService['qibla_info_note'] ??
                        'Telefonunuzu yatay tutun. Yeşil Kabe ibresi kıble yönünü gösterir. Kalibrasyon için telefonu 8 çizerek hareket ettirin.')
                  : (_languageService['compass_no_data'] ??
                        'Pusula verisi alınamıyor. Cihazınızın sensör desteğini kontrol edin.'),
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CompassDialPainter extends CustomPainter {
  final List<String> directions;

  _CompassDialPainter({required this.directions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final majorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 1, ringPaint);

    for (int i = 0; i < 360; i += 5) {
      final angle = (i - 90) * math.pi / 180;
      final isMajor = i % 30 == 0;
      final isMedium = i % 10 == 0;
      final tickLength = isMajor
          ? 16.0
          : isMedium
          ? 10.0
          : 6.0;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 6),
        center.dy + math.sin(angle) * (radius - 6),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 6 - tickLength),
        center.dy + math.sin(angle) * (radius - 6 - tickLength),
      );
      canvas.drawLine(inner, outer, isMajor ? majorPaint : tickPaint);
    }

    for (int i = 0; i < 360; i += 30) {
      final angle = (i - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: i.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 30) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 30) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }

    // Yön harfleri - dil desteği ile
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color:
                (i == 0 || i == 2) // N ve S için kırmızı
                ? const Color(0xFFE4504D)
                : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 58) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 58) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) {
    return oldDelegate.directions != directions;
  }
}

/// Klasik Pusula Painter - Vintage tarzı
class _KlasikCompassPainter extends CustomPainter {
  final List<String> directions;
  
  _KlasikCompassPainter({required this.directions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dış çerçeve - altın rengi
    final outerRing = Paint()
      ..color = const Color(0xFFD4A574)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 2, outerRing);

    // İç arka plan gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF5DEB3),
          const Color(0xFFE8D4A8),
          const Color(0xFFD4C4A4),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 6, bgPaint);

    // Tick çizgileri
    final tickPaint = Paint()
      ..color = const Color(0xFF5D4E37)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 360; i += 10) {
      final angle = (i - 90) * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 14.0 : 8.0;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 10),
        center.dy + math.sin(angle) * (radius - 10),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 10 - tickLength),
        center.dy + math.sin(angle) * (radius - 10 - tickLength),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Yön harfleri - vintage stil
    final dirColors = [
      const Color(0xFF8B0000), // N - Koyu kırmızı
      const Color(0xFF5D4E37), // E
      const Color(0xFF5D4E37), // S
      const Color(0xFF5D4E37), // W
    ];
    
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: dirColors[i],
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 50) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 50) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// İslami Pusula Painter - Yeşil tonlar ve İslami motifler
class _IslamiCompassPainter extends CustomPainter {
  final List<String> directions;
  
  _IslamiCompassPainter({required this.directions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dış çerçeve - zümrüt yeşili
    final outerRing = Paint()
      ..color = const Color(0xFF00695C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius - 2, outerRing);

    // İkinci çerçeve - altın
    final goldRing = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 8, goldRing);

    // Arka plan gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF004D40),
          const Color(0xFF00695C),
          const Color(0xFF00897B),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 12, bgPaint);

    // İslami geometrik desenler (8 köşeli yıldız efekti)
    final patternPaint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final start = Offset(
        center.dx + math.cos(angle) * 30,
        center.dy + math.sin(angle) * 30,
      );
      final end = Offset(
        center.dx + math.cos(angle) * (radius - 60),
        center.dy + math.sin(angle) * (radius - 60),
      );
      canvas.drawLine(start, end, patternPaint);
    }

    // Tick çizgileri
    final tickPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 360; i += 15) {
      final angle = (i - 90) * math.pi / 180;
      final isMajor = i % 45 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 15),
        center.dy + math.sin(angle) * (radius - 15),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 15 - tickLength),
        center.dy + math.sin(angle) * (radius - 15 - tickLength),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Yön harfleri
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 45) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 45) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Minimal Pusula Painter - Sade ve temiz
class _MinimalCompassPainter extends CustomPainter {
  final List<String> directions;
  
  _MinimalCompassPainter({required this.directions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Arka plan - beyaz
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - 2, bgPaint);

    // İnce çerçeve
    final ringPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 2, ringPaint);

    // Sadece ana yön çizgileri
    final linePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 10),
        center.dy + math.sin(angle) * (radius - 10),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 30),
        center.dy + math.sin(angle) * (radius - 30),
      );
      canvas.drawLine(inner, outer, linePaint);
    }

    // Yön harfleri - minimal
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: i == 0 ? Colors.red.shade400 : Colors.grey.shade700,
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 55) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 55) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }

    // Merkez nokta
    canvas.drawCircle(center, 4, Paint()..color = Colors.grey.shade400);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lüks Pusula Painter - Altın ve premium görünüm
class _LuksCompassPainter extends CustomPainter {
  final List<String> directions;
  
  _LuksCompassPainter({required this.directions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dış altın çerçeve
    final goldGradient = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFFFFD700),
          const Color(0xFFFFA500),
          const Color(0xFFFFD700),
          const Color(0xFFDAA520),
          const Color(0xFFFFD700),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 2, goldGradient);

    // İç koyu arka plan
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1A1A2E),
          const Color(0xFF16213E),
          const Color(0xFF0F0F1A),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 8));
    canvas.drawCircle(center, radius - 8, bgPaint);

    // Elmas şekilli tickler
    final diamondPaint = Paint()..color = const Color(0xFFFFD700);
    for (int i = 0; i < 360; i += 30) {
      final angle = (i - 90) * math.pi / 180;
      final pos = Offset(
        center.dx + math.cos(angle) * (radius - 20),
        center.dy + math.sin(angle) * (radius - 20),
      );
      
      final path = Path();
      path.moveTo(pos.dx, pos.dy - 4);
      path.lineTo(pos.dx + 3, pos.dy);
      path.lineTo(pos.dx, pos.dy + 4);
      path.lineTo(pos.dx - 3, pos.dy);
      path.close();
      
      canvas.drawPath(path, diamondPaint);
    }

    // Yön harfleri - lüks altın
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: i == 0 ? const Color(0xFFFF4444) : const Color(0xFFFFD700),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 55) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 55) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dijital Pusula Painter - Siber/Matrix tarzı
class _DijitalCompassPainter extends CustomPainter {
  final List<String> directions;
  
  _DijitalCompassPainter({required this.directions});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Arka plan - koyu
    final bgPaint = Paint()..color = const Color(0xFF0D0D0D);
    canvas.drawCircle(center, radius - 2, bgPaint);

    // Neon yeşil çerçeve
    final ringPaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 4, ringPaint);

    // İç çerçeve
    final innerRing = Paint()
      ..color = const Color(0xFF00FF00).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 30, innerRing);
    canvas.drawCircle(center, radius - 60, innerRing);

    // Dijital tickler
    final tickPaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    for (int i = 0; i < 360; i += 10) {
      final angle = (i - 90) * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 15.0 : 8.0;
      final color = isMajor 
          ? const Color(0xFF00FF00) 
          : const Color(0xFF00FF00).withOpacity(0.5);
      
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 8),
        center.dy + math.sin(angle) * (radius - 8),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 8 - tickLength),
        center.dy + math.sin(angle) * (radius - 8 - tickLength),
      );
      canvas.drawLine(inner, outer, tickPaint..color = color);
    }

    // Derece numaraları - dijital font stil
    for (int i = 0; i < 360; i += 30) {
      final angle = (i - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: i.toString().padLeft(3, '0'),
          style: const TextStyle(
            color: Color(0xFF00FF00),
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 35) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 35) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }

    // Yön harfleri - neon
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: i == 0 ? const Color(0xFFFF0040) : const Color(0xFF00FF00),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            shadows: [
              Shadow(
                color: (i == 0 ? const Color(0xFFFF0040) : const Color(0xFF00FF00))
                    .withOpacity(0.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx + math.cos(angle) * (radius - 60) - textPainter.width / 2,
        center.dy + math.sin(angle) * (radius - 60) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }

    // Merkez crosshair
    final crossPaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy + 10),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
