import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'diyanet_api_service.dart';
import 'konum_service.dart';
import 'language_service.dart';
import 'alarm_service.dart';

/// Special day and night types
enum OzelGunTuru { bayram, kandil, mubarekGece, onemliGun }

/// Special day model - pulls translations dynamically
class OzelGun {
  final String adKey;
  final String aciklamaKey;
  final OzelGunTuru tur;
  final int hicriAy;
  final int hicriGun;
  final bool geceOncesiMi; // Kandil nights start on the previous night

  const OzelGun({
    required this.adKey,
    required this.aciklamaKey,
    required this.tur,
    required this.hicriAy,
    required this.hicriGun,
    this.geceOncesiMi = false,
  });

  /// Returns translated name
  String get ad {
    final langService = LanguageService();
    return langService[adKey] ?? adKey;
  }

  /// Returns translated description
  String get aciklama {
    final langService = LanguageService();
    return langService[aciklamaKey] ?? aciklamaKey;
  }

  /// Returns greeting message
  String get tebrikMesaji {
    final langService = LanguageService();
    switch (tur) {
      case OzelGunTuru.bayram:
        return '${langService['eid_mubarak'] ?? ''} 🌙';
      case OzelGunTuru.kandil:
        return '${langService['kandil_mubarak'] ?? ''} ✨';
      case OzelGunTuru.mubarekGece:
        return '$ad ${langService['blessed_night'] ?? ''} 🤲';
      case OzelGunTuru.onemliGun:
        return '$ad ${langService['blessed_day'] ?? ''} 📿';
    }
  }

  /// Subtitle message
  String get altMesaj {
    return aciklama;
  }
}

class OzelGunlerService {
  static const String _sonGosterilenGunKey = 'son_gosterilen_ozel_gun';

  static const String _hijriDayShiftKey = 'hijri_day_shift';
  static const String _hijriDayShiftDateKey = 'hijri_day_shift_date';

  static const String _imsakSaatKey = 'ozel_gun_imsak_saat';
  static const String _imsakDakikaKey = 'ozel_gun_imsak_dakika';
  static const String _imsakDateKey = 'ozel_gun_imsak_date';
  static const String _aksamSaatKey = 'ozel_gun_aksam_saat';
  static const String _aksamDakikaKey = 'ozel_gun_aksam_dakika';

  // Cache keys for special days list
  // v2: 'tarih' artık özel günün gerçek tarihi (eskiden gösterim tarihiydi).
  static const String _ozelGunlerCacheKey = 'ozel_gunler_cache_v2';
  static const String _ozelGunlerCacheTimeKey = 'ozel_gunler_cache_time_v2';

  static int _hijriDayShift = 0;

  /// Public getter for hijri day shift (used by HomeWidgetService for native sync)
  static int get hijriDayShift => _hijriDayShift;

  /// Gün sınırları: normal özel günler imsakla başlar, kandil/mübarek geceler
  /// bir önceki günün akşam ezanıyla başlayıp asıl günün imsağında biter.
  /// Varsayılanlar [syncVakitlerWithDiyanet] ile güncel değerlerle değişir.
  static int _imsakSaat = 5;
  static int _imsakDakika = 30;
  static int _aksamSaat = 19;
  static int _aksamDakika = 0;

  /// Session-level popup shown flag
  /// Stays true during the session to show the popup only once
  static bool _sessionPopupShown = false;

  /// Sync Hijri calculations with Turkey/Diyanet calendar to prevent 1-day drift.
  ///
  /// The `hijri` package (Umm al-Qura) can differ from Turkey's official
  /// calendar on some dates (e.g., Ramadan start, Berat) by ±1 day.
  ///
  /// We compute a small day shift (typically -1/0/+1) by finding which
  /// `HijriCalendar.fromDate(today + shift)` matches Diyanet's Hijri date.
  static Future<void> syncHijriDayShiftWithDiyanet() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';

      // Apply cached shift immediately if available.
      final cachedShift = prefs.getInt(_hijriDayShiftKey);
      if (cachedShift != null) {
        _hijriDayShift = cachedShift;
      }

      // If we already synced today, stop here.
      final cachedDateKey = prefs.getString(_hijriDayShiftDateKey);
      if (cachedDateKey == todayKey) {
        debugPrint(
          '🗓️ [HijriShift] Using cached shift for today: $_hijriDayShift',
        );
        return;
      }

      final ilceId = await KonumService.getIlceId();
      if (ilceId == null ||
          ilceId.isEmpty ||
          KonumService.isManualIlceId(ilceId)) {
        debugPrint('🗓️ [HijriShift] Skip: no Turkey district selected');
        return;
      }

      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      final hicriKisa = vakitler?['HicriTarihKisa']?.toString() ?? '';
      if (hicriKisa.isEmpty || !hicriKisa.contains('.')) {
        debugPrint('🗓️ [HijriShift] Skip: Diyanet Hijri date missing');
        return;
      }

      final parts = hicriKisa.split('.');
      if (parts.length < 3) return;

      final hDay = int.tryParse(parts[0]) ?? 0;
      final hMonth = int.tryParse(parts[1]) ?? 0;
      final hYear = int.tryParse(parts[2]) ?? 0;
      if (hDay <= 0 || hMonth <= 0 || hYear <= 0) return;

      final todayDate = DateTime(now.year, now.month, now.day);

      int? foundShift;
      for (final shift in const [-2, -1, 0, 1, 2]) {
        final testDate = todayDate.add(Duration(days: shift));
        final testHijri = HijriCalendar.fromDate(testDate);
        if (testHijri.hYear == hYear &&
            testHijri.hMonth == hMonth &&
            testHijri.hDay == hDay) {
          foundShift = shift;
          break;
        }
      }

      if (foundShift == null) {
        debugPrint(
          '🗓️ [HijriShift] No matching shift found (Diyanet=$hicriKisa)',
        );
        return;
      }

      _hijriDayShift = foundShift;
      await prefs.setInt(_hijriDayShiftKey, foundShift);
      await prefs.setString(_hijriDayShiftDateKey, todayKey);

      debugPrint(
        '🗓️ [HijriShift] Applied shift=$_hijriDayShift (Diyanet=$hicriKisa)',
      );
    } catch (e) {
      debugPrint('🗓️ [HijriShift] Failed to sync: $e');
    }
  }

  /// Özel gün sınırlarında kullanılan imsak ve akşam vakitlerini Diyanet'ten
  /// senkronize eder. Normal özel günler imsakla başlar; kandil/mübarek geceler
  /// bir önceki günün akşam ezanıyla başlayıp asıl günün imsağında biter.
  static Future<void> syncVakitlerWithDiyanet() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';

      final cachedImsakSaat = prefs.getInt(_imsakSaatKey);
      final cachedImsakDakika = prefs.getInt(_imsakDakikaKey);
      if (cachedImsakSaat != null && cachedImsakDakika != null) {
        _imsakSaat = cachedImsakSaat;
        _imsakDakika = cachedImsakDakika;
      }
      final cachedAksamSaat = prefs.getInt(_aksamSaatKey);
      final cachedAksamDakika = prefs.getInt(_aksamDakikaKey);
      if (cachedAksamSaat != null && cachedAksamDakika != null) {
        _aksamSaat = cachedAksamSaat;
        _aksamDakika = cachedAksamDakika;
      }

      final cachedDateKey = prefs.getString(_imsakDateKey);
      if (cachedDateKey == todayKey) {
        debugPrint(
          '🌅 [Vakit] Using cached times: imsak=$_imsakSaat:$_imsakDakika '
          'aksam=$_aksamSaat:$_aksamDakika',
        );
        return;
      }

      final ilceId = await KonumService.getIlceId();
      if (ilceId == null ||
          ilceId.isEmpty ||
          KonumService.isManualIlceId(ilceId)) {
        debugPrint('🌅 [Vakit] Skip: no Turkey district selected');
        return;
      }

      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      final imsak = _parseSaat(vakitler?['Imsak']);
      final aksam = _parseSaat(vakitler?['Aksam']);
      if (imsak == null || aksam == null) {
        debugPrint('🌅 [Vakit] Skip: Imsak/Aksam time missing');
        return;
      }

      _imsakSaat = imsak.saat;
      _imsakDakika = imsak.dakika;
      _aksamSaat = aksam.saat;
      _aksamDakika = aksam.dakika;
      await prefs.setInt(_imsakSaatKey, imsak.saat);
      await prefs.setInt(_imsakDakikaKey, imsak.dakika);
      await prefs.setInt(_aksamSaatKey, aksam.saat);
      await prefs.setInt(_aksamDakikaKey, aksam.dakika);
      await prefs.setString(_imsakDateKey, todayKey);

      debugPrint(
        '🌅 [Vakit] Applied imsak=$_imsakSaat:$_imsakDakika '
        'aksam=$_aksamSaat:$_aksamDakika',
      );
    } catch (e) {
      debugPrint('🌅 [Vakit] Failed to sync: $e');
    }
  }

  static ({int saat, int dakika})? _parseSaat(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    final saat = int.tryParse(parts[0]);
    final dakika = int.tryParse(parts[1]);
    if (saat == null || dakika == null) return null;
    return (saat: saat, dakika: dakika);
  }

  /// Sadece SharedPreferences'taki önbellek değerini hafızaya yükler.
  /// syncHijriDayShiftWithDiyanet() öncesinde çağrılan servisler
  /// (örn. HomeWidgetService.initialize) için güvenlik katmanı sağlar.
  static Future<void> loadCachedHijriShift() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt(_hijriDayShiftKey);
      if (cached != null) {
        _hijriDayShift = cached;
        debugPrint('🗓️ [HijriShift] Cached shift pre-loaded: $_hijriDayShift');
      }
    } catch (e) {
      debugPrint('🗓️ [HijriShift] loadCachedHijriShift failed: $e');
    }
  }

  static HijriCalendar hijriNowTR() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    return HijriCalendar.fromDate(base.add(Duration(days: _hijriDayShift)));
  }

  static DateTime? _parseDottedDate(String value) {
    // Expected: dd.MM.yyyy
    final parts = value.split('.');
    if (parts.length < 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  static ({int day, int month, int year})? _parseDottedHijriDate(String value) {
    // Expected: dd.MM.yyyy (Hijri)
    final parts = value.split('.');
    if (parts.length < 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return (day: day, month: month, year: year);
  }

  static bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  /// TEST MODE - used during development
  /// Should be false in production.
  static const bool _testModu = false;
  static const OzelGun _testOzelGun = OzelGun(
    adKey: 'barat',
    aciklamaKey: 'barat_desc',
    tur: OzelGunTuru.kandil,
    hicriAy: 8,
    hicriGun: 15,
    geceOncesiMi: true,
  );

  /// Special days by Hijri calendar
  /// Hijri months: 1-Muharram, 2-Safar, 3-Rabi al-Awwal, 4-Rabi al-Thani, 5-Jumada al-Awwal,
  /// 6-Jumada al-Thani, 7-Rajab, 8-Shaban, 9-Ramadan, 10-Shawwal, 11-Dhul Qadah, 12-Dhul Hijjah
  static const List<OzelGun> ozelGunler = [
    // Muharram (1)
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

    // Rabi al-Awwal (3)
    OzelGun(
      adKey: 'mawlid',
      aciklamaKey: 'mawlid_desc',
      tur: OzelGunTuru.kandil,
      hicriAy: 3,
      hicriGun: 12,
      geceOncesiMi: true,
    ),

    // Rajab (7)
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

    // Shaban (8)
    OzelGun(
      adKey: 'barat',
      aciklamaKey: 'barat_desc',
      tur: OzelGunTuru.kandil,
      hicriAy: 8,
      hicriGun: 15,
      geceOncesiMi: true,
    ),

    // Ramadan (9)
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

    // Shawwal (10)
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

    // Dhul Hijjah (12)
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

  /// Check if today is a special day
  /// Banner becomes active after 09:00
  static OzelGun? bugunOzelGunMu() {
    // TEST MODE - for development
    if (_testModu) {
      return _testOzelGun;
    }

    final now = DateTime.now();
    final hicri = hijriNowTR();
    final hicriAy = hicri.hMonth;
    final hicriGun = hicri.hDay;

    debugPrint(
      '📅 [OzelGun] Today: $now.day/$now.month/$now.year $now.hour:$now.minute',
    );
    debugPrint('📅 [OzelGun] Hicri: $hicriGun/$hicriAy/$hicri.hYear');

    final imsakVakti = DateTime(
      now.year,
      now.month,
      now.day,
      _imsakSaat,
      _imsakDakika,
    );
    for (final ozelGun in ozelGunler) {
      if (ozelGun.hicriAy != hicriAy) continue;

      if (!ozelGun.geceOncesiMi) {
        // 1. Bayram/arefe gibi gündüz başlayan günler: imsaktan gün sonuna.
        if (ozelGun.hicriGun == hicriGun && !now.isBefore(imsakVakti)) {
          debugPrint('✅ [OzelGun] Today is special: ${ozelGun.ad}');
          return ozelGun;
        }
      } else {
        // 2. Kandil/mübarek geceler: İslami günde önce gece gelir; asıl günün
        //    imsağında biter. Kullanıcı geceyi önceden bilsin diye gösterim
        //    bir önceki gün sabah 09:00'da başlar (akşam ezanı yalnızca
        //    "gece başladı" bildirimi için kullanılır).
        // a) Kandilden önceki gün, 09:00'dan gece yarısına kadar.
        if (ozelGun.hicriGun == hicriGun + 1 && now.hour >= 9) {
          debugPrint(
            '✅ [OzelGun] Tonight is kandil/night: ${ozelGun.ad} (show today)',
          );
          return ozelGun;
        }
        // b) Kandilin asıl günü, gece yarısından imsağa kadar.
        if (ozelGun.hicriGun == hicriGun && now.isBefore(imsakVakti)) {
          debugPrint(
            '✅ [OzelGun] Night continues: ${ozelGun.ad} '
            '(until Imsak $_imsakSaat:$_imsakDakika)',
          );
          return ozelGun;
        }
      }
    }

    debugPrint('❌ [OzelGun] No special day/night today');
    return null;
  }

  /// Check if popup should be shown today
  static Future<bool> popupGosterilmeliMi() async {
    // Do not show again if already shown in this session
    if (_sessionPopupShown) {
      return false;
    }

    final ozelGun = bugunOzelGunMu();
    if (ozelGun == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final sonGosterilen = prefs.getString(_sonGosterilenGunKey);

    final gosterimAnahtari = _ozelGunGosterimAnahtari(ozelGun);

    // Do not show again if this occurrence was already shown
    // (window may span two calendar days: previous day 09:00 → Imsak).
    if (sonGosterilen == gosterimAnahtari) {
      return false;
    }

    return true;
  }

  /// Mark popup as shown
  static Future<void> popupGosterildiIsaretle() async {
    // Mark session flag
    _sessionPopupShown = true;

    final ozelGun = bugunOzelGunMu();
    if (ozelGun == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sonGosterilenGunKey,
      _ozelGunGosterimAnahtari(ozelGun),
    );
  }

  /// Bir özel günün "gösterildi" anahtarı: takvim gününe değil, o özel günün
  /// hicri oluşuna göre üretilir. Böylece gece öncesi ve gece sonrası (imsağa
  /// kadar) iki farklı miladi güne düşse bile aynı anahtar kalır ve popup
  /// sadece bir kez gösterilir.
  static String _ozelGunGosterimAnahtari(OzelGun ozelGun) {
    final hicri = hijriNowTR();
    return '${ozelGun.adKey}_${hicri.hYear}_${ozelGun.hicriAy}_${ozelGun.hicriGun}';
  }

  /// Get upcoming special days (within 30 days)
  static List<Map<String, dynamic>> yaklasanOzelGunler() {
    final List<Map<String, dynamic>> sonuc = [];
    final bugun = hijriNowTR();

    for (final ozelGun in ozelGunler) {
      // This year's date
      int hedefYil = bugun.hYear;

      // If this year's date passed, use next year
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
        ).subtract(Duration(days: _hijriDayShift));
        // Kandil/mübarek geceler önceki akşam başlar → gösterim tarihi 1 gün önce
        final gosterimTarih = ozelGun.geceOncesiMi
            ? tarih.subtract(const Duration(days: 1))
            : tarih;
        final simdi = DateTime.now();
        // Kalan gün özel günün gerçek tarihine göre hesaplanır; gece öncesi
        // gösterim kaydırması bu sayacı etkilemez.
        final fark = tarih
            .difference(DateTime(simdi.year, simdi.month, simdi.day))
            .inDays;

        // Add those within 365 days
        if (fark >= 0 && fark <= 365) {
          sonuc.add({
            'ozelGun': ozelGun,
            'tarih': tarih,
            'gosterimTarih': gosterimTarih,
            'kalanGun': fark,
            'hicriTarih':
                '${ozelGun.hicriGun} ${_getHicriAyAdi(ozelGun.hicriAy)} $hedefYil',
          });
        }
      } catch (e) {
        // Date conversion error
        debugPrint('Date conversion error: $e');
      }
    }

    // Sort by date
    sonuc.sort(
      (a, b) => (a['kalanGun'] as int).compareTo(b['kalanGun'] as int),
    );

    return sonuc;
  }

  /// Load saved special days list from SharedPreferences.
  /// Returns instantly without any network call. Data persists permanently
  /// until user explicitly taps the refresh button.
  static Future<List<Map<String, dynamic>>?> _loadCachedOzelGunler() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_ozelGunlerCacheKey);
      if (jsonStr == null) return null;

      final now = DateTime.now();
      final decoded = jsonDecode(jsonStr) as List;
      final result = decoded.map((item) {
        final map = item as Map<String, dynamic>;
        // Reconstruct OzelGun from cached key
        final adKey = map['adKey'] as String;
        final ozelGun = ozelGunler.firstWhere(
          (g) => g.adKey == adKey && g.hicriGun == (map['hicriGun'] as int),
          orElse: () => ozelGunler.first,
        );
        final tarih = DateTime.parse(map['tarih'] as String);
        final gosterimTarihStr = map['gosterimTarih'] as String?;
        final gosterimTarih = gosterimTarihStr != null
            ? DateTime.parse(gosterimTarihStr)
            : (ozelGun.geceOncesiMi
                  ? tarih.subtract(const Duration(days: 1))
                  : tarih);
        return {
          'ozelGun': ozelGun,
          'tarih': tarih,
          'gosterimTarih': gosterimTarih,
          'kalanGun': tarih
              .difference(DateTime(now.year, now.month, now.day))
              .inDays,
          'hicriTarih': map['hicriTarih'] as String,
        };
      }).where((m) => (m['kalanGun'] as int) >= 0).toList();

      // Re-sort by remaining days (might have changed since cache)
      result.sort(
        (a, b) => (a['kalanGun'] as int).compareTo(b['kalanGun'] as int),
      );

      debugPrint('📂 Loaded ${result.length} cached special days');
      return result;
    } catch (e) {
      debugPrint('⚠️ Failed to load cached special days: $e');
      return null;
    }
  }

  /// Save special days list to SharedPreferences for offline access.
  static Future<void> _saveCachedOzelGunler(
    List<Map<String, dynamic>> gunler,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = gunler.map((item) {
        final ozelGun = item['ozelGun'] as OzelGun;
        final tarih = item['tarih'] as DateTime;
        final gosterimTarih = (item['gosterimTarih'] as DateTime?) ?? tarih;
        return {
          'adKey': ozelGun.adKey,
          'hicriGun': ozelGun.hicriGun,
          'tarih': tarih.toIso8601String(),
          'gosterimTarih': gosterimTarih.toIso8601String(),
          'hicriTarih': item['hicriTarih'] as String,
        };
      }).toList();
      await prefs.setString(_ozelGunlerCacheKey, jsonEncode(serialized));
      await prefs.setInt(
        _ozelGunlerCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('💾 Saved ${gunler.length} special days to cache');
    } catch (e) {
      debugPrint('⚠️ Failed to save special days cache: $e');
    }
  }

  /// Load special days from local cache (instant, no network).
  /// Returns null if no cache available.
  static Future<List<Map<String, dynamic>>?> cachedOzelGunler() async {
    return _loadCachedOzelGunler();
  }

  /// Get upcoming special days using Turkey/Diyanet calendar mapping.
  ///
  /// This avoids 1-day drift and also handles Hijri month length differences
  /// (e.g., Ramadan can be 29 days in Turkey).
  /// Results are cached locally for offline/instant access.
  static Future<List<Map<String, dynamic>>> yaklasanOzelGunlerAsync({
    int daysAhead = 365,
  }) async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId == null ||
        ilceId.isEmpty ||
        KonumService.isManualIlceId(ilceId)) {
      return yaklasanOzelGunler();
    }

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(Duration(days: daysAhead));

    final dayRows = <({DateTime gDate, int hDay, int hMonth, int hYear})>[];

    // Iterate months between startDate and endDate (inclusive).
    var year = startDate.year;
    var month = startDate.month;
    while (true) {
      final monthStart = DateTime(year, month, 1);
      if (monthStart.isAfter(endDate)) break;

      try {
        final list = await DiyanetApiService.getAylikVakitler(
          ilceId,
          year,
          month,
        );
        for (final item in list) {
          final gStr = item['MiladiTarihKisa']?.toString() ?? '';
          final hStr = item['HicriTarihKisa']?.toString() ?? '';
          if (gStr.isEmpty || hStr.isEmpty) continue;

          final gDate = _parseDottedDate(gStr);
          final h = _parseDottedHijriDate(hStr);
          if (gDate == null || h == null) continue;

          if (_isDateInRange(gDate, startDate, endDate)) {
            dayRows.add((
              gDate: gDate,
              hDay: h.day,
              hMonth: h.month,
              hYear: h.year,
            ));
          }
        }
      } catch (e) {
        debugPrint('⚠️ [OzelGunler] Failed to fetch month $month/$year: $e');
      }

      // next month
      if (month == 12) {
        month = 1;
        year++;
      } else {
        month++;
      }
    }

    // Ensure chronological order.
    dayRows.sort((a, b) => a.gDate.compareTo(b.gDate));

    // If API data is insufficient, fall back to local Hijri calculation
    if (dayRows.length < 30) {
      debugPrint(
        '⚠️ [OzelGunler] API data insufficient (${dayRows.length} rows), '
        'falling back to local Hijri calculation',
      );
      return yaklasanOzelGunler();
    }

    final result = <Map<String, dynamic>>[];

    for (final ozelGun in ozelGunler) {
      ({DateTime gDate, int hDay, int hMonth, int hYear})? match;
      for (final row in dayRows) {
        if (row.hMonth == ozelGun.hicriAy && row.hDay == ozelGun.hicriGun) {
          match = row;
          break;
        }
      }

      if (match == null) continue;

      final kalanGun = match.gDate.difference(startDate).inDays;
      if (kalanGun < 0 || kalanGun > daysAhead) continue;

      // Kandil/mübarek geceler önceki akşam başlar → gösterim/bildirim 1 gün önce
      final gosterimTarih = ozelGun.geceOncesiMi
          ? match.gDate.subtract(const Duration(days: 1))
          : match.gDate;

      result.add({
        'ozelGun': ozelGun,
        // Özel günün gerçek (hicri) tarihi — listede bu gösterilir.
        'tarih': match.gDate,
        // Gösterim/bildirimin başladığı gün (kandillerde bir gün önce).
        'gosterimTarih': gosterimTarih,
        'kalanGun': kalanGun,
        'hicriTarih':
            '${ozelGun.hicriGun} ${_getHicriAyAdi(ozelGun.hicriAy)} ${match.hYear}',
      });
    }

    // If no results found from API data, fall back to local calculation
    if (result.isEmpty) {
      debugPrint(
        '⚠️ [OzelGunler] No special days matched from API data, '
        'falling back to local Hijri calculation',
      );
      return yaklasanOzelGunler();
    }

    result.sort(
      (a, b) => (a['kalanGun'] as int).compareTo(b['kalanGun'] as int),
    );

    // Save results to local cache
    await _saveCachedOzelGunler(result);

    return result;
  }

  /// Return Hijri month name
  static String _getHicriAyAdi(int ay) {
    final languageService = LanguageService();
    if (ay >= 1 && ay <= 12) {
      return languageService['hijri_month_$ay'] ?? '';
    }
    return '';
  }

  // ========== SPECIAL DAY NOTIFICATIONS ==========

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int _ozelGunBildirimIdBase = 5000;

  /// Schedule special day notifications
  /// Schedule notifications for special days within 7 days
  /// For geceOncesiMi: schedule both previous day 09:00 and main day 00:05
  static Future<void> scheduleOzelGunBildirimleri() async {
    // Ensure Hijri calendar is aligned (important for conversions used below).
    await syncHijriDayShiftWithDiyanet();
    await syncVakitlerWithDiyanet();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('ozel_gun_bildirimleri_aktif') ?? true;

    if (!enabled) {
      debugPrint('📅 Special day notifications disabled');
      await cancelOzelGunBildirimleri();
      return;
    }

    debugPrint('📅 Scheduling special day notifications...');

    // Cancel existing notifications first
    await cancelOzelGunBildirimleri();

    // Get upcoming special days (prefer Diyanet mapping)
    final yaklasanlar = await yaklasanOzelGunlerAsync(daysAhead: 14);
    int zamanlanandi = 0;

    debugPrint('📅 ========== SPECIAL DAY SCHEDULING ==========');
    debugPrint('📅 Found ${yaklasanlar.length} special days total');

    int idOffset = 0;
    for (int i = 0; i < yaklasanlar.length && i < 10; i++) {
      final item = yaklasanlar[i];
      final ozelGun = item['ozelGun'] as OzelGun;
      // Bildirimler gösterim tarihine göre kurulur: kandillerde bu, geceyi
      // içeren bir önceki gündür (ör. 23'ünü 24'üne bağlayan gece → 23 Ağustos).
      final tarih =
          (item['gosterimTarih'] as DateTime?) ?? (item['tarih'] as DateTime);
      final kalanGun = item['kalanGun'] as int;

      debugPrint('\n🔍 Checking: ${ozelGun.ad}');
      debugPrint('   📆 Date: ${tarih.day}/${tarih.month}/${tarih.year}');
      debugPrint('   ⏰ Days left: $kalanGun');
      debugPrint('   🌙 Night-before: ${ozelGun.geceOncesiMi}');

      // Only schedule for special days within 7 days
      if (kalanGun > 7) {
        debugPrint('   ⏭️ Skipped: more than 7 days');
        continue;
      }

      if (ozelGun.geceOncesiMi) {
        // tarih = gecenin başladığı gün (ör. Kadir Gecesi → 16 Mart)
        // 1) O günün saat 09:00'ında bildirim ("Bu akşam Kadir Gecesi")
        DateTime oncekiGunBildirimi = DateTime(
          tarih.year,
          tarih.month,
          tarih.day,
          9,
          0,
        );
        if (oncekiGunBildirimi.isAfter(DateTime.now())) {
          final tzOncekiGun = tz.TZDateTime.from(oncekiGunBildirimi, tz.local);
          debugPrint(
            '   📍 Night-before notification: ${oncekiGunBildirimi.day}/${oncekiGunBildirimi.month} ${oncekiGunBildirimi.hour}:${oncekiGunBildirimi.minute.toString().padLeft(2, "0")}',
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
              '❌ Special day notification scheduling failed: ${ozelGun.ad} - $e',
            );
          }
        }
        // 2) Gecenin fiilen başladığı an: aynı günün akşam ezanı.
        //    (ör. 23 Ağustos'u 24'üne bağlayan kandil → 23 Ağustos akşamı)
        DateTime geceBildirimi = DateTime(
          tarih.year,
          tarih.month,
          tarih.day,
          _aksamSaat,
          _aksamDakika,
        );
        if (geceBildirimi.isAfter(DateTime.now())) {
          final tzGece = tz.TZDateTime.from(geceBildirimi, tz.local);
          debugPrint(
            '   📍 Night notification: ${geceBildirimi.day}/${geceBildirimi.month} ${geceBildirimi.hour}:${geceBildirimi.minute.toString().padLeft(2, "0")}',
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
              '❌ Special day notification scheduling failed: ${ozelGun.ad} - $e',
            );
          }
        }
      } else {
        // Other days: 09:00 of the same day
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
            '   📍 Normal day notification: ${bildirimZamani.day}/${bildirimZamani.month} ${bildirimZamani.hour}:${bildirimZamani.minute.toString().padLeft(2, "0")}',
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
              '❌ Special day notification scheduling failed: ${ozelGun.ad} - $e',
            );
          }
        }
      }
    }

    debugPrint('✅ $zamanlanandi special day notifications scheduled');
  }

  /// Schedule a single special day notification using AlarmManager
  /// Works even when the app is closed
  static Future<void> _scheduleOzelGunBildirimi({
    required int id,
    required OzelGun ozelGun,
    required tz.TZDateTime scheduledDate,
  }) async {
    final languageService = LanguageService();
    await languageService.load();

    // Notification content
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

    // Schedule via AlarmManager (works even when app is closed)
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
        '   📅 ${ozelGun.ad} - $tarihStr (ID: $id) - scheduled via AlarmManager ✅',
      );
    } else {
      debugPrint(
        '   ❌ ${ozelGun.ad} - AlarmManager scheduling failed, using fallback',
      );

      // Fallback: use zonedSchedule
      final channelName =
          languageService['special_days_channel_name'] ?? 'Special days';
      final channelDesc =
          languageService['special_days_channel_desc'] ??
          'Special days, nights, and holidays';
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'ozel_gunler_channel',
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        visibility: NotificationVisibility.public,
        autoCancel: false,
        ongoing: false,
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: androidPlatformChannelSpecifics,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'ozel_gun_${ozelGun.adKey}',
      );
      debugPrint(
        '   📅 ${ozelGun.ad} - $tarihStr (ID: $id) - scheduled via zonedSchedule',
      );
    }
  }

  /// Cancel special day notifications
  static Future<void> cancelOzelGunBildirimleri() async {
    for (int i = 0; i < 10; i++) {
      await _notificationsPlugin.cancel(id: _ozelGunBildirimIdBase + i);
      await AlarmService.cancelAlarm(_ozelGunBildirimIdBase + i);
    }
    debugPrint('🚫 Special day notifications canceled');
  }

  /// Enable/disable special day notifications
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
