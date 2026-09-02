import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Kütüphane > Hadisler'de gösterilen tek bir hadis kaydı.
class HadisKaydi {
  final String id;
  final String kategori;
  final String metin;
  final String kaynak;

  const HadisKaydi({
    required this.id,
    required this.kategori,
    required this.metin,
    required this.kaynak,
  });
}

/// Kütüphane > Hadisler sayfasını besler. Veri, "günün hadisi" kartıyla
/// aynı kaynaktan (Riyâzü's-Sâlihîn, bkz. GunlukHadisDuaService) gelir;
/// ayrı bir veri dosyası gerekmez, aynı iki asset (havuz + metinler)
/// burada da okunur.
class HadisKutuphanesiService {
  static const String _havuzAsset = 'assets/data/gunluk_icerik_havuzu.json';
  static const String _metinlerAsset = 'assets/data/gunluk_icerik_metinleri.json';
  static const String _favoriAnahtari = 'hadis_favorileri';

  static List<HadisKaydi>? _tumHadisler;
  static Future<List<HadisKaydi>>? _yuklemeFuture;

  static Future<List<HadisKaydi>> tumHadisler() {
    if (_tumHadisler != null) return Future.value(_tumHadisler);
    return _yuklemeFuture ??= _yukle();
  }

  static Future<List<HadisKaydi>> _yukle() async {
    try {
      final havuzStr = await rootBundle.loadString(_havuzAsset);
      final metinlerStr = await rootBundle.loadString(_metinlerAsset);
      final havuz = json.decode(havuzStr) as Map<String, dynamic>;
      final metinler = json.decode(metinlerStr) as Map<String, dynamic>;

      final kaynaklar = (havuz['hadis'] as List?) ?? const [];
      final hadisler = <HadisKaydi>[];
      for (final kaynak in kaynaklar) {
        if (kaynak is! Map) continue;
        final kitap = kaynak['kitap']?.toString() ?? '';
        final nolar = (kaynak['nolar'] as List?)?.whereType<int>() ?? const [];
        for (final no in nolar) {
          final key = '$kitap/$no';
          final kayit = metinler[key];
          if (kayit is! Map) continue;
          final metin = kayit['text']?.toString() ?? '';
          if (metin.isEmpty) continue;
          final kaynakMetni = kayit['source']?.toString() ?? '';
          final ayracIndex = kaynakMetni.indexOf(' — ');
          final baslik = ayracIndex >= 0
              ? kaynakMetni.substring(0, ayracIndex)
              : 'Hadis';
          final atif = ayracIndex >= 0
              ? kaynakMetni.substring(ayracIndex + 3)
              : kaynakMetni;
          hadisler.add(
            HadisKaydi(id: key, kategori: baslik, metin: metin, kaynak: atif),
          );
        }
      }
      _tumHadisler = hadisler;
      return hadisler;
    } catch (_) {
      _yuklemeFuture = null;
      return const [];
    }
  }

  /// Kategorileri (konu başlıklarını), kayıt sayısıyla birlikte alfabetik
  /// sırada döndürür.
  static Future<List<MapEntry<String, int>>> kategoriler() async {
    final hadisler = await tumHadisler();
    final sayac = <String, int>{};
    for (final h in hadisler) {
      sayac[h.kategori] = (sayac[h.kategori] ?? 0) + 1;
    }
    final girdiler = sayac.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return girdiler;
  }

  static Future<List<HadisKaydi>> kategoriyeGoreHadisler(
    String kategori,
  ) async {
    final tumu = await tumHadisler();
    return tumu.where((h) => h.kategori == kategori).toList();
  }

  static Future<Set<String>> favoriIdleri() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoriAnahtari) ?? const []).toSet();
  }

  static Future<bool> favoriDegistir(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriler = (prefs.getStringList(_favoriAnahtari) ?? const [])
        .toSet();
    final eklendiMi = !favoriler.contains(id);
    if (eklendiMi) {
      favoriler.add(id);
    } else {
      favoriler.remove(id);
    }
    await prefs.setStringList(_favoriAnahtari, favoriler.toList());
    return eklendiMi;
  }

  static Future<List<HadisKaydi>> favoriHadisler() async {
    final favoriler = await favoriIdleri();
    if (favoriler.isEmpty) return const [];
    final tumu = await tumHadisler();
    return tumu.where((h) => favoriler.contains(h.id)).toList();
  }
}
