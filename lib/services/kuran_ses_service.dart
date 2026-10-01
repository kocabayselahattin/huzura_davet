import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kuran_veri_service.dart';

/// Kur'an sesli okuyuşunda seçilebilecek bir okuyucu (qari).
///
/// [id], islamic.network CDN'inin "edition" kimliğiyle birebir aynıdır
/// (bkz. `https://cdn.islamic.network/quran/audio/128/<id>`), böylece
/// [KuranSesService] için ekstra bir eşleme tablosuna gerek kalmaz.
class Okuyucu {
  final String id;
  final String ad;

  const Okuyucu({required this.id, required this.ad});
}

/// Kur'an ayetlerinin sesli okunuşunu, kullanıcının seçtiği okuyucuyla, sure
/// bazında isteğe bağlı indirir ve çalar. Hiçbir ses dosyası uygulamayla
/// birlikte gelmez — kullanıcı bir sureyi indirmediği sürece hiç veri
/// çekilmez.
class KuranSesService {
  static const String _cdnKok = 'https://cdn.islamic.network/quran/audio/128';

  static const String _aktifOkuyucuAnahtari = 'kuran_sesi_okuyucu';
  static const String varsayilanOkuyucuId = 'ar.alafasy';

  /// Desteklenen okuyucular. Kütüphane > Sesli Kur'an İndirme Ayarları
  /// ekranında bu sırayla listelenir.
  static const List<Okuyucu> okuyucular = [
    Okuyucu(id: 'ar.alafasy', ad: 'Mishary Rashid Alafasy'),
    Okuyucu(id: 'ar.abdulbasitmurattal', ad: 'Abdul Basit Abdus Samad'),
    Okuyucu(id: 'ar.husary', ad: 'Mahmoud Khalil Al-Husary'),
    Okuyucu(id: 'ar.minshawi', ad: 'Mohamed Siddiq El-Minshawi'),
    Okuyucu(id: 'ar.abdurrahmaansudais', ad: 'Abdul Rahman Al-Sudais'),
    Okuyucu(id: 'ar.mahermuaiqly', ad: 'Maher Al Muaiqly'),
  ];

  static Directory? _kokDizin;
  static String? _aktifOkuyucuOnbellek;
  static bool _gecisYapildi = false;

  static Future<Directory> _kokKlasor() async {
    if (_kokDizin != null) return _kokDizin!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/kuran_sesleri');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _kokDizin = dir;
    return dir;
  }

  /// Eski sürümlerde (okuyucu seçimi eklenmeden önce) sesler doğrudan
  /// `kuran_sesleri/{sure}_{ayet}.mp3` olarak, tek okuyucu (Alafasy)
  /// varsayılarak indiriliyordu. Bu dosyalar kaybolmasın diye bir kereliğine
  /// `kuran_sesleri/ar.alafasy/` altına taşınır.
  static Future<void> _eskiDosyalariTasi() async {
    if (_gecisYapildi) return;
    _gecisYapildi = true;
    try {
      final kok = await _kokKlasor();
      final desen = RegExp(r'^\d+_\d+\.mp3$');
      final eskiDosyalar = await kok
          .list()
          .where((e) => e is File && desen.hasMatch(e.uri.pathSegments.last))
          .cast<File>()
          .toList();
      if (eskiDosyalar.isEmpty) return;

      final hedefKlasor = Directory('${kok.path}/$varsayilanOkuyucuId');
      if (!await hedefKlasor.exists()) {
        await hedefKlasor.create(recursive: true);
      }
      for (final dosya in eskiDosyalar) {
        final ad = dosya.uri.pathSegments.last;
        final hedef = File('${hedefKlasor.path}/$ad');
        if (!await hedef.exists()) {
          await dosya.rename(hedef.path);
        } else {
          await dosya.delete();
        }
      }
    } catch (_) {
      // Geçiş başarısız olsa da uygulama akışını engellemez; eski dosyalar
      // olduğu yerde kalır, gerekirse yeniden indirilir.
    }
  }

  static Future<Directory> _sesKlasoru(String okuyucuId) async {
    final kok = await _kokKlasor();
    await _eskiDosyalariTasi();
    final dir = Directory('${kok.path}/$okuyucuId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> aktifOkuyucuId() async {
    if (_aktifOkuyucuOnbellek != null) return _aktifOkuyucuOnbellek!;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_aktifOkuyucuAnahtari) ?? varsayilanOkuyucuId;
    _aktifOkuyucuOnbellek = id;
    return id;
  }

  static Future<void> aktifOkuyucuAyarla(String okuyucuId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aktifOkuyucuAnahtari, okuyucuId);
    _aktifOkuyucuOnbellek = okuyucuId;
  }

  static String _cdnTaban(String okuyucuId) => '$_cdnKok/$okuyucuId';

  /// Surenin başından itibaren global (Kur'an geneli) ayet numarasını
  /// hesaplar (1-6236 arası) — CDN ayetleri bu numarayla adresliyor.
  static int globalAyetNo(int sureNo, int ayetNo) {
    int toplam = 0;
    for (int s = 1; s < sureNo; s++) {
      toplam += KuranVeriService.sureAyetleri(s).length;
    }
    return toplam + ayetNo;
  }

  static Future<File> _dosyaYolu(
    int sureNo,
    int ayetNo,
    String okuyucuId,
  ) async {
    final dir = await _sesKlasoru(okuyucuId);
    return File('${dir.path}/${sureNo}_$ayetNo.mp3');
  }

  static Future<bool> ayetIndirilmisMi(
    int sureNo,
    int ayetNo, {
    String? okuyucuId,
  }) async {
    final id = okuyucuId ?? await aktifOkuyucuId();
    final dosya = await _dosyaYolu(sureNo, ayetNo, id);
    return dosya.exists();
  }

  /// Bir ayetin çalınabilir kaynağını döndürür: yerelde indirilmişse dosya
  /// yolu, değilse doğrudan CDN URL'i (akış/streaming). Her zaman aktif
  /// okuyucuya göre çözümlenir.
  static Future<({String kaynak, bool yerel})> calmaKaynagi(
    int sureNo,
    int ayetNo,
  ) async {
    final okuyucuId = await aktifOkuyucuId();
    final dosya = await _dosyaYolu(sureNo, ayetNo, okuyucuId);
    if (await dosya.exists()) {
      return (kaynak: dosya.path, yerel: true);
    }
    final globalNo = globalAyetNo(sureNo, ayetNo);
    return (kaynak: '${_cdnTaban(okuyucuId)}/$globalNo.mp3', yerel: false);
  }

  /// Belirtilen okuyucudan bir ayetin akış URL'ini döndürür (indirilmiş olup
  /// olmadığına bakmaksızın) — okuyucu seçimi ekranında önizleme için.
  static String onizlemeUrl(String okuyucuId, {int globalAyetNo = 1}) {
    return '${_cdnTaban(okuyucuId)}/$globalAyetNo.mp3';
  }

  static Future<bool> sureTamIndirilmisMi(
    int sureNo, {
    String? okuyucuId,
  }) async {
    final id = okuyucuId ?? await aktifOkuyucuId();
    final ayetSayisi = KuranVeriService.sureAyetleri(sureNo).length;
    if (ayetSayisi == 0) return false;
    for (int i = 1; i <= ayetSayisi; i++) {
      if (!await ayetIndirilmisMi(sureNo, i, okuyucuId: id)) return false;
    }
    return true;
  }

  /// Sureyi ayet ayet indirir. [ilerleme] her tamamlanan ayette çağrılır.
  /// Zaten indirilmiş ayetler tekrar indirilmez (kesintiden devam edebilir).
  /// [okuyucuId] verilmezse aktif okuyucu kullanılır.
  static Future<void> sureyiIndir(
    int sureNo, {
    required void Function(int tamamlanan, int toplam) ilerleme,
    int esZamanliIstek = 4,
    String? okuyucuId,
  }) async {
    final id = okuyucuId ?? await aktifOkuyucuId();
    final ayetSayisi = KuranVeriService.sureAyetleri(sureNo).length;
    if (ayetSayisi == 0) return;

    final baslangicGlobal = globalAyetNo(sureNo, 1);
    int tamamlanan = 0;

    Future<void> birAyetIndir(int ayetNo) async {
      final dosya = await _dosyaYolu(sureNo, ayetNo, id);
      if (!await dosya.exists()) {
        final globalNo = baslangicGlobal + ayetNo - 1;
        try {
          final response = await http
              .get(Uri.parse('${_cdnTaban(id)}/$globalNo.mp3'))
              .timeout(const Duration(seconds: 20));
          if (response.statusCode == 200) {
            await dosya.writeAsBytes(response.bodyBytes);
          }
        } catch (_) {
          // Bir ayet indirilemezse indirmeyi durdurma; kullanıcı tekrar
          // deneyebilir, o ayet çalınırken akıştan (streaming) oynatılır.
        }
      }
      tamamlanan++;
      ilerleme(tamamlanan, ayetSayisi);
    }

    final kuyruk = List.generate(ayetSayisi, (i) => i + 1);
    while (kuyruk.isNotEmpty) {
      final parti = kuyruk.take(esZamanliIstek).toList();
      kuyruk.removeRange(0, parti.length);
      await Future.wait(parti.map(birAyetIndir));
    }
  }

  static Future<void> sureyiSil(int sureNo, {String? okuyucuId}) async {
    final id = okuyucuId ?? await aktifOkuyucuId();
    final ayetSayisi = KuranVeriService.sureAyetleri(sureNo).length;
    for (int i = 1; i <= ayetSayisi; i++) {
      final dosya = await _dosyaYolu(sureNo, i, id);
      if (await dosya.exists()) {
        await dosya.delete();
      }
    }
  }
}
