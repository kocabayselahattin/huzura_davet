import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'alarm_service.dart';
import 'konum_service.dart';
import 'diyanet_api_service.dart';

/// Erken hatırlatma alarm servisi
/// Her vakit için bağımsız erken hatırlatma alarmı kurar
/// Ses dosyası, süre gibi ayarları yönetir
class EarlyReminderService {
  static bool _initialized = false;

  // Vakit isimleri (API uyumlu)
  static const List<String> _vakitler = [
    'Imsak',
    'Gunes',
    'Ogle',
    'Ikindi',
    'Aksam',
    'Yatsi',
  ];

  // Vakit Türkçe isimleri
  static const Map<String, String> _vakitTurkce = {
    'Imsak': 'İmsak',
    'Gunes': 'Güneş',
    'Ogle': 'Öğle',
    'Ikindi': 'İkindi',
    'Aksam': 'Akşam',
    'Yatsi': 'Yatsı',
  };

  // Varsayılan erken bildirim süreleri (dakika)
  static const Map<String, int> varsayilanErkenSureler = {
    'imsak': 15,
    'gunes': 45,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
  };

  // Varsayılan ses ID'si
  static const String varsayilanSes = 'best';

  /// Servisi başlat
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('✅ Erken hatırlatma servisi başlatıldı');
  }

  // =============================================
  // AYAR YÖNETİMİ
  // =============================================

  /// Erken hatırlatma süresini al (dakika)
  static Future<int> getErkenSure(String vakitKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('erken_$vakitKey') ??
        (varsayilanErkenSureler[vakitKey] ?? 15);
  }

  /// Erken hatırlatma süresini ayarla (dakika)
  static Future<void> setErkenSure(String vakitKey, int dakika) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('erken_$vakitKey', dakika);
    debugPrint('💾 Erken süre kaydedildi: $vakitKey = $dakika dk');
  }

  /// Erken hatırlatma alarm sesini al (ses ID'si)
  static Future<String> getErkenSes(String vakitKey) async {
    final prefs = await SharedPreferences.getInstance();
    final ses = prefs.getString('erken_bildirim_sesi_$vakitKey');
    if (ses != null && ses.isNotEmpty) return ses;
    // Kayıtlı ses yoksa vaktinde sesini kullan
    final vaktindeSes = prefs.getString('bildirim_sesi_$vakitKey');
    return vaktindeSes ?? varsayilanSes;
  }

  /// Erken hatırlatma alarm sesini ayarla (ses ID'si)
  static Future<void> setErkenSes(String vakitKey, String sesId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('erken_bildirim_sesi_$vakitKey', sesId);
    debugPrint('💾 Erken ses kaydedildi: $vakitKey = $sesId');
  }

  /// Ses dosyası adını Android raw resource adına normalize et
  /// Örn: "best.mp3" → "best", "akşam_ezanı.mp3" → "aksam_ezani"
  static String normalizeSoundName(String soundFile) {
    if (soundFile.isEmpty) return 'best';
    String name = soundFile.toLowerCase();
    // Yol varsa sondaki dosya adını al
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    // .mp3 uzantısını kaldır
    if (name.endsWith('.mp3')) {
      name = name.substring(0, name.length - 4);
    }
    // Geçersiz karakterleri temizle
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    // Birden fazla alt çizgiyi teke indir
    name = name.replaceAll(RegExp(r'_+'), '_');
    // Baş ve sondaki alt çizgileri kaldır
    name = name.replaceAll(RegExp(r'^_+|_+$'), '');
    if (name.isEmpty) return 'best';
    return name;
  }

  // =============================================
  // ALARM ZAMANLAMA
  // =============================================

  /// Tüm vakitler için erken hatırlatma alarmlarını zamanla (7 günlük)
  static Future<int> scheduleAllEarlyReminders() async {
    try {
      if (!_initialized) await initialize();

      debugPrint('⏰ ===== ERKEN HATIRLATMA ZAMANLAMA BAŞLIYOR =====');

      // Mevcut erken alarmları iptal et
      await cancelAllEarlyReminders();

      // Konum ID'sini al
      final ilceId = await KonumService.getIlceId();
      if (ilceId == null || ilceId.isEmpty) {
        debugPrint('❌ KONUM SEÇİLMEMİŞ! Erken hatırlatmalar zamanlanamıyor.');
        debugPrint('⚠️ Lütfen ana sayfadan konum seçin.');
        debugPrint('==========================================');
        return 0;
      }
      debugPrint('📍 Konum ID: $ilceId');

      // 7 günlük vakit bilgisi al
      final now = DateTime.now();
      debugPrint('🕐 Şimdiki zaman: $now');

      final aylikVakitler = await DiyanetApiService.getAylikVakitler(
        ilceId,
        now.year,
        now.month,
      );
      debugPrint('📅 Bu ay vakit sayısı: ${aylikVakitler.length}');

      // Gelecek ay da lazım olabilir
      List<Map<String, dynamic>> sonrakiAyVakitler = [];
      if (now.day > 24) {
        final sonrakiAy = now.month == 12 ? 1 : now.month + 1;
        final sonrakiYil = now.month == 12 ? now.year + 1 : now.year;
        sonrakiAyVakitler = await DiyanetApiService.getAylikVakitler(
          ilceId,
          sonrakiYil,
          sonrakiAy,
        );
        debugPrint('📅 Gelecek ay vakit sayısı: ${sonrakiAyVakitler.length}');
      }

      final tumVakitler = [...aylikVakitler, ...sonrakiAyVakitler];
      if (tumVakitler.isEmpty) {
        debugPrint('❌ VAKİT BİLGİSİ ALINAMADI!');
        debugPrint('⚠️ İnternet bağlantısını kontrol edin.');
        debugPrint('==========================================');
        return 0;
      }
      debugPrint('📊 Toplam vakit bilgisi: ${tumVakitler.length} gün');

      final prefs = await SharedPreferences.getInstance();
      int alarmCount = 0;
      int skippedCount = 0;

      // 7 gün için döngü
      for (int gun = 0; gun < 7; gun++) {
        final hedefTarih = now.add(Duration(days: gun));
        final hedefTarihStr =
            '${hedefTarih.day.toString().padLeft(2, '0')}.${hedefTarih.month.toString().padLeft(2, '0')}.${hedefTarih.year}';

        debugPrint('\\n📆 Gün $gun: $hedefTarihStr');

        // O güne ait vakitleri bul
        final gunVakitler = tumVakitler.firstWhere(
          (v) => v['MiladiTarihKisa'] == hedefTarihStr,
          orElse: () => <String, dynamic>{},
        );

        if (gunVakitler.isEmpty) {
          debugPrint('   ⚠️ Bu gün için vakit bilgisi yok');
          continue;
        }

        for (int i = 0; i < _vakitler.length; i++) {
          final vakitKey = _vakitler[i];
          final vakitKeyLower = vakitKey.toLowerCase();

          // Ana bildirim switch'i - kapalıysa erken hatırlatma da kapalı
          final bildirimAcik = prefs.getBool('bildirim_$vakitKeyLower') ?? true;
          if (!bildirimAcik) {
            debugPrint(
              '   ⏭️ $vakitKey ana bildirimi kapalı, erken hatırlatma atlanıyor',
            );
            skippedCount++;
            continue;
          }

          // Erken hatırlatma süresi
          final erkenDakika =
              prefs.getInt('erken_$vakitKeyLower') ??
              (varsayilanErkenSureler[vakitKeyLower] ?? 15);

          // Erken dakika 0 ise kullanıcı kapatmış demektir
          if (erkenDakika <= 0) {
            debugPrint('   ⏭️ $vakitKey erken hatırlatma kapalı (0 dk)');
            skippedCount++;
            continue;
          }

          // Vakit saatini al
          final vakitSaati = gunVakitler[vakitKey]?.toString();
          if (vakitSaati == null || vakitSaati == '—:—' || vakitSaati.isEmpty) {
            debugPrint('   ⚠️ $vakitKey saati bulunamadı');
            continue;
          }

          final parts = vakitSaati.split(':');
          if (parts.length != 2) continue;
          final saat = int.tryParse(parts[0]);
          final dakika = int.tryParse(parts[1]);
          if (saat == null || dakika == null) continue;

          // Vakit saatini kaydet (BootReceiver için) - ÖNEMLI!
          final dateKey =
              '${hedefTarih.year}-${hedefTarih.month.toString().padLeft(2, '0')}-${hedefTarih.day.toString().padLeft(2, '0')}';
          await prefs.setString('vakit_${vakitKeyLower}_$dateKey', vakitSaati);

          // Tam vakit zamanı
          final vakitZamani = DateTime(
            hedefTarih.year,
            hedefTarih.month,
            hedefTarih.day,
            saat,
            dakika,
          );

          // Erken alarm zamanı
          final erkenAlarmZamani = vakitZamani.subtract(
            Duration(minutes: erkenDakika),
          );

          if (!erkenAlarmZamani.isAfter(now)) {
            debugPrint(
              '   ⏭️ $vakitKey erken alarm zamanı geçmiş ($erkenAlarmZamani)',
            );
            skippedCount++;
            continue;
          }

          // Erken alarm sesini al - ARTIK SES ID'Sİ KULLANIYORUZ
          final erkenSesId =
              prefs.getString('erken_bildirim_sesi_$vakitKeyLower') ??
              prefs.getString('bildirim_sesi_$vakitKeyLower') ??
              varsayilanSes;

          // Benzersiz alarm ID'si oluştur
          final erkenAlarmId = AlarmService.generateAlarmId(
            '${vakitKeyLower}_erken',
            erkenAlarmZamani,
          );

          debugPrint(
            '   ⏰ $vakitKey erken alarm: $erkenAlarmZamani ($erkenDakika dk önce), ses: $erkenSesId, ID: $erkenAlarmId',
          );

          // Alarmı zamanla - SES ID'SİNİ DİREKT GÖNDERİYORUZ
          final success = await AlarmService.scheduleAlarm(
            prayerName: '${_vakitTurkce[vakitKey]} ($erkenDakika dk)',
            triggerAtMillis: erkenAlarmZamani.millisecondsSinceEpoch,
            soundPath: erkenSesId, // Ses ID'si
            useVibration: true,
            alarmId: erkenAlarmId,
            isEarly: true,
            earlyMinutes: erkenDakika,
          );

          if (success) {
            alarmCount++;
            debugPrint('      ✅ Erken alarm zamanlandı');
          } else {
            debugPrint('      ❌ Erken alarm zamanlanamadı');
            skippedCount++;
          }
        }
      }

      debugPrint('\\n⏰ ===== ERKEN HATIRLATMA ZAMANLAMA BİTTİ =====');
      debugPrint('✅ Kurulan alarm sayısı: $alarmCount');
      debugPrint('⏭️ Atlanan/başarısız: $skippedCount');
      debugPrint('==========================================\\n');
      return alarmCount;
    } catch (e, stackTrace) {
      debugPrint('❌ ERKEN HATIRLATMA ZAMANLAMA HATASI: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      debugPrint('==========================================');
      return 0;
    }
  }

  /// Tüm erken hatırlatma alarmlarını iptal et
  static Future<void> cancelAllEarlyReminders() async {
    final now = DateTime.now();
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = now.add(Duration(days: gun));
      for (final vakitKey in _vakitler) {
        final vakitKeyLower = vakitKey.toLowerCase();
        final erkenAlarmId = AlarmService.generateAlarmId(
          '${vakitKeyLower}_erken',
          hedefTarih,
        );
        await AlarmService.cancelAlarm(erkenAlarmId);
      }
    }
    debugPrint('🗑️ Tüm erken hatırlatma alarmları iptal edildi');
  }

  /// Belirli bir vakit için erken hatırlatma alarmını iptal et
  static Future<void> cancelEarlyReminder(String vakitKeyLower) async {
    final now = DateTime.now();
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = now.add(Duration(days: gun));
      final erkenAlarmId = AlarmService.generateAlarmId(
        '${vakitKeyLower}_erken',
        hedefTarih,
      );
      await AlarmService.cancelAlarm(erkenAlarmId);
    }
    debugPrint('🗑️ $vakitKeyLower erken hatırlatma alarmı iptal edildi');
  }

  /// Ayarları topluca kaydet ve alarmları yeniden zamanla
  /// Returns: Kurulan alarm sayısı
  static Future<int> saveAndReschedule({
    required Map<String, int> erkenSureler,
    required Map<String, String> erkenSesler,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    debugPrint('💾 Erken hatırlatma ayarları kaydediliyor...');
    for (final entry in erkenSureler.entries) {
      await prefs.setInt('erken_${entry.key}', entry.value);
      debugPrint('   - ${entry.key}: ${entry.value} dakika');
    }

    for (final entry in erkenSesler.entries) {
      await prefs.setString('erken_bildirim_sesi_${entry.key}', entry.value);
    }

    debugPrint('💾 Erken hatırlatma ayarları kaydedildi');

    // Alarmları yeniden zamanla ve kurulan alarm sayısını döndür
    final alarmCount = await scheduleAllEarlyReminders();
    debugPrint('🔔 Toplam $alarmCount erken hatırlatma alarmı kuruldu');
    return alarmCount;
  }
}
