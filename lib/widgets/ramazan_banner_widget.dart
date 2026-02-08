import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/language_service.dart';
import '../services/tema_service.dart';

class RamazanBannerWidget extends StatefulWidget {
  const RamazanBannerWidget({super.key});

  @override
  State<RamazanBannerWidget> createState() => _RamazanBannerWidgetState();
}

class _RamazanBannerWidgetState extends State<RamazanBannerWidget> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  Timer? _timer;
  Duration _remaining = Duration.zero;
  String _labelKey = 'iftar_remaining';
  bool _loading = true;

  DateTime? _imsakTime;
  DateTime? _iftarTime;
  DateTime? _tomorrowImsakTime;

  bool get _isRamadan => HijriCalendar.now().hMonth == 9;

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onChanged);
    _languageService.addListener(_onChanged);
    _loadTimes();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemaining();
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _temaService.removeListener(_onChanged);
    _languageService.removeListener(_onChanged);
    super.dispose();
  }

  Future<String?> _getImsakForDate(String ilceId, DateTime date) async {
    final vakitler = await DiyanetApiService.getAylikVakitler(
      ilceId,
      date.year,
      date.month,
    );

    final tarihStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    for (final v in vakitler) {
      if (v['MiladiTarihKisa']?.toString() == tarihStr) {
        return v['Imsak']?.toString();
      }
    }

    return null;
  }

  DateTime _timeToDateTime(DateTime base, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  Future<void> _loadTimes() async {
    if (!_isRamadan) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    final ilceId = await KonumService.getIlceId();
    if (ilceId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
    if (vakitler == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    final now = DateTime.now();
    final imsakStr = vakitler['Imsak'];
    final aksamStr = vakitler['Aksam'];

    if (imsakStr == null || aksamStr == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowImsakStr =
        await _getImsakForDate(ilceId, tomorrow) ??
        (await _getImsakForDate(
          ilceId,
          DateTime(tomorrow.year, tomorrow.month + 1, 1),
        ));

    setState(() {
      _imsakTime = _timeToDateTime(now, imsakStr);
      _iftarTime = _timeToDateTime(now, aksamStr);
      _tomorrowImsakTime = tomorrowImsakStr == null
          ? _timeToDateTime(now, imsakStr).add(const Duration(days: 1))
          : _timeToDateTime(tomorrow, tomorrowImsakStr);
      _loading = false;
    });

    _updateRemaining();
  }

  void _updateRemaining() {
    if (!_isRamadan || _loading) return;
    if (_imsakTime == null || _iftarTime == null) return;

    final now = DateTime.now();

    DateTime target;
    if (now.isBefore(_imsakTime!)) {
      _labelKey = 'imsak_remaining';
      target = _imsakTime!;
    } else if (now.isBefore(_iftarTime!)) {
      _labelKey = 'iftar_remaining';
      target = _iftarTime!;
    } else {
      _labelKey = 'imsak_remaining';
      target = _tomorrowImsakTime ?? _imsakTime!.add(const Duration(days: 1));
    }

    final remaining = target.difference(now);
    if (mounted) {
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRamadan || _loading || _imsakTime == null || _iftarTime == null) {
      return const SizedBox.shrink();
    }

    final renkler = _temaService.renkler;
    final label = _languageService[_labelKey];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            renkler.vurgu.withValues(alpha: 0.9),
            renkler.vurguSecondary.withValues(alpha: 0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: renkler.vurgu.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.nights_stay, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${_formatDuration(_remaining)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
