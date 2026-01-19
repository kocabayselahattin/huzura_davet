import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geomag/geomag.dart';
import '../services/tema_service.dart';

class KibleSayfa extends StatefulWidget {
  const KibleSayfa({super.key});

  @override
  State<KibleSayfa> createState() => _KibleSayfaState();
}

class _KibleSayfaState extends State<KibleSayfa> {
  final TemaService _temaService = TemaService();
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

  // Kabe koordinatları
  static const double kabeEnlem = 21.4225;
  static const double kabeBoylam = 39.8262;

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _startCompass();
    _konumuAl();
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _compassSub?.cancel();
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
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _pusulaDestegi = false;
        });
      },
    );
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
            _hata = 'Konum izni reddedildi';
            _hataAksiyon = Geolocator.openAppSettings;
            _hataAksiyonLabel = 'Ayarlara Git';
            _yukleniyor = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _hata = 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.';
          _hataAksiyon = Geolocator.openAppSettings;
          _hataAksiyonLabel = 'Ayarlara Git';
          _yukleniyor = false;
        });
        return;
      }

      // Konum servisinin açık olup olmadığını kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _hata = 'Konum servisi kapalı. Lütfen açın.';
          _hataAksiyon = Geolocator.openLocationSettings;
          _hataAksiyonLabel = 'Konum Ayarları';
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
              const SnackBar(
                content: Text('Canlı konum alınamadı, son bilinen konum kullanıldı.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            _hata = 'Konum alınamadı. Lütfen GPS\'i açık alanda tekrar deneyin.\nHata: $e';
            _hataAksiyon = _konumuAl;
            _hataAksiyonLabel = 'Tekrar Dene';
            _yukleniyor = false;
          });
          return;
        }
      }

      if (position == null) {
        setState(() {
          _hata = 'Konum bilgisi alınamadı.';
          _hataAksiyon = _konumuAl;
          _hataAksiyonLabel = 'Tekrar Dene';
          _yukleniyor = false;
        });
        return;
      }

      // Kıble açısını hesapla
      final kibleAcisi = _kibleHesapla(
        position.latitude,
        position.longitude,
      );

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
        _hata = 'Konum alınamadı: $e';
        _hataAksiyon = _konumuAl;
        _hataAksiyonLabel = 'Tekrar Dene';
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

    // Kıble açısını hesapla (düzeltilmiş formül)
    final dLon = lon2 - lon1;
    
    // Düzeltilmiş bearing hesaplaması
    final y = math.sin(dLon);
    final x = math.cos(lat1) * math.tan(lat2) - math.sin(lat1) * math.cos(dLon);
    
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
      final result = geoMag.calculate(
        lat,
        lon,
        altitudeFeet,
        DateTime.now(),
      );
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
          'Kıble Yönü',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _konumuAl,
            tooltip: 'Konumu yenile',
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
                    'Konum alınıyor...',
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
              style: TextStyle(
                color: renkler.yaziPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _hataAksiyon ?? _konumuAl,
              icon: const Icon(Icons.settings),
              label: Text(_hataAksiyonLabel ?? 'Tekrar Dene'),
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
      ? _normalizeAngle((heading ?? 0).toDouble() + (_declination ?? 0)).toDouble()
      : null;
    final double? relative =
      trueHeading != null ? _normalizeAngle(qibla - trueHeading) : null;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          _konumBilgisi(renkler),
          const SizedBox(height: 24),
          _modernPusula(renkler, relative, trueHeading),
          const SizedBox(height: 24),
          _kibleAcisiGoster(renkler),
          const SizedBox(height: 16),
          _bilgiNotu(renkler, hasHeading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _konumBilgisi(TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: renkler.ayirac.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: renkler.vurgu, size: 20),
              const SizedBox(width: 8),
              Text(
                'Mevcut Konum',
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
              'Enlem: ${_konum!.latitude.toStringAsFixed(4)}°',
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Boylam: ${_konum!.longitude.toStringAsFixed(4)}°',
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 14,
              ),
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
                    painter: _CompassDialPainter(),
                  ),
                ),
                // Kabe simgesi pusula üzerinde kıble açısına göre döner
                Transform.rotate(
                  angle: _toRadians(kabeAngle),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.mosque, color: Colors.brown, size: 38),
                        SizedBox(height: 4),
                        Text('Kabe', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                          children: const [
                            Icon(Icons.check_circle, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Doğru Yöndesiniz',
                              style: TextStyle(
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
                          'Pusula kalibre ediliyor',
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

  Widget _qiblaArrow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(26, 22),
          painter: _TrianglePainter(color: const Color(0xFF45D06E)),
        ),
        const SizedBox(height: 4),
        const Icon(
          Icons.mosque,
          color: Colors.black,
          size: 18,
        ),
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
          const Icon(
            Icons.mosque,
            color: Colors.black,
            size: 16,
          ),
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
    if (derece >= 337.5 || derece < 22.5) return 'N';
    if (derece >= 22.5 && derece < 67.5) return 'NE';
    if (derece >= 67.5 && derece < 112.5) return 'E';
    if (derece >= 112.5 && derece < 157.5) return 'SE';
    if (derece >= 157.5 && derece < 202.5) return 'S';
    if (derece >= 202.5 && derece < 247.5) return 'SW';
    if (derece >= 247.5 && derece < 292.5) return 'W';
    return 'NW';
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              colors: [
                Colors.greenAccent.shade200,
                Colors.green.shade600,
              ],
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
        const SizedBox(height: 12),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade500,
                Colors.green.shade800,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.6),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(
            Icons.mosque,
            color: Colors.white,
            size: 26,
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
        border: Border.all(
          color: renkler.ayirac.withValues(alpha: 0.25),
        ),
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
            alignment: Alignment(
              math.cos(angle),
              math.sin(angle),
            ),
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
        border: Border.all(
          color: renkler.ayirac.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: renkler.vurgu),
          const SizedBox(width: 6),
          Text(
            '$title: ',
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 12,
            ),
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
              'Cihazda pusula sensörü bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: renkler.yaziPrimary,
                fontSize: 16,
              ),
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
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Kıble Açısı',
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 14,
            ),
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
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pusula: $headingText',
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manyetik sapma: $declinationText',
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getYonAdi(double derece) {
    if (derece >= 337.5 || derece < 22.5) return 'Kuzey';
    if (derece >= 22.5 && derece < 67.5) return 'Kuzeydoğu';
    if (derece >= 67.5 && derece < 112.5) return 'Doğu';
    if (derece >= 112.5 && derece < 157.5) return 'Güneydoğu';
    if (derece >= 157.5 && derece < 202.5) return 'Güney';
    if (derece >= 202.5 && derece < 247.5) return 'Güneybatı';
    if (derece >= 247.5 && derece < 292.5) return 'Batı';
    return 'Kuzeybatı';
  }

  Widget _bilgiNotu(TemaRenkleri renkler, bool hasHeading) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasHeading
                  ? 'Telefonunuzu yatay tutun. Yeşil Kabe ibresi kıble yönünü gösterir. Kalibrasyon için telefonu 8 çizerek hareket ettirin.'
                  : 'Pusula verisi alınamıyor. Cihazınızın sensör desteğini kontrol edin.',
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
      final tickLength = isMajor ? 16.0 : isMedium ? 10.0 : 6.0;
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

    final directions = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: (directions[i] == 'N' || directions[i] == 'S')
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
