import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_service.dart';

/// Özel gün ve gece türleri
enum OzelGunTuru {
  bayram,
  kandil,
  mubarekGece,
  onemliGun,
}

/// Özel gün modeli - Çevirileri dinamik olarak alır
class OzelGun {
  final String adKey;
  final String aciklamaKey;
  final OzelGunTuru tur;
  final int hicriAy;
  final int hicriGun;
  final bool geceOncesiMi; // Kandiller geceden başlar

  const OzelGun({
    required this.adKey,
    required this.aciklamaKey,
    required this.tur,
    required this.hicriAy,
    required this.hicriGun,
    this.geceOncesiMi = false,
  });

  /// Çevirili ad döndürür
  String get ad {
    final langService = LanguageService();
    return langService[adKey] ?? adKey;
  }

  /// Çevirili açıklama döndürür
  String get aciklama {
    final langService = LanguageService();
    return langService[aciklamaKey] ?? aciklamaKey;
  }

  /// Tebrik mesajını döndürür
  String get tebrikMesaji {
    final langService = LanguageService();
    switch (tur) {
      case OzelGunTuru.bayram:
        return '${langService['eid_mubarak'] ?? 'Bayramınız Mübarek Olsun!'} 🌙';
      case OzelGunTuru.kandil:
        return '${langService['kandil_mubarak'] ?? 'Kandiliniz Mübarek Olsun!'} ✨';
      case OzelGunTuru.mubarekGece:
        return '$ad ${langService['blessed_night'] ?? 'Mübarek Olsun!'} 🤲';
      case OzelGunTuru.onemliGun:
        return '$ad ${langService['blessed_day'] ?? 'Hayırlı Olsun!'} 📿';
    }
  }

  /// Alt başlık mesajı
  String get altMesaj {
    return aciklama;
  }
}

class OzelGunlerService {
  static const String _sonGosterilenGunKey = 'son_gosterilen_ozel_gun';
  
  /// Oturum bazlı popup gösterildi flag'i
  /// Uygulama açık olduğu sürece true kalır, böylece aynı oturumda popup bir kez gösterilir
  static bool _sessionPopupShown = false;
  
  /// TEST MODU - Geliştirme sırasında test için kullanılır
  /// Production'da false olmalı!
  static const bool _testModu = false;
  static const OzelGun _testOzelGun = OzelGun(
    adKey: 'barat',
    aciklamaKey: 'barat_desc',
    tur: OzelGunTuru.kandil,
    hicriAy: 8,
    hicriGun: 15,
    geceOncesiMi: true,
  );
  
  /// Hicri takvime göre tüm özel günler
  /// Hicri aylar: 1-Muharrem, 2-Safer, 3-Rebiülevvel, 4-Rebiülahir, 5-Cemaziyelevvel,
  /// 6-Cemaziyelahir, 7-Recep, 8-Şaban, 9-Ramazan, 10-Şevval, 11-Zilkade, 12-Zilhicce
  static const List<OzelGun> ozelGunler = [
    // Muharrem Ayı (1)
    OzelGun(
      adKey: 'hijri_new_year',
      aciklamaKey: 'hijri_new_year_desc',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 1,
      hicriGun: 1,
    ),
    OzelGun(
      adKey: 'ashura',
      aciklamaKey: 'ashura_desc',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 1,
      hicriGun: 10,
    ),
    
    // Rebiülevvel Ayı (3)
    OzelGun(
      adKey: 'mawlid',
      aciklamaKey: 'mawlid_desc',
      tur: OzelGunTuru.kandil,
      hicriAy: 3,
      hicriGun: 12,
      geceOncesiMi: true,
    ),
    
    // Recep Ayı (7)
    OzelGun(
      adKey: 'ragaib',
      aciklamaKey: 'ragaib_desc',
      tur: OzelGunTuru.kandil,
      hicriAy: 7,
      hicriGun: 1,
      geceOncesiMi: true,
    ),
    OzelGun(
      adKey: 'miraj',
      aciklamaKey: 'miraj_desc',
      tur: OzelGunTuru.kandil,
      hicriAy: 7,
      hicriGun: 27,
      geceOncesiMi: true,
    ),
    
    // Şaban Ayı (8)
    OzelGun(
      adKey: 'barat',
      aciklamaKey: 'barat_desc',
      tur: OzelGunTuru.kandil,
      hicriAy: 8,
      hicriGun: 15,
      geceOncesiMi: true,
    ),
    
    // Ramazan Ayı (9)
    OzelGun(
      adKey: 'ramadan_start',
      aciklamaKey: 'ramadan_start_desc',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 9,
      hicriGun: 1,
    ),
    OzelGun(
      adKey: 'laylat_al_qadr',
      aciklamaKey: 'laylat_al_qadr_desc',
      tur: OzelGunTuru.mubarekGece,
      hicriAy: 9,
      hicriGun: 27,
      geceOncesiMi: true,
    ),
    
    // Şevval Ayı (10)
    OzelGun(
      adKey: 'eid_al_fitr',
      aciklamaKey: 'eid_al_fitr_day1',
      tur: OzelGunTuru.bayram,
      hicriAy: 10,
      hicriGun: 1,
    ),
    OzelGun(
      adKey: 'eid_al_fitr',
      aciklamaKey: 'eid_al_fitr_day2',
      tur: OzelGunTuru.bayram,
      hicriAy: 10,
      hicriGun: 2,
    ),
    OzelGun(
      adKey: 'eid_al_fitr',
      aciklamaKey: 'eid_al_fitr_day3',
      tur: OzelGunTuru.bayram,
      hicriAy: 10,
      hicriGun: 3,
    ),
    
    // Zilhicce Ayı (12)
    OzelGun(
      adKey: 'arafa',
      aciklamaKey: 'arafa_desc',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 12,
      hicriGun: 9,
    ),
    OzelGun(
      adKey: 'eid_al_adha',
      aciklamaKey: 'eid_al_adha_day1',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 10,
    ),
    OzelGun(
      adKey: 'eid_al_adha',
      aciklamaKey: 'eid_al_adha_day2',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 11,
    ),
    OzelGun(
      adKey: 'eid_al_adha',
      aciklamaKey: 'eid_al_adha_day3',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 12,
    ),
    OzelGun(
      adKey: 'eid_al_adha',
      aciklamaKey: 'eid_al_adha_day4',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 13,
    ),
  ];

  /// Bugün özel bir gün mü kontrol et
  static OzelGun? bugunOzelGunMu() {
    // TEST MODU - Geliştirme sırasında test için
    if (_testModu) {
      return _testOzelGun;
    }
    
    final hicri = HijriCalendar.now();
    final hicriAy = hicri.hMonth;
    final hicriGun = hicri.hDay;
    
    // Kandiller için önceki günün akşamından itibaren başlar
    // Bu yüzden hem bugünü hem de yarını kontrol ediyoruz
    for (final ozelGun in ozelGunler) {
      if (ozelGun.hicriAy == hicriAy && ozelGun.hicriGun == hicriGun) {
        return ozelGun;
      }
      
      // Kandiller için bir gün öncesinde de göster (akşamdan itibaren)
      if (ozelGun.geceOncesiMi) {
        final dun = hicriGun - 1;
        if (ozelGun.hicriAy == hicriAy && ozelGun.hicriGun == dun + 1 && DateTime.now().hour >= 18) {
          return ozelGun;
        }
      }
    }
    
    return null;
  }

  /// Bugün popup gösterilmeli mi kontrol et
  static Future<bool> popupGosterilmeliMi() async {
    // Oturum içinde zaten gösterildiyse tekrar gösterme
    if (_sessionPopupShown) {
      return false;
    }
    
    final ozelGun = bugunOzelGunMu();
    if (ozelGun == null) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final sonGosterilen = prefs.getString(_sonGosterilenGunKey);
    
    final bugun = DateTime.now();
    final bugunKey = '${ozelGun.ad}_${bugun.year}_${bugun.month}_${bugun.day}';
    
    // Aynı gün daha önce gösterilmişse tekrar gösterme
    if (sonGosterilen == bugunKey) {
      return false;
    }
    
    return true;
  }

  /// Popup gösterildi olarak işaretle
  static Future<void> popupGosterildiIsaretle() async {
    // Oturum flag'ini işaretle
    _sessionPopupShown = true;
    
    final ozelGun = bugunOzelGunMu();
    if (ozelGun == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final bugun = DateTime.now();
    final bugunKey = '${ozelGun.ad}_${bugun.year}_${bugun.month}_${bugun.day}';
    
    await prefs.setString(_sonGosterilenGunKey, bugunKey);
  }

  /// Yaklaşan özel günleri getir (30 gün içinde)
  static List<Map<String, dynamic>> yaklasanOzelGunler() {
    final List<Map<String, dynamic>> sonuc = [];
    final bugun = HijriCalendar.now();
    
    for (final ozelGun in ozelGunler) {
      // Bu yılın tarihi
      int hedefYil = bugun.hYear;
      
      // Eğer bu yılki tarih geçtiyse, gelecek yılı kullan
      if (ozelGun.hicriAy < bugun.hMonth || 
          (ozelGun.hicriAy == bugun.hMonth && ozelGun.hicriGun < bugun.hDay)) {
        hedefYil++;
      }
      
      try {
        final hicriTarih = HijriCalendar()
          ..hYear = hedefYil
          ..hMonth = ozelGun.hicriAy
          ..hDay = ozelGun.hicriGun;
        
        final miladiTarih = hicriTarih.hijriToGregorian(hedefYil, ozelGun.hicriAy, ozelGun.hicriGun);
        final tarih = DateTime(miladiTarih.year, miladiTarih.month, miladiTarih.day);
        final simdi = DateTime.now();
        final fark = tarih.difference(simdi).inDays;
        
        // 365 gün içinde olanları ekle
        if (fark >= 0 && fark <= 365) {
          sonuc.add({
            'ozelGun': ozelGun,
            'tarih': tarih,
            'kalanGun': fark,
            'hicriTarih': '${ozelGun.hicriGun} ${_getHicriAyAdi(ozelGun.hicriAy)} $hedefYil',
          });
        }
      } catch (e) {
        // Tarih dönüşüm hatası
        print('Tarih dönüşüm hatası: $e');
      }
    }
    
    // Tarihe göre sırala
    sonuc.sort((a, b) => (a['kalanGun'] as int).compareTo(b['kalanGun'] as int));
    
    return sonuc;
  }

  /// Hicri ay adını döndür
  static String _getHicriAyAdi(int ay) {
    final languageService = LanguageService();
    if (ay >= 1 && ay <= 12) {
      return languageService['hijri_month_$ay'] ?? '';
    }
    return '';
  }
}
