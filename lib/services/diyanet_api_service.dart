import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'namazvakti_api_service.dart';
import 'aladhan_api_service.dart';

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
  
  // Cache'i SharedPreferences'a kaydet
  static Future<void> _saveVakitToPrefs(String ilceId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(data);
      await prefs.setString('vakit_cache_$ilceId', jsonStr);
      await prefs.setInt('vakit_cache_time_$ilceId', DateTime.now().millisecondsSinceEpoch);
      print('💾 Vakit verileri kaydedildi: $ilceId');
    } catch (e) {
      print('⚠️ Cache kaydetme hatası: $e');
    }
  }
  
  // SharedPreferences'tan cache yükle
  static Future<Map<String, dynamic>?> _loadVakitFromPrefs(String ilceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('vakit_cache_$ilceId');
      final cacheTime = prefs.getInt('vakit_cache_time_$ilceId');
      
      if (jsonStr != null && cacheTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
        final now = DateTime.now();
        
        // Cache 7 günden eskiyse kullanma
        if (now.difference(cacheDate).inDays < 7) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          print('📂 Kaydedilmiş vakit verileri yüklendi: $ilceId');
          return data;
        } else {
          print('⏰ Kaydedilmiş veriler çok eski (${now.difference(cacheDate).inDays} gün)');
        }
      }
    } catch (e) {
      print('⚠️ Cache yükleme hatası: $e');
    }
    return null;
  }
  
  // Aylık vakit cache'ini SharedPreferences'a kaydet
  static Future<void> _saveAylikVakitToPrefs(String cacheKey, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(data);
      await prefs.setString('aylik_vakit_$cacheKey', jsonStr);
      await prefs.setInt('aylik_vakit_time_$cacheKey', DateTime.now().millisecondsSinceEpoch);
      print('💾 Aylık vakit verileri kaydedildi: $cacheKey');
    } catch (e) {
      print('⚠️ Aylık cache kaydetme hatası: $e');
    }
  }
  
  // Aylık vakit cache'ini SharedPreferences'tan yükle
  static Future<List<Map<String, dynamic>>?> _loadAylikVakitFromPrefs(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('aylik_vakit_$cacheKey');
      final cacheTime = prefs.getInt('aylik_vakit_time_$cacheKey');
      
      if (jsonStr != null && cacheTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
        final now = DateTime.now();
        
        // Cache 30 günden eskiyse kullanma
        if (now.difference(cacheDate).inDays < 30) {
          final data = jsonDecode(jsonStr) as List;
          final result = data.map((item) => item as Map<String, dynamic>).toList();
          print('📂 Kaydedilmiş aylık vakit verileri yüklendi: $cacheKey');
          return result;
        } else {
          print('⏰ Kaydedilmiş aylık veriler çok eski (${now.difference(cacheDate).inDays} gün)');
        }
      }
    } catch (e) {
      print('⚠️ Aylık cache yükleme hatası: $e');
    }
    return null;
  }

  /// Bugünün namaz vakitlerini döndürür (Imsak, Gunes, Ogle, Ikindi, Aksam, Yatsi)
  static Future<Map<String, String>?> getBugunVakitler(String ilceId) async {
    // Geçersiz ID kontrolü - bazı ilçe ID'leri API'de çalışmıyor
    if (ilceId.isEmpty || ilceId == '0') {
      print('⚠️ Geçersiz ilçe ID, lütfen Ayarlar > Konum\'dan il/ilçe seçin');
      return null;
    }
    
    final data = await getVakitler(ilceId);
    if (data == null) {
      // Diyanet API başarısız - 500 hatası muhtemelen geçersiz ID
      print('⚠️ İlçe ID $ilceId için veri alınamadı. Ayarlar > Konum\'dan farklı bir ilçe seçmeyi deneyin.');
      return await NamazVaktiApiService.getBugunVakitler(ilceId);
    }
    
    final vakitler = data['vakitler'];
    if (vakitler == null || vakitler is! List || vakitler.isEmpty) {
      // Yedek API'yi dene
      return await NamazVaktiApiService.getBugunVakitler(ilceId);
    }
    
    // Bugünün tarihini al
    final now = DateTime.now();
    final bugunStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    
    // Bugünün vakitlerini bul
    Map<String, dynamic>? bugunVakit;
    for (final v in vakitler) {
      if (v is Map<String, dynamic>) {
        final tarih = v['MiladiTarihKisa'] ?? '';
        if (tarih == bugunStr) {
          bugunVakit = v;
          break;
        }
      }
    }
    
    // Bugun bulunamazsa ilk kaydı kullan
    if (bugunVakit == null && vakitler.isNotEmpty) {
      bugunVakit = vakitler.first as Map<String, dynamic>?;
      print('⚠️ Bugünün vakti bulunamadı, ilk kayıt kullanılıyor');
    }
    
    if (bugunVakit == null) {
      // Yedek API'yi dene
      return await NamazVaktiApiService.getBugunVakitler(ilceId);
    }
    
    return {
      'Imsak': bugunVakit['Imsak']?.toString() ?? '05:30',
      'Gunes': bugunVakit['Gunes']?.toString() ?? '07:00',
      'Ogle': bugunVakit['Ogle']?.toString() ?? '12:30',
      'Ikindi': bugunVakit['Ikindi']?.toString() ?? '15:30',
      'Aksam': bugunVakit['Aksam']?.toString() ?? '18:00',
      'Yatsi': bugunVakit['Yatsi']?.toString() ?? '19:30',
      'HicriTarihKisa': bugunVakit['HicriTarihKisa']?.toString() ?? '',
      'HicriTarihUzun': bugunVakit['HicriTarihUzun']?.toString() ?? '',
      'MiladiTarihKisa': bugunVakit['MiladiTarihKisa']?.toString() ?? '',
      'MiladiTarihUzun': bugunVakit['MiladiTarihUzun']?.toString() ?? '',
    };
  }

  // Belirli bir ay için vakitleri getir
  static Future<List<Map<String, dynamic>>> getAylikVakitler(
    String ilceId,
    int yil,
    int ay,
  ) async {
    final cacheKey = '$ilceId-$yil-$ay';
    
    // 1. RAM cache'de varsa döndür
    if (_aylikVakitCache.containsKey(cacheKey)) {
      print('📦 Aylık RAM cache kullanılıyor: $cacheKey');
      return _aylikVakitCache[cacheKey]!;
    }

    // 2. SharedPreferences'tan yükle
    final savedData = await _loadAylikVakitFromPrefs(cacheKey);
    if (savedData != null && savedData.isNotEmpty) {
      _aylikVakitCache[cacheKey] = savedData;
      print('💾 Aylık kaydedilmiş veriler kullanılıyor: $cacheKey');
      return savedData;
    }

    try {
      // API bugünden itibaren veri döndürüyor, parametreler kullanılacak
      // Çözüm: parametresiz çağrı yap ve tüm ayları lokalde parse et
      final uri = Uri.parse('$_baseUrl/vakitler/$ilceId');
      
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        
        // API direkt liste döndürüyor
        if (decoded is List) {
          final tumVakitler = decoded
              .whereType<Map<String, dynamic>>()
              .map(_normalizeVakitEntry)
              .toList();
          
          // Tüm vakitleri ay ay grupla ve cache'le
          final Map<String, List<Map<String, dynamic>>> ayGruplari = {};
          
          for (var vakit in tumVakitler) {
            final tarih = vakit['MiladiTarihKisa'] ?? '';
            try {
              final parts = tarih.split('.');
              if (parts.length == 3) {
                final ayNum = int.parse(parts[1]);
                final yilNum = int.parse(parts[2]);
                final key = '$ilceId-$yilNum-$ayNum';
                
                if (!ayGruplari.containsKey(key)) {
                  ayGruplari[key] = [];
                }
                ayGruplari[key]!.add(vakit);
              }
            } catch (e) {
              // Tarih parse hatası
            }
          }
          
          // Tüm ayları cache'le ve kaydet
          for (var entry in ayGruplari.entries) {
            _aylikVakitCache[entry.key] = entry.value;
            await _saveAylikVakitToPrefs(entry.key, entry.value);
          }
          
          // İstenen ayı döndür
          if (ayGruplari.containsKey(cacheKey)) {
            print('✅ Aylık vakitler alındı ve kaydedildi: $cacheKey (${ayGruplari[cacheKey]!.length} gün)');
            return ayGruplari[cacheKey]!;
          }
        }
      } else if (response.statusCode == 500 || response.statusCode == 400) {
        print('⚠️ İlçe ID "$ilceId" API\'de desteklenmiyor. Lütfen farklı bir il/ilçe seçin.');
      }
    } catch (e) {
      print('⚠️ Aylık vakit alınamadı ($cacheKey): $e');
    }

    // Diyanet başarısız olursa Aladhan API'yi dene (Her ay için çalışır!)
    print('! Diyanet API yetersiz, Aladhan API deneniyor...');
    try {
      final aladhanVakitler = await AladhanApiService.getAylikVakitler(
        yil: yil,
        ay: ay,
        city: 'Istanbul', // TODO: İlçe ID'sine göre şehir belirle
        country: 'Turkey',
      );
      if (aladhanVakitler.isNotEmpty) {
        _aylikVakitCache[cacheKey] = aladhanVakitler;
        return aladhanVakitler;
      }
    } catch (e) {
      print('⚠️ Aladhan API de başarısız: $e');
    }

    // API'den veri alınamadıysa boş liste döndür
    print('❌ Aylık vakitler alınamadı: $cacheKey');
    return [];
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

  // Vakit saatlerini getir (önce cache, gerekirse API)
  // Cache süresi: 7 gün - Kullanıcı yenile butonu ile manuel güncelleme yapabilir
  static Future<Map<String, dynamic>?> getVakitler(String ilceId) async {
    final now = DateTime.now();
    
    // 1. RAM cache'i kontrol et (hızlı erişim için)
    final cached = _vakitCache[ilceId];
    final cachedTime = _vakitCacheTimes[ilceId];
    if (cached != null && cachedTime != null) {
      // RAM cache 7 günden yeni ise kullan
      if (now.difference(cachedTime).inDays < 7) {
        print('📦 RAM cache kullanılıyor ($ilceId) - ${now.difference(cachedTime).inDays} gün önce');
        return cached;
      }
    }

    // 2. SharedPreferences'tan kaydedilmiş veriyi kontrol et (7 gün cache)
    final savedData = await _loadVakitFromPrefs(ilceId);
    if (savedData != null) {
      // Cache'i RAM'e de yükle (hızlı erişim için)
      _vakitCache[ilceId] = savedData;
      _vakitCacheTimes[ilceId] = now;
      print('💾 Kaydedilmiş veriler kullanılıyor (7 gün cache): $ilceId');
      return savedData;
    }

    // 3. Cache yoksa veya eskiyse - İnternetten yeni veri al
    print('🌐 Cache yok veya eski, API\'den veri çekiliyor: $ilceId');
    try {
      final remote = await _fetchRemoteVakitler(ilceId);
      if (remote != null) {
        _vakitCache[ilceId] = remote;
        _vakitCacheTimes[ilceId] = now;
        await _saveVakitToPrefs(ilceId, remote); // Kalıcı olarak kaydet
        print('✅ API\'den veri başarıyla alındı ve kaydedildi: $ilceId');
        return remote;
      }
    } catch (e) {
      print('⚠️ Canlı vakit alınamadı ($ilceId): $e');
    }

    // 4. İnternet yoksa ve RAM cache'de eski veri varsa onu kullan
    if (cached != null) {
      print('ℹ️ İnternet yok, eski RAM cache kullanılıyor: $ilceId');
      return cached;
    }

    print('❌ API\'den veri alınamadı ve hiçbir cache yok: $ilceId');
    return null;
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
      if (response.statusCode == 500) {
        print('❌ İlçe ID "$ilceId" API\'de desteklenmiyor. Lütfen farklı bir il/ilçe seçin.');
      } else {
        print('⚠️ Vakit isteği başarısız (${response.statusCode}): $ilceId');
      }
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
}
