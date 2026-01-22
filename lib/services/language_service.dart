import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  Map<String, dynamic> _localizedStrings = {};
  String _currentLanguage = 'tr';

  String get currentLanguage => _currentLanguage;

  List<Map<String, String>> get supportedLanguages => [
    {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'fa', 'name': 'فارسی', 'flag': '🇮🇷'},
  ];

  Future<void> load([String? languageCode]) async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = languageCode ?? prefs.getString('language') ?? 'tr';
    
    try {
      String jsonString = await rootBundle.loadString('assets/lang/$_currentLanguage.json');
      _localizedStrings = json.decode(jsonString);
      
      // Dil tercihini kaydet (ilk açılışta da kaydedilmiş olsun)
      if (!prefs.containsKey('language')) {
        await prefs.setString('language', _currentLanguage);
      }
    } catch (e) {
      print('⚠️ Dil dosyası yüklenemedi ($_currentLanguage), Türkçe yükleniyor: $e');
      _currentLanguage = 'tr';
      String jsonString = await rootBundle.loadString('assets/lang/tr.json');
      _localizedStrings = json.decode(jsonString);
      await prefs.setString('language', _currentLanguage);
    }
    
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    await load(languageCode);
  }

  String? translate(String key) {
    return _localizedStrings[key] as String?;
  }

  String? operator [](String key) => translate(key);
}
