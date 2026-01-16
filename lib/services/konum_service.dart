import 'package:shared_preferences/shared_preferences.dart';

class KonumService {
  static const String _ilKey = 'selected_il';
  static const String _ilIdKey = 'selected_il_id';
  static const String _ilceKey = 'selected_ilce';
  static const String _ilceIdKey = 'selected_ilce_id';

  // Seçilen il bilgisini kaydet
  static Future<void> setIl(String ilAdi, String ilId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ilKey, ilAdi);
    await prefs.setString(_ilIdKey, ilId);
  }

  // Seçilen ilçe bilgisini kaydet
  static Future<void> setIlce(String ilceAdi, String ilceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ilceKey, ilceAdi);
    await prefs.setString(_ilceIdKey, ilceId);
  }

  // Kaydedilen il adını getir
  static Future<String?> getIl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilKey);
  }

  // Kaydedilen il ID'sini getir
  static Future<String?> getIlId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilIdKey);
  }

  // Kaydedilen ilçe adını getir
  static Future<String?> getIlce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilceKey);
  }

  // Kaydedilen ilçe ID'sini getir
  static Future<String?> getIlceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilceIdKey);
  }

  // Tüm konum bilgilerini temizle
  static Future<void> clearKonum() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ilKey);
    await prefs.remove(_ilIdKey);
    await prefs.remove(_ilceKey);
    await prefs.remove(_ilceIdKey);
  }
}
