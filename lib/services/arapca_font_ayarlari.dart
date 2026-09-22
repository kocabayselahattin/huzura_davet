import 'package:shared_preferences/shared_preferences.dart';

/// Arapça (Kur'an) metinlerinde kullanılabilecek font seçenekleri.
/// Fontlar assets/fonts altında gömülü olarak bulunur, internet gerektirmez.
class ArapcaFontSecenegi {
  final String fontFamily;
  final String isim;
  final String aciklama;

  const ArapcaFontSecenegi({
    required this.fontFamily,
    required this.isim,
    required this.aciklama,
  });
}

class ArapcaFontAyarlari {
  static const String varsayilanFont = 'Amiri';
  static const String _prefsAnahtari = 'arapca_font_secimi';

  static const List<ArapcaFontSecenegi> secenekler = [
    ArapcaFontSecenegi(
      fontFamily: 'Amiri',
      isim: 'Nesih',
      aciklama: 'Klasik ve zarif bir Arapça yazı tipi',
    ),
    ArapcaFontSecenegi(
      fontFamily: 'NotoNaskhArabic',
      isim: 'Kolay Okunur',
      aciklama: 'Sade, bilgisayar yazısı gibi net bir yazı tipi',
    ),
    ArapcaFontSecenegi(
      fontFamily: 'ScheherazadeNew',
      isim: 'Mushaf',
      aciklama: 'Geleneksel mushaf görünümüne yakın yazı tipi',
    ),
  ];

  static Future<String> yukle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsAnahtari) ?? varsayilanFont;
  }

  static Future<void> kaydet(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsAnahtari, fontFamily);
  }
}
