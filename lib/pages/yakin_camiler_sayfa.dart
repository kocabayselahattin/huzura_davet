import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class YakinCamilerSayfa extends StatefulWidget {
  const YakinCamilerSayfa({super.key});

  @override
  State<YakinCamilerSayfa> createState() => _YakinCamilerSayfaState();
}

class _YakinCamilerSayfaState extends State<YakinCamilerSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  List<Map<String, dynamic>> _camiler = [];
  bool _yukleniyor = true;
  String? _hata;
  VoidCallback? _hataAksiyon;
  String? _hataAksiyonLabel;
  Position? _konum;

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
    _camileriYukle();
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _camileriYukle() async {
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
            _hata = _languageService['location_permission_denied_msg'] ?? 'Konum izni reddedildi';
            _hataAksiyon = Geolocator.openAppSettings;
            _hataAksiyonLabel = _languageService['go_to_settings'] ?? 'Ayarlara Git';
            _yukleniyor = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _hata = _languageService['location_permission_denied_forever'] ?? 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.';
          _hataAksiyon = Geolocator.openAppSettings;
          _hataAksiyonLabel = _languageService['go_to_settings'] ?? 'Ayarlara Git';
          _yukleniyor = false;
        });
        return;
      }

      // Konum servisinin açık olup olmadığını kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _hata = _languageService['location_service_disabled'] ?? 'Konum servisi kapalı. Lütfen açın.';
          _hataAksiyon = Geolocator.openLocationSettings;
          _hataAksiyonLabel = _languageService['location_settings'] ?? 'Konum Ayarları';
          _yukleniyor = false;
        });
        return;
      }

      Position? position;
      
      // Önce son bilinen konumu al (hızlı başlangıç için)
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      
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
                content: Text(_languageService['last_known_location_used'] ?? 'Canlı konum alınamadı, son bilinen konum kullanıldı.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            _hata = '${_languageService['could_not_get_location'] ?? 'Konum alınamadı. Lütfen GPS\'i açık alanda tekrar deneyin.'}\n${_languageService['error'] ?? 'Hata'}: $e';
            _hataAksiyon = _camileriYukle;
            _hataAksiyonLabel = _languageService['try_again'] ?? 'Tekrar Dene';
            _yukleniyor = false;
          });
          return;
        }
      }

      if (position == null) {
        setState(() {
          _hata = _languageService['location_not_available'] ?? 'Konum bilgisi alınamadı.';
          _hataAksiyon = _camileriYukle;
          _hataAksiyonLabel = _languageService['try_again'] ?? 'Tekrar Dene';
          _yukleniyor = false;
        });
        return;
      }

      setState(() {
        _konum = position;
      });

      // Overpass API ile yakındaki camileri bul
      await _yakinCamileriAra(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _hata = '${_languageService['could_not_get_location'] ?? 'Konum alınamadı'}: $e';
        _hataAksiyon = _camileriYukle;
        _hataAksiyonLabel = _languageService['try_again'] ?? 'Tekrar Dene';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _yakinCamileriAra(double enlem, double boylam) async {
    try {
      // Overpass API sorgusu (5km yarıçapında camiler)
      final query = '''
        [out:json][timeout:25];
        (
          node["amenity"="place_of_worship"]["religion"="muslim"](around:2000,$enlem,$boylam);
          way["amenity"="place_of_worship"]["religion"="muslim"](around:2000,$enlem,$boylam);
          relation["amenity"="place_of_worship"]["religion"="muslim"](around:2000,$enlem,$boylam);
        );
        out center;
      ''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        final List<Map<String, dynamic>> camiler = [];
        for (final element in elements) {
          double? lat;
          double? lon;
          Map<String, dynamic>? tags;
          
          if (element['type'] == 'node') {
            lat = element['lat'] as double?;
            lon = element['lon'] as double?;
            tags = element['tags'] as Map<String, dynamic>?;
          } else if (element['type'] == 'way' || element['type'] == 'relation') {
            // Way ve relation için merkez koordinatlarını kullan
            final center = element['center'] as Map<String, dynamic>?;
            if (center != null) {
              lat = center['lat'] as double?;
              lon = center['lon'] as double?;
            }
            tags = element['tags'] as Map<String, dynamic>?;
          }

          if (lat != null && lon != null && tags != null && tags['name'] != null) {
            final mesafe = Geolocator.distanceBetween(
              enlem,
              boylam,
              lat,
              lon,
            );

            camiler.add({
              'ad': tags['name'] ?? 'İsimsiz Cami',
              'enlem': lat,
              'boylam': lon,
              'mesafe': mesafe,
              'adres': tags['addr:street'] ?? tags['addr:full'] ?? '',
            });
          }
        }

        // Mesafeye göre sırala (en yakından en uzağa)
        camiler.sort((a, b) => (a['mesafe'] as double).compareTo(b['mesafe'] as double));

        print('✅ ${camiler.length} cami bulundu, en yakın: ${camiler.isNotEmpty ? camiler[0]['ad'] : 'yok'} (${camiler.isNotEmpty ? (camiler[0]['mesafe'] as double).round() : 0}m)');

        setState(() {
          _camiler = camiler;
          _yukleniyor = false;
        });
      } else {
        setState(() {
          _hata = 'Camiler yüklenemedi';
          _yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        _hata = 'Camiler aranırken hata oluştu: $e';
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _languageService['nearby_mosques_title'] ?? 'Yakındaki Camiler',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _camileriYukle,
            tooltip: _languageService['try_again'] ?? 'Yenile',
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
                    _languageService['loading_mosques'] ?? 'Yakındaki camiler aranıyor...',
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
              : _camileriGoster(renkler),
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
              onPressed: _hataAksiyon ?? _camileriYukle,
              icon: const Icon(Icons.settings),
              label: Text(_hataAksiyonLabel ?? (_languageService['try_again'] ?? 'Tekrar Dene')),
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

  Widget _camileriGoster(TemaRenkleri renkler) {
    if (_camiler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mosque,
              size: 80,
              color: renkler.yaziSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _languageService['no_mosque_nearby'] ?? 'Yakınınızda cami bulunamadı',
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '5 km ${_languageService['searching_within'] ?? 'yarıçapında arama yapılıyor'}',
              style: TextStyle(
                color: renkler.yaziSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            if (_konum != null) ...[
              const SizedBox(height: 24),
              Text(
                '${_languageService['location'] ?? 'Konum'}: ${_konum!.latitude.toStringAsFixed(6)}, ${_konum!.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  color: renkler.yaziSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Bilgi banner
        if (_konum != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: renkler.ayirac.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: renkler.vurgu, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _languageService['your_location'] ?? 'Mevcut Konumunuz',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_camiler.length} ${_languageService['mosques_found'] ?? 'cami bulundu'} (5 km ${_languageService['within_km'] ?? 'içinde'})',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_languageService['latitude'] ?? 'Enlem'}: ${_konum!.latitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${_languageService['longitude'] ?? 'Boylam'}: ${_konum!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Cami listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _camiler.length,
            itemBuilder: (context, index) {
              return _camiKarti(_camiler[index], renkler);
            },
          ),
        ),
      ],
    );
  }

  Widget _camiKarti(Map<String, dynamic> cami, TemaRenkleri renkler) {
    final mesafe = (cami['mesafe'] as double) / 1000; // Km'ye çevir
    final mesafeText = mesafe < 1
        ? '${(mesafe * 1000).toInt()} m'
        : '${mesafe.toStringAsFixed(1)} km';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: renkler.ayirac.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: renkler.vurgu.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.mosque,
            color: renkler.vurgu,
            size: 28,
          ),
        ),
        title: Text(
          cami['ad'],
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.near_me,
                  size: 14,
                  color: renkler.yaziSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  mesafeText,
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (cami['adres'].isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                cami['adres'],
                style: TextStyle(
                  color: renkler.yaziSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.directions,
            color: renkler.vurgu,
            size: 28,
          ),
          onPressed: () {
            _yolTarifiAl(cami);
          },
        ),
      ),
    );
  }

  void _yolTarifiAl(Map<String, dynamic> cami) {
    if (_konum == null) return;

    final renkler = _temaService.renkler;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: renkler.kartArkaPlan,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cami['ad'],
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _languageService['google_maps_directions'] ?? 'Google Maps üzerinden yol tarifi almak ister misiniz?',
                style: TextStyle(color: renkler.yaziSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: renkler.yaziSecondary,
                        side: BorderSide(color: renkler.ayirac),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(_languageService['give_up'] ?? 'Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _openGoogleMaps(cami);
                      },
                      icon: const Icon(Icons.map),
                      label: Text(_languageService['google_maps'] ?? 'Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: renkler.vurgu,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGoogleMaps(Map<String, dynamic> cami) async {
    final lat = cami['enlem'] as double;
    final lon = cami['boylam'] as double;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking',
    );

    final launched = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService['google_maps_could_not_open'] ?? 'Google Maps açılamadı.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}
