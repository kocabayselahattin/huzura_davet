import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/splash_screen.dart';
import 'services/tema_service.dart';
import 'services/home_widget_service.dart';
import 'services/dnd_service.dart';
import 'services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'services/scheduled_notification_service.dart';
import 'services/daily_content_notification_service.dart';

/// İlk kurulumda varsayılan bildirim ayarlarını SharedPreferences'a kaydet
Future<void> _initializeDefaultNotificationSettings(
  SharedPreferences prefs,
) async {
  // Daha önce ayarlar kaydedilmiş mi kontrol et
  final alreadyInitialized =
      prefs.getBool('notification_settings_initialized') ?? false;
  if (alreadyInitialized) return;

  debugPrint('🔔 İlk kurulum: Varsayılan bildirim ayarları kaydediliyor...');

  // Varsayılan erken bildirim süreleri (dakika)
  const defaultErkenBildirim = {
    'imsak': 15,
    'gunes': 45,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
  };

  // Varsayılan bildirim açık durumları
  const defaultBildirimAcik = {
    'imsak': true,
    'gunes': true,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Varsayılan bildirim sesleri
  const defaultBildirimSesi = {
    'imsak': 'best.mp3',
    'gunes': 'best.mp3',
    'ogle': 'best.mp3',
    'ikindi': 'best.mp3',
    'aksam': 'best.mp3',
    'yatsi': 'best.mp3',
  };

  // Her vakit için varsayılan değerleri kaydet
  for (final vakit in defaultErkenBildirim.keys) {
    // Erken bildirim süresi
    if (!prefs.containsKey('erken_$vakit')) {
      await prefs.setInt('erken_$vakit', defaultErkenBildirim[vakit]!);
    }
    // Bildirim açık/kapalı
    if (!prefs.containsKey('bildirim_$vakit')) {
      await prefs.setBool('bildirim_$vakit', defaultBildirimAcik[vakit]!);
    }
    // Bildirim sesi
    if (!prefs.containsKey('bildirim_sesi_$vakit')) {
      await prefs.setString(
        'bildirim_sesi_$vakit',
        defaultBildirimSesi[vakit]!,
      );
    }
  }

  // Günlük içerik bildirimleri varsayılan olarak açık
  if (!prefs.containsKey('daily_content_notifications_enabled')) {
    await prefs.setBool('daily_content_notifications_enabled', true);
  }

  // Ayarların başlatıldığını işaretle
  await prefs.setBool('notification_settings_initialized', true);
  debugPrint('✅ Varsayılan bildirim ayarları kaydedildi');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Uygulama dikey yönde sabit kalsın
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Tarih formatını Türkçe için başlat
  await initializeDateFormatting('tr_TR', null);

  // Tema servisini başlat
  final temaService = TemaService();
  await temaService.temayiYukle();

  // Dil servisini başlat
  final languageService = LanguageService();
  await languageService.load();

  // Home Widget servisini başlat ve arka plan güncellemelerini planla
  await HomeWidgetService.initialize();

  // Android için arka plan widget güncellemelerini başlat
  if (Platform.isAndroid) {
    try {
      await const MethodChannel(
        'huzur_vakti/widgets',
      ).invokeMethod('scheduleWidgetUpdates');
    } catch (e) {
      debugPrint('⚠️ Widget arka plan güncellemeleri başlatılamadı: $e');
    }
  }

  // Sessize alma ayarı açıksa DND zamanlamasını kur
  final prefs = await SharedPreferences.getInstance();
  final sessizeAl = prefs.getBool('sessize_al') ?? false;
  if (sessizeAl) {
    await DndService.schedulePrayerDnd();
  }

  // 🔔 İlk kurulumda varsayılan erken bildirim değerlerini kaydet
  await _initializeDefaultNotificationSettings(prefs);

  // Bildirim altyapısını başlat
  await NotificationService.initialize(null);

  // Zamanlanmış bildirim servisini başlat
  await ScheduledNotificationService.initialize();

  // Günlük içerik bildirimleri servisini başlat
  await DailyContentNotificationService.initialize();
  await DailyContentNotificationService.scheduleDailyContentNotifications();

  // 🔔 Uygulama başlatıldığında alarmları yeniden zamanla
  // Bu boot sonrası veya uygulama güncellemesi sonrası alarmları geri yükler
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
