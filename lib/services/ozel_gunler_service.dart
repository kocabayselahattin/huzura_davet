import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Özel gün ve gece türleri
enum OzelGunTuru {
  bayram,
  kandil,
  mubarekGece,
  onemliGun,
}

/// Özel gün modeli
class OzelGun {
  final String ad;
  final String aciklama;
  final OzelGunTuru tur;
  final int hicriAy;
  final int hicriGun;
  final bool geceOncesiMi; // Kandiller geceden başlar

  const OzelGun({
    required this.ad,
    required this.aciklama,
    required this.tur,
    required this.hicriAy,
    required this.hicriGun,
    this.geceOncesiMi = false,
  });

  /// Tebrik mesajını döndürür
  String get tebrikMesaji {
    switch (tur) {
      case OzelGunTuru.bayram:
        return 'Bayramınız Mübarek Olsun! 🌙';
      case OzelGunTuru.kandil:
        return 'Kandiliniz Mübarek Olsun! ✨';
      case OzelGunTuru.mubarekGece:
        return '$ad Mübarek Olsun! 🤲';
      case OzelGunTuru.onemliGun:
        return '$ad Hayırlı Olsun! 📿';
    }
  }

  /// Alt başlık mesajı
  String get altMesaj {
    return aciklama;
  }
}

class OzelGunlerService {
  static const String _sonGosterilenGunKey = 'son_gosterilen_ozel_gun';
  
  /// Hicri takvime göre tüm özel günler
  /// Hicri aylar: 1-Muharrem, 2-Safer, 3-Rebiülevvel, 4-Rebiülahir, 5-Cemaziyelevvel,
  /// 6-Cemaziyelahir, 7-Recep, 8-Şaban, 9-Ramazan, 10-Şevval, 11-Zilkade, 12-Zilhicce
  static const List<OzelGun> ozelGunler = [
    // Muharrem Ayı (1)
    OzelGun(
      ad: 'Hicri Yılbaşı',
      aciklama: 'Yeni Hicri yılınız mübarek olsun',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 1,
      hicriGun: 1,
    ),
    OzelGun(
      ad: 'Aşure Günü',
      aciklama: 'Muharrem ayının 10. günü',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 1,
      hicriGun: 10,
    ),
    
    // Rebiülevvel Ayı (3)
    OzelGun(
      ad: 'Mevlid Kandili',
      aciklama: 'Peygamber Efendimizin doğum günü',
      tur: OzelGunTuru.kandil,
      hicriAy: 3,
      hicriGun: 12,
      geceOncesiMi: true,
    ),
    
    // Recep Ayı (7)
    OzelGun(
      ad: 'Regaip Kandili',
      aciklama: 'Recep ayının ilk Cuma gecesi',
      tur: OzelGunTuru.kandil,
      hicriAy: 7,
      hicriGun: 1, // İlk Cuma gecesi - dinamik hesaplanacak
      geceOncesiMi: true,
    ),
    OzelGun(
      ad: 'Miraç Kandili',
      aciklama: 'Peygamberimizin göklere yükselişi',
      tur: OzelGunTuru.kandil,
      hicriAy: 7,
      hicriGun: 27,
      geceOncesiMi: true,
    ),
    
    // Şaban Ayı (8)
    OzelGun(
      ad: 'Berat Kandili',
      aciklama: 'Günahların affedildiği gece',
      tur: OzelGunTuru.kandil,
      hicriAy: 8,
      hicriGun: 15,
      geceOncesiMi: true,
    ),
    
    // Ramazan Ayı (9)
    OzelGun(
      ad: 'Ramazan Ayı Başlangıcı',
      aciklama: 'On bir ayın sultanı Ramazan-ı Şerif',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 9,
      hicriGun: 1,
    ),
    OzelGun(
      ad: 'Kadir Gecesi',
      aciklama: 'Bin aydan hayırlı gece',
      tur: OzelGunTuru.mubarekGece,
      hicriAy: 9,
      hicriGun: 27,
      geceOncesiMi: true,
    ),
    
    // Şevval Ayı (10)
    OzelGun(
      ad: 'Ramazan Bayramı',
      aciklama: 'Ramazan Bayramı 1. Gün',
      tur: OzelGunTuru.bayram,
      hicriAy: 10,
      hicriGun: 1,
    ),
    OzelGun(
      ad: 'Ramazan Bayramı',
      aciklama: 'Ramazan Bayramı 2. Gün',
      tur: OzelGunTuru.bayram,
      hicriAy: 10,
      hicriGun: 2,
    ),
    OzelGun(
      ad: 'Ramazan Bayramı',
      aciklama: 'Ramazan Bayramı 3. Gün',
      tur: OzelGunTuru.bayram,
      hicriAy: 10,
      hicriGun: 3,
    ),
    
    // Zilhicce Ayı (12)
    OzelGun(
      ad: 'Arefe Günü',
      aciklama: 'Kurban Bayramı arefesi',
      tur: OzelGunTuru.onemliGun,
      hicriAy: 12,
      hicriGun: 9,
    ),
    OzelGun(
      ad: 'Kurban Bayramı',
      aciklama: 'Kurban Bayramı 1. Gün',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 10,
    ),
    OzelGun(
      ad: 'Kurban Bayramı',
      aciklama: 'Kurban Bayramı 2. Gün',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 11,
    ),
    OzelGun(
      ad: 'Kurban Bayramı',
      aciklama: 'Kurban Bayramı 3. Gün',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 12,
    ),
    OzelGun(
      ad: 'Kurban Bayramı',
      aciklama: 'Kurban Bayramı 4. Gün',
      tur: OzelGunTuru.bayram,
      hicriAy: 12,
      hicriGun: 13,
    ),
  ];

  /// Bugün özel bir gün mü kontrol et
  static OzelGun? bugunOzelGunMu() {
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
    const aylar = [
      '',
      'Muharrem',
      'Safer',
      'Rebiülevvel',
      'Rebiülahir',
      'Cemaziyelevvel',
      'Cemaziyelahir',
      'Recep',
      'Şaban',
      'Ramazan',
      'Şevval',
      'Zilkade',
      'Zilhicce',
    ];
    if (ay >= 1 && ay <= 12) {
      return aylar[ay];
    }
    return '';
  }
}
