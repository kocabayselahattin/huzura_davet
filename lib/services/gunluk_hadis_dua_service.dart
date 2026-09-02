import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'kuran_veri_service.dart';
import 'language_service.dart';

/// Günün ayeti / hadisi / duası için **tek kaynak**.
///
/// Hem ana ekrandaki "Günün İçeriği" kartı hem de günlük içerik bildirimleri
/// buradan beslenir; böylece ikisi her zaman aynı içeriği gösterir.
///
/// - Ayet: cihazda gömülü tam Kur'an'dan (Elmalılı Hamdi Yazır meali) —
///   tarihe göre deterministik, internet gerektirmez.
/// - Hadis / Dua: cihazda gömülü, önceden indirilmiş Sahih-i Buhârî Türkçe
///   çevirisinden (bkz. assets/data/gunluk_icerik_metinleri.json — kaynağı
///   fawazahmed0/hadith-api, tool/gunluk_icerik_indir.dart ile tek seferlik
///   indirilip pakete gömüldü). Bu sayede uygulama içerik için ağa hiç
///   bağımlı değildir; dış CDN kapansa/değişse bile hiçbir şey etkilenmez.
/// - Sonuç yine de **tarih anahtarlı** önbelleğe yazılır; bildirimler ileri
///   tarihler için önceden hazırlandığında o gün gelince kart aynı
///   önbellekten okur ve içerik birebir aynı olur.
/// - Havuzdaki bir numara herhangi bir nedenle yerel metinler dosyasında
///   bulunamazsa (ör. gelecekte havuz güncellenip metin dosyası eşlenmezse)
///   dil dosyasındaki küçük yedek havuza düşülür.
class GunlukHadisDuaService {
  /// Havuz dosyası: hangi kitabın hangi hadis numaralarının günlük içerik
  /// olarak kullanılabileceğini tutar (metinlerin kendisi değil, yalnızca
  /// numaralar — gerçek metinler [_metinlerAsset] içinde).
  ///
  /// Numaralar önceden süzülmüştür (çeviri mevcut ve karta/bildirime sığacak
  /// uzunlukta). Aksi halde uygun içeriği bulmak için ileri arama gerekiyor ve
  /// ardışık günler aynı hadise düşebiliyordu.
  static const _havuzAsset = 'assets/data/gunluk_icerik_havuzu.json';

  /// "kitap/no" -> {text, source} eşlemesini tutan, cihazda gömülü metin
  /// dosyası (bkz. tool/gunluk_icerik_indir.dart).
  static const _metinlerAsset = 'assets/data/gunluk_icerik_metinleri.json';

  static List<_HavuzKaynagi>? _hadisKaynaklari;
  static List<_HavuzKaynagi>? _duaKaynaklari;
  static Map<String, dynamic>? _metinler;
  static Future<void>? _havuzFuture;

  /// Havuzdaki numaralar kaynak kitapta olduğu sırayla (konu/bölüm sırasıyla)
  /// durduğu için sıra numarasını doğrudan kullanmak, bir kitabın tek bir
  /// konusunun (ör. "Kitâbü'l-İstiskâ" / yağmur duası bölümü) art arda onlarca
  /// gün gösterilmesine yol açar. Sabit tohumlu bir karıştırma ile sıra
  /// numarasını havuz içinde deterministik ama "dağınık" bir konuma
  /// eşleştiriyoruz; tarihe göre sonuç yine sabit kalır (kart/bildirim
  /// tutarlılığı bozulmaz), sadece ardışık günler artık aynı bölüme denk
  /// gelmez.
  static const int _karistirmaTohumu = 20240101;
  static List<int>? _hadisKarisikSira;
  static List<int>? _duaKarisikSira;

  static List<int> _karisikSiraOlustur(int uzunluk) {
    final sira = List<int>.generate(uzunluk, (i) => i);
    final rastgele = Random(_karistirmaTohumu);
    for (var i = uzunluk - 1; i > 0; i--) {
      final j = rastgele.nextInt(i + 1);
      final gecici = sira[i];
      sira[i] = sira[j];
      sira[j] = gecici;
    }
    return sira;
  }

  static Future<void> _havuzuYukle() {
    if (_hadisKaynaklari != null) return Future.value();
    return _havuzFuture ??= _havuzuOku();
  }

  static Future<void> _havuzuOku() async {
    try {
      final jsonStr = await rootBundle.loadString(_havuzAsset);
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      _hadisKaynaklari = _kaynaklariAyristir(data['hadis']);
      _duaKaynaklari = _kaynaklariAyristir(data['dua']);
      _hadisKarisikSira = _karisikSiraOlustur(
        _hadisKaynaklari!.fold<int>(0, (t, k) => t + k.nolar.length),
      );
      _duaKarisikSira = _karisikSiraOlustur(
        _duaKaynaklari!.fold<int>(0, (t, k) => t + k.nolar.length),
      );

      final metinlerStr = await rootBundle.loadString(_metinlerAsset);
      _metinler = json.decode(metinlerStr) as Map<String, dynamic>;
    } catch (_) {
      _havuzFuture = null;
    }
  }

  static List<_HavuzKaynagi> _kaynaklariAyristir(dynamic liste) {
    if (liste is! List) return [];
    return liste
        .whereType<Map<String, dynamic>>()
        .map(
          (k) => _HavuzKaynagi(
            kitap: k['kitap']?.toString() ?? '',
            kisaAd: k['kisa']?.toString() ?? '',
            nolar: (k['nolar'] as List?)?.whereType<int>().toList() ?? const [],
          ),
        )
        .where((k) => k.kitap.isNotEmpty && k.nolar.isNotEmpty)
        .toList();
  }

  static String _gunAnahtari(DateTime tarih) =>
      '${tarih.year}-${tarih.month}-${tarih.day}';

  static String _cacheMetinKey(String tur, DateTime tarih) =>
      'gunluk_${tur}_metin_${_gunAnahtari(tarih)}';

  static String _cacheKaynakKey(String tur, DateTime tarih) =>
      'gunluk_${tur}_kaynak_${_gunAnahtari(tarih)}';

  /// Referans tarihten bu yana geçen gün sayısı (tarihe göre deterministik).
  static int _gunSayisi(DateTime tarih) {
    final referans = DateTime(2024, 1, 1);
    final bugun = DateTime(tarih.year, tarih.month, tarih.day);
    return bugun.difference(referans).inDays;
  }

  /// Birden fazla kitabın numara listelerini tek bir sıralı havuz gibi ele
  /// alır; verilen sıra numarasının hangi kitabın hangi hadisine denk
  /// geldiğini döndürür. Havuzdaki her numara kullanılabilir olduğu için
  /// ardışık günler farklı içerik alır.
  static ({String kitap, String kisaAd, int no})? _havuzKonumu(
    List<_HavuzKaynagi> kaynaklar,
    List<int> karisikSira,
    int sira,
  ) {
    final toplam = kaynaklar.fold<int>(0, (t, k) => t + k.nolar.length);
    if (toplam == 0) return null;
    final duzSira = ((sira % toplam) + toplam) % toplam;
    var kalan = karisikSira[duzSira];
    for (final kaynak in kaynaklar) {
      if (kalan < kaynak.nolar.length) {
        return (
          kitap: kaynak.kitap,
          kisaAd: kaynak.kisaAd,
          no: kaynak.nolar[kalan],
        );
      }
      kalan -= kaynak.nolar.length;
    }
    return null;
  }

  /// Yerel yedek havuz için ay bazında dönen index (eski davranışla aynı).
  static int _yerelIndex({
    required DateTime date,
    required int length,
    required int contentOffset,
  }) {
    if (length <= 0) return 0;
    final monthKey = date.year * 12 + date.month;
    final monthOffset = (monthKey * 17 + contentOffset) % length;
    final dayOffset = date.day - 1;
    return (monthOffset + dayOffset) % length;
  }

  /// Yerel metin havuzundan tek bir hadis/dua metnini bulur ("kitap/no"
  /// anahtarıyla). Metin indirme sırasında zaten temizlenmiş olarak
  /// kaydedildiği için burada ek işleme gerek yoktur (bkz.
  /// tool/gunluk_icerik_indir.dart).
  static Map<String, String>? _hadisNoBul(String kitap, int no) {
    final kayit = _metinler?['$kitap/$no'];
    if (kayit is! Map) return null;
    final metin = kayit['text']?.toString() ?? '';
    if (metin.isEmpty) return null;
    return {
      'text': metin,
      'source': kayit['source']?.toString() ?? '',
    };
  }

  /// Havuzdaki [baslangicSira] konumundan başlayarak, yerel metin dosyasında
  /// karşılığı bulunan ilk hadisi döndürür. Numaralar önceden süzülüp
  /// indirildiği için ilk deneme normalde başarılı olur; ek denemeler
  /// yalnızca (teorik olarak) eksik kalmış birkaç kayda karşıdır.
  static Map<String, String>? _uygunHadisBul({
    required List<_HavuzKaynagi> kaynaklar,
    required List<int> karisikSira,
    required int baslangicSira,
    int denemeSayisi = 3,
  }) {
    for (int i = 0; i < denemeSayisi; i++) {
      final konum = _havuzKonumu(kaynaklar, karisikSira, baslangicSira + i);
      if (konum == null) return null;
      final sonuc = _hadisNoBul(konum.kitap, konum.no);
      if (sonuc != null && (sonuc['text'] ?? '').isNotEmpty) {
        return sonuc;
      }
    }
    return null;
  }

  static Map<String, String> _yerelHavuzdan({
    required String listeAnahtari,
    required DateTime tarih,
    required int contentOffset,
  }) {
    final liste = LanguageService()[listeAnahtari];
    if (liste is List && liste.isNotEmpty) {
      final index = _yerelIndex(
        date: tarih,
        length: liste.length,
        contentOffset: contentOffset,
      );
      final oge = liste[index];
      if (oge is Map) {
        return {
          'text': oge['text']?.toString() ?? '',
          'source': oge['source']?.toString() ?? '',
        };
      }
    }
    return {'text': '', 'source': ''};
  }

  /// Günün ayeti — gömülü tam Kur'an'dan, tarihe göre deterministik.
  /// Kur'an verisi henüz yüklenmemişse yerel havuza düşer.
  static Map<String, String> gununAyeti(DateTime tarih) {
    if (KuranVeriService.yuklendiMi) {
      final ayet = KuranVeriService.gununAyeti(tarih);
      if ((ayet['text'] ?? '').isNotEmpty) return ayet;
    }
    return _yerelHavuzdan(
      listeAnahtari: 'verses',
      tarih: tarih,
      contentOffset: 0,
    );
  }

  /// Ortak akış: önbellek → gömülü metin havuzu → yedek havuz. Sonuç her
  /// durumda önbelleğe yazılır, böylece kart ve bildirim aynı içeriği gösterir.
  static Future<Map<String, String>> _icerikGetir({
    required String tur,
    required DateTime tarih,
    required bool duaMi,
    required String yerelListeAnahtari,
    required int yerelOffset,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final metinKey = _cacheMetinKey(tur, tarih);
    final kaynakKey = _cacheKaynakKey(tur, tarih);

    final onbellekMetin = prefs.getString(metinKey);
    if (onbellekMetin != null && onbellekMetin.isNotEmpty) {
      return {
        'text': onbellekMetin,
        'source': prefs.getString(kaynakKey) ?? '',
      };
    }

    await _havuzuYukle();
    final kaynaklar =
        (duaMi ? _duaKaynaklari : _hadisKaynaklari) ?? const <_HavuzKaynagi>[];
    final karisikSira =
        (duaMi ? _duaKarisikSira : _hadisKarisikSira) ?? const <int>[];

    final gomuluSonuc = kaynaklar.isEmpty || karisikSira.isEmpty
        ? null
        : _uygunHadisBul(
            kaynaklar: kaynaklar,
            karisikSira: karisikSira,
            baslangicSira: _gunSayisi(tarih),
          );

    final sonuc = gomuluSonuc ??
        _yerelHavuzdan(
          listeAnahtari: yerelListeAnahtari,
          tarih: tarih,
          contentOffset: yerelOffset,
        );

    if ((sonuc['text'] ?? '').isNotEmpty) {
      await prefs.setString(metinKey, sonuc['text']!);
      await prefs.setString(kaynakKey, sonuc['source'] ?? '');
      await _eskiOnbellegiTemizle(prefs);
    }

    return sonuc;
  }

  /// Günün hadisi (Sahih-i Buhârî, Türkçe).
  static Future<Map<String, String>> gununHadisi(DateTime tarih) {
    return _icerikGetir(
      tur: 'hadis',
      tarih: tarih,
      duaMi: false,
      yerelListeAnahtari: 'hadiths',
      yerelOffset: 14,
    );
  }

  /// Günün duası (Buhârî, Müslim ve Tirmizî'nin dua/zikir bölümleri).
  static Future<Map<String, String>> gununDuasi(DateTime tarih) {
    return _icerikGetir(
      tur: 'dua',
      tarih: tarih,
      duaMi: true,
      yerelListeAnahtari: 'prayers',
      yerelOffset: 7,
    );
  }

  /// 30 günden eski önbellek kayıtlarını siler (SharedPreferences şişmesin).
  static Future<void> _eskiOnbellegiTemizle(SharedPreferences prefs) async {
    final sinir = DateTime.now().subtract(const Duration(days: 30));
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith('gunluk_hadis_') && !key.startsWith('gunluk_dua_')) {
        continue;
      }
      final parcalar = key.split('_');
      if (parcalar.length < 4) continue;
      final tarihParcalari = parcalar.last.split('-');
      if (tarihParcalari.length != 3) continue;
      final yil = int.tryParse(tarihParcalari[0]);
      final ay = int.tryParse(tarihParcalari[1]);
      final gun = int.tryParse(tarihParcalari[2]);
      if (yil == null || ay == null || gun == null) continue;
      if (DateTime(yil, ay, gun).isBefore(sinir)) {
        await prefs.remove(key);
      }
    }
  }
}

/// Bir hadis kitabının, günlük içerik havuzunda kullanılabilir hadis
/// numaraları. Metinler burada tutulmaz; her gün yalnızca seçilen numara
/// CDN'den çekilir.
class _HavuzKaynagi {
  /// CDN'deki edisyon adı (ör. "tur-bukhari").
  final String kitap;

  /// Kaynakta gösterilecek kısa ad (ör. "Buhârî").
  final String kisaAd;

  final List<int> nolar;

  const _HavuzKaynagi({
    required this.kitap,
    required this.kisaAd,
    required this.nolar,
  });
}
