import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/splash_screen.dart';
import 'services/tema_service.dart';
import 'services/home_widget_service.dart';
import 'services/dnd_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tarih formatını Türkçe için başlat
  await initializeDateFormatting('tr_TR', null);
  
  // Tema servisini başlat
  final temaService = TemaService();
  await temaService.temayiYukle();
  
  // Home Widget servisini başlat
  await HomeWidgetService.initialize();

  // Sessize alma ayarı açıksa DND zamanlamasını kur
  final prefs = await SharedPreferences.getInstance();
  final sessizeAl = prefs.getBool('sessize_al') ?? false;
  if (sessizeAl) {
    await DndService.schedulePrayerDnd();
  }

  // Bildirim altyapısını başlat
  await NotificationService.initialize(null);
  
  runApp(const HuzurVaktiApp());
}

class HuzurVaktiApp extends StatefulWidget {
  const HuzurVaktiApp({super.key});

  @override
  State<HuzurVaktiApp> createState() => _HuzurVaktiAppState();
}

class _HuzurVaktiAppState extends State<HuzurVaktiApp> {
  final TemaService _temaService = TemaService();

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Huzur Vakti',
      theme: _temaService.buildThemeData(),

      home: const SplashScreen(),
    );
  }
}
