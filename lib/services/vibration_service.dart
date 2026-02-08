import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Service that manages vibration
class VibrationService {
  static const MethodChannel _channel = MethodChannel('huzur_vakti/vibration');

  /// Light vibration (on each tap)
  static Future<void> light() async {
    if (Platform.isAndroid) {
      // Use native vibration on Android (more reliable)
      try {
        await _channel.invokeMethod('vibrate', {'duration': 25});
        return;
      } catch (e) {
        debugPrint('⚠️ Native light vibration error: $e');
      }
    }
    // Fallback to HapticFeedback on iOS or errors
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('⚠️ HapticFeedback error: $e');
    }
  }

  /// Medium vibration (normal tap)
  static Future<void> medium() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('vibrate', {'duration': 50});
        return;
      } catch (e) {
        debugPrint('⚠️ Native medium vibration error: $e');
      }
    }
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('⚠️ HapticFeedback error: $e');
    }
  }

  /// Heavy vibration (lap complete, reset)
  static Future<void> heavy() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('vibrate', {'duration': 80});
        return;
      } catch (e) {
        debugPrint('⚠️ Native heavy vibration error: $e');
      }
    }
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('⚠️ HapticFeedback error: $e');
    }
  }

  /// Selection change vibration
  static Future<void> selection() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('vibrate', {'duration': 15});
        return;
      } catch (e) {
        debugPrint('⚠️ Native selection vibration error: $e');
      }
    }
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('⚠️ Selection vibration error: $e');
    }
  }

  /// Custom duration vibration (Android native)
  static Future<void> vibrate(int durationMs) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('vibrate', {'duration': durationMs});
      } catch (e) {
        debugPrint('⚠️ Native vibration error: $e');
        await HapticFeedback.selectionClick();
      }
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Pattern vibration (Android native)
  static Future<void> vibratePattern(List<int> pattern) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('vibratePattern', {'pattern': pattern});
      } catch (e) {
        debugPrint('⚠️ Pattern vibration error: $e');
      }
    }
  }

  /// Success vibration (two short pulses)
  static Future<void> success() async {
    if (Platform.isAndroid) {
      // Two short pulses: wait-vibrate-wait-vibrate
      await vibratePattern([0, 80, 100, 80]);
    } else {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    }
  }
}
