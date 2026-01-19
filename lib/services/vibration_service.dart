import 'package:flutter/services.dart';
import 'dart:io';

/// Titreşim servisini yöneten sınıf
class VibrationService {
  static const MethodChannel _channel = MethodChannel('huzur_vakti/vibration');

  /// Hafif titreşim (tık sesi gibi)
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('⚠️ Hafif titreşim hatası: $e');
    }
  }

  /// Orta şiddette titreşim (normal tıklama)
  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      print('⚠️ Orta titreşim hatası: $e');
      // Alternatif: native vibration
      try {
        await _vibrateNative(100);
      } catch (e2) {
        print('⚠️ Native titreşim de başarısız: $e2');
      }
    }
  }

  /// Güçlü titreşim (önemli eylemler)
  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('⚠️ Güçlü titreşim hatası: $e');
      // Alternatif: native vibration
      try {
        await _vibrateNative(200);
      } catch (e2) {
        print('⚠️ Native titreşim de başarısız: $e2');
      }
    }
  }

  /// Seçim değişikliği titreşimi
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      print('⚠️ Seçim titreşimi hatası: $e');
    }
  }

  /// Özel süreli titreşim (Android native)
  static Future<void> _vibrateNative(int durationMs) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('vibrate', {'duration': durationMs});
      } catch (e) {
        print('⚠️ Native titreşim hatası: $e');
      }
    }
  }

  /// Pattern titreşim (Android native)
  static Future<void> vibratePattern(List<int> pattern) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('vibratePattern', {'pattern': pattern});
      } catch (e) {
        print('⚠️ Pattern titreşim hatası: $e');
      }
    }
  }

  /// Başarı titreşimi (kısa-uzun-kısa)
  static Future<void> success() async {
    if (Platform.isAndroid) {
      await vibratePattern([0, 50, 100, 100, 100, 50]);
    } else {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    }
  }
}
