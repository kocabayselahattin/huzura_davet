import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'namazvakti_api_service.dart';
import 'aladhan_api_service.dart';
import 'konum_service.dart';
import '../data/il_ilce_data.dart';

class DiyanetApiService {
  static const _baseUrl = 'https://ezanvakti.emushaf.net';
  static const _userAgent = 'HuzurVaktiApp/1.0';
  static final Map<String, Map<String, dynamic>> _vakitCache = {};

  // City and district cache
  static List<Map<String, dynamic>>? _illerCache;
  static final Map<String, List<Map<String, dynamic>>> _ilcelerCache = {};

  // Monthly times cache
  static final Map<String, List<Map<String, dynamic>>> _aylikVakitCache = {};

  // Clear cache
  static void clearCache() {
    _vakitCache.clear();
    _aylikVakitCache.clear();
    _illerCache = null;
    _ilcelerCache.clear();
    debugPrint('✅ DiyanetApiService cache cleared');
  }

  // Save cache to SharedPreferences
  static Future<void> _saveVakitToPrefs(
    String ilceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(data);
      await prefs.setString('vakit_cache_$ilceId', jsonStr);
      await prefs.setInt(
        'vakit_cache_time_$ilceId',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('💾 Prayer data saved: $ilceId');
    } catch (e) {
      debugPrint('⚠️ Cache save error: $e');
    }
  }

  // Load cache from SharedPreferences.
  //
  // Yaşına göre değil, içeriğine göre güvenilir sayılır: bir tarihe ait
  // namaz vakti hiç değişmez, dolayısıyla önbelleğin ne zaman indirildiği
  // değil, bugünü kapsayıp kapsamadığı önemlidir (bkz. [getVakitler]).
  // Eskiden burada "7 günden eskiyse kullanma" kısıtı vardı; bu, API'nin
  // tek istekte döndürdüğü ~32 günlük pencerenin geri kalanını (internet
  // olmasa bile hâlâ geçerli günleri) gereksiz yere çöpe atıyordu.
  static Future<Map<String, dynamic>?> _loadVakitFromPrefs(
    String ilceId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('vakit_cache_$ilceId');
      if (jsonStr == null) return null;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      debugPrint('📂 Cached prayer data loaded: $ilceId');
      return data;
    } catch (e) {
      debugPrint('⚠️ Cache load error: $e');
    }
    return null;
  }

  /// [data] (getVakitler'ın döndürdüğü `{'vakitler': [...]}` biçimi)
  /// bugünün tarihini içeriyor mu?
  static bool _vakitVerisiBugunuIcerirMi(Map<String, dynamic> data) {
    final vakitler = data['vakitler'];
    if (vakitler is! List) return false;
    final now = DateTime.now();
    final bugunStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    return vakitler.any(
      (v) => v is Map && (v['MiladiTarihKisa'] ?? '') == bugunStr,
    );
  }

  // Save monthly cache to SharedPreferences
  static Future<void> _saveAylikVakitToPrefs(
    String cacheKey,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(data);
      await prefs.setString('aylik_vakit_$cacheKey', jsonStr);
      await prefs.setInt(
        'aylik_vakit_time_$cacheKey',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('💾 Monthly prayer data saved: $cacheKey');
    } catch (e) {
      debugPrint('⚠️ Monthly cache save error: $e');
    }
  }

  // Load monthly cache from SharedPreferences.
  //
  // Bir ayın namaz vakitleri hiç değişmeyen, deterministik veridir; bu
  // yüzden burada da yaşa göre atma yok — [getAylikVakitler] zaten günü
  // eksikse (savedData.length < ayGunuSayisi) tamamlama/yeniden çekme
  // mantığını kendi içinde uyguluyor.
  static Future<List<Map<String, dynamic>>?> _loadAylikVakitFromPrefs(
    String cacheKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('aylik_vakit_$cacheKey');
      if (jsonStr == null) return null;
      final data = jsonDecode(jsonStr) as List;
      final result = data.map((item) => item as Map<String, dynamic>).toList();
      debugPrint('📂 Cached monthly data loaded: $cacheKey');
      return result;
    } catch (e) {
      debugPrint('⚠️ Monthly cache load error: $e');
    }
    return null;
  }

  /// Returns today's prayer times (Imsak, Gunes, Ogle, Ikindi, Aksam, Yatsi)
  static Future<Map<String, String>?> getBugunVakitler(String ilceId) async {
    if (KonumService.isManualIlceId(ilceId)) {
      final manualData = await KonumService.getManualKonumData(ilceId);
      if (manualData != null) {
        final lat = manualData['lat'] as num?;
        final lon = manualData['lon'] as num?;
        if (lat != null && lon != null) {
          return await AladhanApiService.getBugunVakitler(
            latitude: lat.toDouble(),
            longitude: lon.toDouble(),
            timeZone: null,
          );
        }
      }
      debugPrint('⚠️ Manual location data missing for: $ilceId');
      return null;
    }
    // Invalid ID check
    if (ilceId.isEmpty || ilceId == '0') {
      debugPrint(
        '⚠️ Invalid district ID. Please select a location in Settings > Location.',
      );
      return null;
    }

    final data = await getVakitler(ilceId);
    if (data == null) {
      // Diyanet API failed - likely invalid ID
      debugPrint(
        '⚠️ No data for district ID $ilceId. Try selecting a different location in Settings > Location.',
      );
      return await NamazVaktiApiService.getBugunVakitler(ilceId);
    }

    final vakitler = data['vakitler'];
    if (vakitler == null || vakitler is! List || vakitler.isEmpty) {
      // Try backup API
      return await NamazVaktiApiService.getBugunVakitler(ilceId);
    }

    // Get today date
    final now = DateTime.now();
    final bugunStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    // Find today prayer times
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

    // If today is missing, use first entry
    if (bugunVakit == null && vakitler.isNotEmpty) {
      bugunVakit = vakitler.first as Map<String, dynamic>?;
      debugPrint('⚠️ Today not found, using first entry');
    }

    if (bugunVakit == null) {
      // Try backup API
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

  // Fetch times for a specific month
  static Future<List<Map<String, dynamic>>> getAylikVakitler(
    String ilceId,
    int yil,
    int ay,
  ) async {
    if (KonumService.isManualIlceId(ilceId)) {
      final manualData = await KonumService.getManualKonumData(ilceId);
      if (manualData != null) {
        final city = manualData['city']?.toString() ?? '';
        final country = manualData['country']?.toString() ?? '';
        if (city.isNotEmpty && country.isNotEmpty) {
          return await AladhanApiService.getAylikVakitler(
            yil: yil,
            ay: ay,
            city: city,
            country: country,
          );
        }
      }
      debugPrint('⚠️ Manual location data missing for: $ilceId');
      return [];
    }
    final cacheKey = '$ilceId-$yil-$ay';
    final ayGunuSayisi = _daysInMonth(yil, ay);

    // 1. Return from RAM cache if available
    if (_aylikVakitCache.containsKey(cacheKey)) {
      final cached = _aylikVakitCache[cacheKey]!;
      if (cached.length >= ayGunuSayisi) {
        print('📦 Using monthly RAM cache: $cacheKey');
        return cached;
      }
      final filled = await _fillMissingDaysWithAladhan(
        yil: yil,
        ay: ay,
        base: cached,
      );
      _aylikVakitCache[cacheKey] = filled;
      await _saveAylikVakitToPrefs(cacheKey, filled);
      return filled;
    }

    // 2. Load from SharedPreferences
    final savedData = await _loadAylikVakitFromPrefs(cacheKey);
    if (savedData != null && savedData.isNotEmpty) {
      if (savedData.length >= ayGunuSayisi) {
        _aylikVakitCache[cacheKey] = savedData;
        print('💾 Using saved monthly data: $cacheKey');
        return savedData;
      }
      final filled = await _fillMissingDaysWithAladhan(
        yil: yil,
        ay: ay,
        base: savedData,
      );
      _aylikVakitCache[cacheKey] = filled;
      await _saveAylikVakitToPrefs(cacheKey, filled);
      return filled;
    }

    try {
      // API returns data from today; fetch all and filter locally
      final uri = Uri.parse('$_baseUrl/vakitler/$ilceId');

      final response = await http
          .get(
            uri,
            headers: {'Accept': 'application/json', 'User-Agent': _userAgent},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);

        // API returns a list directly
        if (decoded is List) {
          final tumVakitler = decoded
              .whereType<Map<String, dynamic>>()
              .map(_normalizeVakitEntry)
              .toList();

          // Group all times by month and cache
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
              // Date parse error
            }
          }

          // Cache and save all months
          for (var entry in ayGruplari.entries) {
            _aylikVakitCache[entry.key] = entry.value;
            await _saveAylikVakitToPrefs(entry.key, entry.value);
          }

          // Return requested month (fill missing days if needed)
          if (ayGruplari.containsKey(cacheKey)) {
            final filled = await _fillMissingDaysWithAladhan(
              yil: yil,
              ay: ay,
              base: ayGruplari[cacheKey]!,
            );
            _aylikVakitCache[cacheKey] = filled;
            await _saveAylikVakitToPrefs(cacheKey, filled);
            print(
              '✅ Monthly times fetched and saved: $cacheKey (${filled.length} days)',
            );
            return filled;
          }
        }
      } else if (response.statusCode == 500 || response.statusCode == 400) {
        print(
          '⚠️ District ID "$ilceId" is not supported by the API. Please choose a different location.',
        );
      }
    } catch (e) {
      print('⚠️ Monthly times fetch failed ($cacheKey): $e');
    }

    // If Diyanet fails, try Aladhan API (works for every month)
    print('! Diyanet API insufficient, trying Aladhan API...');
    try {
      final aladhanCity = await _getAladhanCity();
      final aladhanVakitler = await AladhanApiService.getAylikVakitler(
        yil: yil,
        ay: ay,
        city: aladhanCity['city']!,
        country: aladhanCity['country']!,
      );
      if (aladhanVakitler.isNotEmpty) {
        _aylikVakitCache[cacheKey] = aladhanVakitler;
        return aladhanVakitler;
      }
    } catch (e) {
      print('⚠️ Aladhan API also failed: $e');
    }

    // Return empty list if no data
    print('❌ Monthly times not available: $cacheKey');
    return [];
  }

  static int _daysInMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final next = DateTime(year, month + 1, 1);
    return next.difference(start).inDays;
  }

  static String _normalizeDateKey(String raw) {
    final parts = raw.split('.');
    if (parts.length != 3) return raw;
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];
    return '$day.$month.$year';
  }

  static DateTime? _parseDateKey(String raw) {
    final parts = raw.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  static Future<Map<String, String>> _getAladhanCity() async {
    final il = await KonumService.getIl();
    final city = _normalizeCityForAladhan(il ?? 'Istanbul');
    return {'city': city, 'country': 'Turkey'};
  }

  static String _normalizeCityForAladhan(String city) {
    final trimmed = city.trim();
    if (trimmed.isEmpty) return 'Istanbul';
    return trimmed
        .replaceAll('İ', 'I')
        .replaceAll('ı', 'i')
        .replaceAll('Ğ', 'G')
        .replaceAll('ğ', 'g')
        .replaceAll('Ş', 'S')
        .replaceAll('ş', 's')
        .replaceAll('Ç', 'C')
        .replaceAll('ç', 'c')
        .replaceAll('Ö', 'O')
        .replaceAll('ö', 'o')
        .replaceAll('Ü', 'U')
        .replaceAll('ü', 'u');
  }

  static Future<List<Map<String, dynamic>>> _fillMissingDaysWithAladhan({
    required int yil,
    required int ay,
    required List<Map<String, dynamic>> base,
  }) async {
    final ayGunuSayisi = _daysInMonth(yil, ay);
    if (base.length >= ayGunuSayisi) return base;

    final aladhanCity = await _getAladhanCity();
    var aladhanVakitler = await AladhanApiService.getAylikVakitler(
      yil: yil,
      ay: ay,
      city: aladhanCity['city']!,
      country: aladhanCity['country']!,
    );

    if (aladhanVakitler.isEmpty && aladhanCity['city'] != 'Istanbul') {
      aladhanVakitler = await AladhanApiService.getAylikVakitler(
        yil: yil,
        ay: ay,
        city: 'Istanbul',
        country: 'Turkey',
      );
    }

    if (aladhanVakitler.isEmpty) return base;

    final byDate = <String, Map<String, dynamic>>{};
    for (final entry in base) {
      final rawDate = entry['MiladiTarihKisa']?.toString() ?? '';
      final key = _normalizeDateKey(rawDate);
      if (key.isNotEmpty) {
        final normalized = Map<String, dynamic>.from(entry);
        normalized['MiladiTarihKisa'] = key;
        byDate[key] = normalized;
      }
    }

    for (final entry in aladhanVakitler) {
      final rawDate = entry['MiladiTarihKisa']?.toString() ?? '';
      final key = _normalizeDateKey(rawDate);
      if (key.isNotEmpty && !byDate.containsKey(key)) {
        final normalized = Map<String, dynamic>.from(entry);
        normalized['MiladiTarihKisa'] = key;
        byDate[key] = normalized;
      }
    }

    final merged = byDate.values.toList();
    merged.sort((a, b) {
      final aDate = _parseDateKey(a['MiladiTarihKisa']?.toString() ?? '');
      final bDate = _parseDateKey(b['MiladiTarihKisa']?.toString() ?? '');
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });

    return merged;
  }

  static const _illerPrefsKey = 'diyanet_iller_cache_v1';
  static const _ilcelerPrefsKeyPrefix = 'diyanet_ilceler_cache_v1_';

  // Fetch cities from API. Bir kez başarıyla çekildikten sonra sonuç
  // SharedPreferences'a kaydedilir; bir sonraki açılışta ağ beklenmeden
  // bu kayıttan anında dönülür (arka planda güncel veriyle sessizce
  // yenilenir — bkz. gorselPaylas ilgisiz, ana_sayfa.dart çağırır).
  static Future<List<Map<String, dynamic>>> getIller() async {
    if (_illerCache != null) {
      return _illerCache!;
    }

    // Kalıcı önbellek varsa anında onu döndür, API'yi arkada tazele.
    final persisted = await _loadPersistedIller();
    if (persisted != null && persisted.isNotEmpty) {
      _illerCache = persisted;
      unawaited(_fetchAndPersistIller());
      return persisted;
    }

    final fetched = await _fetchAndPersistIller();
    if (fetched != null) return fetched;

    // Fallback - hiç ağ/önbellek yoksa uygulamayla gelen tam liste
    return IlIlceData.getIller();
  }

  static Future<List<Map<String, dynamic>>?> _fetchAndPersistIller() async {
    try {
      final uri = Uri.parse('$_baseUrl/sehirler/2'); // Turkey = 2
      final response = await http
          .get(
            uri,
            headers: {'Accept': 'application/json', 'User-Agent': _userAgent},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        if (decoded is List) {
          _illerCache = decoded
              .map(
                (item) => {
                  'SehirID': item['SehirID']?.toString() ?? '',
                  'SehirAdi': _fixTurkishChars(
                    item['SehirAdi']?.toString() ?? '',
                  ),
                },
              )
              .toList();
          print('✅ ${_illerCache!.length} cities loaded from API');
          unawaited(_savePersistedIller(_illerCache!));
          return _illerCache!;
        }
      }
    } catch (e) {
      print('⚠️ Cities API error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>?> _loadPersistedIller() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_illerPrefsKey);
      if (jsonStr == null) return null;
      final decoded = jsonDecode(jsonStr) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _savePersistedIller(
    List<Map<String, dynamic>> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_illerPrefsKey, jsonEncode(data));
    } catch (_) {
      // Kaydedilemezse sorun değil, bir sonraki açılışta tekrar denenir.
    }
  }

  // Fetch districts from API — aynı kalıcı önbellek + arka plan tazeleme
  // stratejisi.
  static Future<List<Map<String, dynamic>>> getIlceler(String ilId) async {
    if (_ilcelerCache.containsKey(ilId)) {
      return _ilcelerCache[ilId]!;
    }

    final persisted = await _loadPersistedIlceler(ilId);
    if (persisted != null && persisted.isNotEmpty) {
      _ilcelerCache[ilId] = persisted;
      unawaited(_fetchAndPersistIlceler(ilId));
      return persisted;
    }

    final fetched = await _fetchAndPersistIlceler(ilId);
    if (fetched != null) return fetched;

    // Fallback - hiç ağ/önbellek yoksa uygulamayla gelen tam liste
    final yerel = IlIlceData.getIlceler(ilId);
    if (yerel.isNotEmpty) return yerel;
    return [
      {'IlceID': ilId, 'IlceAdi': 'Merkez'},
    ];
  }

  static Future<List<Map<String, dynamic>>?> _fetchAndPersistIlceler(
    String ilId,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/ilceler/$ilId');
      final response = await http
          .get(
            uri,
            headers: {'Accept': 'application/json', 'User-Agent': _userAgent},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        if (decoded is List) {
          final ilceler = decoded
              .map(
                (item) => {
                  'IlceID': item['IlceID']?.toString() ?? '',
                  'IlceAdi': _fixTurkishChars(
                    item['IlceAdi']?.toString() ?? '',
                  ),
                },
              )
              .toList();
          _ilcelerCache[ilId] = List<Map<String, dynamic>>.from(ilceler);
          print('✅ ${ilceler.length} districts loaded from API (city: $ilId)');
          unawaited(_savePersistedIlceler(ilId, _ilcelerCache[ilId]!));
          return _ilcelerCache[ilId]!;
        }
      }
    } catch (e) {
      print('⚠️ Districts API error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>?> _loadPersistedIlceler(
    String ilId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_ilcelerPrefsKeyPrefix$ilId');
      if (jsonStr == null) return null;
      final decoded = jsonDecode(jsonStr) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _savePersistedIlceler(
    String ilId,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_ilcelerPrefsKeyPrefix$ilId', jsonEncode(data));
    } catch (_) {
      // Kaydedilemezse sorun değil, bir sonraki açılışta tekrar denenir.
    }
  }

  // Fix Turkish characters
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


  // Fetch times (cache first, then API if needed)
  // Önbellek, yaşına göre değil bugünü kapsayıp kapsamadığına göre
  // güvenilir sayılır (bkz. [_vakitVerisiBugunuIcerirMi]). API tek istekte
  // ~32 günlük veri döndürdüğü için, internet günlerce kesilse bile o
  // pencere bugünü kapsadığı sürece hiç ağa çıkmadan doğru vakit gösterilir.
  static Future<Map<String, dynamic>?> getVakitler(String ilceId) async {
    // 1. RAM önbelleği bugünü kapsıyorsa anında dön.
    final cachedRam = _vakitCache[ilceId];
    if (cachedRam != null && _vakitVerisiBugunuIcerirMi(cachedRam)) {
      print('📦 Using RAM cache ($ilceId)');
      return cachedRam;
    }

    // 2. Kalıcı önbellek bugünü kapsıyorsa (ağ hiç gerekmeden) onu kullan.
    final savedData = await _loadVakitFromPrefs(ilceId);
    if (savedData != null && _vakitVerisiBugunuIcerirMi(savedData)) {
      _vakitCache[ilceId] = savedData;
      print('💾 Using saved data (covers today): $ilceId');
      return savedData;
    }

    // 3. Hiçbir önbellek bugünü kapsamıyor — taze veri çekmeyi dene.
    print('🌐 Cache does not cover today, fetching from API: $ilceId');
    try {
      final remote = await _fetchRemoteVakitler(ilceId);
      if (remote != null) {
        _vakitCache[ilceId] = remote;
        await _saveVakitToPrefs(ilceId, remote); // Save persistently
        print('✅ API data fetched and saved: $ilceId');
        return remote;
      }
    } catch (e) {
      print('⚠️ Live times fetch failed ($ilceId): $e');
    }

    // 4. Çevrimdışı ve taze veri alınamadı — elde ne varsa (bugünü
    // kapsamasa bile) en son çare olarak döndür; hiç veri yoktansa
    // en güncel bilinen veriyi göstermek daha iyidir.
    if (cachedRam != null) {
      print('ℹ️ Offline, using stale RAM cache: $ilceId');
      return cachedRam;
    }
    if (savedData != null) {
      print('ℹ️ Offline, using stale persisted cache: $ilceId');
      return savedData;
    }

    print('❌ API fetch failed and no cache available: $ilceId');
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchRemoteVakitler(
    String ilceId,
  ) async {
    final uri = Uri.parse('$_baseUrl/vakitler/$ilceId');
    final response = await http
        .get(
          uri,
          headers: {'Accept': 'application/json', 'User-Agent': _userAgent},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      if (response.statusCode == 500) {
        print(
          '❌ District ID "$ilceId" is not supported by the API. Please choose a different location.',
        );
      } else {
        print('⚠️ Times request failed (${response.statusCode}): $ilceId');
      }
      return null;
    }

    final body = utf8.decode(response.bodyBytes);
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      print('⚠️ Unexpected times format: $ilceId');
      return null;
    }

    final vakitler = decoded
        .whereType<Map<String, dynamic>>()
        .map(_normalizeVakitEntry)
        .toList();

    if (vakitler.isEmpty) {
      print('⚠️ Empty times data returned: $ilceId');
      return null;
    }

    print('✅ Times fetched live: $ilceId');
    return {'IlceID': ilceId, 'vakitler': vakitler};
  }

  static Map<String, dynamic> _normalizeVakitEntry(Map<String, dynamic> raw) {
    // API already returns correct format (e.g. "16.01.2026")
    // No transformation needed
    return Map<String, dynamic>.from(raw);
  }
}
