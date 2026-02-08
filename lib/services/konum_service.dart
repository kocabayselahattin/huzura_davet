import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/konum_model.dart';

class KonumService {
  static const String _ilKey = 'selected_il';
  static const String _ilIdKey = 'selected_il_id';
  static const String _ilceKey = 'selected_ilce';
  static const String _ilceIdKey = 'selected_ilce_id';
  static const String _konumlarKey = 'saved_locations'; // Multi-location list
  static const String _aktifKonumIndexKey =
      'active_location_index'; // Active location index
  static const String _manualKonumPrefix = 'manual:';
  static const String _manualKonumKeyPrefix = 'manual_konum_';

  static bool isManualIlceId(String? ilceId) {
    return ilceId != null && ilceId.startsWith(_manualKonumPrefix);
  }

  static Future<void> setManualKonumData({
    required String key,
    required double lat,
    required double lon,
    required String city,
    required String country,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'lat': lat,
      'lon': lon,
      'city': city,
      'country': country,
    });
    await prefs.setString('$_manualKonumKeyPrefix$key', payload);
  }

  static Future<Map<String, dynamic>?> getManualKonumData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString('$_manualKonumKeyPrefix$key');
    if (payload == null || payload.isEmpty) return null;
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Save selected city
  static Future<void> setIl(String ilAdi, String ilId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ilKey, ilAdi);
    await prefs.setString(_ilIdKey, ilId);
  }

  // Save selected district
  static Future<void> setIlce(String ilceAdi, String ilceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ilceKey, ilceAdi);
    await prefs.setString(_ilceIdKey, ilceId);
  }

  // Get saved city name
  static Future<String?> getIl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilKey);
  }

  // Get saved city ID
  static Future<String?> getIlId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilIdKey);
  }

  // Get saved district name
  static Future<String?> getIlce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilceKey);
  }

  // Get saved district ID
  static Future<String?> getIlceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilceIdKey);
  }

  // Check if district ID is valid
  // Some legacy IDs do not work in the API (e.g. 1219, 1823, 1421)
  static Future<bool> isIlceIdValid(String? ilceId) async {
    if (ilceId == null || ilceId.isEmpty) return false;

    // Known invalid IDs (legacy local IDs that cause 500/400 errors in API)
    const invalidIds = [
      '1219', '1823', '1020', '1003', '1421', // Legacy system IDs
      '1200', '1201', '1202', '1203', '1204', '1205', // Other legacy IDs
    ];
    if (invalidIds.contains(ilceId)) {
      return false;
    }

    // Valid IDs are usually in 9000-18000 range (new system)
    try {
      final idNum = int.parse(ilceId);
      if (idNum < 9000 || idNum > 20000) {
        return false;
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  // Clear if location is invalid
  static Future<bool> validateAndClearIfInvalid() async {
    final ilceId = await getIlceId();
    final isValid = await isIlceIdValid(ilceId);

    if (!isValid && ilceId != null) {
      debugPrint(
        '⚠️ Invalid district ID detected: $ilceId - clearing...',
      );
      await clearKonum();
      return false;
    }

    return isValid;
  }

  // Clear all location data
  static Future<void> clearKonum() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ilKey);
    await prefs.remove(_ilIdKey);
    await prefs.remove(_ilceKey);
    await prefs.remove(_ilceIdKey);
  }

  // ============ MULTI-LOCATION SYSTEM ============

  // Get all saved locations
  static Future<List<KonumModel>> getKonumlar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_konumlarKey) ?? [];

    if (jsonList.isEmpty) {
      // If a legacy location exists, add it to the list
      final il = prefs.getString(_ilKey);
      final ilId = prefs.getString(_ilIdKey);
      final ilce = prefs.getString(_ilceKey);
      final ilceId = prefs.getString(_ilceIdKey);

      if (il != null && ilId != null && ilce != null && ilceId != null) {
        final eskiKonum = KonumModel(
          ilAdi: il,
          ilId: ilId,
          ilceAdi: ilce,
          ilceId: ilceId,
          aktif: true,
        );
        // Save directly - do not call addKonum (avoid infinite loop)
        await prefs.setStringList(_konumlarKey, [
          jsonEncode(eskiKonum.toJson()),
        ]);
        return [eskiKonum];
      }
      return [];
    }

    return jsonList
        .map((json) => KonumModel.fromJson(jsonDecode(json)))
        .toList();
  }

  // Add new location
  static Future<void> addKonum(KonumModel konum) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_konumlarKey) ?? [];
    final konumlar = jsonList
        .map((json) => KonumModel.fromJson(jsonDecode(json)))
        .toList();

    // Do not add duplicates
    if (konumlar.any((k) => k.ilceId == konum.ilceId && k.ilId == konum.ilId)) {
      debugPrint('⚠️ Location already saved: ${konum.tamAd}');
      return;
    }

    // Add new location
    konumlar.add(konum);
    await _saveKonumlar(konumlar);
    debugPrint('✅ Location added: ${konum.tamAd}');
  }

  // Remove location
  static Future<void> removeKonum(int index) async {
    final konumlar = await getKonumlar();

    if (index >= 0 && index < konumlar.length) {
      final silinenKonum = konumlar[index];
      konumlar.removeAt(index);
      await _saveKonumlar(konumlar);

      // If active location was removed, make the first active
      final aktifIndex = await getAktifKonumIndex();
      if (aktifIndex == index && konumlar.isNotEmpty) {
        await setAktifKonumIndex(0);
      }

      debugPrint('✅ Location removed: ${silinenKonum.tamAd}');
    }
  }

  // Get active location index
  static Future<int> getAktifKonumIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_aktifKonumIndexKey) ?? 0;
  }

  // Set active location index
  static Future<void> setAktifKonumIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aktifKonumIndexKey, index);

    // Also save active location to legacy system (compatibility)
    final konumlar = await getKonumlar();
    if (index >= 0 && index < konumlar.length) {
      final aktifKonum = konumlar[index];
      await setIl(aktifKonum.ilAdi, aktifKonum.ilId);
      await setIlce(aktifKonum.ilceAdi, aktifKonum.ilceId);
      debugPrint('✅ Active location changed: ${aktifKonum.tamAd}');
    }
  }

  // Get active location
  static Future<KonumModel?> getAktifKonum() async {
    final konumlar = await getKonumlar();
    final index = await getAktifKonumIndex();

    if (konumlar.isEmpty) return null;
    if (index >= 0 && index < konumlar.length) {
      return konumlar[index];
    }
    return konumlar.first;
  }

  // Save locations (private)
  static Future<void> _saveKonumlar(List<KonumModel> konumlar) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = konumlar.map((k) => jsonEncode(k.toJson())).toList();
    await prefs.setStringList(_konumlarKey, jsonList);
  }

  // ============ COMPASS STYLE ============
  static const String _pusulaStiliKey = 'compass_style';

  // Save compass style
  static Future<void> setPusulaStili(int styleIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pusulaStiliKey, styleIndex);
  }

  // Get compass style (default: 0 - Modern)
  static Future<int> getPusulaStili() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pusulaStiliKey) ?? 0;
  }
}
