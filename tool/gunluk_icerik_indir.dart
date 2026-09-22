// Tek seferlik yardımcı script: gunluk_icerik_havuzu.json'daki tüm
// hadis/dua numaralarının gerçek metnini fawazahmed0/hadith-api CDN'inden
// çekip assets/data/gunluk_icerik_metinleri.json'a yazar. Bu dosya
// oluştuktan sonra uygulama artık ağa hiç bağımlı kalmadan çalışır.
//
// Çalıştırma: dart run tool/gunluk_icerik_indir.dart
// Yarıda kesilirse tekrar çalıştırmak kaldığı yerden devam eder (çıktı
// dosyasındaki mevcut anahtarlar atlanır).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _cdnBase =
    'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';
const _havuzYolu = 'assets/data/gunluk_icerik_havuzu.json';
const _cikisYolu = 'assets/data/gunluk_icerik_metinleri.json';

/// gunluk_hadis_dua_service.dart::_metniTemizle ile birebir aynı olmalı.
String _metniTemizle(String text) {
  var temiz = text;
  temiz = temiz.split('İZAHI İÇİN BURAYA TIKLA').first;
  temiz = temiz.replaceAll(RegExp(r'Tekrar:[^.]*\.'), '');
  temiz = temiz.replaceAll(RegExp(r'Diğer Tahric:.*$', dotAll: true), '');
  return temiz.trim();
}

void main() async {
  final havuz =
      jsonDecode(await File(_havuzYolu).readAsString()) as Map<String, dynamic>;

  final gorevler = <String, ({String kitap, String kisaAd, int no})>{};
  void topla(dynamic liste) {
    for (final k in (liste as List).cast<Map<String, dynamic>>()) {
      final kitap = k['kitap'] as String;
      final kisaAd = k['kisa'] as String;
      for (final no in (k['nolar'] as List).cast<int>()) {
        gorevler['$kitap/$no'] = (kitap: kitap, kisaAd: kisaAd, no: no);
      }
    }
  }

  topla(havuz['hadis']);
  topla(havuz['dua']);

  final cikisDosyasi = File(_cikisYolu);
  Map<String, dynamic> sonuc = {};
  if (await cikisDosyasi.exists()) {
    sonuc = jsonDecode(await cikisDosyasi.readAsString()) as Map<String, dynamic>;
  }

  final eksikler =
      gorevler.entries.where((e) => !sonuc.containsKey(e.key)).toList();
  stdout.writeln(
    'Toplam: ${gorevler.length}, önceden tamam: ${sonuc.length}, eksik: ${eksikler.length}',
  );

  final client = http.Client();
  var hatali = 0;
  const esZamanli = 15;

  Future<void> kaydet() async {
    await cikisDosyasi.writeAsString(jsonEncode(sonuc));
  }

  for (var i = 0; i < eksikler.length; i += esZamanli) {
    final grup = eksikler.skip(i).take(esZamanli);
    await Future.wait(
      grup.map((girdi) async {
        final k = girdi.value;
        try {
          final resp = await client
              .get(Uri.parse('$_cdnBase/${k.kitap}/${k.no}.json'))
              .timeout(const Duration(seconds: 12));
          if (resp.statusCode != 200) {
            hatali++;
            return;
          }
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          final hadithler = data['hadiths'];
          if (hadithler is! List || hadithler.isEmpty) {
            hatali++;
            return;
          }
          final ilk = hadithler.first as Map<String, dynamic>;
          final metin = _metniTemizle(ilk['text']?.toString() ?? '');
          if (metin.isEmpty) {
            hatali++;
            return;
          }
          sonuc[girdi.key] = {
            'text': metin,
            'source': '${k.kisaAd}, ${ilk['hadithnumber']}',
          };
        } catch (_) {
          hatali++;
        }
      }),
    );

    if ((i ~/ esZamanli) % 10 == 0) {
      await kaydet();
      stdout.writeln('İlerleme: ${sonuc.length}/${gorevler.length} (hata: $hatali)');
    }
  }

  await kaydet();
  client.close();
  stdout.writeln('Bitti. Toplam: ${sonuc.length}/${gorevler.length}, hata: $hatali');
}
