import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PermissionService {
  static const MethodChannel _channel = MethodChannel(
    'huzur_vakti/permissions',
  );
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  static Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    try {
      await _notificationsPlugin.initialize();
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('⚠️ Bildirim init hatası: $e');
    }
  }

  /// Konum izni kontrolü
  static Future<bool> checkLocationPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// Konum izni iste
  static Future<bool> requestLocationPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      // Önce servis durumunu kontrol et
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('⚠️ Konum izni hatası: $e');
      return false;
    }
  }

  /// Bildirim izni kontrolü
  static Future<bool> checkNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      await _ensureNotificationsInitialized();
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled();
        return enabled ?? true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Bildirim izni iste
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      await _ensureNotificationsInitialized();
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        final result = await androidImpl.requestNotificationsPermission();
        if (result != null) return result;
        final enabled = await androidImpl.areNotificationsEnabled();
        return enabled ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Bildirim izni hatası: $e');
      return true;
    }
  }

  /// Tüm gerekli izinleri iste (sıralı olarak, çakışma önlemek için)
  static Future<void> requestAllPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      // Android 13+ için bildirim izni - timeout ile
      final hasNotification = await requestNotificationPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      debugPrint(
        '📱 Bildirim izni: ${hasNotification ? "verildi" : "istendi/reddedildi"}',
      );

      debugPrint('✅ İzinler kontrol edildi');
    } catch (e) {
      debugPrint('⚠️ İzin kontrolü hatası: $e');
    }
  }

  /// Overlay (diğer uygulamaların üstünde) izni kontrolü
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Overlay izin ayarlarını aç
  static Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openOverlaySettings');
    } catch (e) {
      debugPrint('⚠️ Overlay ayarları açılamadı: $e');
    }
  }

  /// Exact alarm izni kontrolü (Android 12+)
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        return await androidImpl.canScheduleExactNotifications() ?? true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Exact alarm izni iste
  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        await androidImpl.requestExactAlarmsPermission();
        return await androidImpl.canScheduleExactNotifications() ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Exact alarm izni hatası: $e');
      return true;
    }
  }

  /// Exact alarm ayarlarını aç
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } catch (e) {
      debugPrint('⚠️ Alarm ayarları açılamadı: $e');
    }
  }

  /// Pil optimizasyonu devre dışı bırakma kontrolü
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>(
        'isBatteryOptimizationDisabled',
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Pil optimizasyonu muafiyeti iste
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestBatteryOptimizationExemption');
    } catch (e) {
      debugPrint('⚠️ Pil optimizasyonu muafiyeti istenemedi: $e');
    }
  }

  /// Pil optimizasyonu ayarlarını aç
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('⚠️ Pil ayarları açılamadı: $e');
    }
  }
}
