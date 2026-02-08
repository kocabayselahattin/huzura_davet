import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'diyanet_api_service.dart';
import 'konum_service.dart';
import 'language_service.dart';

class DndService {
  static const MethodChannel _channel = MethodChannel('huzur_vakti/dnd');

  static Future<bool> hasPolicyAccess() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('hasPolicyAccess');
    return result ?? false;
  }

  static Future<void> openPolicySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openPolicySettings');
  }

  static Future<bool> schedulePrayerDnd() async {
    if (!Platform.isAndroid) return false;

    // Check permission
    final hasAccess = await hasPolicyAccess();
    if (!hasAccess) {
      debugPrint('⚠️ DND permission missing. User must grant it in settings.');
      return false;
    }

    final entries = await _buildEntries();
    if (entries.isEmpty) {
      debugPrint('⚠️ No DND entries to schedule.');
      return false;
    }

    debugPrint('📵 Scheduling DND for ${entries.length} entries...');

    final payload = entries
        .map(
          (entry) => {
            'startAt': entry.startAt.millisecondsSinceEpoch,
            'durationMinutes': entry.durationMinutes,
            'label': entry.label,
          },
        )
        .toList();

    final result = await _channel.invokeMethod<bool>('scheduleDnd', {
      'entries': payload,
    });

    debugPrint(result == true ? '✅ DND scheduled' : '❌ DND scheduling failed');
    return result ?? false;
  }

  static Future<void> cancelPrayerDnd() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('cancelDnd');
  }

  static Future<List<_DndEntry>> _buildEntries() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId == null) return [];

    final data = await DiyanetApiService.getVakitler(ilceId);
    if (data == null || data['vakitler'] == null) return [];

    final vakitler = List<Map<String, dynamic>>.from(data['vakitler'] as List);

    final now = DateTime.now();
    final days = [now, now.add(const Duration(days: 1))];
    final entries = <_DndEntry>[];

    for (final day in days) {
      final entry = _findVakitEntryForDate(vakitler, day);
      if (entry == null) continue;

      final schedule = _buildDayEntries(entry, day, 30, now);
      entries.addAll(schedule);
    }

    return entries;
  }

  static List<_DndEntry> _buildDayEntries(
    Map<String, dynamic> entry,
    DateTime day,
    int defaultDuration,
    DateTime now,
  ) {
    final result = <_DndEntry>[];
    final isFriday = day.weekday == DateTime.friday;

    final languageService = LanguageService();
    final fridayLabel = languageService['friday'] ?? 'Friday';
    final vakitler = [
      {'key': 'Ogle', 'label': languageService['ogle'] ?? 'Dhuhr', 'isCumaVakti': true},
      {'key': 'Ikindi', 'label': languageService['ikindi'] ?? 'Asr', 'isCumaVakti': false},
      {'key': 'Aksam', 'label': languageService['aksam'] ?? 'Maghrib', 'isCumaVakti': false},
      {'key': 'Yatsi', 'label': languageService['yatsi'] ?? 'Isha', 'isCumaVakti': false},
    ];

    for (final vakit in vakitler) {
      final saat = entry[vakit['key']]?.toString() ?? '';
      final startAt = _parseDateTime(day, saat);
      if (startAt == null) continue;
      if (startAt.isBefore(now)) {
        continue;
      }

      // Friday Dhuhr is 60 minutes, others 30.
      final isCumaVakti = isFriday && (vakit['isCumaVakti'] as bool);
      final duration = isCumaVakti ? 60 : 30;

      result.add(
        _DndEntry(
          startAt: startAt,
          durationMinutes: duration,
          label: isCumaVakti ? fridayLabel : vakit['label'] as String,
        ),
      );
    }

    return result;
  }

  static Map<String, dynamic>? _findVakitEntryForDate(
    List<Map<String, dynamic>> entries,
    DateTime date,
  ) {
    final target = DateFormat('dd.MM.yyyy').format(date);
    for (final entry in entries) {
      final tarih = entry['MiladiTarihKisa']?.toString() ?? '';
      if (tarih == target) {
        return entry;
      }
    }
    return null;
  }

  static DateTime? _parseDateTime(DateTime date, String saat) {
    final parts = saat.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

class _DndEntry {
  final DateTime startAt;
  final int durationMinutes;
  final String label;

  const _DndEntry({
    required this.startAt,
    required this.durationMinutes,
    required this.label,
  });
}
