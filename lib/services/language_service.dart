import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  Map<String, dynamic> _localizedStrings = {};
  Map<String, dynamic> _fallbackStrings = {};
  String _currentLanguage = 'tr';

  String get currentLanguage => _currentLanguage;

  List<Map<String, String>> get supportedLanguages => [
    {'code': 'tr', 'name': 'Turkish', 'flag': '🇹🇷'},
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
      String jsonString = await rootBundle.loadString(
        'assets/lang/$_currentLanguage.json',
      );
      _localizedStrings = json.decode(jsonString);

      // NOTE: Do not persist language selection here - user must choose.
      // Only save if already selected via changeLanguage.
    } catch (e) {
      print(
        '⚠️ Language file load failed ($_currentLanguage), falling back to Turkish: $e',
      );
      _currentLanguage = 'tr';
      String jsonString = await rootBundle.loadString('assets/lang/tr.json');
      _localizedStrings = json.decode(jsonString);
    }

    await _ensureFallbackLoaded();

    notifyListeners();
  }

  Future<void> _ensureFallbackLoaded() async {
    if (_fallbackStrings.isNotEmpty) return;
    try {
      String jsonString = await rootBundle.loadString('assets/lang/en.json');
      _fallbackStrings = json.decode(jsonString);
    } catch (e) {
      _fallbackStrings = {};
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('language');
    if (_currentLanguage == languageCode && saved == languageCode) {
      return;
    }
    await prefs.setString('language', languageCode);
    await load(languageCode);
  }

  String? translate(String key) {
    final value = _localizedStrings[key] ?? _fallbackStrings[key];
    if (value is String) {
      return value;
    }
    return null;
  }

  /// Return non-string values (List, Map, etc.)
  dynamic get(String key) {
    return _localizedStrings.containsKey(key)
        ? _localizedStrings[key]
        : _fallbackStrings[key];
  }

  dynamic operator [](String key) => get(key);
}
