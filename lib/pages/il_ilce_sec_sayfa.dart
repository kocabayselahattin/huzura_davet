import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/home_widget_service.dart';
import '../services/language_service.dart';
import '../data/il_ilce_data.dart';
import '../models/konum_model.dart';

class IlIlceSecSayfa extends StatefulWidget {
  final bool ilkKurulum;
  final bool otomatikKonumTespit;

  const IlIlceSecSayfa({
    super.key,
    this.ilkKurulum = false,
    this.otomatikKonumTespit = false,
  });

  @override
  State<IlIlceSecSayfa> createState() => _IlIlceSecSayfaState();
}

class _IlIlceSecSayfaState extends State<IlIlceSecSayfa> {
  final LanguageService _languageService = LanguageService();
  List<Map<String, dynamic>> iller = [];
  List<Map<String, dynamic>> filtrelenmisIller = [];
  List<Map<String, dynamic>> ilceler = [];
  List<Map<String, dynamic>> filtrelenmisIlceler = [];

  String? secilenIlAdi;
  String? secilenIlId;
  String? secilenIlceAdi;
  String? secilenIlceId;
  bool yukleniyor = false;
  bool konumTespit = false;
  bool _manuelAraniyor = false;

  /// "Tamam"a basıldıktan sonra kayıt/widget güncellemesi sürerken true olur;
  /// düğme dönen göstergeye çevrilir ve tekrar basılamaz.
  bool _kaydediliyor = false;
  double? _manuelLat;
  double? _manuelLon;
  String? _manuelCity;
  String? _manuelCountry;

  // ScrollController for district list
  final ScrollController _ilceScrollController = ScrollController();

  // Country selection
  String secilenUlkeKodu = 'TR';
  final List<Map<String, String>> ulkeler = [
    {'kod': 'TR', 'emoji': '🇹🇷', 'adKey': 'country_turkey'},
    {'kod': 'DE', 'emoji': '🇩🇪', 'adKey': 'country_germany'},
    {'kod': 'NL', 'emoji': '🇳🇱', 'adKey': 'country_netherlands'},
    {'kod': 'BE', 'emoji': '🇧🇪', 'adKey': 'country_belgium'},
    {'kod': 'FR', 'emoji': '🇫🇷', 'adKey': 'country_france'},
    {'kod': 'GB', 'emoji': '🇬🇧', 'adKey': 'country_uk'},
    {'kod': 'AT', 'emoji': '🇦🇹', 'adKey': 'country_austria'},
    {'kod': 'SA', 'emoji': '🇸🇦', 'adKey': 'country_saudi_arabia'},
    {'kod': 'AE', 'emoji': '🇦🇪', 'adKey': 'country_uae'},
    {'kod': 'QA', 'emoji': '🇶🇦', 'adKey': 'country_qatar'},
    {'kod': 'KW', 'emoji': '🇰🇼', 'adKey': 'country_kuwait'},
    {'kod': 'US', 'emoji': '🇺🇸', 'adKey': 'country_usa'},
    {'kod': 'CA', 'emoji': '🇨🇦', 'adKey': 'country_canada'},
  ];

  final TextEditingController _ilAramaController = TextEditingController();
  final TextEditingController _ilceAramaController = TextEditingController();

  String _ulkeAdi(String kod) {
    final ulke = ulkeler.firstWhere(
      (u) => u['kod'] == kod,
      orElse: () => <String, String>{},
    );
    final adKey = ulke['adKey'] ?? '';
    if (adKey.isEmpty) return '';
    return _languageService[adKey] ?? '';
  }

  String _ulkeGorunenAd(String kod) {
    final ulke = ulkeler.firstWhere(
      (u) => u['kod'] == kod,
      orElse: () => <String, String>{},
    );
    final emoji = ulke['emoji'] ?? '';
    final ad = _ulkeAdi(kod);
    if (emoji.isEmpty) return ad;
    if (ad.isEmpty) return emoji;
    return '$emoji $ad';
  }

  String _manuelKonumKey(String city, String countryCode) {
    final normalizedCity = city.trim();
    return 'manual:$countryCode:$normalizedCity';
  }

  @override
  void initState() {
    super.initState();
    _illeriYukle();
    if (widget.ilkKurulum && widget.otomatikKonumTespit) {
      _konumuTespitEt();
    }
  }

  @override
  void dispose() {
    _ilAramaController.dispose();
    _ilceAramaController.dispose();
    _ilceScrollController.dispose();
    super.dispose();
  }

  Future<void> _illeriYukle() async {
    // Yerel veriyi anında göster ki liste API cevabını beklerken (yavaş
    // ağda 10 sn'ye kadar sürebiliyor) boş görünmesin. API başarılı
    // olursa liste sessizce güncel veriyle değiştirilir.
    setState(() {
      iller = IlIlceData.getIller();
      filtrelenmisIller = _ilAramaController.text.trim().isEmpty
          ? iller
          : iller.where((il) {
              final sehirAdi = (il['SehirAdi'] ?? '').toString().toLowerCase();
              return sehirAdi.contains(_ilAramaController.text.trim().toLowerCase());
            }).toList();
      yukleniyor = true;
    });
    print('✅ ${iller.length} cities loaded from local data (instant)');

    try {
      final illerData = await DiyanetApiService.getIller();
      if (illerData.isNotEmpty && mounted) {
        setState(() {
          iller = illerData;
          filtrelenmisIller = _ilAramaController.text.trim().isEmpty
              ? iller
              : iller.where((il) {
                  final sehirAdi = (il['SehirAdi'] ?? '').toString().toLowerCase();
                  return sehirAdi.contains(
                    _ilAramaController.text.trim().toLowerCase(),
                  );
                }).toList();
        });
        print('✅ ${iller.length} cities loaded from API (refreshed)');
      }
    } catch (e) {
      print('⚠️ City API load failed, keeping local data: $e');
    } finally {
      if (mounted) {
        setState(() {
          yukleniyor = false;
        });
      }
    }
  }

  Future<void> _ilceleriYukle(String ilId) async {
    // Yerel veriyi anında göster ki liste API cevabını beklerken boş
    // görünmesin; API başarılı olursa güncel veriyle sessizce değiştirilir.
    setState(() {
      ilceler = IlIlceData.getIlceler(ilId);
      filtrelenmisIlceler = ilceler;
      _ilceAramaController.clear();
      yukleniyor = true;
    });
    print('✅ ${ilceler.length} districts loaded from local data (instant)');

    try {
      final ilcelerData = await DiyanetApiService.getIlceler(ilId);
      if (ilcelerData.isNotEmpty && mounted) {
        setState(() {
          ilceler = ilcelerData;
          filtrelenmisIlceler = ilceler;
        });
        print('✅ ${ilceler.length} districts loaded from API (refreshed)');
      }
    } catch (e) {
      print('⚠️ District API load failed, keeping local data: $e');
    } finally {
      if (mounted) {
        setState(() {
          yukleniyor = false;
        });
      }
    }
  }

  void _ilAra(String aranan) {
    setState(() {
      if (aranan.isEmpty) {
        filtrelenmisIller = iller;
      } else {
        filtrelenmisIller = iller.where((il) {
          final sehirAdi = (il['SehirAdi'] ?? il['IlceAdi'] ?? '')
              .toString()
              .toLowerCase();
          return sehirAdi.contains(aranan.toLowerCase());
        }).toList();
      }
    });
  }

  void _ilceAra(String aranan) {
    setState(() {
      if (aranan.isEmpty) {
        filtrelenmisIlceler = ilceler;
      } else {
        filtrelenmisIlceler = ilceler.where((ilce) {
          final ilceAdi = (ilce['IlceAdi'] ?? '').toString().toLowerCase();
          return ilceAdi.contains(aranan.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _manuelKonumBul() async {
    final cityInput = _ilAramaController.text.trim();
    if (cityInput.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _languageService['search_city'] ?? 'Please enter a city name.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _manuelAraniyor = true;
      _manuelLat = null;
      _manuelLon = null;
      _manuelCity = null;
      _manuelCountry = null;
      secilenIlId = null;
      secilenIlceId = null;
    });

    try {
      final countryCode = secilenUlkeKodu.toLowerCase();
      final encodedQuery = Uri.encodeComponent(cityInput);
      final url =
          'https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&limit=1&q=$encodedQuery&countrycodes=$countryCode&accept-language=en';

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'HuzurVakti/2.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final item = decoded.first as Map<String, dynamic>;
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          final address = item['address'] as Map<String, dynamic>?;
          final city =
              address?['city'] ??
              address?['town'] ??
              address?['state'] ??
              cityInput;
          final country = address?['country'] ?? _ulkeAdi(secilenUlkeKodu);

          if (lat != null && lon != null) {
            final manualKey = _manuelKonumKey(city.toString(), secilenUlkeKodu);
            setState(() {
              _manuelLat = lat;
              _manuelLon = lon;
              _manuelCity = city.toString();
              _manuelCountry = country.toString();
              secilenIlAdi = _manuelCity;
              secilenIlId = 'manual:$secilenUlkeKodu';
              secilenIlceAdi = _manuelCountry;
              secilenIlceId = manualKey;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _languageService['location_saved_updating'] ??
                        'Location found. You can save now.',
                  ),
                ),
              );
            }
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _languageService['city_not_found'] ?? 'City not found',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _languageService['location_unavailable_enable_gps'] ??
                  'Location search failed. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _manuelAraniyor = false;
        });
      }
    }
  }

  // City/country info from IP API
  String? _ipCity;
  String? _ipCountry;
  String? _ipCountryCode;

  // Reverse geocoding info
  String? _geoCity;
  String? _geoDistrict;
  String? _geoCountryCode;

  Future<void> _konumuTespitEt() async {
    setState(() {
      konumTespit = true;
    });

    try {
      Position? position;

      // PRIORITY 1: Get location via GPS
      print('📍 Getting location via GPS...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15),
            );
            print('📍 GPS success: ${position.latitude}, ${position.longitude}');

            // Get city/district info from GPS coordinates (reverse geocoding)
            await _reverseGeocode(position.latitude, position.longitude);
          } catch (e) {
            print('⚠️ GPS failed: $e');
          }
        }
      }

      // PRIORITY 2: If GPS fails, try IP-based location
      if (position == null) {
        print('🌐 Trying IP-based location...');
        final ipResult = await _getIpBasedLocationWithCity();

        if (ipResult != null) {
          position = ipResult['position'] as Position?;
          _ipCity = ipResult['city'] as String?;
          _ipCountry = ipResult['country'] as String?;
          _ipCountryCode = ipResult['countryCode'] as String?;

          print('🌐 IP location: $_ipCity, $_ipCountry ($_ipCountryCode)');
        }
      }

      // Determine country code (GPS reverse geocoding first, then IP)
      final countryCode = _geoCountryCode ?? _ipCountryCode;

      // Set language by country
      if (countryCode != null) {
        await _setLanguageByCountry(countryCode);
      }

      if (position == null) {
        _konumHatasi(
          _languageService['location_unavailable_enable_gps'] ??
              'Location unavailable. Please enable GPS or choose manually.',
        );
        return;
      }

      print('📍 Location acquired: ${position.latitude}, ${position.longitude}');

      // For Turkey
      if (countryCode == 'TR' || countryCode == null) {
        await _turkiyeKonumBul(position);
      } else {
        // For other countries
        await _digerUlkeKonumBul(position);
      }
    } catch (e) {
      print('❌ Location detection error: $e');
      final errorDetails = e.toString().substring(
        0,
        e.toString().length > 50 ? 50 : e.toString().length,
      );
      _konumHatasi(
        (_languageService['location_error_detail'] ??
                'Location error: {error}')
            .replaceAll('{error}', '$errorDetails...'),
      );
    }
  }

  /// Get city/district info from coordinates (Nominatim reverse geocoding)
  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final languageCode = _languageService.currentLanguage;
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1&accept-language=$languageCode';

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'HuzurVakti/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
            // District info (try town, county, district, suburb in order)
          _geoDistrict =
              address['town'] ??
              address['county'] ??
              address['district'] ??
              address['suburb'] ??
              address['city_district'];

            // City info (try province, state, city in order)
          _geoCity = address['province'] ?? address['state'] ?? address['city'];

            // Country code
          _geoCountryCode = address['country_code']?.toString().toUpperCase();

          print(
            '🗺️ Reverse Geocoding: $_geoCity / $_geoDistrict ($_geoCountryCode)',
          );
        }
      }
    } catch (e) {
      print('⚠️ Reverse geocoding error: $e');
    }
  }

  /// Find city/district for Turkey
  Future<void> _turkiyeKonumBul(Position position) async {
    // Load city list first (if not loaded)
    if (iller.isEmpty) {
      await _illeriYukle();
    }

    // Find nearest city by coordinates
    Map<String, dynamic>? enYakinIl;

    // PRIORITY 1: City from GPS reverse geocoding
    if (_geoCity != null && _geoCity!.isNotEmpty) {
      final aramaSehir = _geoCity!
          .toUpperCase()
          .replaceAll('İ', 'I')
          .replaceAll('Ş', 'S')
          .replaceAll('Ğ', 'G')
          .replaceAll('Ü', 'U')
          .replaceAll('Ö', 'O')
          .replaceAll('Ç', 'C')
          .replaceAll(' PROVINCE', '')
          .replaceAll(' İLİ', '')
          .replaceAll(' IL', '')
          .trim();

      try {
        enYakinIl = iller.firstWhere((il) {
          final sehirAdi = (il['SehirAdi'] ?? il['IlceAdi'] ?? '')
              .toString()
              .toUpperCase()
              .replaceAll('İ', 'I')
              .replaceAll('Ş', 'S')
              .replaceAll('Ğ', 'G')
              .replaceAll('Ü', 'U')
              .replaceAll('Ö', 'O')
              .replaceAll('Ç', 'C');
          return sehirAdi.contains(aramaSehir) || aramaSehir.contains(sehirAdi);
        });
        print('🏙️ GPS reverse geocoding matched city: $_geoCity');
      } catch (_) {
        print('⚠️ GPS reverse geocoding did not match city: $_geoCity');
      }
    }

    // PRIORITY 2: City from IP
    if (enYakinIl == null && _ipCity != null && _ipCity!.isNotEmpty) {
      final aramaSehir = _ipCity!
          .toUpperCase()
          .replaceAll('İ', 'I')
          .replaceAll('Ş', 'S')
          .replaceAll('Ğ', 'G')
          .replaceAll('Ü', 'U')
          .replaceAll('Ö', 'O')
          .replaceAll('Ç', 'C');

      try {
        enYakinIl = iller.firstWhere((il) {
          final sehirAdi = (il['SehirAdi'] ?? il['IlceAdi'] ?? '')
              .toString()
              .toUpperCase()
              .replaceAll('İ', 'I')
              .replaceAll('Ş', 'S')
              .replaceAll('Ğ', 'G')
              .replaceAll('Ü', 'U')
              .replaceAll('Ö', 'O')
              .replaceAll('Ç', 'C');
          return sehirAdi.contains(aramaSehir) || aramaSehir.contains(sehirAdi);
        });
        print('🏙️ IP city matched: $_ipCity');
      } catch (_) {
        print('⚠️ IP city did not match: $_ipCity');
      }
    }

    // PRIORITY 3: Find nearest city from coordinates
    enYakinIl ??= _enYakinIliBul(position.latitude, position.longitude);

    if (enYakinIl != null && enYakinIl.isNotEmpty) {
      final ilId =
          enYakinIl['SehirID']?.toString() ??
          enYakinIl['IlceID']?.toString() ??
          '';
      final ilAdi = enYakinIl['SehirAdi'] ?? enYakinIl['IlceAdi'] ?? '';

      print('🏙️ Nearest city found: $ilAdi (ID: $ilId)');

      setState(() {
        secilenIlId = ilId;
        secilenIlAdi = ilAdi;
      });

      await _ilceleriYukle(ilId);

      // Find the best matching district
      await _enUygunIlceyiBul(ilAdi);
    } else {
      _konumHatasi(
        _languageService['location_not_found_manual'] ??
            'Location could not be determined. Please choose manually.',
      );
    }
  }

  /// Find location for other countries
  Future<void> _digerUlkeKonumBul(Position position) async {
    // Use city info from IP directly
    if (_ipCity != null && _ipCity!.isNotEmpty) {
      // Load city list first
      if (iller.isEmpty) {
        await _illeriYukle();
      }

      // Find city in the list
      Map<String, dynamic>? bulunanIl;
      final aramaSehir = _ipCity!.toUpperCase();

      try {
        bulunanIl = iller.firstWhere((il) {
          final sehirAdi = (il['SehirAdi'] ?? il['IlceAdi'] ?? '')
              .toString()
              .toUpperCase();
          return sehirAdi.contains(aramaSehir) || aramaSehir.contains(sehirAdi);
        });
      } catch (_) {
        // Not found - try by coordinates
        bulunanIl = _enYakinIliBul(position.latitude, position.longitude);
      }

      if (bulunanIl != null) {
        final ilId =
            bulunanIl['SehirID']?.toString() ??
            bulunanIl['IlceID']?.toString() ??
            '';
        final ilAdi = bulunanIl['SehirAdi'] ?? bulunanIl['IlceAdi'] ?? '';

        setState(() {
          secilenIlId = ilId;
          secilenIlAdi = ilAdi;
        });

        await _ilceleriYukle(ilId);
        await _enUygunIlceyiBul(ilAdi);
      } else {
        // City not found for other country - inform user
        setState(() {
          konumTespit = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (_languageService['location_from_ip_prompt'] ??
                        'Your location: {city}, {country}. Please select a city from the list.')
                    .replaceAll('{city}', _ipCity ?? '')
                    .replaceAll('{country}', _ipCountry ?? ''),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      _konumHatasi(
        _languageService['city_info_unavailable'] ??
            'City information could not be retrieved. Please choose manually.',
      );
    }
  }

  /// Find and select the best matching district
  Future<void> _enUygunIlceyiBul(String ilAdi) async {
    if (ilceler.isEmpty) {
      setState(() {
        konumTespit = false;
      });
      return;
    }

    Map<String, dynamic>? secilenIlce;

    // PRIORITY 1: District from GPS reverse geocoding
    if (_geoDistrict != null && _geoDistrict!.isNotEmpty) {
      final aramaIlce = _geoDistrict!
          .toUpperCase()
          .replaceAll('İ', 'I')
          .replaceAll('Ş', 'S')
          .replaceAll('Ğ', 'G')
          .replaceAll('Ü', 'U')
          .replaceAll('Ö', 'O')
          .replaceAll('Ç', 'C')
          .replaceAll(' İLÇESİ', '')
          .replaceAll(' ILCESI', '')
          .trim();

      try {
        secilenIlce = ilceler.firstWhere((ilce) {
          final ilceAdi = (ilce['IlceAdi'] ?? '')
              .toString()
              .toUpperCase()
              .replaceAll('İ', 'I')
              .replaceAll('Ş', 'S')
              .replaceAll('Ğ', 'G')
              .replaceAll('Ü', 'U')
              .replaceAll('Ö', 'O')
              .replaceAll('Ç', 'C');
          return ilceAdi == aramaIlce ||
              ilceAdi.contains(aramaIlce) ||
              aramaIlce.contains(ilceAdi);
        });
        print('🏘️ GPS reverse geocoding matched district: $_geoDistrict');
      } catch (_) {
        print('⚠️ GPS reverse geocoding did not match district: $_geoDistrict');
        secilenIlce = null;
      }
    }

    // PRIORITY 2: Look for the "MERKEZ" district
    if (secilenIlce == null) {
      try {
        secilenIlce = ilceler.firstWhere((ilce) {
          final ilceAdi = (ilce['IlceAdi'] ?? '').toString().toUpperCase();
          return ilceAdi == 'MERKEZ';
        });
        print('🏘️ MERKEZ district found');
      } catch (_) {
        secilenIlce = null;
      }
    }

    // PRIORITY 3: Find district containing the city name
    if (secilenIlce == null) {
      final aramaIlAdi = ilAdi
          .toUpperCase()
          .replaceAll('İ', 'I')
          .replaceAll('Ş', 'S')
          .replaceAll('Ğ', 'G')
          .replaceAll('Ü', 'U')
          .replaceAll('Ö', 'O')
          .replaceAll('Ç', 'C');

      try {
        secilenIlce = ilceler.firstWhere((ilce) {
          final ilceAdi = (ilce['IlceAdi'] ?? '')
              .toString()
              .toUpperCase()
              .replaceAll('İ', 'I')
              .replaceAll('Ş', 'S')
              .replaceAll('Ğ', 'G')
              .replaceAll('Ü', 'U')
              .replaceAll('Ö', 'O')
              .replaceAll('Ç', 'C');
          return ilceAdi.contains(aramaIlAdi) || aramaIlAdi.contains(ilceAdi);
        });
        print('🏘️ District matched city name');
      } catch (_) {
        secilenIlce = null;
      }
    }

    // PRIORITY 4: Find district containing IP city name
    if (secilenIlce == null && _ipCity != null) {
      final aramaCity = _ipCity!
          .toUpperCase()
          .replaceAll('İ', 'I')
          .replaceAll('Ş', 'S')
          .replaceAll('Ğ', 'G')
          .replaceAll('Ü', 'U')
          .replaceAll('Ö', 'O')
          .replaceAll('Ç', 'C');

      try {
        secilenIlce = ilceler.firstWhere((ilce) {
          final ilceAdi = (ilce['IlceAdi'] ?? '')
              .toString()
              .toUpperCase()
              .replaceAll('İ', 'I')
              .replaceAll('Ş', 'S')
              .replaceAll('Ğ', 'G')
              .replaceAll('Ü', 'U')
              .replaceAll('Ö', 'O')
              .replaceAll('Ç', 'C');
          return ilceAdi.contains(aramaCity) || aramaCity.contains(ilceAdi);
        });
        print('🏘️ IP city matched district: $_ipCity');
      } catch (_) {
        secilenIlce = null;
      }
    }

    // PRIORITY 5: If still not found, select the first district
    if (secilenIlce == null && ilceler.isNotEmpty) {
      secilenIlce = ilceler.first;
      print('🏘️ Default first district selected');
    }

    if (secilenIlce != null) {
      final ilceId = secilenIlce['IlceID']?.toString();
      final ilceAdi = secilenIlce['IlceAdi']?.toString();

      setState(() {
        secilenIlceId = ilceId;
        secilenIlceAdi = ilceAdi;
        konumTespit = false;
      });

      print('🏘️ District selected: $secilenIlceAdi (ID: $secilenIlceId)');

      // Find district in list and scroll
      _scrollToSelectedIlce();
    } else {
      setState(() {
        konumTespit = false;
      });
    }
  }

  /// Scroll to the selected district
  void _scrollToSelectedIlce() {
    if (secilenIlceId == null || filtrelenmisIlceler.isEmpty) return;

    // Find the district index
    final index = filtrelenmisIlceler.indexWhere(
      (ilce) => ilce['IlceID']?.toString() == secilenIlceId,
    );

    if (index != -1) {
      // Delay scroll slightly to allow ListView to build
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_ilceScrollController.hasClients) {
          // Each item is roughly 56px high
          final scrollOffset = (index * 56.0).clamp(
            0.0,
            _ilceScrollController.position.maxScrollExtent,
          );

          _ilceScrollController.animateTo(
            scrollOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  // IP-based location detection with city and country info
  Future<Map<String, dynamic>?> _getIpBasedLocationWithCity() async {
    try {
      // Use ip-api.com free API for IP-based location
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=status,lat,lon,city,country,countryCode,regionName',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          final lat = data['lat'] as double;
          final lon = data['lon'] as double;
          final city = data['city'] as String?;
          final regionName = data['regionName'] as String?;
          final country = data['country'] as String?;
          final countryCode = data['countryCode'] as String?;

          print(
            '🌐 IP location: $city ($regionName), $country ($countryCode) - $lat, $lon',
          );

          return {
            'position': Position(
              latitude: lat,
              longitude: lon,
              timestamp: DateTime.now(),
              accuracy: 5000,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
            'city': city ?? regionName,
            'country': country,
            'countryCode': countryCode,
          };
        }
      }
    } catch (e) {
      print('⚠️ IP-API error: $e');
    }

    // Try alternative API
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final lat = (data['latitude'] as num).toDouble();
          final lon = (data['longitude'] as num).toDouble();
          final city = data['city'] as String?;
          final region = data['region'] as String?;
          final country = data['country'] as String?;
          final countryCode = data['country_code'] as String?;

          print(
            '🌐 IP location (alt): $city ($region), $country ($countryCode) - $lat, $lon',
          );

          return {
            'position': Position(
              latitude: lat,
              longitude: lon,
              timestamp: DateTime.now(),
              accuracy: 5000,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
            'city': city ?? region,
            'country': country,
            'countryCode': countryCode,
          };
        }
      }
    } catch (e) {
      print('⚠️ Alternative IP error: $e');
    }

    return null;
  }

  /// Set app language by country code
  Future<void> _setLanguageByCountry(String countryCode) async {
    // Country code -> language code mapping
    final countryToLanguage = {
      // Turkish
      'TR': 'tr',
      // English
      'GB': 'en', 'US': 'en', 'AU': 'en', 'CA': 'en', 'NZ': 'en', 'IE': 'en',
      // German
      'DE': 'de', 'AT': 'de', 'CH': 'de', 'LI': 'de',
      // French
      'FR': 'fr', 'BE': 'fr', 'LU': 'fr', 'MC': 'fr',
      // Arabic
      'SA': 'ar', 'AE': 'ar', 'EG': 'ar', 'IQ': 'ar', 'JO': 'ar', 'KW': 'ar',
      'LB': 'ar', 'LY': 'ar', 'MA': 'ar', 'OM': 'ar', 'QA': 'ar', 'SY': 'ar',
      'TN': 'ar', 'YE': 'ar', 'BH': 'ar', 'DZ': 'ar', 'PS': 'ar', 'SD': 'ar',
      // Persian
      'IR': 'fa', 'AF': 'fa', 'TJ': 'fa',
    };

    final languageCode = countryToLanguage[countryCode.toUpperCase()] ?? 'en';
    final currentLang = _languageService.currentLanguage;

    // Change only on first setup or if language is not set yet
    if (widget.ilkKurulum && currentLang != languageCode) {
      print('🌍 Country: $countryCode -> Language: $languageCode');
      await _languageService.changeLanguage(languageCode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (_languageService['language_set_for_country'] ??
                        'App language set to {language} for {country}')
                  .replaceAll('{country}', countryCode)
                  .replaceAll('{language}', languageCode),
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _konumHatasi(String mesaj) {
    setState(() {
      konumTespit = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mesaj),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Turkey city coordinates (approximate centers)
  Map<String, dynamic>? _enYakinIliBul(double lat, double lon) {
    // City coordinates (approximate)
    final ilKoordinatlari = {
      'Adana': [37.0, 35.3],
      'Adıyaman': [37.75, 38.27],
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

    double minMesafe = double.infinity;
    String? enYakinIlAdi;

    for (final entry in ilKoordinatlari.entries) {
      final ilLat = entry.value[0];
      final ilLon = entry.value[1];

      // Simple distance calculation
      final mesafe = _mesafeHesapla(lat, lon, ilLat, ilLon);

      if (mesafe < minMesafe) {
        minMesafe = mesafe;
        enYakinIlAdi = entry.key;
      }
    }

    if (enYakinIlAdi != null) {
      // Find in city data (case-insensitive)
      final aramaIlAdi = enYakinIlAdi.toUpperCase();
      try {
        return iller.firstWhere((il) {
          final sehirAdi = (il['SehirAdi'] ?? il['IlceAdi'] ?? '')
              .toString()
              .toUpperCase();
          return sehirAdi.contains(aramaIlAdi) || aramaIlAdi.contains(sehirAdi);
        });
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  double _mesafeHesapla(double lat1, double lon1, double lat2, double lon2) {
    // Simple Euclidean distance (approximate)
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return dLat * dLat + dLon * dLon;
  }

  /// Konumu kaydeden "Tamam" düğmesi.
  ///
  /// Kayıt sırasında widget güncellemesi ve vakit yenilemesi yapıldığı için
  /// birkaç saniye sürebiliyor; bu sürede düğme dönen göstergeye çevrilir ve
  /// yeniden basılamaz. Aksi hâlde ekran donmuş gibi görünüyordu.
  ///
  /// `yukleniyor` de engelleyici listeye eklendi: il/ilçe listesi önce yerel
  /// (eski format ID'li) veriyle anında gösterilip arka planda güncel API
  /// verisiyle değiştiriliyor — bu yenileme bitmeden kaydedilirse eski,
  /// geçersiz bir ilçe ID'si kaydedilip uygulama yeniden açıldığında konumun
  /// sıfırlanmasına yol açabilir.
  Widget _tamamDugmesi() {
    return ElevatedButton.icon(
      onPressed: (_kaydediliyor || yukleniyor) ? null : _kaydet,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyanAccent,
        foregroundColor: const Color(0xFF1B2741),
        disabledBackgroundColor: Colors.cyanAccent.withOpacity(0.7),
        disabledForegroundColor: const Color(0xFF1B2741),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: _kaydediliyor
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B2741)),
              ),
            )
          : const Icon(Icons.check),
      label: Text(
        _kaydediliyor
            ? (_languageService['location_saved_updating'] ?? 'Updating...')
            : (_languageService['ok'] ?? 'OK'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) return;
    if (secilenIlId != null && secilenIlceId != null) {
      setState(() => _kaydediliyor = true);
      try {
        if (KonumService.isManualIlceId(secilenIlceId)) {
          if (_manuelLat == null ||
              _manuelLon == null ||
              _manuelCity == null ||
              _manuelCountry == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _languageService['location_unavailable_enable_gps'] ??
                        'Location search failed. Try again.',
                  ),
                ),
              );
            }
            return;
          }
          await KonumService.setManualKonumData(
            key: secilenIlceId!,
            lat: _manuelLat!,
            lon: _manuelLon!,
            city: _manuelCity!,
            country: _manuelCountry!,
          );
        }
        // Create a new location model
        final yeniKonum = KonumModel(
          ilAdi: secilenIlAdi!,
          ilId: secilenIlId!,
          ilceAdi: secilenIlceAdi!,
          ilceId: secilenIlceId!,
          aktif: true,
        );

        // Add location to list (no-op if already exists)
        await KonumService.addKonum(yeniKonum);

        // Save to legacy system as well (compatibility)
        await KonumService.setIl(secilenIlAdi!, secilenIlId!);
        await KonumService.setIlce(secilenIlceAdi!, secilenIlceId!);

        // Update widgets and app data immediately
        print('🔄 Location changed, updating data...');
        await HomeWidgetService.updateAllWidgets();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService['location_saved_updating'] ??
                    'Location saved and updating...',
              ),
            ),
          );
          // Return true to trigger home page refresh
          Navigator.pop(context, true);
        }
      } finally {
        // Sayfa kapanmışsa setState çağrılmaz; kalırsa düğme yeniden basılabilir
        // hâle gelir (ör. konum verisi eksik olduğu için erken dönüldüğünde).
        if (mounted) setState(() => _kaydediliyor = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.ilkKurulum,
      child: Scaffold(
        backgroundColor: const Color(0xFF1B2741),
        appBar: AppBar(
          title: Text(
            widget.ilkKurulum
                ? _languageService['location_selection'] ?? 'Location Selection'
                : _languageService['select_city_district'] ??
                    'Select City/District',
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !widget.ilkKurulum,
          actions: [
            if (secilenIlceId != null)
              IconButton(icon: const Icon(Icons.check), onPressed: _kaydet),
          ],
        ),
        body: Column(
          children: [
            // Country selector (future support for more countries)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A3F5F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _languageService['country'] ?? 'Country:',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: secilenUlkeKodu,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: const Color(0xFF2A3F5F),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: ulkeler.map((ulke) {
                        final kod = ulke['kod'] ?? '';
                        return DropdownMenuItem<String>(
                          value: kod,
                          child: Text(_ulkeGorunenAd(kod)),
                        );
                      }).toList(),
                      onChanged: (yeniUlke) {
                        if (yeniUlke != null) {
                          setState(() {
                            secilenUlkeKodu = yeniUlke;
                            // Clear city list for non-Turkey countries
                            if (yeniUlke != 'TR') {
                              iller = [];
                              filtrelenmisIller = [];
                              ilceler = [];
                              filtrelenmisIlceler = [];
                              secilenIlAdi = null;
                              secilenIlId = null;
                              secilenIlceAdi = null;
                              secilenIlceId = null;
                            } else {
                              _illeriYukle();
                            }
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // City name input for non-Turkey countries
            if (secilenUlkeKodu != 'TR')
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3F5F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.cyanAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _languageService['city_info_title'] ??
                              'City Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _languageService['city_info_desc'] ??
                          'Detect your location via GPS or type the city name below:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ilAramaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            _languageService['city_example_hint'] ??
                          'e.g., Berlin, London, Paris...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.location_city,
                          color: Colors.white54,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1B2741),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _manuelCity = value.trim().isEmpty ? null : value.trim();
                          _manuelCountry = _ulkeAdi(secilenUlkeKodu);
                          secilenIlAdi = _manuelCity;
                          secilenIlId = null;
                          secilenIlceAdi = _manuelCountry;
                          secilenIlceId = null;
                          _manuelLat = null;
                          _manuelLon = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _manuelAraniyor ? null : _manuelKonumBul,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: const Color(0xFF1B2741),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _manuelAraniyor
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Color(0xFF1B2741),
                                  ),
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _languageService['search'] ?? 'Search',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wb_sunny, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _languageService['prayer_times_based_on_gps'] ??
                                  'Prayer times will be calculated based on your GPS coordinates.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // GPS location detection button (always shown)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  if (konumTespit)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              Colors.cyanAccent,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          _languageService['location_detecting'] ??
                              'Detecting location...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: _konumuTespitEt,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.cyanAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _languageService['auto_find_location'] ??
                                        'Auto Find Location',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _languageService['gps_detect_desc'] ??
                                        'Detect your city and district via GPS',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.cyanAccent,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // City search and selection (Turkey only)
            if (secilenUlkeKodu == 'TR')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _ilAramaController,
                  onChanged: _ilAra,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                        _languageService['search_city'] ?? 'Search city...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _ilAramaController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              _ilAramaController.clear();
                              _ilAra('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Liste anında yerel veriyle dolduruluyor; bu sadece arka planda
            // güncel API verisi çekilirken görülen ince bir bilgilendirme.
            // Liste hiçbir zaman boş kalmıyor, sadece burada tazeleniyor.
            if (yukleniyor)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.cyanAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _languageService['updating_from_internet'] ??
                          'Güncel liste internetten alınıyor...',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // City list
            if (secilenIlId == null)
              Expanded(
                child: filtrelenmisIller.isEmpty
                    ? Center(
                        child: Text(
                          _languageService['city_not_found'] ?? 'City not found',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtrelenmisIller.length,
                        itemBuilder: (context, index) {
                          final il = filtrelenmisIller[index];
                          final sehirAdi =
                              il['SehirAdi'] ?? il['IlceAdi'] ?? '';
                          final sehirId =
                              il['SehirID']?.toString() ??
                              il['IlceID']?.toString() ??
                              '';

                          return ListTile(
                            leading: const Icon(
                              Icons.location_city,
                              color: Colors.white54,
                            ),
                            title: Text(
                              sehirAdi,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white54,
                            ),
                            onTap: () {
                              setState(() {
                                secilenIlId = sehirId;
                                secilenIlAdi = sehirAdi;
                                secilenIlceId = null;
                                secilenIlceAdi = null;
                                _ilAramaController.clear();
                              });
                              _ilceleriYukle(sehirId);
                            },
                          );
                        },
                      ),
              ),

            // Selected city display and district selection (Turkey only)
            if (secilenUlkeKodu == 'TR' && secilenIlId != null) ...[
              // Selected city
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city, color: Colors.cyanAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            secilenIlAdi ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (secilenIlceAdi != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.greenAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  secilenIlceAdi!,
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '✓ ${_languageService['selected'] ?? 'Selected'}',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.cyanAccent),
                      onPressed: () {
                        setState(() {
                          secilenIlId = null;
                          secilenIlAdi = null;
                          secilenIlceId = null;
                          secilenIlceAdi = null;
                          ilceler = [];
                          filtrelenmisIlceler = [];
                        });
                      },
                      tooltip:
                          _languageService['change_city'] ?? 'Change City',
                    ),
                  ],
                ),
              ),

              // District search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _ilceAramaController,
                  onChanged: _ilceAra,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                      _languageService['search_district'] ??
                        'Search district...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _ilceAramaController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              _ilceAramaController.clear();
                              _ilceAra('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // District list
              Expanded(
                child: filtrelenmisIlceler.isEmpty
                    ? Center(
                        child: Text(
                          _languageService['district_not_found'] ??
                              'District not found',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: _ilceScrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtrelenmisIlceler.length,
                        itemBuilder: (context, index) {
                          final ilce = filtrelenmisIlceler[index];
                          final isSelected =
                              secilenIlceId == ilce['IlceID'].toString();
                          final ilceAdi = ilce['IlceAdi'] ?? '';

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.cyanAccent.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.location_on_outlined,
                                color: isSelected
                                    ? Colors.cyanAccent
                                    : Colors.white54,
                              ),
                              title: Text(
                                ilceAdi,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.cyanAccent
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.cyanAccent,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  secilenIlceId = ilce['IlceID'].toString();
                                  secilenIlceAdi = ilce['IlceAdi'];
                                });
                              },
                            ),
                          );
                        },
                      ),
              ),

              // Show OK button when a district is selected
              if (secilenIlceId != null)
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3F5F),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: _tamamDugmesi(),
                      ),
                    ),
                  ),
                ),
            ],

            if (secilenUlkeKodu != 'TR' && secilenIlceId != null)
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3F5F),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: _tamamDugmesi(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
