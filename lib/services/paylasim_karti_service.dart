import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Paylaşım kartını PNG'ye çevirip sistem paylaşım penceresine veren servis.
class PaylasimKartiService {
  PaylasimKartiService._();

  /// Üretilen görselin piksel yoğunluğu. Kart 360 mantıksal piksel geniş
  /// olduğu için 3x ile 1080 piksellik sosyal medya ölçüsü çıkar.
  static const double _pikselOrani = 3;

  /// Geçici dosyaların temizlenmeden önce saklandığı süre.
  static const Duration _dosyaOmru = Duration(days: 1);

  /// [anahtar] ile işaretlenmiş [RepaintBoundary]'nin PNG baytlarını üretir.
  ///
  /// Kart henüz boyanmadıysa bir kare beklenir; yakalanamazsa null döner.
  static Future<Uint8List?> pngUret(GlobalKey anahtar) async {
    try {
      final sinir =
          anahtar.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (sinir == null) return null;

      // İlk karede kart henüz boyanmamış olabilir; boyanmasını bekle.
      // Burada RenderObject.debugNeedsPaint kullanılamaz: değeri yalnızca
      // assert içinde atandığı için sürüm derlemesinde okunduğunda hata
      // fırlatır ve paylaşım sonsuza dek "yükleniyor"da kalır.
      await WidgetsBinding.instance.endOfFrame;

      final gorsel = await sinir.toImage(pixelRatio: _pikselOrani);
      final baytlar = await gorsel.toByteData(format: ui.ImageByteFormat.png);
      gorsel.dispose();
      return baytlar?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// PNG baytlarını geçici klasöre yazar.
  static Future<File> _dosyayaYaz(Uint8List baytlar) async {
    final klasor = await getTemporaryDirectory();
    final dosya = File(
      '${klasor.path}${Platform.pathSeparator}'
      'huzura_davet_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return dosya.writeAsBytes(baytlar, flush: true);
  }

  /// Önceki paylaşımlardan kalan geçici görselleri siler.
  static Future<void> _eskiDosyalariTemizle() async {
    try {
      final klasor = await getTemporaryDirectory();
      final simdi = DateTime.now();
      await for (final girdi in klasor.list()) {
        if (girdi is! File) continue;
        final ad = girdi.uri.pathSegments.last;
        if (!ad.startsWith('huzura_davet_') || !ad.endsWith('.png')) continue;
        final yas = simdi.difference(await girdi.lastModified());
        if (yas > _dosyaOmru) await girdi.delete();
      }
    } catch (_) {
      // Temizlik başarısız olsa da paylaşım akışını engellemez.
    }
  }

  /// Kartı görsel olarak paylaşır. Görsel üretilemezse false döner ki
  /// çağıran taraf metin paylaşımına düşebilsin.
  static Future<bool> gorselPaylas({
    required GlobalKey kartAnahtari,
    String? metin,
    String? konu,
    Rect? konum,
  }) async {
    final baytlar = await pngUret(kartAnahtari);
    if (baytlar == null) return false;

    try {
      final dosya = await _dosyayaYaz(baytlar);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(dosya.path, mimeType: 'image/png')],
          text: metin,
          subject: konu,
          sharePositionOrigin: konum,
        ),
      );
      unawaited(_eskiDosyalariTemizle());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Birden çok karta bölünmüş içeriği tüm görselleri tek paylaşımda
  /// birlikte göndererek paylaşır (bkz. PaylasimIcerigi.metniBol). Herhangi
  /// bir kart yakalanamazsa false döner ki çağıran taraf metin paylaşımına
  /// düşebilsin.
  static Future<bool> gorselleriPaylas({
    required List<GlobalKey> kartAnahtarlari,
    String? metin,
    String? konu,
    Rect? konum,
  }) async {
    if (kartAnahtarlari.isEmpty) return false;
    if (kartAnahtarlari.length == 1) {
      return gorselPaylas(
        kartAnahtari: kartAnahtarlari.first,
        metin: metin,
        konu: konu,
        konum: konum,
      );
    }

    final dosyalar = <File>[];
    for (final anahtar in kartAnahtarlari) {
      final baytlar = await pngUret(anahtar);
      if (baytlar == null) return false;
      dosyalar.add(await _dosyayaYaz(baytlar));
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            for (final dosya in dosyalar)
              XFile(dosya.path, mimeType: 'image/png'),
          ],
          text: metin,
          subject: konu,
          sharePositionOrigin: konum,
        ),
      );
      unawaited(_eskiDosyalariTemizle());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kartın içeriğini düz metin olarak paylaşır.
  static Future<bool> metinPaylas({
    required String metin,
    String? konu,
    Rect? konum,
  }) async {
    if (metin.trim().isEmpty) return false;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: metin.trim(),
          subject: konu,
          sharePositionOrigin: konum,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bir widget'ın global koordinatlardaki dikdörtgeni. iPad'de paylaşım
  /// penceresinin doğru yerden açılması için gerekir.
  static Rect? konumBul(BuildContext context) {
    final kutu = context.findRenderObject() as RenderBox?;
    if (kutu == null || !kutu.hasSize) return null;
    return kutu.localToGlobal(Offset.zero) & kutu.size;
  }
}
