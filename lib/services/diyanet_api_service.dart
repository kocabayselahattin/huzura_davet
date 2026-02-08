import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'namazvakti_api_service.dart';
import 'aladhan_api_service.dart';
import 'konum_service.dart';

class DiyanetApiService {
  static const _baseUrl = 'https://ezanvakti.emushaf.net';
  static const _userAgent = 'HuzurVaktiApp/1.0';
  static final Map<String, Map<String, dynamic>> _vakitCache = {};
  static final Map<String, DateTime> _vakitCacheTimes = {};

  // City and district cache
  static List<Map<String, dynamic>>? _illerCache;
  static final Map<String, List<Map<String, dynamic>>> _ilcelerCache = {};

  // Monthly times cache
  static final Map<String, List<Map<String, dynamic>>> _aylikVakitCache = {};

  // Clear cache
  static void clearCache() {
    _vakitCache.clear();
    _vakitCacheTimes.clear();
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

  // Load cache from SharedPreferences
  static Future<Map<String, dynamic>?> _loadVakitFromPrefs(
    String ilceId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('vakit_cache_$ilceId');
      final cacheTime = prefs.getInt('vakit_cache_time_$ilceId');

      if (jsonStr != null && cacheTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
        final now = DateTime.now();

        // Do not use cache older than 7 days
        if (now.difference(cacheDate).inDays < 7) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          debugPrint('📂 Cached prayer data loaded: $ilceId');
          return data;
        } else {
          debugPrint(
            '⏰ Cached data too old (${now.difference(cacheDate).inDays} days)',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Cache load error: $e');
    }
    return null;
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

  // Load monthly cache from SharedPreferences
  static Future<List<Map<String, dynamic>>?> _loadAylikVakitFromPrefs(
    String cacheKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('aylik_vakit_$cacheKey');
      final cacheTime = prefs.getInt('aylik_vakit_time_$cacheKey');

      if (jsonStr != null && cacheTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
        final now = DateTime.now();

        // Do not use cache older than 30 days
        if (now.difference(cacheDate).inDays < 30) {
          final data = jsonDecode(jsonStr) as List;
          final result = data
              .map((item) => item as Map<String, dynamic>)
              .toList();
          debugPrint('📂 Cached monthly data loaded: $cacheKey');
          return result;
        } else {
          debugPrint(
            '⏰ Cached monthly data too old (${now.difference(cacheDate).inDays} days)',
          );
        }
      }
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

    // 1. Return from RAM cache if available
    if (_aylikVakitCache.containsKey(cacheKey)) {
      print('📦 Using monthly RAM cache: $cacheKey');
      return _aylikVakitCache[cacheKey]!;
    }

    // 2. Load from SharedPreferences
    final savedData = await _loadAylikVakitFromPrefs(cacheKey);
    if (savedData != null && savedData.isNotEmpty) {
      _aylikVakitCache[cacheKey] = savedData;
      print('💾 Using saved monthly data: $cacheKey');
      return savedData;
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

          // Return requested month
          if (ayGruplari.containsKey(cacheKey)) {
            print(
              '✅ Monthly times fetched and saved: $cacheKey (${ayGruplari[cacheKey]!.length} days)',
            );
            return ayGruplari[cacheKey]!;
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
      final aladhanVakitler = await AladhanApiService.getAylikVakitler(
        yil: yil,
        ay: ay,
        city: 'Istanbul', // TODO: Determine city from district ID
        country: 'Turkey',
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

  // Fetch cities from API
  static Future<List<Map<String, dynamic>>> getIller() async {
    if (_illerCache != null) {
      return _illerCache!;
    }

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
          return _illerCache!;
        }
      }
    } catch (e) {
      print('⚠️ Cities API error: $e');
    }

    // Fallback - default cities
    return _getDefaultIller();
  }

  // Fetch districts from API
  static Future<List<Map<String, dynamic>>> getIlceler(String ilId) async {
    if (_ilcelerCache.containsKey(ilId)) {
      return _ilcelerCache[ilId]!;
    }

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
          return _ilcelerCache[ilId]!;
        }
      }
    } catch (e) {
      print('⚠️ Districts API error: $e');
    }

    // Fallback - default district (city center)
    return [
      {'IlceID': ilId, 'IlceAdi': 'Merkez'},
    ];
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

  // Default cities list (fallback)
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

  // Fetch times (cache first, then API if needed)
  // Cache duration: 7 days - user can manually refresh
  static Future<Map<String, dynamic>?> getVakitler(String ilceId) async {
    final now = DateTime.now();

    // 1. Check RAM cache (fast access)
    final cached = _vakitCache[ilceId];
    final cachedTime = _vakitCacheTimes[ilceId];
    if (cached != null && cachedTime != null) {
      // Use RAM cache if newer than 7 days
      if (now.difference(cachedTime).inDays < 7) {
        print(
          '📦 Using RAM cache ($ilceId) - ${now.difference(cachedTime).inDays} days ago',
        );
        return cached;
      }
    }

    // 2. Check saved data from SharedPreferences (7-day cache)
    final savedData = await _loadVakitFromPrefs(ilceId);
    if (savedData != null) {
      // Load into RAM cache (fast access)
      _vakitCache[ilceId] = savedData;
      _vakitCacheTimes[ilceId] = now;
      print('💾 Using saved data (7-day cache): $ilceId');
      return savedData;
    }

    // 3. If no cache or too old, fetch from API
    print('🌐 No cache or stale, fetching from API: $ilceId');
    try {
      final remote = await _fetchRemoteVakitler(ilceId);
      if (remote != null) {
        _vakitCache[ilceId] = remote;
        _vakitCacheTimes[ilceId] = now;
        await _saveVakitToPrefs(ilceId, remote); // Save persistently
        print('✅ API data fetched and saved: $ilceId');
        return remote;
      }
    } catch (e) {
      print('⚠️ Live times fetch failed ($ilceId): $e');
    }

    // 4. If offline and RAM cache exists, use it
    if (cached != null) {
      print('ℹ️ Offline, using older RAM cache: $ilceId');
      return cached;
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
