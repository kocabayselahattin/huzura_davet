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

  // Ülke seçimi
  String secilenUlke = '🇹🇷 Türkiye';
  final List<Map<String, String>> ulkeler = [
    {'kod': 'TR', 'ad': '🇹🇷 Türkiye'},
    {'kod': 'DE', 'ad': '🇩🇪 Almanya'},
    {'kod': 'NL', 'ad': '🇳🇱 Hollanda'},
    {'kod': 'BE', 'ad': '🇧🇪 Belçika'},
    {'kod': 'FR', 'ad': '🇫🇷 Fransa'},
    {'kod': 'GB', 'ad': '🇬🇧 İngiltere'},
    {'kod': 'AT', 'ad': '🇦🇹 Avusturya'},
    {'kod': 'SA', 'ad': '🇸🇦 Suudi Arabistan'},
    {'kod': 'AE', 'ad': '🇦🇪 BAE'},
    {'kod': 'QA', 'ad': '🇶🇦 Katar'},
    {'kod': 'KW', 'ad': '🇰🇼 Kuveyt'},
    {'kod': 'US', 'ad': '🇺🇸 ABD'},
    {'kod': 'CA', 'ad': '🇨🇦 Kanada'},
  ];

  final TextEditingController _ilAramaController = TextEditingController();
  final TextEditingController _ilceAramaController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _illeriYukle() async {
    setState(() {
      yukleniyor = true;
    });

    // Önce API'den dene (güncel ve doğru veriler için)
    try {
      final illerData = await DiyanetApiService.getIller();
      if (illerData.isNotEmpty) {
        setState(() {
          iller = illerData;
          filtrelenmisIller = iller;
          yukleniyor = false;
        });
        print('✅ ${iller.length} il API\'den yüklendi');
        return;
      }
    } catch (e) {
      print('⚠️ API\'den il yüklenemedi, yerel veriye geçiliyor: $e');
    }

    // API başarısız olursa yerel veriye fallback
    final yerelIller = IlIlceData.getIller();
    setState(() {
      iller = yerelIller;
      filtrelenmisIller = iller;
      yukleniyor = false;
    });
    print('✅ ${iller.length} il yerel veriden yüklendi (fallback)');
  }

  Future<void> _ilceleriYukle(String ilId) async {
    setState(() {
      yukleniyor = true;
    });

    // Önce API'den dene (güncel ve doğru veriler için)
    try {
      final ilcelerData = await DiyanetApiService.getIlceler(ilId);
      if (ilcelerData.isNotEmpty) {
        setState(() {
          ilceler = ilcelerData;
          filtrelenmisIlceler = ilceler;
          _ilceAramaController.clear();
          yukleniyor = false;
        });
        print('✅ ${ilceler.length} ilçe API\'den yüklendi');
        return;
      }
    } catch (e) {
      print('⚠️ API\'den ilçe yüklenemedi, yerel veriye geçiliyor: $e');
    }

    // API başarısız olursa yerel veriye fallback
    final yerelIlceler = IlIlceData.getIlceler(ilId);
    setState(() {
      ilceler = yerelIlceler;
      filtrelenmisIlceler = ilceler;
      _ilceAramaController.clear();
      yukleniyor = false;
    });
    print('✅ ${ilceler.length} ilçe yerel veriden yüklendi (fallback)');
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

  Future<void> _konumuTespitEt() async {
    setState(() {
      konumTespit = true;
    });

    try {
      Position? position;

      // Önce GPS ile dene
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          // Önce son bilinen konumu al (hızlı başlangıç için)
          Position? lastKnown;
          try {
            lastKnown = await Geolocator.getLastKnownPosition();
          } catch (e) {
            print('⚠️ Son bilinen konum alınamadı: $e');
          }

          try {
            // Konum al - önce düşük hassasiyetle hızlı sonuç al
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 10),
            );
            print(
              '📍 GPS (düşük hassasiyet): ${position.latitude}, ${position.longitude}',
            );
          } catch (e) {
            print('⚠️ Düşük hassasiyetli konum alınamadı: $e');
            // Daha yüksek hassasiyetle tekrar dene
            try {
              position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 20),
              );
              print(
                '📍 GPS (orta hassasiyet): ${position.latitude}, ${position.longitude}',
              );
            } catch (e2) {
              print('⚠️ Orta hassasiyetli konum da alınamadı: $e2');
              // Son bilinen konumu kullan
              if (lastKnown != null) {
                position = lastKnown;
                print(
                  '📍 Son bilinen konum: ${position.latitude}, ${position.longitude}',
                );
              }
            }
          }
        }
      }

      // GPS başarısız olduysa IP tabanlı konum dene (mobil veri için)
      if (position == null) {
        print('🌐 GPS başarısız, IP tabanlı konum deneniyor...');
        position = await _getIpBasedLocation();

        if (position != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'GPS kapalı, internet üzerinden yaklaşık konum tespit edildi.',
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }

      if (position == null) {
        _konumHatasi(
          'Konum alınamadı. Lütfen GPS\'i açın veya manuel seçim yapın.',
        );
        return;
      }

      print('📍 Konum alındı: ${position.latitude}, ${position.longitude}');

      // Önce il listesini yükle (eğer yüklü değilse)
      if (iller.isEmpty) {
        await _illeriYukle();
      }

      // Koordinatlara göre en yakın ili bul
      final enYakinIl = _enYakinIliBul(position.latitude, position.longitude);

      if (enYakinIl != null && enYakinIl.isNotEmpty) {
        final ilId =
            enYakinIl['SehirID']?.toString() ??
            enYakinIl['IlceID']?.toString() ??
            '';
        final ilAdi = enYakinIl['SehirAdi'] ?? enYakinIl['IlceAdi'] ?? '';

        print('🏙️ En yakın il bulundu: $ilAdi (ID: $ilId)');

        setState(() {
          secilenIlId = ilId;
          secilenIlAdi = ilAdi;
        });

        await _ilceleriYukle(ilId);

        // En uygun ilçeyi bul
        if (ilceler.isNotEmpty) {
          Map<String, dynamic>? secilenIlce;

          // Önce "MERKEZ" adlı ilçeyi ara
          try {
            secilenIlce = ilceler.firstWhere((ilce) {
              final ilceAdi = (ilce['IlceAdi'] ?? '').toString().toUpperCase();
              return ilceAdi == 'MERKEZ';
            });
          } catch (_) {
            secilenIlce = null;
          }

          // Merkez bulunamadıysa, il adını içeren ilçeyi ara
          if (secilenIlce == null) {
            try {
              secilenIlce = ilceler.firstWhere((ilce) {
                final ilceAdi = (ilce['IlceAdi'] ?? '')
                    .toString()
                    .toUpperCase();
                return ilceAdi.contains(ilAdi.toUpperCase()) ||
                    ilAdi.toUpperCase().contains(ilceAdi);
              });
            } catch (_) {
              secilenIlce = null;
            }
          }

          // Hala bulunamadıysa ilk ilçeyi seç
          if (secilenIlce == null && ilceler.isNotEmpty) {
            secilenIlce = ilceler.first;
          }

          if (secilenIlce != null) {
            setState(() {
              secilenIlceId = secilenIlce!['IlceID'].toString();
              secilenIlceAdi = secilenIlce['IlceAdi'];
              konumTespit = false;
            });

            print('🏘️ İlçe seçildi: $secilenIlceAdi (ID: $secilenIlceId)');
          } else {
            setState(() {
              konumTespit = false;
            });
          }
        } else {
          setState(() {
            konumTespit = false;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Konumunuz tespit edildi: $ilAdi${secilenIlceAdi != null ? " / $secilenIlceAdi" : ""}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _konumHatasi('Konum tespit edilemedi. Lütfen manuel seçim yapın.');
      }
    } catch (e) {
      print('❌ Konum tespit hatası: $e');
      _konumHatasi(
        'Konum alınırken hata oluştu: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}...',
      );
    }
  }

  // IP tabanlı konum tespiti (mobil veri/WiFi için)
  Future<Position?> _getIpBasedLocation() async {
    try {
      // ip-api.com ücretsiz API kullanarak IP tabanlı konum al
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=status,lat,lon,city,country',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          final lat = data['lat'] as double;
          final lon = data['lon'] as double;

          print(
            '🌐 IP tabanlı konum: $lat, $lon (${data['city']}, ${data['country']})',
          );

          // Geolocator Position nesnesi oluştur
          return Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: 5000, // IP tabanlı konum ~5km hassasiyet
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      }

      print('⚠️ IP-API yanıtı başarısız: ${response.statusCode}');
    } catch (e) {
      print('⚠️ IP tabanlı konum hatası: $e');
    }

    // Alternatif API dene
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final lat = (data['latitude'] as num).toDouble();
          final lon = (data['longitude'] as num).toDouble();

          print('🌐 IP tabanlı konum (alternatif): $lat, $lon');

          return Position(
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
          );
        }
      }
    } catch (e) {
      print('⚠️ Alternatif IP konum hatası: $e');
    }

    return null;
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

  // Türkiye illeri koordinatları (yaklaşık merkez koordinatları)
  Map<String, dynamic>? _enYakinIliBul(double lat, double lon) {
    // İl koordinatları (yaklaşık)
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

      // Basit mesafe hesaplama
      final mesafe = _mesafeHesapla(lat, lon, ilLat, ilLon);

      if (mesafe < minMesafe) {
        minMesafe = mesafe;
        enYakinIlAdi = entry.key;
      }
    }

    if (enYakinIlAdi != null) {
      // İl verisinde bul (büyük/küçük harf duyarsız)
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
    // Basit Öklid mesafesi (yaklaşık)
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return dLat * dLat + dLon * dLon;
  }

  Future<void> _kaydet() async {
    if (secilenIlId != null && secilenIlceId != null) {
      // Yeni konum modeli oluştur
      final yeniKonum = KonumModel(
        ilAdi: secilenIlAdi!,
        ilId: secilenIlId!,
        ilceAdi: secilenIlceAdi!,
        ilceId: secilenIlceId!,
        aktif: true,
      );

      // Konumu listeye ekle (zaten varsa eklenmez)
      await KonumService.addKonum(yeniKonum);

      // Eski sisteme de kaydet (uyumluluk için)
      await KonumService.setIl(secilenIlAdi!, secilenIlId!);
      await KonumService.setIlce(secilenIlceAdi!, secilenIlceId!);

      // Widget'ları ve uygulama verilerini hemen güncelle
      print('🔄 Konum değişti, veriler güncelleniyor...');
      await HomeWidgetService.updateAllWidgets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_languageService['location_saved'] ?? 'Konum kaydedildi ve güncelleniyor...')),
        );
        // Ana sayfanın güncellemesi için true döndür
        Navigator.pop(context, true);
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
          title: Text(widget.ilkKurulum ? _languageService['location_selection'] ?? 'Konum Seçimi' : _languageService['select_city_district'] ?? 'İl/İlçe Seç'),
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
            // Ülke seçici (gelecekte daha fazla ülke için)
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
                    _languageService['country'] ?? 'Ülke:',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: secilenUlke,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: const Color(0xFF2A3F5F),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: ulkeler.map((ulke) {
                        return DropdownMenuItem<String>(
                          value: ulke['ad'],
                          child: Text(ulke['ad']!),
                        );
                      }).toList(),
                      onChanged: (yeniUlke) {
                        if (yeniUlke != null) {
                          setState(() {
                            secilenUlke = yeniUlke;
                            // Türkiye dışındaki ülkeler için şehir listesini temizle
                            if (!yeniUlke.contains('Türkiye')) {
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

            // Türkiye dışındaki ülkeler için şehir adı girişi
            if (!secilenUlke.contains('Türkiye'))
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
                          'Şehir Bilgisi',
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
                      'GPS ile konumunuzu tespit edin veya aşağıya şehir adını yazın:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ilAramaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Örn: Berlin, London, Paris...',
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
                        if (value.isNotEmpty) {
                          setState(() {
                            secilenIlAdi = value;
                            secilenIlceAdi = secilenUlke.split(
                              ' ',
                            )[1]; // Ülke adı
                            // Koordinatlar GPS ile alınacak
                          });
                        }
                      },
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
                              'Namaz vakitleri GPS koordinatlarınıza göre hesaplanacaktır.',
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

            // GPS ile konum tespit butonu (her zaman göster)
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
                    const Row(
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
                          'Konum tespit ediliyor...',
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
                                    _languageService['auto_find_location'] ?? 'Konumu Otomatik Bul',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _languageService['gps_detect_desc'] ?? 'GPS ile il ve ilçenizi tespit edin',
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

            // İl Arama ve Seçimi (sadece Türkiye için)
            if (secilenUlke.contains('Türkiye'))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _ilAramaController,
                  onChanged: _ilAra,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _languageService['search_city'] ?? 'İl ara...',
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

            // İl Listesi
            if (secilenIlId == null)
              Expanded(
                child: filtrelenmisIller.isEmpty
                    ? Center(
                        child: Text(
                          _languageService['city_not_found'] ?? 'İl bulunamadı',
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

            // Seçili il göstergesi ve ilçe seçimi (sadece Türkiye için)
            if (secilenUlke.contains('Türkiye') && secilenIlId != null) ...[
              // Seçili il
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
                      child: Text(
                        secilenIlAdi ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
                      tooltip: 'İl Değiştir',
                    ),
                  ],
                ),
              ),

              // İlçe Arama
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _ilceAramaController,
                  onChanged: _ilceAra,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _languageService['search_district'] ?? 'İlçe ara...',
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

              // İlçe Listesi
              Expanded(
                child: filtrelenmisIlceler.isEmpty
                    ? Center(
                        child: Text(
                          _languageService['district_not_found'] ?? 'İlçe bulunamadı',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtrelenmisIlceler.length,
                        itemBuilder: (context, index) {
                          final ilce = filtrelenmisIlceler[index];
                          final isSelected =
                              secilenIlceId == ilce['IlceID'].toString();
                          final ilceAdi = ilce['IlceAdi'] ?? '';

                          return ListTile(
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
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
