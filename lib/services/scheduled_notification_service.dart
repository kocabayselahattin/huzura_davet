import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'konum_service.dart';
import 'diyanet_api_service.dart';
import 'alarm_service.dart';
import 'early_reminder_service.dart';

/// Zamanlanmış alarm servisi - Uygulama kapalıyken bile vakit alarmlarını kurar
/// NOT: Erken hatırlatma alarmları EarlyReminderService tarafından yönetilir
class ScheduledNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Timer? _dailyScheduleTimer;
  static DateTime? _lastScheduleDate;

  // Vakit isimleri
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

  /// Servisi başlat
  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(settings: initializationSettings);

    // Android 13+ için bildirim izni kontrolü
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      final hasPermission =
          await androidImplementation.areNotificationsEnabled() ?? false;
      debugPrint('📱 Bildirim izni durumu: $hasPermission');

      if (!hasPermission) {
        debugPrint('⚠️ Bildirim izni verilmemiş! İzin isteniyor...');
        final granted =
            await androidImplementation.requestNotificationsPermission() ??
            false;
        debugPrint('📱 Bildirim izni sonucu: $granted');

        if (!granted) {
          debugPrint('❌ Bildirim izni reddedildi! Bildirimler çalışmayacak.');
        }
      }

      // Exact alarm izni kontrolü (Android 12+)
      final canScheduleExact =
          await androidImplementation.canScheduleExactNotifications() ?? false;
      debugPrint('⏰ Exact alarm izni: $canScheduleExact');

      if (!canScheduleExact) {
        debugPrint('⚠️ Exact alarm izni yok! İzin isteniyor...');
        final granted =
            await androidImplementation.requestExactAlarmsPermission() ?? false;
        debugPrint('⏰ Exact alarm izni sonucu: $granted');
      }
    }

    _initialized = true;
    debugPrint('✅ Zamanlanmış bildirim servisi başlatıldı');

    // Günlük zamanlama kontrolü başlat
    _startDailyScheduleCheck();
  }

  /// Gunluk alarmlari kontrol eden timer baslat
  /// 7 gunluk zamanlama oldugu icin her gun yeniden zamanlamaya gerek yok
  /// Sadece zamanlamalar bitince yeniden zamanla
  static void _startDailyScheduleCheck() {
    _dailyScheduleTimer?.cancel();
    // Her 30 dakikada bir kontrol et (pil tasarrufu için)
    _dailyScheduleTimer = Timer.periodic(const Duration(minutes: 30), (
      _,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // İlk kez zamanlanıyorsa
      if (_lastScheduleDate == null) {
        debugPrint('📅 İlk zamanlama yapılıyor...');
        await scheduleAllPrayerNotifications();
        _lastScheduleDate = today;
        return;
      }

      // 7 günlük zamanlama olduğu için 6. günde yeniden zamanla
      // Böylece her zaman en az 1 günlük önceden zamanlanmış olur
      final daysSinceLastSchedule = today.difference(_lastScheduleDate!).inDays;
      if (daysSinceLastSchedule >= 6) {
        debugPrint('📅 6 gün geçti, bildirimler yeniden zamanlanıyor...');
        await scheduleAllPrayerNotifications();
        _lastScheduleDate = today;
      }
    });
  }

  /// Tum vakit alarmlarini zamanla (7 gunluk - 1 hafta)
  /// Bu sayede uygulama birkac gun acilmasa bile alarmlar calisir
  static Future<void> scheduleAllPrayerNotifications() async {
    try {
      // 7 gün için zamanlama (1 hafta)
      const int zamanlamaSuresi = 7;
      debugPrint(
        '🔔 $zamanlamaSuresi günlük vakit bildirimleri zamanlanıyor...',
      );

      // Önce mevcut namaz vakti bildirimlerini/alarmlarını iptal et
      await cancelAllNotifications();

      // Konum ID'sini al
      final ilceId = await KonumService.getIlceId();
      if (ilceId == null || ilceId.isEmpty) {
        debugPrint('⚠️ KRITIK: Konum seçilmemiş, bildirimler zamanlanamıyor!');
        debugPrint('📍 Kullanıcı konum seçmeli (il/ilçe)');
        return;
      }

      // 7 günlük vakit bilgisi için aylık verileri al
      final now = DateTime.now();
      final aylikVakitler = await DiyanetApiService.getAylikVakitler(
        ilceId,
        now.year,
        now.month,
      );

      // Gelecek ay da lazım olabilir (ay sonundaysak veya 7 gün için)
      List<Map<String, dynamic>> sonrakiAyVakitler = [];
      if (now.day > 24) {
        // 7 gün için erken başla
        final sonrakiAy = now.month == 12 ? 1 : now.month + 1;
        final sonrakiYil = now.month == 12 ? now.year + 1 : now.year;
        sonrakiAyVakitler = await DiyanetApiService.getAylikVakitler(
          ilceId,
          sonrakiYil,
          sonrakiAy,
        );
      }

      // Tüm vakitleri birleştir
      final tumVakitler = [...aylikVakitler, ...sonrakiAyVakitler];

      if (tumVakitler.isEmpty) {
        debugPrint('⚠️ Vakit bilgisi alınamadı');
        return;
      }

      debugPrint('📋 Toplam ${tumVakitler.length} günlük veri alındı');

      // Kullanıcı ayarlarını yükle
      final prefs = await SharedPreferences.getInstance();
      int alarmCount = 0;

      // 7 gün için döngü (1 hafta)
      for (int gun = 0; gun < zamanlamaSuresi; gun++) {
        final hedefTarih = now.add(Duration(days: gun));
        final hedefTarihStr =
            '${hedefTarih.day.toString().padLeft(2, '0')}.${hedefTarih.month.toString().padLeft(2, '0')}.${hedefTarih.year}';

        // O güne ait vakitleri bul
        final gunVakitler = tumVakitler.firstWhere(
          (v) => v['MiladiTarihKisa'] == hedefTarihStr,
          orElse: () => <String, dynamic>{},
        );

        if (gunVakitler.isEmpty) {
          debugPrint('⚠️ $hedefTarihStr için vakit bulunamadı');
          continue;
        }

        // Her vakit için TAM VAKİT alarmı zamanla
        // NOT: Erken hatırlatma alarmları EarlyReminderService tarafından ayrıca zamanlanır
        for (int i = 0; i < _vakitler.length; i++) {
          final vakitKey = _vakitler[i];
          final vakitKeyLower = vakitKey.toLowerCase();

          // Ana bildirim switch'i - bu vakit için tüm bildirimler açık mı?
          final bildirimAcik = prefs.getBool('bildirim_$vakitKeyLower') ?? true;

          // Vaktinde bildirim - tam vakitte bildirim gönder
          final varsayilanVaktinde =
              (vakitKeyLower == 'ogle' ||
              vakitKeyLower == 'ikindi' ||
              vakitKeyLower == 'aksam' ||
              vakitKeyLower == 'yatsi');
          final vaktindeBildirim =
              prefs.getBool('vaktinde_$vakitKeyLower') ?? varsayilanVaktinde;

          debugPrint(
            '🔍 [$vakitKey] bildirim=$bildirimAcik, vaktinde=$vaktindeBildirim',
          );

          final vakitSaati = gunVakitler[vakitKey]?.toString();
          if (vakitSaati == null || vakitSaati == '—:—' || vakitSaati.isEmpty) {
            continue;
          }

          // Vaktinde alarm ses dosyası - normalize et
          final sesDosyasiRaw =
              prefs.getString('bildirim_sesi_$vakitKeyLower') ?? 'best.mp3';
          final sesDosyasiNormalized =
              EarlyReminderService.normalizeSoundName(sesDosyasiRaw);

          // Vakit saatini parse et
          final parts = vakitSaati.split(':');
          if (parts.length != 2) continue;

          final saat = int.tryParse(parts[0]);
          final dakika = int.tryParse(parts[1]);
          if (saat == null || dakika == null) continue;

          // Vakit saatini kaydet (BootReceiver için)
          final dateKey =
              '${hedefTarih.year}-${hedefTarih.month.toString().padLeft(2, '0')}-${hedefTarih.day.toString().padLeft(2, '0')}';
          await prefs.setString('vakit_${vakitKeyLower}_$dateKey', vakitSaati);

          debugPrint(
            '📌 $vakitKey: $saat:$dakika, Bildirim: $bildirimAcik, Vaktinde: $vaktindeBildirim',
          );

          // Ana bildirim switch'i kapalıysa atla
          if (!bildirimAcik) {
            debugPrint('   ⏭️ Bildirim kapalı, atlanıyor');
            continue;
          }

          // TAM VAKİT ALARMI - Sadece vaktinde bildirim açıksa çal
          var alarmZamani = DateTime(
            hedefTarih.year,
            hedefTarih.month,
            hedefTarih.day,
            saat,
            dakika,
          );

          if (vaktindeBildirim && alarmZamani.isAfter(now)) {
            final alarmId = AlarmService.generateAlarmId(
              vakitKeyLower,
              alarmZamani,
            );

            debugPrint('   Alarm ID: $alarmId, Ses: $sesDosyasiNormalized');

            final success = await AlarmService.scheduleAlarm(
              prayerName: _vakitTurkce[vakitKey] ?? vakitKey,
              triggerAtMillis: alarmZamani.millisecondsSinceEpoch,
              soundPath: sesDosyasiNormalized,
              useVibration: true,
              alarmId: alarmId,
              isEarly: false,
              earlyMinutes: 0,
            );

            if (success) {
              alarmCount++;
              debugPrint('   ✅ Tam vakit alarmı zamanlandı');
            } else {
              debugPrint('   ❌ Tam vakit alarmı zamanlanamadı');
            }
          } else if (!vaktindeBildirim) {
            debugPrint(
              '   ⏭️ Vaktinde bildirim kapalı, alarm atlanıyor',
            );
          } else {
            debugPrint('   ⏭️ Alarm zamanı geçmiş, atlanıyor');
          }
        }
      }

      // Erken hatırlatma alarmlarını da zamanla (EarlyReminderService üzerinden)
      final erkenAlarmCount =
          await EarlyReminderService.scheduleAllEarlyReminders();
      alarmCount += erkenAlarmCount;

      debugPrint(
        '🔔 $zamanlamaSuresi gunluk zamanlama tamamlandi: $alarmCount alarm (erken: $erkenAlarmCount)',
      );

      // Son zamanlama tarihini kaydet
      await prefs.setString('last_schedule_date', now.toIso8601String());
      await prefs.setInt('scheduled_days', zamanlamaSuresi);
    } catch (e, stackTrace) {
      debugPrint('❌ Bildirim zamanlama hatası: $e');
      debugPrint('📋 Stack trace: $stackTrace');
    }
  }

  /// Tum namaz vakti alarmlarini iptal et
  /// NOT: Gunluk icerik ve ozel gun alarmlarini iptal etmez
  static Future<void> cancelAllNotifications() async {
    await _cancelPrayerAlarms();
    debugPrint('🗑️ Namaz vakti alarmlari iptal edildi');
  }

  /// Namaz vakti alarmlarını iptal et (sadece tam vakit alarmları)
  /// NOT: Erken hatırlatma alarmları EarlyReminderService tarafından iptal edilir
  static Future<void> _cancelPrayerAlarms() async {
    final now = DateTime.now();
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = now.add(Duration(days: gun));
      for (final vakitKey in _vakitler) {
        final vakitKeyLower = vakitKey.toLowerCase();
        final alarmId = AlarmService.generateAlarmId(vakitKeyLower, hedefTarih);
        await AlarmService.cancelAlarm(alarmId);
      }
    }
    // Erken hatırlatma alarmlarını da iptal et
    await EarlyReminderService.cancelAllEarlyReminders();
  }

  /// Yarının alarmlarını zamanla (gece yarısında çağrılacak)
  static Future<void> scheduleNextDayNotifications() async {
    await scheduleAllPrayerNotifications();
  }
}
