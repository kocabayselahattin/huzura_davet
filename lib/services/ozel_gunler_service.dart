import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'language_service.dart';
import 'alarm_service.dart';

/// Özel gün ve gece türleri
enum OzelGunTuru { bayram, kandil, mubarekGece, onemliGun }

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
  /// Banner sabah 09:00'dan itibaren aktif olur
  static OzelGun? bugunOzelGunMu() {
    // TEST MODU - Geliştirme sırasında test için
    if (_testModu) {
      return _testOzelGun;
    }

    final now = DateTime.now();
    final hicri = HijriCalendar.now();
    final hicriAy = hicri.hMonth;
    final hicriGun = hicri.hDay;

    debugPrint(
      '📅 [OzelGun] Bugün: \\${now.day}/\\${now.month}/\\${now.year} \\${now.hour}:\\${now.minute}',
    );
    debugPrint(
      '📅 [OzelGun] Hicri: \\${hicriGun}/\\${hicriAy}/\\${hicri.hYear}',
    );

    for (final ozelGun in ozelGunler) {
      // 1. Normal özel günler (geceOncesiMi == false): sadece o gün 09:00'dan itibaren
      if (!ozelGun.geceOncesiMi) {
        if (ozelGun.hicriAy == hicriAy && ozelGun.hicriGun == hicriGun) {
          if (now.hour >= 9) {
            debugPrint('✅ [OzelGun] Bugün özel gün: \\${ozelGun.ad}');
            return ozelGun;
          } else {
            debugPrint(
              '⏰ [OzelGun] \\${ozelGun.ad} var ama henüz saat 09:00 olmadı (\\${now.hour}:\\${now.minute})',
            );
          }
        }
      } else {
        // 2. Kandil/gece günleri: hem bir önceki gün 09:00'dan, hem de asıl günün sabah 09:00'ına kadar
        // a) Bir önceki gün 09:00'dan geceye kadar
        if (ozelGun.hicriAy == hicriAy && ozelGun.hicriGun == hicriGun + 1) {
          if (now.hour >= 9) {
            debugPrint(
              '✅ [OzelGun] Yarın kandil/gece: \\${ozelGun.ad} (bugün göster)',
            );
            return ozelGun;
          } else {
            debugPrint(
              '⏰ [OzelGun] Yarın \\${ozelGun.ad} ama henüz saat 09:00 olmadı (\\${now.hour}:\\${now.minute})',
            );
          }
        }
        // b) Asıl gün gece 00:00'dan sabah 09:00'a kadar (yani gece boyunca)
        if (ozelGun.hicriAy == hicriAy &&
            ozelGun.hicriGun == hicriGun &&
            now.hour < 9) {
          debugPrint(
            '✅ [OzelGun] Gece devam ediyor: \\${ozelGun.ad} (sabah 09:00\'a kadar göster)',
          );
          return ozelGun;
        }
      }
    }

    debugPrint('❌ [OzelGun] Bugün özel gün/gece yok');
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

        final miladiTarih = hicriTarih.hijriToGregorian(
          hedefYil,
          ozelGun.hicriAy,
          ozelGun.hicriGun,
        );
        final tarih = DateTime(
          miladiTarih.year,
          miladiTarih.month,
          miladiTarih.day,
        );
        final simdi = DateTime.now();
        final fark = tarih.difference(simdi).inDays;

        // 365 gün içinde olanları ekle
        if (fark >= 0 && fark <= 365) {
          sonuc.add({
            'ozelGun': ozelGun,
            'tarih': tarih,
            'kalanGun': fark,
            'hicriTarih':
                '${ozelGun.hicriGun} ${_getHicriAyAdi(ozelGun.hicriAy)} $hedefYil',
          });
        }
      } catch (e) {
        // Tarih dönüşüm hatası
        debugPrint('Tarih dönüşüm hatası: $e');
      }
    }

    // Tarihe göre sırala
    sonuc.sort(
      (a, b) => (a['kalanGun'] as int).compareTo(b['kalanGun'] as int),
    );

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

  // ========== ÖZEL GÜN BİLDİRİMLERİ ==========

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int _ozelGunBildirimIdBase = 5000;

  /// Özel gün bildirimlerini zamanla
  /// 7 gün içindeki özel günler için bildirim zamanlar
  /// GeceOncesiMi olanlarda hem bir önceki gün 09:00'da, hem de asıl gün 00:05'te (sabah 09:00'dan önce) bildirim kurulur
  static Future<void> scheduleOzelGunBildirimleri() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('ozel_gun_bildirimleri_aktif') ?? true;

    if (!enabled) {
      debugPrint('📅 Özel gün bildirimleri devre dışı');
      await cancelOzelGunBildirimleri();
      return;
    }

    debugPrint('📅 Özel gün bildirimleri zamanlanıyor...');

    // Önce mevcut bildirimleri iptal et
    await cancelOzelGunBildirimleri();

    // Yaklaşan özel günleri al (7 gün içinde)
    final yaklasanlar = yaklasanOzelGunler();
    int zamanlanandi = 0;

    debugPrint('📅 ========== ÖZEL GÜN BİLDİRİM ZAMANLAMA ==========');
    debugPrint('📅 Toplam ${yaklasanlar.length} özel gün bulundu');

    int idOffset = 0;
    for (int i = 0; i < yaklasanlar.length && i < 10; i++) {
      final item = yaklasanlar[i];
      final ozelGun = item['ozelGun'] as OzelGun;
      final tarih = item['tarih'] as DateTime;
      final kalanGun = item['kalanGun'] as int;

      debugPrint('\n🔍 Kontrol ediliyor: ${ozelGun.ad}');
      debugPrint('   📆 Tarih: ${tarih.day}/${tarih.month}/${tarih.year}');
      debugPrint('   ⏰ Kalan gün: $kalanGun');
      debugPrint('   🌙 Gece öncesi mi: ${ozelGun.geceOncesiMi}');

      // Sadece 7 gün içindeki özel günler için bildirim zamanla
      if (kalanGun > 7) {
        debugPrint('   ⏭️ Atlandı: 7 günden fazla');
        continue;
      }

      if (ozelGun.geceOncesiMi) {
        // 1) Bir önceki gün 09:00'da (banner gibi)
        DateTime oncekiGunBildirimi = DateTime(
          tarih.year,
          tarih.month,
          tarih.day - 1,
          9,
          0,
        );
        if (oncekiGunBildirimi.isAfter(DateTime.now())) {
          final tzOncekiGun = tz.TZDateTime.from(oncekiGunBildirimi, tz.local);
          debugPrint(
            '   📍 Kandil/gece için önceki gün bildirimi: ${oncekiGunBildirimi.day}/${oncekiGunBildirimi.month} ${oncekiGunBildirimi.hour}:${oncekiGunBildirimi.minute.toString().padLeft(2, "0")}',
          );
          try {
            await _scheduleOzelGunBildirimi(
              id: _ozelGunBildirimIdBase + idOffset,
              ozelGun: ozelGun,
              scheduledDate: tzOncekiGun,
            );
            zamanlanandi++;
            idOffset++;
          } catch (e) {
            debugPrint(
              '❌ Özel gün bildirimi zamanlanamadı: ${ozelGun.ad} - $e',
            );
          }
        }
        // 2) Asıl gün gece 00:05'te (sabah 09:00'dan önce, gece boyunca)
        DateTime geceBildirimi = DateTime(
          tarih.year,
          tarih.month,
          tarih.day,
          0,
          5,
        );
        if (geceBildirimi.isAfter(DateTime.now())) {
          final tzGece = tz.TZDateTime.from(geceBildirimi, tz.local);
          debugPrint(
            '   📍 Kandil/gece için gece bildirimi: ${geceBildirimi.day}/${geceBildirimi.month} ${geceBildirimi.hour}:${geceBildirimi.minute.toString().padLeft(2, "0")}',
          );
          try {
            await _scheduleOzelGunBildirimi(
              id: _ozelGunBildirimIdBase + idOffset,
              ozelGun: ozelGun,
              scheduledDate: tzGece,
            );
            zamanlanandi++;
            idOffset++;
          } catch (e) {
            debugPrint(
              '❌ Özel gün bildirimi zamanlanamadı: ${ozelGun.ad} - $e',
            );
          }
        }
      } else {
        // Diğer günler: o günün sabahı 09:00
        DateTime bildirimZamani = DateTime(
          tarih.year,
          tarih.month,
          tarih.day,
          9,
          0,
        );
        if (bildirimZamani.isAfter(DateTime.now())) {
          final tzBildirimZamani = tz.TZDateTime.from(bildirimZamani, tz.local);
          debugPrint(
            '   📍 Normal gün bildirimi: ${bildirimZamani.day}/${bildirimZamani.month} ${bildirimZamani.hour}:${bildirimZamani.minute.toString().padLeft(2, "0")}',
          );
          try {
            await _scheduleOzelGunBildirimi(
              id: _ozelGunBildirimIdBase + idOffset,
              ozelGun: ozelGun,
              scheduledDate: tzBildirimZamani,
            );
            zamanlanandi++;
            idOffset++;
          } catch (e) {
            debugPrint(
              '❌ Özel gün bildirimi zamanlanamadı: ${ozelGun.ad} - $e',
            );
          }
        }
      }
    }

    debugPrint('✅ $zamanlanandi özel gün bildirimi zamanlandı');
  }

  /// Tek bir özel gün bildirimi zamanla - AlarmManager kullanarak
  /// Bu sayede uygulama kapalı olsa bile bildirim gelir
  static Future<void> _scheduleOzelGunBildirimi({
    required int id,
    required OzelGun ozelGun,
    required tz.TZDateTime scheduledDate,
  }) async {
    final languageService = LanguageService();
    await languageService.load();

    // Bildirim içeriği
    String icon;
    switch (ozelGun.tur) {
      case OzelGunTuru.bayram:
        icon = '🎉';
        break;
      case OzelGunTuru.kandil:
        icon = '🕯️';
        break;
      case OzelGunTuru.mubarekGece:
        icon = '🌙';
        break;
      case OzelGunTuru.onemliGun:
        icon = '📿';
        break;
    }

    final title = '$icon ${ozelGun.ad}';
    final body = ozelGun.tebrikMesaji;

    // AlarmManager kullanarak zamanla (uygulama kapalı olsa bile çalışır)
    final triggerAtMillis = scheduledDate.millisecondsSinceEpoch;

    final success = await AlarmService.scheduleOzelGunAlarm(
      title: title,
      body: body,
      triggerAtMillis: triggerAtMillis,
      alarmId: id,
    );

    final tarihStr =
        '${scheduledDate.day}/${scheduledDate.month} ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}';

    if (success) {
      debugPrint(
        '   📅 ${ozelGun.ad} - $tarihStr (ID: $id) - AlarmManager ile zamanlandı ✅',
      );
    } else {
      debugPrint(
        '   ❌ ${ozelGun.ad} - AlarmManager ile zamanlanamadı, fallback kullanılıyor',
      );

      // Fallback: zonedSchedule kullan
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'ozel_gunler_channel',
        'Özel Günler',
        channelDescription: 'Kandiller, bayramlar ve mübarek geceler',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        visibility: NotificationVisibility.public,
        autoCancel: false,
        ongoing: true,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: androidPlatformChannelSpecifics,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'ozel_gun_${ozelGun.adKey}',
      );
      debugPrint(
        '   📅 ${ozelGun.ad} - $tarihStr (ID: $id) - zonedSchedule ile zamanlandı',
      );
    }
  }

  /// Özel gün bildirimlerini iptal et
  static Future<void> cancelOzelGunBildirimleri() async {
    for (int i = 0; i < 10; i++) {
      await _notificationsPlugin.cancel(id: _ozelGunBildirimIdBase + i);
      await AlarmService.cancelAlarm(_ozelGunBildirimIdBase + i);
    }
    debugPrint('🚫 Özel gün bildirimleri iptal edildi');
  }

  /// Özel gün bildirimlerini aç/kapat
  static Future<void> setOzelGunBildirimleriEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ozel_gun_bildirimleri_aktif', enabled);

    if (enabled) {
      await scheduleOzelGunBildirimleri();
    } else {
      await cancelOzelGunBildirimleri();
    }
  }
}
