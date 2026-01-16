import 'dart:convert';
import 'package:http/http.dart' as http;

class DiyanetApiService {
  static const String baseUrl = 'https://ezanvakti.herokuapp.com';

  // Tüm illeri getir
  static Future<List<Map<String, dynamic>>> getIller() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sehirler'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('İller alınırken hata: $e');
      return [];
    }
  }

  // İlçeleri getir
  static Future<List<Map<String, dynamic>>> getIlceler(String ilId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ilceler/$ilId'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('İlçeler alınırken hata: $e');
      return [];
    }
  }

  // Vakit saatlerini getir
  static Future<Map<String, dynamic>?> getVakitler(String ilceId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/vakitler/$ilceId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Vakitler alınırken hata: $e');
      return null;
    }
  }
}
