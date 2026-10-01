import 'package:flutter/foundation.dart';

/// Günlük içerik bildirimine (günün ayeti/hadisi/duası) tıklanınca hangi
/// sayfanın açılacağını [GununIcerigiWidget]'a iletir.
///
/// main.dart, native taraftan (bkz. AlarmService.gunlukIcerikDinle /
/// gunlukIcerikBekleyenTuruAl) gelen tür kimliğini [bildir] ile buraya
/// yazar; widget [acilacakSayfa]'yı dinleyip kendi sayfasına atlar ve
/// tükettikten sonra null'a döner.
class GunlukIcerikYonlendirmeService {
  GunlukIcerikYonlendirmeService._();

  /// 0=ayet, 1=hadis, 2=dua. null: bekleyen istek yok.
  static final ValueNotifier<int?> acilacakSayfa = ValueNotifier<int?>(null);

  // "tahajjud" burada yok: GununIcerigiWidget'ta ona ait bir sayfa yok,
  // bildirimi zaten kendi alarmıyla (uyandırma sesi) amacına ulaşıyor.
  static const Map<String, int> _turSayfaEslesmesi = {
    'verse': 0,
    'hadith': 1,
    'prayer': 2,
  };

  static void bildir(String tur) {
    final sayfa = _turSayfaEslesmesi[tur];
    if (sayfa != null) acilacakSayfa.value = sayfa;
  }
}
