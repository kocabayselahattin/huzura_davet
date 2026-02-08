import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../services/dnd_service.dart';
import '../services/scheduled_notification_service.dart';
import '../services/daily_content_notification_service.dart';
import '../services/early_reminder_service.dart';
import '../services/language_service.dart';
import '../services/tema_service.dart';

class BildirimAyarlariSayfa extends StatefulWidget {
  const BildirimAyarlariSayfa({super.key});

  @override
  State<BildirimAyarlariSayfa> createState() => _BildirimAyarlariSayfaState();
}

class _BildirimAyarlariSayfaState extends State<BildirimAyarlariSayfa> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final LanguageService _languageService = LanguageService();
  final TemaService _temaService = TemaService();

  // Notification on/off states
  // Defaults should match main.dart
  final Map<String, bool> _bildirimAcik = {
    'imsak': true,
    'gunes': true,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // On-time notification (show at exact time)
  // Default: enabled for Dhuhr, Asr, Maghrib, Isha
  final Map<String, bool> _vaktindeBildirim = {
    'imsak': false,
    'gunes': false,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Alarm on/off states (alarm plays on lock screen)
  // Default: enabled for Dhuhr, Asr, Maghrib, Isha
  final Map<String, bool> _alarmAcik = {
    'imsak': false,
    'gunes': false,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Mute during prayer times
  bool _sessizeAl = false;

  // Lock screen notification
  bool _kilitEkraniBildirimi = false;

  // Daily content notifications
  bool _gunlukIcerikBildirimleri = true;

  // Daily content alarm settings
  TimeOfDay _gunlukAyetSaati = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _gunlukHadisSaati = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _gunlukDuaSaati = const TimeOfDay(hour: 20, minute: 0);
  String _gunlukIcerikSesi = 'ding_dong'; // Ses ID'si

  // Sound playback state (play/pause toggle)
  String? _sesCalanKey; // Which prayer is playing

  // MethodChannel for lock screen service
  static const _lockScreenChannel = MethodChannel('huzur_vakti/lockscreen');

  // Change tracking
  bool _degisiklikYapildi = false;

  // Early reminder durations (minutes)
  // Default: 15 minutes before (sunrise 45 minutes)
  final Map<String, int> _erkenBildirim = {
    'imsak': 15,
    'gunes': 45,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
  };

  // On-time sound selection (per prayer) - default: best (ID)
  final Map<String, String> _bildirimSesi = {
    'imsak': 'best',
    'gunes': 'best',
    'ogle': 'best',
    'ikindi': 'best',
    'aksam': 'best',
    'yatsi': 'best',
  };

  // Early reminder sound selection (per prayer) - default: best (ID)
  final Map<String, String> _erkenBildirimSesi = {
    'imsak': 'best',
    'gunes': 'best',
    'ogle': 'best',
    'ikindi': 'best',
    'aksam': 'best',
    'yatsi': 'best',
  };

  final List<int> _erkenSureler = [0, 5, 10, 15, 20, 30, 45, 60];

  // Sound options - getter because it needs languageService
  // Each sound has a lowercase unique ID (Android raw resource name)
  List<Map<String, String>> get _sesSecenekleri => [
    {
      'id': 'aksam_ezani',
      'ad': _languageService['sound_aksam_ezani'] ?? '',
      'dosya': 'aksam_ezani.mp3',
    },
    {
      'id': 'ayasofya_ezan_sesi',
      'ad': _languageService['sound_ayasofya_ezan'] ?? '',
      'dosya': 'ayasofya_ezan_sesi.mp3',
    },
    {
      'id': 'best',
      'ad': _languageService['sound_best'] ?? '',
      'dosya': 'best.mp3',
    },
    {
      'id': 'corner',
      'ad': _languageService['sound_corner'] ?? '',
      'dosya': 'Corner.mp3',
    },
    {
      'id': 'ding_dong',
      'ad': _languageService['sound_ding_dong'] ?? '',
      'dosya': 'Ding_Dong.mp3',
    },
    {
      'id': 'esselatu_hayrun_minen_nevm1',
      'ad':
          _languageService['sound_esselatu_1'] ??
          '',
      'dosya': 'esselatu_hayrun_minen_nevm1.mp3',
    },
    {
      'id': 'esselatu_hayrun_minen_nevm2',
      'ad':
          _languageService['sound_esselatu_2'] ??
          '',
      'dosya': 'esselatu_hayrun_minen_nevm2.mp3',
    },
    {
      'id': 'melodi',
      'ad': _languageService['sound_melodi'] ?? '',
      'dosya': 'melodi.mp3',
    },
    {
      'id': 'mescid_i_nebi_sabah_ezani',
      'ad':
          _languageService['sound_mescid_nebi_sabah'] ??
          '',
      'dosya': 'mescid_i_nebi_sabah_ezani.mp3',
    },
    {
      'id': 'snaps',
      'ad': _languageService['sound_snaps'] ?? '',
      'dosya': 'snaps.mp3',
    },
    {
      'id': 'sweet_favour',
      'ad': _languageService['sound_sweet_favour'] ?? '',
      'dosya': 'Sweet_Favour.mp3',
    },
    {
      'id': 'violet',
      'ad': _languageService['sound_violet'] ?? '',
      'dosya': 'Violet.mp3',
    },
    {
      'id': 'sabah_ezani_saba',
      'ad': _languageService['sound_sabah_ezani_saba'] ?? '',
      'dosya': 'sabah_ezani_saba.mp3',
    },
    {
      'id': 'ogle_ezani_rast',
      'ad': _languageService['sound_ogle_ezani_rast'] ?? '',
      'dosya': 'ogle_ezani_rast.mp3',
    },
    {
      'id': 'ikindi_ezani_hicaz',
      'ad':
          _languageService['sound_ikindi_ezani_hicaz'] ??
          '',
      'dosya': 'ikindi_ezani_hicaz.mp3',
    },
    {
      'id': 'aksam_ezani_segah',
      'ad':
          _languageService['sound_aksam_ezani_segah'] ?? '',
      'dosya': 'aksam_ezani_segah.mp3',
    },
    {
      'id': 'yatsi_ezani_ussak',
      'ad':
          _languageService['sound_yatsi_ezani_ussak'] ?? '',
      'dosya': 'yatsi_ezani_ussak.mp3',
    },
    {
      'id': 'ney_uyan',
      'ad': _languageService['sound_ney_uyan'] ?? '',
      'dosya': 'ney_uyan.mp3',
    },
    {
      'id': 'custom',
      'ad': _languageService['custom_sound'] ?? '',
      'dosya': 'custom',
    },
  ];

  // Custom sound paths
  final Map<String, String> _ozelSesDosyalari = {};

  List<Map<String, String>> get _gunlukIcerikSesSecenekleri =>
      _sesSecenekleri.where((s) => s['dosya'] != 'custom').toList();

  /// Normalize file name for Android resource rules
  /// - Lowercase
  /// - Replace locale-specific characters
  /// - Prefix with "sound_" if it starts with a digit
  /// - Replace invalid characters with underscore
  String _normalizeFileName(String fileName) {
    // Split extension
    final lastDot = fileName.lastIndexOf('.');
    String name = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    String ext = lastDot > 0 ? fileName.substring(lastDot) : '';

    // Lowercase
    name = name.toLowerCase();
    ext = ext.toLowerCase();

    // Replace locale-specific characters
    final turkceKarakterler = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'Ç': 'c',
      'Ğ': 'g',
      'İ': 'i',
      'Ö': 'o',
      'Ş': 's',
      'Ü': 'u',
    };
    turkceKarakterler.forEach((key, value) {
      name = name.replaceAll(key, value);
    });

    // Keep letters, digits, and underscore only
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    // Collapse multiple underscores
    name = name.replaceAll(RegExp(r'_+'), '_');

    // Trim leading/trailing underscores
    name = name.replaceAll(RegExp(r'^_+|_+$'), '');

    // Use default name if empty
    if (name.isEmpty) {
      name = 'custom_sound';
    }

    // Prefix with "sound_" if starts with a digit
    if (RegExp(r'^[0-9]').hasMatch(name)) {
      name = 'sound_$name';
    }

    return '$name$ext';
  }

  /// Copy custom sound file with a safe name into app directory
  Future<String?> _copyCustomSoundFile(
    String sourcePath,
    String vakitKey,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soundsDir = Directory('${appDir.path}/custom_sounds');

      // Create directory if missing
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      // Get original file name and normalize
      final originalFileName = sourcePath.split('/').last.split('\\').last;
      final safeFileName = _normalizeFileName(originalFileName);

      // Create unique name (prayer key + timestamp)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${vakitKey}_${timestamp}_$safeFileName';

      final destPath = '${soundsDir.path}/$uniqueFileName';

      // Copy file
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);

      return destPath;
    } catch (e) {
      debugPrint('Sound file copy failed: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
    _ayarlariYukle();
    _baslangicAyarlari();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _baslangicAyarlari() async {
    // Initialize daily content notifications
    try {
      await DailyContentNotificationService.initialize();
      await DailyContentNotificationService.scheduleDailyContentNotifications();
      debugPrint('✅ Daily content notifications scheduled on startup');
    } catch (e) {
      debugPrint('❌ Daily content notification error: $e');
    }
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (final vakit in _bildirimAcik.keys) {
        _bildirimAcik[vakit] =
            prefs.getBool('bildirim_$vakit') ?? _bildirimAcik[vakit]!;
        // On-time defaults: enabled for Dhuhr, Asr, Maghrib, Isha
        final varsayilanVaktinde =
            (vakit == 'ogle' ||
            vakit == 'ikindi' ||
            vakit == 'aksam' ||
            vakit == 'yatsi');
        _vaktindeBildirim[vakit] =
            prefs.getBool('vaktinde_$vakit') ?? varsayilanVaktinde;
        _alarmAcik[vakit] = prefs.getBool('alarm_$vakit') ?? _alarmAcik[vakit]!;
        _erkenBildirim[vakit] =
            prefs.getInt('erken_$vakit') ?? _erkenBildirim[vakit]!;
        _bildirimSesi[vakit] =
            prefs.getString('bildirim_sesi_$vakit') ?? _bildirimSesi[vakit]!;
        // Early sound: fallback to on-time sound if missing
        _erkenBildirimSesi[vakit] =
            prefs.getString('erken_bildirim_sesi_$vakit') ??
            _bildirimSesi[vakit]!;

        // Load custom sound paths
        final ozelSes = prefs.getString('ozel_ses_$vakit');
        if (ozelSes != null) {
          _ozelSesDosyalari[vakit] = ozelSes;
        }
        final ozelErkenSes = prefs.getString('ozel_erken_ses_$vakit');
        if (ozelErkenSes != null) {
          _ozelSesDosyalari['${vakit}_erken'] = ozelErkenSes;
        }
      }
      _gunlukIcerikBildirimleri =
          prefs.getBool('daily_content_notifications_enabled') ?? true;
      _gunlukAyetSaati = _parseTimeOfDay(
        prefs.getString('daily_content_verse_time'),
        const TimeOfDay(hour: 8, minute: 0),
      );
      _gunlukHadisSaati = _parseTimeOfDay(
        prefs.getString('daily_content_hadith_time'),
        const TimeOfDay(hour: 13, minute: 0),
      );
      _gunlukDuaSaati = _parseTimeOfDay(
        prefs.getString('daily_content_prayer_time'),
        const TimeOfDay(hour: 20, minute: 0),
      );
      _gunlukIcerikSesi =
          prefs.getString('daily_content_notification_sound') ??
          _gunlukIcerikSesi;
      _sessizeAl = prefs.getBool('sessize_al') ?? false;
      _kilitEkraniBildirimi =
          prefs.getBool('kilit_ekrani_bildirimi_aktif') ?? false;
    });
  }

  Future<void> _ayarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();

    // Bildirim izinlerini kontrol et
    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidImpl = notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      // Notification permission check
      final hasNotificationPermission =
          await androidImpl.areNotificationsEnabled() ?? false;
      if (!hasNotificationPermission) {
        if (mounted) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                _languageService['notification_permission_required'] ?? '',
              ),
              content: Text(
                _languageService['notification_permission_message'] ?? '',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_languageService['give_up'] ?? ''),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_languageService['allow'] ?? ''),
                ),
              ],
            ),
          );

          if (shouldRequest == true) {
            final granted = await androidImpl.requestNotificationsPermission();
            if (granted != true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _languageService['notification_permission_denied'] ?? '',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          } else {
            return;
          }
        }
      }

      // Exact alarm permission check
      final canScheduleExact =
          await androidImpl.canScheduleExactNotifications() ?? false;
      if (!canScheduleExact) {
        if (mounted) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                _languageService['exact_alarm_permission_required'] ?? '',
              ),
              content: Text(
                _languageService['exact_alarm_permission_message'] ?? '',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_languageService['give_up'] ?? ''),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_languageService['allow'] ?? ''),
                ),
              ],
            ),
          );

          if (shouldRequest == true) {
            await androidImpl.requestExactAlarmsPermission();
          }
        }
      }
    }

    for (final vakit in _bildirimAcik.keys) {
      await prefs.setBool('bildirim_$vakit', _bildirimAcik[vakit]!);
      await prefs.setBool('vaktinde_$vakit', _vaktindeBildirim[vakit]!);
      await prefs.setBool('alarm_$vakit', _alarmAcik[vakit]!);
      await prefs.setInt('erken_$vakit', _erkenBildirim[vakit]!);
      await prefs.setString('bildirim_sesi_$vakit', _bildirimSesi[vakit]!);
      await prefs.setString(
        'erken_bildirim_sesi_$vakit',
        _erkenBildirimSesi[vakit]!,
      );
      debugPrint(
        '💾 [$vakit] Kaydedildi: bildirim=${_bildirimAcik[vakit]}, vaktinde=${_vaktindeBildirim[vakit]}, alarm=${_alarmAcik[vakit]}, erken=${_erkenBildirim[vakit]}, ses=${_bildirimSesi[vakit]}, erkenSes=${_erkenBildirimSesi[vakit]}',
      );

      // Save custom sound paths
      if (_ozelSesDosyalari.containsKey(vakit)) {
        await prefs.setString('ozel_ses_$vakit', _ozelSesDosyalari[vakit]!);
      }
      if (_ozelSesDosyalari.containsKey('${vakit}_erken')) {
        await prefs.setString(
          'ozel_erken_ses_$vakit',
          _ozelSesDosyalari['${vakit}_erken']!,
        );
      }
    }
    await prefs.setBool('sessize_al', _sessizeAl);
    await DailyContentNotificationService.setDailyContentNotificationSettings(
      enabled: _gunlukIcerikBildirimleri,
      soundFileName: _gunlukIcerikSesi,
      verseTime: _formatTimeOfDay(_gunlukAyetSaati),
      hadithTime: _formatTimeOfDay(_gunlukHadisSaati),
      prayerTime: _formatTimeOfDay(_gunlukDuaSaati),
    );

    // NOTE: DndService is no longer used. AlarmService checks "sessize_al"
    // and silences the phone. Conflict avoided.
    // Clear legacy DND schedules
    if (!_sessizeAl) {
      await DndService.cancelPrayerDnd();
    }

    // Save and reschedule early reminders first (new service)
    int erkenAlarmSayisi = 0;
    try {
      erkenAlarmSayisi = await EarlyReminderService.saveAndReschedule(
        erkenSureler: Map<String, int>.from(_erkenBildirim),
        erkenSesler: Map<String, String>.from(_erkenBildirimSesi),
      );
      debugPrint(
        '✅ Early reminder save completed: $erkenAlarmSayisi alarms',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Early reminder save error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_languageService['early_reminder_error'] ?? ''}: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    // Reschedule on-time notifications
    await ScheduledNotificationService.scheduleAllPrayerNotifications();
    // Daily content alarm settings updated above

    setState(() {
      _degisiklikYapildi = false;
    });

    if (mounted) {
      // Calculate active early reminder count
      final aktifErkenSayisi = _erkenBildirim.entries
          .where((e) => e.value > 0 && (_bildirimAcik[e.key] ?? false))
          .length;

      String mesaj;
      Color renk;

      if (aktifErkenSayisi > 0 && erkenAlarmSayisi == 0) {
        // Early reminders selected but not scheduled
        mesaj =
            _languageService['notification_settings_saved_early_reminder_failed'] ??
            '';
        renk = Colors.orange;
      } else {
        // Success
        mesaj = _languageService['notification_settings_saved'] ?? '';
        renk = Colors.green;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mesaj),
          backgroundColor: renk,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _toggleSessizeAl(bool value) async {
    // NOTE: DndService is no longer used. AlarmService checks "sessize_al"
    // and silences the phone. Conflict avoided.
    // Users can manage silent mode with Stay/Exit buttons.

    if (!value) {
      // Clear legacy DND schedules when disabling mute
      await DndService.cancelPrayerDnd();
    }

    if (mounted) {
      setState(() {
        _sessizeAl = value;
      });
    }
  }

  TimeOfDay _parseTimeOfDay(String? value, TimeOfDay fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDailyContentTime({
    required TimeOfDay current,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      setState(() {
        onSelected(picked);
        _degisiklikYapildi = true;
      });
    }
  }

  /// Toggle lock screen notification
  Future<void> _toggleKilitEkraniBildirimi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kilit_ekrani_bildirimi_aktif', value);

    try {
      if (value) {
        // Start service
        await _lockScreenChannel.invokeMethod('startLockScreenService');
        debugPrint('✅ Lock screen notification service started');
      } else {
        // Stop service
        await _lockScreenChannel.invokeMethod('stopLockScreenService');
        debugPrint('🛑 Lock screen notification service stopped');
      }
    } catch (e) {
      debugPrint('❌ Lock screen notification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _languageService['lock_screen_error'] ?? '',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _kilitEkraniBildirimi = !value; // Revert
        });
      }
    }
  }

  Future<void> _sesCal(String key, String sesId) async {
    try {
      if (_sesCalanKey == key) {
        // Stop if the same button was pressed
        await _audioPlayer.stop();
        setState(() => _sesCalanKey = null);
      } else {
        // If a different button was pressed, stop then play new
        await _audioPlayer.stop();

        if (sesId == 'custom' && _ozelSesDosyalari.containsKey(key)) {
          // Play custom sound
          await _audioPlayer.play(DeviceFileSource(_ozelSesDosyalari[key]!));
        } else if (sesId != 'custom') {
          // Resolve file name from ID
          final sesSecenegi = _sesSecenekleri.firstWhere(
            (s) => s['id'] == sesId,
            orElse: () => _sesSecenekleri.first,
          );
          final sesDosyasi = sesSecenegi['dosya']!;
          // Play asset sound
          await _audioPlayer.play(AssetSource('sounds/$sesDosyasi'));
        }

        setState(() => _sesCalanKey = key);

        // Auto toggle when playback ends
        _audioPlayer.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            setState(() => _sesCalanKey = null);
          }
        });
      }
    } catch (e) {
      setState(() => _sesCalanKey = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_languageService['sound_error'] ?? ''}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _ozelSesSec(String key) async {
    final isErken = key.endsWith('_erken');
    final baseKey = isErken ? key.replaceFirst('_erken', '') : key;
    // Inform the user first
    final devam = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageService['custom_sound_title'] ?? '',
        ),
        content: Text(
          _languageService['custom_sound_info'] ?? '',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService['cancel'] ?? ''),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_languageService['select_file'] ?? ''),
          ),
        ],
      ),
    );

    if (devam != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final secilenDosyaYolu = result.files.single.path!;

        // Copy file with a safe name into app directory
        final guvenliDosyaYolu = await _copyCustomSoundFile(
          secilenDosyaYolu,
          key,
        );

        if (guvenliDosyaYolu != null) {
          setState(() {
            _ozelSesDosyalari[key] = guvenliDosyaYolu;
            if (isErken) {
              _erkenBildirimSesi[baseKey] = 'custom';
            } else {
              _bildirimSesi[baseKey] = 'custom';
            }
            _degisiklikYapildi = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _languageService['custom_sound_selected'] ?? '',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Play selected sound
          await _sesCal(key, 'custom');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _languageService['custom_sound_copy_error'] ?? '',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // User canceled, keep previous selection
        if (mounted) {
          setState(() {
            // If custom selected but file missing, fallback to default
            if (isErken) {
              if (_erkenBildirimSesi[baseKey] == 'custom' &&
                  !_ozelSesDosyalari.containsKey(key)) {
                _erkenBildirimSesi[baseKey] = _sesSecenekleri.first['id']!;
              }
            } else {
              if (_bildirimSesi[baseKey] == 'custom' &&
                  !_ozelSesDosyalari.containsKey(key)) {
                _bildirimSesi[baseKey] = _sesSecenekleri.first['id']!;
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_languageService['sound_select_error'] ?? ''}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // ... existing code ...

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    return WillPopScope(
      onWillPop: () async {
        if (_degisiklikYapildi) {
          final kaydet = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: renkler.kartArkaPlan,
              title: Text(
                _languageService['save_changes_title'] ?? '',
                style: TextStyle(color: renkler.yaziPrimary),
              ),
              content: Text(
                _languageService['save_changes_message'] ?? '',
                style: TextStyle(color: renkler.yaziSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    _languageService['dont_save'] ?? '',
                    style: TextStyle(color: renkler.yaziSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: renkler.vurgu,
                  ),
                  child: Text(
                    _languageService['save'] ?? '',
                    style: TextStyle(color: renkler.arkaPlan),
                  ),
                ),
              ],
            ),
          );

          if (kaydet == true) {
            await _ayarlariKaydet();
          }
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _temaService.renkler.arkaPlan,
        appBar: AppBar(
          title: Text(
            _languageService['notification_settings_title'] ?? '',
            style: TextStyle(color: _temaService.renkler.yaziPrimary),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: _temaService.renkler.yaziPrimary),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _ayarlariKaydet,
              tooltip: _languageService['save'] ?? '',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: renkler.vurgu.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: renkler.vurgu.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: renkler.vurgu),
                      const SizedBox(width: 12),
                      Text(
                        _languageService['notification_alarm_system'] ?? '',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _languageService['notification_info_text'] ?? '',
                    style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Mute during prayer times
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: renkler.kartArkaPlan,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: renkler.ayirac),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.volume_off, color: renkler.vurguSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _languageService['mute_during_prayer'] ?? '',
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _sessizeAl,
                        onChanged: (value) async {
                          setState(() {
                            _degisiklikYapildi = true;
                          });
                          await _toggleSessizeAl(value);
                        },
                        activeThumbColor: renkler.vurguSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 36,
                      right: 12,
                      bottom: 6,
                    ),
                    child: Text(
                      _languageService['mute_during_prayer_desc'] ?? '',
                      style: TextStyle(
                        color: renkler.yaziSecondary.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Daily content alarms
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: renkler.kartArkaPlan,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: renkler.ayirac),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: renkler.vurgu,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _languageService['daily_content_notifications'] ?? '',
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _gunlukIcerikBildirimleri,
                        onChanged: (value) async {
                          setState(() {
                            _gunlukIcerikBildirimleri = value;
                            _degisiklikYapildi = true;
                          });
                        },
                        activeThumbColor: renkler.vurgu,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 36,
                      right: 12,
                      bottom: 6,
                    ),
                    child: Text(
                      _languageService['daily_content_notifications_desc'] ??
                          '',
                      style: TextStyle(
                        color: renkler.yaziSecondary.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Alarm zamanlari
                  Padding(
                    padding: const EdgeInsets.only(left: 36, right: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('📖', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_verse_label'] ?? '',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _pickDailyContentTime(
                                current: _gunlukAyetSaati,
                                onSelected: (value) {
                                  _gunlukAyetSaati = value;
                                },
                              ),
                              child: Text(
                                _formatTimeOfDay(_gunlukAyetSaati),
                                style: TextStyle(
                                  color: renkler.vurgu,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('📿', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_hadith_label'] ?? '',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _pickDailyContentTime(
                                current: _gunlukHadisSaati,
                                onSelected: (value) {
                                  _gunlukHadisSaati = value;
                                },
                              ),
                              child: Text(
                                _formatTimeOfDay(_gunlukHadisSaati),
                                style: TextStyle(
                                  color: renkler.vurgu,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('🤲', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_dua_label'] ?? '',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _pickDailyContentTime(
                                current: _gunlukDuaSaati,
                                onSelected: (value) {
                                  _gunlukDuaSaati = value;
                                },
                              ),
                              child: Text(
                                _formatTimeOfDay(_gunlukDuaSaati),
                                style: TextStyle(
                                  color: renkler.vurgu,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.music_note,
                              color: renkler.vurgu,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_content_alarm_sound'] ?? '',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 160,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      _gunlukIcerikSesSecenekleri.any(
                                        (s) => s['id'] == _gunlukIcerikSesi,
                                      )
                                      ? _gunlukIcerikSesi
                                      : _gunlukIcerikSesSecenekleri.first['id'],
                                  isExpanded: true,
                                  dropdownColor: renkler.kartArkaPlan,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: renkler.vurgu,
                                  ),
                                  style: TextStyle(color: renkler.yaziPrimary),
                                  items: _gunlukIcerikSesSecenekleri.map((ses) {
                                    return DropdownMenuItem(
                                      value: ses['id'],
                                      child: Text(
                                        ses['ad']!,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _gunlukIcerikSesi = value;
                                      _degisiklikYapildi = true;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lock screen notification option
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: renkler.kartArkaPlan,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: renkler.ayirac),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_clock, color: renkler.vurguSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _languageService['lock_screen_notification'] ?? '',
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _kilitEkraniBildirimi,
                        onChanged: (value) async {
                          setState(() {
                            _kilitEkraniBildirimi = value;
                            _degisiklikYapildi = true;
                          });
                          await _toggleKilitEkraniBildirimi(value);
                        },
                        activeThumbColor: renkler.vurguSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 36,
                      right: 12,
                      bottom: 6,
                    ),
                    child: Text(
                      _languageService['lock_screen_notification_desc'] ?? '',
                      style: TextStyle(
                        color: renkler.yaziSecondary.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Enable/disable all buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final key in _bildirimAcik.keys) {
                          _bildirimAcik[key] = true;
                        }
                        _degisiklikYapildi = true;
                      });
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: Text(
                      _languageService['enable_all_notifications'] ?? '',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: renkler.vurgu,
                      side: BorderSide(color: renkler.vurgu),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final key in _bildirimAcik.keys) {
                          _bildirimAcik[key] = false;
                        }
                        _degisiklikYapildi = true;
                      });
                    },
                    icon: const Icon(Icons.notifications_off),
                    label: Text(
                      _languageService['disable_all_notifications'] ?? '',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: renkler.vurguSecondary,
                      side: BorderSide(color: renkler.vurguSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Vakit bildirimleri
            _vakitBildirimKarti(
              _languageService['imsak'] ?? '',
              'imsak',
              Icons.nightlight_round,
              _languageService['imsak_desc'] ?? '',
            ),
            _vakitBildirimKarti(
              _languageService['gunes'] ?? '',
              'gunes',
              Icons.wb_sunny,
              _languageService['gunes_desc'] ?? '',
            ),
            _vakitBildirimKarti(
              _languageService['ogle'] ?? '',
              'ogle',
              Icons.light_mode,
              _languageService['ogle_desc'] ?? '',
            ),
            _vakitBildirimKarti(
              _languageService['ikindi'] ?? '',
              'ikindi',
              Icons.brightness_6,
              _languageService['ikindi_desc'] ?? '',
            ),
            _vakitBildirimKarti(
              _languageService['aksam'] ?? '',
              'aksam',
              Icons.wb_twilight,
              _languageService['aksam_desc'] ?? '',
            ),
            _vakitBildirimKarti(
              _languageService['yatsi'] ?? '',
              'yatsi',
              Icons.nights_stay,
              _languageService['yatsi_desc'] ?? '',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _vakitBildirimKarti(
    String baslik,
    String key,
    IconData icon,
    String aciklama,
  ) {
    final renkler = _temaService.renkler;
    final acik = _bildirimAcik[key]!;
    final vaktindeAcik = _vaktindeBildirim[key]!;
    final erkenDakika = _erkenBildirim[key]!;
    final seciliSes = _bildirimSesi[key]!;
    final erkenSeciliSes = _erkenBildirimSesi[key]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: acik
            ? renkler.vurgu.withOpacity(0.05)
            : renkler.kartArkaPlan.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: acik ? renkler.vurgu.withOpacity(0.3) : renkler.ayirac,
        ),
      ),
      child: Column(
        children: [
          // Top section - switch
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: acik
                    ? renkler.vurgu.withOpacity(0.2)
                    : renkler.kartArkaPlan.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: acik ? renkler.vurgu : renkler.yaziSecondary,
              ),
            ),
            title: Text(
              baslik,
              style: TextStyle(
                color: acik ? renkler.yaziPrimary : renkler.yaziSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              aciklama,
              style: TextStyle(
                color: acik ? renkler.yaziSecondary.withOpacity(0.8) : renkler.yaziSecondary.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            trailing: Switch(
              value: acik,
              onChanged: (value) {
                setState(() {
                  _bildirimAcik[key] = value;
                  _degisiklikYapildi = true;
                });
              },
              activeThumbColor: renkler.vurgu,
            ),
          ),

          // Bottom section - on-time, early reminder, and sound selection
          if (acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // On-time notify
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: vaktindeAcik
                          ? renkler.vurguSecondary.withOpacity(0.15)
                          : renkler.kartArkaPlan.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: vaktindeAcik
                            ? renkler.vurguSecondary.withOpacity(0.5)
                            : renkler.ayirac,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: vaktindeAcik
                              ? renkler.vurguSecondary
                              : renkler.yaziSecondary.withOpacity(0.8),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _languageService['notify_at_prayer'] ?? '',
                            style: TextStyle(
                              color: vaktindeAcik
                                  ? renkler.vurguSecondary
                                  : renkler.yaziPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: vaktindeAcik,
                          onChanged: (value) {
                            setState(() {
                              _vaktindeBildirim[key] = value;
                              _degisiklikYapildi = true;
                            });
                          },
                          activeThumbColor: renkler.vurguSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer, color: renkler.yaziSecondary.withOpacity(0.8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _languageService['early_reminder'] ?? '',
                        style: TextStyle(
                          color: renkler.yaziSecondary.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: renkler.kartArkaPlan.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: erkenDakika,
                              isExpanded: true,
                              dropdownColor: renkler.kartArkaPlan,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: renkler.vurgu,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              style: TextStyle(color: renkler.yaziPrimary),
                              items: _erkenSureler.map((dakika) {
                                String label;
                                if (dakika == 0) {
                                  label = _languageService['none'] ?? '';
                                } else if (dakika < 60) {
                                  label =
                                      '$dakika ${_languageService['minutes'] ?? ''}';
                                } else {
                                  label =
                                      '${dakika ~/ 60} ${_languageService['hours'] ?? ''}';
                                }
                                return DropdownMenuItem(
                                  value: dakika,
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _erkenBildirim[key] = value;
                                    _degisiklikYapildi = true;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // === ON-TIME ALARM SOUND ===
                  if (vaktindeAcik) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.alarm,
                                color: renkler.vurguSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _languageService['on_time_sound'] ?? '',
                                style: TextStyle(
                                  color: renkler.vurguSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: renkler.kartArkaPlan.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value:
                                          _sesSecenekleri.any(
                                            (s) => s['id'] == seciliSes,
                                          )
                                          ? seciliSes
                                          : _sesSecenekleri.first['id'],
                                      isExpanded: true,
                                      dropdownColor: renkler.kartArkaPlan,
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: renkler.vurguSecondary,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      style: TextStyle(
                                        color: renkler.yaziPrimary,
                                      ),
                                      items: _sesSecenekleri.map((ses) {
                                        return DropdownMenuItem(
                                          value: ses['id'],
                                          child: Text(ses['ad']!),
                                        );
                                      }).toList(),
                                      onChanged: (value) async {
                                        if (value != null) {
                                          if (value == 'custom') {
                                            await _ozelSesSec(key);
                                          } else {
                                            setState(() {
                                              final eskiSes =
                                                  _bildirimSesi[key]!;
                                              _bildirimSesi[key] = value;
                                              // If early sound matches old on-time sound, sync to new sound
                                              if (_erkenBildirimSesi[key] ==
                                                  eskiSes) {
                                                _erkenBildirimSesi[key] = value;
                                              }
                                              _degisiklikYapildi = true;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: _sesCalanKey == key
                                      ? renkler.vurguSecondary.withOpacity(0.3)
                                      : renkler.vurgu.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  onPressed: () => _sesCal(key, seciliSes),
                                  icon: Icon(
                                    _sesCalanKey == key
                                        ? Icons.stop_circle
                                        : Icons.play_circle,
                                    color: _sesCalanKey == key
                                        ? renkler.vurguSecondary
                                        : renkler.vurgu,
                                    size: 28,
                                  ),
                                  tooltip: _sesCalanKey == key
                                      ? (_languageService['stop'] ?? '')
                                      : (_languageService['listen'] ?? ''),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (seciliSes == 'custom' &&
                              _ozelSesDosyalari.containsKey(key))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_languageService['custom'] ?? ''}: ${_ozelSesDosyalari[key]!.split('/').last.split('\\').last}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // === EARLY REMINDER SOUND ===
                  if (erkenDakika > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: renkler.vurgu.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: renkler.vurgu.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.timer,
                                color: Colors.cyanAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _languageService['early_sound'] ?? '',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value:
                                          _sesSecenekleri.any(
                                            (s) => s['id'] == erkenSeciliSes,
                                          )
                                          ? erkenSeciliSes
                                          : _sesSecenekleri.first['id'],
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF2B3151),
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.cyanAccent,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      items: _sesSecenekleri.map((ses) {
                                        return DropdownMenuItem(
                                          value: ses['id'],
                                          child: Text(ses['ad']!),
                                        );
                                      }).toList(),
                                      onChanged: (value) async {
                                        if (value != null) {
                                          if (value == 'custom') {
                                            await _ozelSesSec('${key}_erken');
                                          } else {
                                            setState(() {
                                              _erkenBildirimSesi[key] = value;
                                              _degisiklikYapildi = true;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: _sesCalanKey == '${key}_erken'
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  onPressed: () =>
                                      _sesCal('${key}_erken', erkenSeciliSes),
                                  icon: Icon(
                                    _sesCalanKey == '${key}_erken'
                                        ? Icons.stop_circle
                                        : Icons.play_circle,
                                    color: _sesCalanKey == '${key}_erken'
                                        ? Colors.red
                                        : Colors.green,
                                    size: 28,
                                  ),
                                  tooltip: _sesCalanKey == '${key}_erken'
                                      ? (_languageService['stop'] ?? '')
                                      : (_languageService['listen'] ?? ''),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (erkenSeciliSes == 'custom' &&
                              _ozelSesDosyalari.containsKey('${key}_erken'))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_languageService['custom'] ?? ''}: ${_ozelSesDosyalari['${key}_erken']!.split('/').last.split('\\').last}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
