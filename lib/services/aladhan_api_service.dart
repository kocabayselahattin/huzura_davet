import 'dart:convert';
import 'package:http/http.dart' as http;

class AladhanApiService {
  static const _baseUrl = 'https://api.aladhan.com/v1';
  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  // Example: Ankara, Turkey (lat: 39.9334, long: 32.8597)
  static Future<Map<String, String>?> getBugunVakitler({
    double latitude = 39.9334,
    double longitude = 32.8597,
    String method = '13', // Diyanet Affairs (Turkey)
    String? timeZone,
    DateTime? date,
  }) async {
    final dt = date ?? DateTime.now();
    final dateStr = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
    final timeZoneParam =
        timeZone == null || timeZone.isEmpty ? '' : '&timezonestring=$timeZone';
    final url =
        '$_baseUrl/timings/$dateStr?latitude=$latitude&longitude=$longitude&method=$method&school=1$timeZoneParam';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final timings = decoded['data']['timings'];
        return {
          'Imsak': timings['Fajr'] ?? '-',
          'Gunes': timings['Sunrise'] ?? '-',
          'Ogle': timings['Dhuhr'] ?? '-',
          'Ikindi': timings['Asr'] ?? '-',
          'Aksam': timings['Maghrib'] ?? '-',
          'Yatsi': timings['Isha'] ?? '-',
        };
      }
    } catch (e) {
      print('Aladhan API error: $e');
    }
    return null;
  }

  /// Fetch times for a specific month (for timetable)
  static Future<List<Map<String, dynamic>>> getAylikVakitler({
    required int yil,
    required int ay,
    String city = 'Istanbul',
    String country = 'Turkey',
  }) async {
    final cacheKey = '$city-$yil-$ay';
    
    // Cache check
    if (_cache.containsKey(cacheKey)) {
      print('📦 Aladhan cache: $cacheKey');
      return _cache[cacheKey]!;
    }

    try {
      // Method 13 = Diyanet Affairs (Turkey)
      final uri = Uri.parse(
        '$_baseUrl/calendarByCity/$yil/$ay?city=$city&country=$country&method=13'
      );
      
      print('🌍 Aladhan API request: $uri');
      
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'HuzurVaktiApp/1.0',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        
        if (decoded['code'] == 200 && decoded['data'] is List) {
          final vakitler = <Map<String, dynamic>>[];
          
          for (var gunData in decoded['data']) {
            final timings = gunData['timings'];
            final date = gunData['date']['gregorian'];
            final hijri = gunData['date']['hijri'];
            
            vakitler.add({
              'MiladiTarihKisa': '${date['day']}.${date['month']['number']}.${date['year']}',
              'MiladiTarihUzun': '${date['day']} ${date['month']['en']} ${date['year']} ${date['weekday']['en']}',
              'HicriTarihKisa': '${hijri['day']}.${hijri['month']['number']}.${hijri['year']}',
              'HicriTarihUzun': '${hijri['day']} ${hijri['month']['en']} ${hijri['year']}',
              'Imsak': _cleanTime(timings['Fajr']),
              'Gunes': _cleanTime(timings['Sunrise']),
              'Ogle': _cleanTime(timings['Dhuhr']),
              'Ikindi': _cleanTime(timings['Asr']),
              'Aksam': _cleanTime(timings['Maghrib']),
              'Yatsi': _cleanTime(timings['Isha']),
            });
          }
          
          if (vakitler.isNotEmpty) {
            _cache[cacheKey] = vakitler;
            print('✅ Aladhan API success: $cacheKey (${vakitler.length} days)');
            return vakitler;
          }
        }
      }
    } catch (e) {
      print('⚠️ Aladhan API error ($cacheKey): $e');
    }

    return [];
  }

  /// Clean time string (remove timezone)
  static String _cleanTime(String time) {
    // "07:30 (EET)" -> "07:30"
    return time.split(' ')[0];
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
    print('✅ Aladhan API cache cleared');
  }
}
