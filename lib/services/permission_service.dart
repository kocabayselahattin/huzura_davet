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
      await _notificationsPlugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('⚠️ Notification init error: $e');
    }
  }

  /// Check location permission.
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

  /// Request location permission.
  static Future<bool> requestLocationPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      // Check service status first
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
      debugPrint('⚠️ Location permission error: $e');
      return false;
    }
  }

  /// Check notification permission.
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

  /// Request notification permission.
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
      debugPrint('⚠️ Notification permission error: $e');
      return true;
    }
  }

  /// Request all permissions in sequence.
  static Future<void> requestAllPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      // Android 13+ notification permission with timeout
      final hasNotification = await requestNotificationPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      debugPrint(
        '📱 Notification permission: ${hasNotification ? "granted" : "requested/denied"}',
      );

      debugPrint('✅ Permissions checked');
    } catch (e) {
      debugPrint('⚠️ Permission check error: $e');
    }
  }

  /// Check overlay permission.
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Open overlay settings.
  static Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openOverlaySettings');
    } catch (e) {
      debugPrint('⚠️ Overlay settings open failed: $e');
    }
  }

  /// Check exact alarm permission (Android 12+).
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

  /// Request exact alarm permission.
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
      debugPrint('⚠️ Exact alarm permission error: $e');
      return true;
    }
  }

  /// Open exact alarm settings.
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } catch (e) {
      debugPrint('⚠️ Exact alarm settings open failed: $e');
    }
  }

  /// Check battery optimization exemption.
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

  /// Request battery optimization exemption.
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestBatteryOptimizationExemption');
    } catch (e) {
      debugPrint('⚠️ Battery optimization exemption request failed: $e');
    }
  }

  /// Open battery optimization settings.
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('⚠️ Battery settings could not be opened: $e');
    }
  }

  /// Check Do Not Disturb (DND) policy access
  static Future<bool> hasDndPolicyAccess() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasDndPolicyAccess');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ DND permission check error: $e');
      return false;
    }
  }

  /// Open Do Not Disturb (DND) policy settings
  static Future<void> openDndPolicySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openDndPolicySettings');
    } catch (e) {
      debugPrint('⚠️ DND settings could not be opened: $e');
    }
  }
}
