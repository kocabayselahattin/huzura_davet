import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'konum_service.dart';
import 'diyanet_api_service.dart';
import 'alarm_service.dart';

/// Zamanlanmış alarm servisi - Uygulama kapalıyken bile vakit alarmlarını kurar
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

  // Varsayılan erken bildirim süreleri (dakika)
  // bildirim_ayarlari_sayfa.dart ile tutarlı olmalı
  static const Map<String, int> _varsayilanErkenBildirim = {
    'imsak': 45,
    'gunes': 30,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
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

        // Her vakit için bildirim ve alarm zamanla
        for (int i = 0; i < _vakitler.length; i++) {
          final vakitKey = _vakitler[i];
          final vakitKeyLower = vakitKey.toLowerCase();

          // Ana bildirim switch'i - bu vakit için tüm bildirimler açık mı?
          final bildirimAcik = prefs.getBool('bildirim_$vakitKeyLower') ?? true;

          // Vaktinde bildirim - tam vakitte bildirim gönder
          // Varsayılan: öğle, ikindi, akşam, yatsı için true
          final varsayilanVaktinde =
              (vakitKeyLower == 'ogle' ||
              vakitKeyLower == 'ikindi' ||
              vakitKeyLower == 'aksam' ||
              vakitKeyLower == 'yatsi');
          final vaktindeBildirim =
              prefs.getBool('vaktinde_$vakitKeyLower') ?? varsayilanVaktinde;

          debugPrint(
            '🔍 [$vakitKey] SharedPreferences: bildirim_$vakitKeyLower=$bildirimAcik, vaktinde_$vakitKeyLower=$vaktindeBildirim',
          );

          final vakitSaati = gunVakitler[vakitKey]?.toString();
          if (vakitSaati == null || vakitSaati == '—:—' || vakitSaati.isEmpty) {
            continue;
          }

          // Erken bildirim süresi (dakika) - varsayılan değerler map'ten alınır
          final varsayilanErken = _varsayilanErkenBildirim[vakitKeyLower] ?? 15;
          final erkenDakika =
              prefs.getInt('erken_$vakitKeyLower') ?? varsayilanErken;

            // Vaktinde alarm ses dosyasi (raw)
            final sesDosyasiRaw =
              prefs.getString('bildirim_sesi_$vakitKeyLower') ?? 'best.mp3';

            // Erken alarm ses dosyasi (raw)
            // Kullanici ayrica erken ses secmediyse, vaktindeki sesi kullan
            final erkenSesKey = 'erken_bildirim_sesi_$vakitKeyLower';
            final erkenSesRaw = prefs.getString(erkenSesKey) ?? sesDosyasiRaw;

          // Vakit saatini parse et
          final parts = vakitSaati.split(':');
          if (parts.length != 2) continue;

          final saat = int.tryParse(parts[0]);
          final dakika = int.tryParse(parts[1]);
          if (saat == null || dakika == null) continue;

          // 🔔 ÖNEMLİ: Vakit saatini SharedPreferences'a kaydet (BootReceiver için)
          // BootReceiver bu bilgiyi kullanarak telefon yeniden başlatıldığında alarmları yeniden zamanlar
          final dateKey =
              '${hedefTarih.year}-${hedefTarih.month.toString().padLeft(2, '0')}-${hedefTarih.day.toString().padLeft(2, '0')}';
          await prefs.setString('vakit_${vakitKeyLower}_$dateKey', vakitSaati);

          debugPrint(
            '📌 $vakitKey: Vakit saati $saat:$dakika, Erken dakika: $erkenDakika, Bildirim açık: $bildirimAcik, Vaktinde: $vaktindeBildirim',
          );

          // Ana bildirim switch'i kapalıysa hiçbir bildirim gönderme
          if (!bildirimAcik) {
            debugPrint('   ⏭️ Bildirim kapalı, atlanıyor');
            continue;
          }

          // ERKEN HATIRLATMA: Bildirim degil, alarm ile calar (asagida)

          // VAKTİNDE HATIRLATMA: Bildirim degil, alarm ile calar (asagida)

          // 🔔 ALARM: Ana bildirim switch'i aciksa alarmlari kur
          if (bildirimAcik) {
            // TAM VAKİT ALARMI - Sadece vaktinde bildirim açıksa çal!
            // Kullanıcı vaktinde bildirimi kapattıysa tam vakit alarmı da kapanmalı
            var alarmZamani = DateTime(
              hedefTarih.year,
              hedefTarih.month,
              hedefTarih.day,
              saat,
              dakika,
            );

            debugPrint('   Tam vakit alarm zamanı: $alarmZamani, Şu an: $now');

            // ÖNEMLİ: vaktindeBildirim de açık olmalı!
            if (vaktindeBildirim && alarmZamani.isAfter(now)) {
              // TAM VAKİT ALARMI için ID (son 2 hane: vakit indexi)
              final alarmId = AlarmService.generateAlarmId(
                vakitKeyLower, // Örn: "ogle"
                alarmZamani,
              );

              debugPrint('   Alarm ID: $alarmId, Ses: $sesDosyasiRaw');

              final success = await AlarmService.scheduleAlarm(
                prayerName: _vakitTurkce[vakitKey] ?? vakitKey,
                triggerAtMillis: alarmZamani.millisecondsSinceEpoch,
                soundPath: sesDosyasiRaw,
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
                '   ⏭️ Vaktinde bildirim kapalı, tam vakit alarmı atlanıyor',
              );
            } else {
              debugPrint('   ⏭️ Tam vakit alarm zamanı geçmiş, atlanıyor');
            }

            // ERKEN ALARM (Vaktinden önce) - Sadece erkenDakika > 0 ise çal
            // erkenDakika = 0 ise kullanıcı erken bildirimi kapatmış demektir
            if (erkenDakika > 0) {
              var erkenAlarmZamani = alarmZamani.subtract(
                Duration(minutes: erkenDakika),
              );

              debugPrint(
                '   Erken alarm zamanı: $erkenAlarmZamani ($erkenDakika dk önce)',
              );

              if (erkenAlarmZamani.isAfter(now)) {
                final erkenAlarmId = AlarmService.generateAlarmId(
                  '${vakitKeyLower}_erken',
                  erkenAlarmZamani,
                );

                final erkenSuccess = await AlarmService.scheduleAlarm(
                  prayerName: '${_vakitTurkce[vakitKey]} ($erkenDakika dk)',
                  triggerAtMillis: erkenAlarmZamani.millisecondsSinceEpoch,
                  soundPath: erkenSesRaw, // Erken alarm sesi kullan
                  useVibration: true,
                  alarmId: erkenAlarmId,
                  isEarly: true,
                  earlyMinutes: erkenDakika,
                );

                if (erkenSuccess) {
                  alarmCount++;
                  debugPrint(
                    '   ✅ Erken alarm zamanlandı (ses: $erkenSesRaw)',
                  );
                } else {
                  debugPrint('   ❌ Erken alarm zamanlanamadı');
                }
              } else {
                debugPrint('   ⏭️ Erken alarm zamanı geçmiş, atlanıyor');
              }
            } else {
              debugPrint(
                '   ⏭️ Erken bildirim kapalı (0 dk), erken alarm atlanıyor',
              );
            }
          } else {
            debugPrint('   ⏭️ Ana bildirim kapalı, tüm alarmlar atlanıyor');
          }
        }
      }

      debugPrint(
        '🔔 $zamanlamaSuresi gunluk zamanlama tamamlandi: $alarmCount alarm',
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

  /// Namaz vakti alarmlarını iptal et (sadece bu servisin ürettiği ID'ler)
  static Future<void> _cancelPrayerAlarms() async {
    final now = DateTime.now();
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = now.add(Duration(days: gun));
      for (final vakitKey in _vakitler) {
        final vakitKeyLower = vakitKey.toLowerCase();
        final alarmId = AlarmService.generateAlarmId(vakitKeyLower, hedefTarih);
        await AlarmService.cancelAlarm(alarmId);

        final erkenAlarmId = AlarmService.generateAlarmId(
          '${vakitKeyLower}_erken',
          hedefTarih,
        );
        await AlarmService.cancelAlarm(erkenAlarmId);
      }
    }
  }

  /// Yarının alarmlarını zamanla (gece yarısında çağrılacak)
  static Future<void> scheduleNextDayNotifications() async {
    await scheduleAllPrayerNotifications();
  }
}
