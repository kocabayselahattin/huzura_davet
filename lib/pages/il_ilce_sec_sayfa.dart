import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../data/il_ilce_data.dart';

class IlIlceSecSayfa extends StatefulWidget {
  final bool ilkKurulum;
  final bool otomatikKonumTespit;

  const IlIlceSecSayfa({super.key, this.ilkKurulum = false, this.otomatikKonumTespit = false});

  @override
  State<IlIlceSecSayfa> createState() => _IlIlceSecSayfaState();
}

class _IlIlceSecSayfaState extends State<IlIlceSecSayfa> {
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
    
    // Önce yerel veriden yükle (daha hızlı ve güvenilir)
    final yerelIller = IlIlceData.getIller();
    if (yerelIller.isNotEmpty) {
      setState(() {
        iller = yerelIller;
        filtrelenmisIller = iller;
        yukleniyor = false;
      });
      print('✅ ${iller.length} il yerel veriden yüklendi');
      return;
    }
    
    // Yerel veri yoksa API'den dene
    final illerData = await DiyanetApiService.getIller();
    setState(() {
      iller = illerData;
      filtrelenmisIller = iller;
      yukleniyor = false;
    });
  }

  Future<void> _ilceleriYukle(String ilId) async {
    setState(() {
      yukleniyor = true;
    });
    
    // Önce yerel veriden yükle
    final yerelIlceler = IlIlceData.getIlceler(ilId);
    if (yerelIlceler.isNotEmpty) {
      setState(() {
        ilceler = yerelIlceler;
        filtrelenmisIlceler = ilceler;
        _ilceAramaController.clear();
        yukleniyor = false;
      });
      print('✅ ${ilceler.length} ilçe yerel veriden yüklendi');
      return;
    }
    
    // Yerel veri yoksa API'den dene
    final ilcelerData = await DiyanetApiService.getIlceler(ilId);
    setState(() {
      ilceler = ilcelerData;
      filtrelenmisIlceler = ilceler;
      _ilceAramaController.clear();
      yukleniyor = false;
    });
  }

  void _ilAra(String aranan) {
    setState(() {
      if (aranan.isEmpty) {
        filtrelenmisIller = iller;
      } else {
        filtrelenmisIller = iller.where((il) {
          final sehirAdi =
              (il['SehirAdi'] ?? il['IlceAdi'] ?? '').toString().toLowerCase();
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
      // Konum servisi izni kontrolü
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _konumHatasi('Konum servisi kapalı. Lütfen manuel seçim yapın.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _konumHatasi('Konum izni reddedildi. Lütfen manuel seçim yapın.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _konumHatasi(
            'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin veya manuel seçim yapın.');
        return;
      }

      // Konum al
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      // Koordinatlara göre en yakın ili bul
      final enYakinIl = _enYakinIliBul(position.latitude, position.longitude);

      if (enYakinIl != null) {
        final ilId = enYakinIl['SehirID']?.toString() ??
            enYakinIl['IlceID']?.toString() ??
            '';
        final ilAdi = enYakinIl['SehirAdi'] ?? enYakinIl['IlceAdi'] ?? '';

        setState(() {
          secilenIlId = ilId;
          secilenIlAdi = ilAdi;
          konumTespit = false;
        });

        await _ilceleriYukle(ilId);

        // İlk ilçeyi otomatik seç (genelde merkez)
        if (ilceler.isNotEmpty) {
          // Merkez ilçesini bulmaya çalış
          final merkez = ilceler.firstWhere(
            (ilce) =>
                (ilce['IlceAdi'] ?? '').toString().toLowerCase() == 'merkez',
            orElse: () => ilceler.first,
          );
          setState(() {
            secilenIlceId = merkez['IlceID'].toString();
            secilenIlceAdi = merkez['IlceAdi'];
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Konumunuz tespit edildi: $ilAdi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _konumHatasi('Konum tespit edilemedi. Lütfen manuel seçim yapın.');
      }
    } catch (e) {
      _konumHatasi('Konum alınırken hata oluştu. Lütfen manuel seçim yapın.');
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
      return iller.firstWhere(
        (il) {
          final sehirAdi = (il['SehirAdi'] ?? il['IlceAdi'] ?? '').toString().toUpperCase();
          return sehirAdi.contains(aramaIlAdi) || aramaIlAdi.contains(sehirAdi);
        },
        orElse: () => <String, dynamic>{},
      );
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
      await KonumService.setIl(secilenIlAdi!, secilenIlId!);
      await KonumService.setIlce(secilenIlceAdi!, secilenIlceId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum kaydedildi')),
        );
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
          title: Text(widget.ilkKurulum ? 'Konum Seçimi' : 'İl/İlçe Seç'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !widget.ilkKurulum,
          actions: [
            if (secilenIlceId != null)
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _kaydet,
              ),
          ],
        ),
        body: Column(
          children: [
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
                            valueColor:
                                AlwaysStoppedAnimation(Colors.cyanAccent),
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
                              child: const Icon(Icons.my_location,
                                  color: Colors.cyanAccent, size: 24),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Konumu Otomatik Bul',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'GPS ile il ve ilçenizi tespit edin',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                color: Colors.cyanAccent, size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // İl Arama ve Seçimi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _ilAramaController,
                onChanged: _ilAra,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'İl ara...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _ilAramaController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // İl Listesi
            if (secilenIlId == null)
              Expanded(
                child: filtrelenmisIller.isEmpty
                    ? const Center(
                        child: Text(
                          'İl bulunamadı',
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
                          final sehirId = il['SehirID']?.toString() ??
                              il['IlceID']?.toString() ??
                              '';

                          return ListTile(
                            leading: const Icon(Icons.location_city,
                                color: Colors.white54),
                            title: Text(
                              sehirAdi,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.white54),
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

            // Seçili il göstergesi ve ilçe seçimi
            if (secilenIlId != null) ...[
              // Seçili il
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    hintText: 'İlçe ara...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _ilceAramaController.text.isNotEmpty
                        ? IconButton(
                            icon:
                                const Icon(Icons.clear, color: Colors.white54),
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
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // İlçe Listesi
              Expanded(
                child: filtrelenmisIlceler.isEmpty
                    ? const Center(
                        child: Text(
                          'İlçe bulunamadı',
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
                                color:
                                    isSelected ? Colors.cyanAccent : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Colors.cyanAccent)
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
