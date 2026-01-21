import 'package:flutter/services.dart';

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
      final result = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'prayerName': prayerName,
        'triggerAtMillis': triggerAtMillis,
        'soundPath': soundPath,
        'useVibration': useVibration,
        'alarmId': alarmId ?? prayerName.hashCode,
      });
      return result ?? false;
    } catch (e) {
      print('Alarm kurma hatası: $e');
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
}
