import 'dart:convert';

import 'package:http/http.dart' as http;

class DiyanetApiService {
  static const _baseUrl = 'https://ezanvakti.emushaf.net';
  static const _userAgent = 'HuzurVaktiApp/1.0';
  static final Map<String, Map<String, dynamic>> _vakitCache = {};
  static final Map<String, DateTime> _vakitCacheTimes = {};
  
  // İl ve İlçe cache
  static List<Map<String, dynamic>>? _illerCache;
  static final Map<String, List<Map<String, dynamic>>> _ilcelerCache = {};

  // Aylık vakit cache
  static final Map<String, List<Map<String, dynamic>>> _aylikVakitCache = {};

  // Cache temizleme metodu
  static void clearCache() {
    _vakitCache.clear();
    _vakitCacheTimes.clear();
    _aylikVakitCache.clear();
    _illerCache = null;
    _ilcelerCache.clear();
    print('✅ DiyanetApiService cache temizlendi');
  }

  // Belirli bir ay için vakitleri getir
  static Future<List<Map<String, dynamic>>> getAylikVakitler(
    String ilceId,
    int yil,
    int ay,
  ) async {
    final cacheKey = '$ilceId-$yil-$ay';
    
    // Cache'de varsa döndür
    if (_aylikVakitCache.containsKey(cacheKey)) {
      return _aylikVakitCache[cacheKey]!;
    }

    try {
      // Ayın ilk ve son gününü hesapla
      final baslangic = DateTime(yil, ay, 1);
      final bitis = DateTime(yil, ay + 1, 0); // Ayın son günü
      
      final baslangicStr = '${baslangic.day.toString().padLeft(2, '0')}.${baslangic.month.toString().padLeft(2, '0')}.${baslangic.year}';
      final bitisStr = '${bitis.day.toString().padLeft(2, '0')}.${bitis.month.toString().padLeft(2, '0')}.${bitis.year}';
      
      final uri = Uri.parse('$_baseUrl/vakitler/$ilceId?baslangic=$baslangicStr&bitis=$bitisStr');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        if (decoded is List) {
          final vakitler = decoded
              .whereType<Map<String, dynamic>>()
              .map(_normalizeVakitEntry)
              .where((v) {
                // Sadece istenen aya ait verileri filtrele
                final tarih = v['MiladiTarihKisa'] ?? '';
                try {
                  final parts = tarih.split('.');
                  if (parts.length == 3) {
                    final ayNum = int.parse(parts[1]);
                    final yilNum = int.parse(parts[2]);
                    return yilNum == yil && ayNum == ay;
                  }
                } catch (e) {}
                return false;
              })
              .toList();
          
          if (vakitler.isNotEmpty) {
            _aylikVakitCache[cacheKey] = vakitler;
            print('✅ Aylık vakitler alındı: $cacheKey (${vakitler.length} gün)');
            return vakitler;
          }
        }
      }
    } catch (e) {
      print('⚠️ Aylık vakit alınamadı ($cacheKey): $e');
    }

    // Alternatif: Normal vakit endpoint'inden dene
    try {
      final data = await getVakitler(ilceId);
      if (data != null && data.containsKey('vakitler')) {
        final tumVakitler = data['vakitler'] as List;
        final ayVakitleri = tumVakitler.where((v) {
          final tarih = v['MiladiTarihKisa'] ?? '';
          try {
            final parts = tarih.split('.');
            if (parts.length == 3) {
              final ayNum = int.parse(parts[1]);
              final yilNum = int.parse(parts[2]);
              return yilNum == yil && ayNum == ay;
            }
          } catch (e) {}
          return false;
        }).map((v) => Map<String, dynamic>.from(v)).toList();
        
        if (ayVakitleri.isNotEmpty) {
          _aylikVakitCache[cacheKey] = ayVakitleri;
          return ayVakitleri;
        }
      }
    } catch (e) {
      print('⚠️ Fallback vakit alınamadı: $e');
    }

    // Son çare: Dummy veri
    final dummyVakitler = _generateDummyMonthVakitler(yil, ay);
    _aylikVakitCache[cacheKey] = dummyVakitler;
    return dummyVakitler;
  }

  // Belirli bir ay için dummy veri oluştur
  static List<Map<String, dynamic>> _generateDummyMonthVakitler(int yil, int ay) {
    final List<Map<String, dynamic>> vakitler = [];
    final ayinSonGunu = DateTime(yil, ay + 1, 0).day;

    for (int gun = 1; gun <= ayinSonGunu; gun++) {
      final tarih = DateTime(yil, ay, gun);
      final gun2 = tarih.day.toString().padLeft(2, '0');
      final ay2 = tarih.month.toString().padLeft(2, '0');
      final yilStr = tarih.year.toString();

      final yilGunu = tarih.difference(DateTime(tarih.year, 1, 1)).inDays;
      final imsakDakika = 20 + (yilGunu % 40);
      final gunesDakika = 45 + (yilGunu % 30);
      final ogleDakika = 50 + (yilGunu % 20);
      final ikindiDakika = 30 + (yilGunu % 35);
      final aksamDakika = 10 + (yilGunu % 30);
      final yatsiDakika = 35 + (yilGunu % 30);

      vakitler.add({
        'MiladiTarihKisa': '$gun2.$ay2.$yilStr',
        'MiladiTarihUzun': '$gun2.$ay2.$yilStr',
        'HicriTarihKisa': '$gun2.$ay2.${(int.parse(yilStr) - 578).toString()}',
        'Imsak': '05:${imsakDakika.toString().padLeft(2, '0')}',
        'Gunes': '06:${gunesDakika.toString().padLeft(2, '0')}',
        'Ogle': '12:${ogleDakika.toString().padLeft(2, '0')}',
        'Ikindi': '15:${ikindiDakika.toString().padLeft(2, '0')}',
        'Aksam': '18:${aksamDakika.toString().padLeft(2, '0')}',
        'Yatsi': '19:${yatsiDakika.toString().padLeft(2, '0')}',
      });
    }
    return vakitler;
  }

  // İlleri API'den getir
  static Future<List<Map<String, dynamic>>> getIller() async {
    if (_illerCache != null) {
      return _illerCache!;
    }

    try {
      final uri = Uri.parse('$_baseUrl/sehirler/2'); // Türkiye = 2
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        if (decoded is List) {
          _illerCache = decoded.map((item) => {
            'SehirID': item['SehirID']?.toString() ?? '',
            'SehirAdi': _fixTurkishChars(item['SehirAdi']?.toString() ?? ''),
          }).toList();
          print('✅ ${_illerCache!.length} il API\'den yüklendi');
          return _illerCache!;
        }
      }
    } catch (e) {
      print('⚠️ İller API hatası: $e');
    }

    // Fallback - Varsayılan iller
    return _getDefaultIller();
  }

  // İlçeleri API'den getir
  static Future<List<Map<String, dynamic>>> getIlceler(String ilId) async {
    if (_ilcelerCache.containsKey(ilId)) {
      return _ilcelerCache[ilId]!;
    }

    try {
      final uri = Uri.parse('$_baseUrl/ilceler/$ilId');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        if (decoded is List) {
          final ilceler = decoded.map((item) => {
            'IlceID': item['IlceID']?.toString() ?? '',
            'IlceAdi': _fixTurkishChars(item['IlceAdi']?.toString() ?? ''),
          }).toList();
          _ilcelerCache[ilId] = List<Map<String, dynamic>>.from(ilceler);
          print('✅ ${ilceler.length} ilçe API\'den yüklendi (il: $ilId)');
          return _ilcelerCache[ilId]!;
        }
      }
    } catch (e) {
      print('⚠️ İlçeler API hatası: $e');
    }

    // Fallback - Varsayılan ilçe (il merkezi)
    return [{'IlceID': ilId, 'IlceAdi': 'Merkez'}];
  }
  
  // Türkçe karakter düzeltme
  static String _fixTurkishChars(String text) {
    return text
      .replaceAll('Ä°', 'İ')
      .replaceAll('Ã', 'Ç')
      .replaceAll('Ä', 'Ğ')
      .replaceAll('Å', 'Ş')
      .replaceAll('Ã–', 'Ö')
      .replaceAll('Ã', 'Ü')
      .replaceAll('Ä±', 'ı');
  }
  
  // Varsayılan iller listesi (fallback)
  static List<Map<String, dynamic>> _getDefaultIller() {
    return [
      {'SehirID': '500', 'SehirAdi': 'ADANA'},
      {'SehirID': '501', 'SehirAdi': 'ADIYAMAN'},
      {'SehirID': '506', 'SehirAdi': 'ANKARA'},
      {'SehirID': '507', 'SehirAdi': 'ANTALYA'},
      {'SehirID': '520', 'SehirAdi': 'BURSA'},
      {'SehirID': '539', 'SehirAdi': 'İSTANBUL'},
      {'SehirID': '540', 'SehirAdi': 'İZMİR'},
      {'SehirID': '552', 'SehirAdi': 'KONYA'},
    ];
  }

  // Vakit saatlerini getir (önce canlı veri, gerekirse cache ya da lokal)
  static Future<Map<String, dynamic>?> getVakitler(String ilceId) async {
    final now = DateTime.now();
    final cached = _vakitCache[ilceId];
    final cachedTime = _vakitCacheTimes[ilceId];

    if (cached != null && cachedTime != null) {
      final sameDay = cachedTime.year == now.year &&
          cachedTime.month == now.month &&
          cachedTime.day == now.day;
      if (sameDay && now.difference(cachedTime) < const Duration(hours: 1)) {
        return cached;
      }
    }

    try {
      final remote = await _fetchRemoteVakitler(ilceId);
      if (remote != null) {
        _vakitCache[ilceId] = remote;
        _vakitCacheTimes[ilceId] = now;
        print('✅ API\'den veri başarıyla alındı ve cache\'lendi: $ilceId');
        return remote;
      }
    } catch (e) {
      print('⚠️ Canlı vakit alınamadı ($ilceId): $e');
    }

    if (cached != null) {
      print('ℹ️ İnternet yok, cache kullanılıyor: $ilceId');
      return cached;
    }

    print('⚠️ Canlı veri yok, sahte verilere düşüldü: $ilceId');
    final fallback = _getDummyVakitler(ilceId);
    _vakitCache[ilceId] = fallback;
    _vakitCacheTimes[ilceId] = now;
    return fallback;
  }

  static Future<Map<String, dynamic>?> _fetchRemoteVakitler(
    String ilceId,
  ) async {
    final uri = Uri.parse('$_baseUrl/vakitler/$ilceId');
    final response = await http
        .get(uri, headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
        })
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      print('⚠️ Vakit isteği başarısız (${response.statusCode}): $ilceId');
      return null;
    }

    final body = utf8.decode(response.bodyBytes);
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      print('⚠️ Beklenmeyen vakit formatı: $ilceId');
      return null;
    }

    final vakitler = decoded
        .whereType<Map<String, dynamic>>()
        .map(_normalizeVakitEntry)
        .toList();

    if (vakitler.isEmpty) {
      print('⚠️ Boş vakit verisi döndü: $ilceId');
      return null;
    }

    print('✅ Vakitler canlı olarak alındı: $ilceId');
    return {
      'IlceID': ilceId,
      'vakitler': vakitler,
    };
  }

  static Map<String, dynamic> _normalizeVakitEntry(
    Map<String, dynamic> raw,
  ) {
    // API zaten doğru formatta veri döndürüyor (örn: "16.01.2026")
    // Herhangi bir dönüşüm gerekmez
    return Map<String, dynamic>.from(raw);
  }

  // Test için sahte vakit verileri
  static Map<String, dynamic> _getDummyVakitler(String ilceId) {
    print('ℹ️ Vakit verileri yerel üretildi');

    // 6 ay için veri oluştur (3 ay geriye, 3 ay ileriye)
    final now = DateTime.now();
    final List<Map<String, dynamic>> vakitler = [];

    // 3 ay önceden başla, 6 ay boyunca veri oluştur
    final baslangic = DateTime(now.year, now.month - 3, 1);

    for (int ayOffset = 0; ayOffset < 6; ayOffset++) {
      final ay = DateTime(baslangic.year, baslangic.month + ayOffset, 1);
      final ayinSonGunu = DateTime(ay.year, ay.month + 1, 0).day;

      for (int gun = 1; gun <= ayinSonGunu; gun++) {
        final tarih = DateTime(ay.year, ay.month, gun);
        final gun2 = tarih.day.toString().padLeft(2, '0');
        final ay2 = tarih.month.toString().padLeft(2, '0');
        final yil = tarih.year.toString();

        // Yılın gününe göre vakit saatlerini değiştir (gerçekçi olsun)
        final yilGunu = tarih.difference(DateTime(tarih.year, 1, 1)).inDays;
        final imsakDakika = 20 + (yilGunu % 40); // 20-60 arası
        final gunesDakika = 45 + (yilGunu % 30); // 45-75 arası
        final ogleDakika = 50 + (yilGunu % 20); // 50-70 arası
        final ikindiDakika = 30 + (yilGunu % 35); // 30-65 arası
        final aksamDakika = 10 + (yilGunu % 30); // 10-40 arası
        final yatsiDakika = 35 + (yilGunu % 30); // 35-65 arası

        vakitler.add({
          'MiladiTarihKisa': '$gun2.$ay2.$yil',
          'MiladiTarihUzun': '$gun2.$ay2.$yil',
          'HicriTarihKisa': '$gun2.$ay2.${(int.parse(yil) - 578).toString()}',
          'HicriTarihUzun':
              '$gun2 ${_getAyAdi(int.parse(ay2))} ${(int.parse(yil) - 578).toString()}',
          'Imsak': '05:${imsakDakika.toString().padLeft(2, '0')}',
          'Gunes': '06:${gunesDakika.toString().padLeft(2, '0')}',
          'Ogle': '12:${ogleDakika.toString().padLeft(2, '0')}',
          'Ikindi': '15:${ikindiDakika.toString().padLeft(2, '0')}',
          'Aksam': '18:${aksamDakika.toString().padLeft(2, '0')}',
          'Yatsi': '19:${yatsiDakika.toString().padLeft(2, '0')}',
        });
      }
    }

    return {
      'IlceID': ilceId,
      'IlceAdi': 'Test İlçe',
      'SehirAdi': 'Test İl',
      'UlkeAdi': 'Türkiye',
      'vakitler': vakitler,
    };
  }

  // Ay adlarını döndürür
  static String _getAyAdi(int ay) {
    const aylar = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return aylar[ay];
  }
}
