import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Android alarm sistemi için Flutter servis sınıfı
/// Bildirim ayarları ile senkronize çalışır
class AlarmService {
  static const _channel = MethodChannel('huzur_vakti/alarms');

  /// Belirli bir vakit için alarm kurar
  /// [prayerName] - Vakit adı (Örn: "Sabah", "Öğle")
  /// [triggerAtMillis] - Alarmın tetikleneceği zaman (Unix timestamp ms)
  /// [soundPath] - Ses dosyası yolu (null ise varsayılan ses kullanılır)
  /// [useVibration] - Titreşim kullanılsın mı
  /// [alarmId] - Benzersiz alarm ID'si (varsayılan: prayerName.hashCode)
  static Future<bool> scheduleAlarm({
    required String prayerName,
    required int triggerAtMillis,
    String? soundPath,
    bool useVibration = true,
    int? alarmId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final triggerTime = DateTime.fromMillisecondsSinceEpoch(triggerAtMillis);

      debugPrint(
        '🔔 [ALARM SCHEDULE] prayerName=$prayerName, triggerTime=$triggerTime, soundPath=$soundPath, alarmId=${alarmId ?? prayerName.hashCode}',
      );

      if (triggerAtMillis <= now) {
        debugPrint('⚠️ Alarm zamanı geçmiş, atlanıyor');
        return false;
      }

      final result = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'prayerName': prayerName,
        'triggerAtMillis': triggerAtMillis,
        'soundPath': soundPath,
        'useVibration': useVibration,
        'alarmId': alarmId ?? prayerName.hashCode,
      });
      debugPrint(
        '✅ [ALARM SCHEDULE RESULT] prayerName=$prayerName, result=$result',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Alarm kurma hatası: $e');
      return false;
    }
  }

  /// Belirli bir alarmı iptal eder
  static Future<bool> cancelAlarm(int alarmId) async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelAlarm', {
        'alarmId': alarmId,
      });
      return result ?? false;
    } catch (e) {
      print('Alarm iptal hatası: $e');
      return false;
    }
  }

  /// Tüm alarmları iptal eder
  static Future<bool> cancelAllAlarms() async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelAllAlarms');
      return result ?? false;
    } catch (e) {
      print('Tüm alarmları iptal hatası: $e');
      return false;
    }
  }

  /// Alarm çalıyor mu kontrol eder
  static Future<bool> isAlarmPlaying() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAlarmPlaying');
      return result ?? false;
    } catch (e) {
      print('Alarm kontrol hatası: $e');
      return false;
    }
  }

  /// Çalan alarmı durdurur
  static Future<bool> stopAlarm() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopAlarm');
      return result ?? false;
    } catch (e) {
      print('Alarm durdurma hatası: $e');
      return false;
    }
  }

  /// Vakit ID'sinden benzersiz alarm ID'si oluşturur
  /// Aynı günde farklı vakitler için farklı ID'ler üretir
  static int generateAlarmId(String prayerKey, DateTime date) {
    // prayerKey: "imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"
    // Tarih ve vakit bazında benzersiz ID
    final dateStr = '${date.year}${date.month}${date.day}';
    return '${dateStr}_$prayerKey'.hashCode.abs();
  }

  /// TEST: 5 saniye sonra çalacak test alarmı
  /// Bu fonksiyon alarm sisteminin çalışıp çalışmadığını test etmek için
  static Future<bool> testAlarm() async {
    try {
      final testTime = DateTime.now().add(const Duration(seconds: 5));
      debugPrint('🧪 TEST ALARM: 5 saniye sonra çalacak - $testTime');

      final result = await scheduleAlarm(
        prayerName: 'Test Alarmı',
        triggerAtMillis: testTime.millisecondsSinceEpoch,
        soundPath: 'ding_dong.mp3',
        useVibration: true,
        alarmId: 99999, // Test için sabit ID
      );

      debugPrint('🧪 TEST ALARM sonucu: $result');
      return result;
    } catch (e) {
      debugPrint('❌ TEST ALARM hatası: $e');
      return false;
    }
  }
}
