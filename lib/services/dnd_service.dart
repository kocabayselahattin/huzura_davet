import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'diyanet_api_service.dart';
import 'konum_service.dart';

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

    // Önce izin var mı kontrol et
    final hasAccess = await hasPolicyAccess();
    if (!hasAccess) {
      print('⚠️ DND izni yok! Kullanıcı ayarlardan izin vermelidir.');
      return false;
    }

    final entries = await _buildEntries();
    if (entries.isEmpty) {
      print('⚠️ DND planlanacak vakit bulunamadı.');
      return false;
    }

    print('📵 ${entries.length} vakit için DND planlanıyor...');

    final payload = entries
        .map((entry) => {
              'startAt': entry.startAt.millisecondsSinceEpoch,
              'durationMinutes': entry.durationMinutes,
              'label': entry.label,
            })
        .toList();

    final result = await _channel.invokeMethod<bool>(
      'scheduleDnd',
      {'entries': payload},
    );
    
    print(result == true ? '✅ DND planlandı' : '❌ DND planlanamadı');
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

      final duration = day.weekday == DateTime.friday ? 60 : 30;
      final schedule = _buildDayEntries(entry, day, duration, now);
      entries.addAll(schedule);
    }

    return entries;
  }

  static List<_DndEntry> _buildDayEntries(
    Map<String, dynamic> entry,
    DateTime day,
    int duration,
    DateTime now,
  ) {
    final result = <_DndEntry>[];
    const vakitler = [
      {'key': 'Ogle', 'label': 'Öğle'},
      {'key': 'Ikindi', 'label': 'İkindi'},
      {'key': 'Aksam', 'label': 'Akşam'},
      {'key': 'Yatsi', 'label': 'Yatsı'},
    ];

    for (final vakit in vakitler) {
      final saat = entry[vakit['key']]?.toString() ?? '';
      final startAt = _parseDateTime(day, saat);
      if (startAt == null) continue;
      if (startAt.isBefore(now)) {
        continue;
      }
      result.add(
        _DndEntry(
          startAt: startAt,
          durationMinutes: duration,
          label: vakit['label']!,
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
