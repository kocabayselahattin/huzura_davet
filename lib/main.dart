import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/splash_screen.dart';
import 'services/tema_service.dart';
import 'services/home_widget_service.dart';
import 'services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'services/scheduled_notification_service.dart';
import 'services/daily_content_notification_service.dart';
import 'services/ozel_gunler_service.dart';

/// Save default notification settings in SharedPreferences on first run.
Future<void> _initializeDefaultNotificationSettings(
  SharedPreferences prefs,
) async {
  // Check if settings were already initialized.
  final alreadyInitialized =
      prefs.getBool('notification_settings_initialized') ?? false;
  if (alreadyInitialized) return;

  debugPrint('🔔 First run: saving default notification settings...');

  // Default early notification offsets (minutes).
  const defaultErkenBildirim = {
    'imsak': 5,
    'gunes': 45,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
  };

  // Default notification enabled states.
  // Imsak disabled by default.
  const defaultBildirimAcik = {
    'imsak': false,
    'gunes': true,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Default notification sounds.
  const defaultBildirimSesi = {
    'imsak': 'best.mp3',
    'gunes': 'best.mp3',
    'ogle': 'best.mp3',
    'ikindi': 'best.mp3',
    'aksam': 'best.mp3',
    'yatsi': 'best.mp3',
  };

  // Default early notification sounds (same as on-time).
  const defaultErkenBildirimSesi = {
    'imsak': 'best.mp3',
    'gunes': 'best.mp3',
    'ogle': 'best.mp3',
    'ikindi': 'best.mp3',
    'aksam': 'best.mp3',
    'yatsi': 'best.mp3',
  };

  // Default on-time reminder states.
  // Imsak and sunrise off; noon, afternoon, sunset, and night on.
  const defaultVaktindeBildirim = {
    'imsak': false,
    'gunes': false,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Default alarm states.
  // Imsak off, others on (including sunrise for early warning).
  const defaultAlarm = {
    'imsak': false,
    'gunes': true,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Save defaults for each prayer time.
  for (final vakit in defaultErkenBildirim.keys) {
    // Early notification offset.
    if (!prefs.containsKey('erken_$vakit')) {
      await prefs.setInt('erken_$vakit', defaultErkenBildirim[vakit]!);
    }
    // Notification enabled/disabled.
    if (!prefs.containsKey('bildirim_$vakit')) {
      await prefs.setBool('bildirim_$vakit', defaultBildirimAcik[vakit]!);
    }
    // Notification sound.
    if (!prefs.containsKey('bildirim_sesi_$vakit')) {
      await prefs.setString(
        'bildirim_sesi_$vakit',
        defaultBildirimSesi[vakit]!,
      );
    }
    // Early notification sound.
    if (!prefs.containsKey('erken_bildirim_sesi_$vakit')) {
      await prefs.setString(
        'erken_bildirim_sesi_$vakit',
        defaultErkenBildirimSesi[vakit]!,
      );
    }
    // On-time reminder.
    if (!prefs.containsKey('vaktinde_$vakit')) {
      await prefs.setBool('vaktinde_$vakit', defaultVaktindeBildirim[vakit]!);
    }
    // Alarm.
    if (!prefs.containsKey('alarm_$vakit')) {
      await prefs.setBool('alarm_$vakit', defaultAlarm[vakit]!);
    }
  }

  // Daily content notifications on by default.
  if (!prefs.containsKey('daily_content_notifications_enabled')) {
    await prefs.setBool('daily_content_notifications_enabled', true);
  }

  // Mark settings as initialized.
  await prefs.setBool('notification_settings_initialized', true);
  debugPrint('✅ Default notification settings saved');

  // Counter: default to Day Cycle (index 22) on first run.
  if (!prefs.containsKey('aktif_sayac_index')) {
    await prefs.setInt('aktif_sayac_index', 22);
    debugPrint('🌞 Counter set to default Day Cycle (aktif_sayac_index=22)');
  }
  if (!prefs.containsKey('secili_sayac_index')) {
    await prefs.setInt('secili_sayac_index', 22);
    debugPrint('🌞 Counter set to default Day Cycle (secili_sayac_index=22)');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app orientation to portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize date formatting for Turkish.
  await initializeDateFormatting('tr_TR', null);

  // Initialize theme service.
  final temaService = TemaService();
  await temaService.temayiYukle();

  // Initialize language service.
  final languageService = LanguageService();
  await languageService.load();

  // Initialize Home Widget service and schedule background updates.
  await HomeWidgetService.initialize();

  // Start background widget updates on Android.
  if (Platform.isAndroid) {
    try {
      await const MethodChannel(
        'huzur_vakti/widgets',
      ).invokeMethod('scheduleWidgetUpdates');
    } catch (e) {
      debugPrint('⚠️ Failed to start widget background updates: $e');
    }
  }

  // NOTE: DndService is no longer used - AlarmService checks "sessize_al"
  // and silences the phone. The systems conflicted, now only AlarmService is active.
  final prefs = await SharedPreferences.getInstance();

  // 🔔 Save default early notification values on first run.
  await _initializeDefaultNotificationSettings(prefs);

  // Initialize notification infrastructure.
  await NotificationService.initialize(null);

  // Initialize scheduled notification service.
  await ScheduledNotificationService.initialize();

  // Initialize daily content notification service.
  await DailyContentNotificationService.initialize();
  await DailyContentNotificationService.scheduleDailyContentNotifications();

  // 🔔 Special day notifications (holy nights, holidays, etc.).
  await OzelGunlerService.scheduleOzelGunBildirimleri();

  // 🔔 Reschedule alarms on app start.
  // Restores alarms after boot or app updates.
  await ScheduledNotificationService.scheduleAllPrayerNotifications();

  runApp(const HuzurVaktiApp());
}

class HuzurVaktiApp extends StatefulWidget {
  const HuzurVaktiApp({super.key});

  @override
  State<HuzurVaktiApp> createState() => _HuzurVaktiAppState();
}

class _HuzurVaktiAppState extends State<HuzurVaktiApp> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _languageService['app_name'],
      theme: _temaService.buildThemeData(),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
        Locale('de', 'DE'),
        Locale('fr', 'FR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashScreen(),
    );
  }
}
