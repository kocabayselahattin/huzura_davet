import 'dart:io';
import 'package:flutter/services.dart';

class PermissionService {
  static const MethodChannel _channel = MethodChannel('huzur_vakti/permissions');

  /// Tüm gerekli izinleri iste (sıralı olarak, çakışma önlemek için)
  static Future<void> requestAllPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      // Android 13+ için bildirim izni - timeout ile
      final hasNotification = await _requestNotificationPermission()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      print('📱 Bildirim izni: ${hasNotification ? "verildi" : "istendi/reddedildi"}');
      
      print('✅ İzinler kontrol edildi');
    } catch (e) {
      print('⚠️ İzin kontrolü hatası: $e');
    }
  }

  /// Bildirim izni iste (Android 13+)
  static Future<bool> _requestNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return result ?? false;
    } catch (e) {
      print('⚠️ Bildirim izni hatası: $e');
      return false;
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
      print('⚠️ Overlay ayarları açılamadı: $e');
    }
  }

  /// Exact alarm izni kontrolü (Android 12+)
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('hasExactAlarmPermission');
      return result ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Exact alarm ayarlarını aç
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } catch (e) {
      print('⚠️ Alarm ayarları açılamadı: $e');
    }
  }

  /// Pil optimizasyonu devre dışı bırakma kontrolü
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Pil optimizasyonu ayarlarını aç
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (e) {
      print('⚠️ Pil ayarları açılamadı: $e');
    }
  }
}
