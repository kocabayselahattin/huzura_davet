import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'konum_service.dart';
import 'diyanet_api_service.dart';
import 'alarm_service.dart';

/// Zamanlanmış bildirim servisi - Uygulama kapalıyken bile vakit bildirimlerini gönderir
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

    // Timezone verilerini yükle
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Bildirime tıklandı: ${response.payload}');
      },
    );

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

  /// Günlük bildirimleri kontrol eden timer başlat
  /// 7 günlük zamanlama olduğu için her gün yeniden zamanlamaya gerek yok
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

  /// Tüm vakit bildirimlerini zamanla (7 günlük - 1 hafta)
  /// Bu sayede uygulama birkaç gün açılmasa bile bildirimler gelir
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
      int scheduledCount = 0;
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

          // Vaktinde alarm ses dosyası
          final sesDosyasiRaw =
              prefs.getString('bildirim_sesi_$vakitKeyLower') ?? 'best.mp3';
          final sesDosyasi = _getSoundResourceName(sesDosyasiRaw);

          // Erken bildirim ses dosyası
          // Kullanıcı ayrı bir erken ses seçmediyse, vaktindeki sesi kullan
          final erkenSesKey = 'erken_bildirim_sesi_$vakitKeyLower';
          final hasErkenSes = prefs.containsKey(erkenSesKey);
          final erkenSesDosyasiRaw = hasErkenSes
              ? (prefs.getString(erkenSesKey) ?? '')
              : sesDosyasiRaw;
          final erkenSesDosyasi = _getSoundResourceName(
            erkenSesDosyasiRaw.isEmpty ? sesDosyasiRaw : erkenSesDosyasiRaw,
          );

          // Vakit saatini parse et
          final parts = vakitSaati.split(':');
          if (parts.length != 2) continue;

          final saat = int.tryParse(parts[0]);
          final dakika = int.tryParse(parts[1]);
          if (saat == null || dakika == null) continue;

          // Tam vakit zamanı
          final tamVakitZamani = DateTime(
            hedefTarih.year,
            hedefTarih.month,
            hedefTarih.day,
            saat,
            dakika,
          );

          // 🔔 ÖNEMLİ: Vakit saatini SharedPreferences'a kaydet (BootReceiver için)
          // BootReceiver bu bilgiyi kullanarak telefon yeniden başlatıldığında alarmları yeniden zamanlar
          final dateKey =
              '${hedefTarih.year}-${hedefTarih.month.toString().padLeft(2, '0')}-${hedefTarih.day.toString().padLeft(2, '0')}';
          await prefs.setString('vakit_${vakitKeyLower}_$dateKey', vakitSaati);

          debugPrint(
            '📌 $vakitKey: Vakit saati $saat:$dakika, Erken dakika: $erkenDakika, Bildirim açık: $bildirimAcik, Vaktinde: $vaktindeBildirim',
          );

          // Benzersiz ID: gun * 100 + vakit index
          final bildirimId = gun * 100 + i + 1;

          // Ana bildirim switch'i kapalıysa hiçbir bildirim gönderme
          if (!bildirimAcik) {
            debugPrint('   ⏭️ Bildirim kapalı, atlanıyor');
            continue;
          }

          // 1. ERKEN BİLDİRİM: Erken dakika > 0 ise erken hatırlatma gönder
          if (erkenDakika > 0) {
            final erkenBildirimZamani = tamVakitZamani.subtract(
              Duration(minutes: erkenDakika),
            );

            if (erkenBildirimZamani.isAfter(now)) {
              await _scheduleNotification(
                id: bildirimId,
                title: '${_vakitTurkce[vakitKey]} Vakti Yaklaşıyor',
                body:
                    '${_vakitTurkce[vakitKey]} vaktine $erkenDakika dakika kaldı',
                scheduledTime: erkenBildirimZamani,
                soundAsset: erkenSesDosyasi, // Erken bildirim sesi kullan
              );
              scheduledCount++;
              debugPrint(
                '   ✅ Erken bildirim zamanlandı: $erkenBildirimZamani (ses: $erkenSesDosyasi)',
              );
            } else {
              debugPrint(
                '   ⏭️ Erken bildirim zamanı geçmiş: $erkenBildirimZamani',
              );
            }
          }

          // 2. VAKTİNDE BİLDİRİM: vaktindeBildirim açıksa tam vakitte bildirim gönder
          if (vaktindeBildirim && tamVakitZamani.isAfter(now)) {
            await _scheduleNotification(
              id: bildirimId + 50,
              title: '${_vakitTurkce[vakitKey]} Vakti Girdi',
              body: '${_vakitTurkce[vakitKey]} vakti girdi. Hayırlı ibadetler!',
              scheduledTime: tamVakitZamani,
              soundAsset: sesDosyasi, // Vaktinde bildirim sesi kullan
            );
            scheduledCount++;
            debugPrint('   ✅ Vaktinde bildirim zamanlandı: $tamVakitZamani');
          } else if (!vaktindeBildirim) {
            debugPrint('   ⏭️ Vaktinde bildirim kapalı');
          } else {
            debugPrint('   ⏭️ Tam vakit zamanı geçmiş: $tamVakitZamani');
          }

          // 🔔 ALARM: Alarm ayarları
          // ÖNEMLİ: Ana bildirim switch'i kapalıysa alarmları da atla!
          // Bu sayede kullanıcı bildirimi kapattığında alarm çalmaz
          // Varsayılan: güneş hariç hepsi için true (imsak OFF ama alarm olabilir)
          // Güneş için de varsayılan açık - erken uyarı için gerekli
          final varsayilanAlarm =
              (vakitKeyLower == 'gunes' ||
              vakitKeyLower == 'ogle' ||
              vakitKeyLower == 'ikindi' ||
              vakitKeyLower == 'aksam' ||
              vakitKeyLower == 'yatsi');
          final alarmAcik =
              prefs.getBool('alarm_$vakitKeyLower') ?? varsayilanAlarm;
          debugPrint(
            '🔔 [$vakitKey] SharedPreferences: alarm_$vakitKeyLower=$alarmAcik, bildirimAcik=$bildirimAcik, vaktindeBildirim=$vaktindeBildirim',
          );

          // ÖNEMLİ: Hem alarm açık olmalı HEM DE ana bildirim switch'i açık olmalı!
          if (alarmAcik && bildirimAcik) {
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

              debugPrint('   Alarm ID: $alarmId, Ses: $sesDosyasi');

              final success = await AlarmService.scheduleAlarm(
                prayerName: _vakitTurkce[vakitKey] ?? vakitKey,
                triggerAtMillis: alarmZamani.millisecondsSinceEpoch,
                soundPath: sesDosyasi,
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
                  soundPath: erkenSesDosyasi, // Erken alarm sesi kullan
                  useVibration: true,
                  alarmId: erkenAlarmId,
                  isEarly: true,
                  earlyMinutes: erkenDakika,
                );

                if (erkenSuccess) {
                  alarmCount++;
                  debugPrint(
                    '   ✅ Erken alarm zamanlandı (ses: $erkenSesDosyasi)',
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
          } else if (!bildirimAcik) {
            debugPrint('   ⏭️ Ana bildirim kapalı, tüm alarmlar atlanıyor');
          } else {
            debugPrint('   ⏭️ Alarm switch kapalı');
          }
        }
      }

      debugPrint(
        '🔔 $zamanlamaSuresi günlük zamanlama tamamlandı: $scheduledCount bildirim, $alarmCount alarm',
      );

      // Son zamanlama tarihini kaydet
      await prefs.setString('last_schedule_date', now.toIso8601String());
      await prefs.setInt('scheduled_days', zamanlamaSuresi);
    } catch (e, stackTrace) {
      debugPrint('❌ Bildirim zamanlama hatası: $e');
      debugPrint('📋 Stack trace: $stackTrace');
    }
  }

  /// Tek bir bildirim zamanla
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? soundAsset,
  }) async {
    try {
      // Ses kaynağı adını al
      final soundResourceName = _getSoundResourceName(soundAsset);
      final channelId = 'vakit_notification_channel_$soundResourceName';

      // Android implementation'ı al ve channel oluştur
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // Ana bildirim kanalı oluştur - varsayılan sistem bildirim sesi
        final channel = AndroidNotificationChannel(
          channelId,
          'Namaz Vakti Bildirimleri',
          description: 'Namaz vakitleri için zamanlanmış bildirimler',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundResourceName),
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        await androidImplementation.createNotificationChannel(channel);
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'Namaz Vakti Bildirimleri',
        channelDescription: 'Namaz vakitleri için zamanlanmış bildirimler',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundResourceName),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        enableLights: true,
        showWhen: true,
        when: scheduledTime.millisecondsSinceEpoch,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        ongoing: true, // Kullanıcı silene kadar kalsın
        autoCancel: false, // Tıklayınca otomatik kapanmasın
        styleInformation: BigTextStyleInformation(body),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduledTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'vakit_$id',
      );

      debugPrint(
        '⏰ Bildirim zamanlandı: ID=$id, Zaman=${scheduledTime.day}/${scheduledTime.month} ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}, Ses=$soundResourceName',
      );
    } catch (e) {
      debugPrint('❌ Bildirim zamanlama hatası (ID=$id): $e');
    }
  }

  /// Tüm namaz vakti bildirimlerini ve alarmlarını iptal et
  /// NOT: Günlük içerik ve özel gün bildirimlerini iptal etmez
  static Future<void> cancelAllNotifications() async {
    await _cancelPrayerNotifications();
    await _cancelPrayerAlarms();
    debugPrint('🗑️ Namaz vakti bildirimleri ve alarmları iptal edildi');
  }

  /// Namaz vakti bildirimlerini iptal et (sadece bu servisin ID aralığı)
  static Future<void> _cancelPrayerNotifications() async {
    for (int gun = 0; gun < 7; gun++) {
      for (int i = 0; i < _vakitler.length; i++) {
        final bildirimId = gun * 100 + i + 1;
        await _notificationsPlugin.cancel(id: bildirimId); // Erken bildirim
        await _notificationsPlugin.cancel(id: bildirimId + 50); // Vaktinde
      }
    }
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

  /// Belirli bir vaktin bildirimini iptal et
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  /// Zamanlanmış bildirimlerin listesini al (debug için)
  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Hemen bir test bildirimi gönder
  static Future<void> sendTestNotification() async {
    try {
      final soundResourceName = _getSoundResourceName(null);
      final channelId = 'test_channel_$soundResourceName';

      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final channel = AndroidNotificationChannel(
          channelId,
          'Test Bildirimleri',
          description: 'Test amaçlı bildirimler',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundResourceName),
          enableVibration: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'Test Bildirimleri',
        channelDescription: 'Test amaçlı bildirimler',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundResourceName),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        autoCancel: false,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: 999,
        title: '🧪 Test Bildirimi',
        body:
            'Bildirim sistemi çalışıyor! ${DateTime.now().toString().substring(11, 19)}',
        notificationDetails: notificationDetails,
      );
      debugPrint('✅ Test bildirimi gönderildi');
    } catch (e) {
      debugPrint('❌ Test bildirimi gönderilemedi: $e');
    }
  }

  /// Kilit ekranı testi için 5 saniye sonra bildirim gönder
  /// Bu sayede kullanıcı telefonu kilitleyip bildirimin gelip gelmediğini test edebilir
  static Future<void> sendLockScreenTestNotification() async {
    try {
      final scheduledTime = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 5));

      final soundResourceName = _getSoundResourceName(null);
      final channelId = 'prayer_notifications_$soundResourceName';

      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final channel = AndroidNotificationChannel(
          channelId,
          'Vakit Bildirimleri',
          description: 'Namaz vakti bildirimleri',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundResourceName),
          enableVibration: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'Vakit Bildirimleri',
        channelDescription: 'Namaz vakti bildirimleri',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundResourceName),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility:
            NotificationVisibility.public, // Kilit ekranında tam görünür
        ticker: 'Kilit Ekranı Test Bildirimi',
        autoCancel: false,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id: 998,
        title: '🔒 Kilit Ekranı Testi',
        body:
            '5 saniye sonra zamanlandı - Kilit ekranında görüyorsan bildirimler çalışıyor!',
        scheduledDate: scheduledTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      debugPrint('✅ Kilit ekranı test bildirimi 5 saniye sonra zamanlandı');
    } catch (e) {
      debugPrint('❌ Kilit ekranı test bildirimi gönderilemedi: $e');
    }
  }

  /// Ses dosyası adını Android raw kaynağı adına dönüştür
  static String _getSoundResourceName(String? soundAsset) {
    if (soundAsset == null || soundAsset.isEmpty) return 'ding_dong';

    String name = soundAsset.toLowerCase();
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.endsWith('.mp3')) {
      name = name.substring(0, name.length - 4);
    }

    // Android resource adı için geçersiz karakterleri temizle
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    // Özel eşlemeler
    if (name == 'best_2015') name = 'best';

    return name;
  }

  /// Yarının bildirimlerini zamanla (gece yarısında çağrılacak)
  static Future<void> scheduleNextDayNotifications() async {
    // Yarın için bildirimleri zamanla
    await scheduleAllPrayerNotifications();
  }
}
