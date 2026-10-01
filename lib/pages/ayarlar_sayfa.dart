import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bildirim_ayarlari_sayfa.dart';
import 'il_ilce_sec_sayfa.dart';
import 'tema_ayarlari_sayfa.dart';
import 'hakkinda_sayfa.dart';
import 'gizlilik_politikasi_sayfa.dart';
import 'sayac_ayarlari_sayfa.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/permission_service.dart';
import 'widget_ayarlari_sayfa.dart';
import 'splash_screen.dart';

class AyarlarSayfa extends StatefulWidget {
  const AyarlarSayfa({super.key});

  @override
  State<AyarlarSayfa> createState() => _AyarlarSayfaState();
}

class _AyarlarSayfaState extends State<AyarlarSayfa>
    with WidgetsBindingObserver {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  // Pil optimizasyonu isteğe bağlı bir ayardır; kullanıcı bunu Ayarlar'dan
  // ne zaman isterse açar (bkz. onboarding_permissions_page.dart'taki not —
  // ilk kurulumda zorunlu tutulmuyor).
  bool _pilOptimizasyonuKapali = false;

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
    WidgetsBinding.instance.addObserver(this);
    _pilDurumunuYukle();
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pil izni harici Ayarlar ekranında verilir; uygulamaya dönünce
    // durumu yeniden kontrol et.
    if (state == AppLifecycleState.resumed) _pilDurumunuYukle();
  }

  Future<void> _pilDurumunuYukle() async {
    if (!Platform.isAndroid) return;
    final kapali = await PermissionService.isBatteryOptimizationDisabled();
    if (mounted) setState(() => _pilOptimizasyonuKapali = kapali);
  }

  Future<void> _pilOptimizasyonuIste() async {
    await PermissionService.requestBatteryOptimizationExemption();
    await _pilDurumunuYukle();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _languageService['settings'] ?? '',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          // Notifications
          _ayarSatiri(
            icon: Icons.notifications,
            iconColor: renkler.vurgu,
            baslik: _languageService['notifications'] ?? '',
            altBaslik:
              _languageService['notification_settings'] ?? '',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BildirimAyarlariSayfa(),
                ),
              );
            },
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // Battery optimization (opsiyonel - alarmların gecikmeden çalması için)
          if (Platform.isAndroid) ...[
            _ayarSatiri(
              icon: Icons.battery_charging_full,
              iconColor: _pilOptimizasyonuKapali
                  ? Colors.green
                  : Colors.orange,
              baslik: _languageService['battery_permission'] ?? '',
              altBaslik: _pilOptimizasyonuKapali
                  ? (_languageService['permission_granted'] ?? '')
                  : (_languageService['battery_permission_desc'] ?? ''),
              onTap: _pilOptimizasyonuKapali ? null : _pilOptimizasyonuIste,
              renkler: renkler,
              trailing: _pilOptimizasyonuKapali
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Icon(Icons.chevron_right, color: renkler.yaziSecondary),
            ),
            Divider(color: renkler.ayirac),
          ],

          // Location settings
          _ayarSatiri(
            icon: Icons.location_on,
            iconColor: renkler.vurgu,
            baslik: _languageService['location'] ?? '',
            altBaslik: _languageService['select_location'] ?? '',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IlIlceSecSayfa()),
              );
            },
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // Language selection
          _ayarSatiri(
            icon: Icons.language,
            iconColor: Colors.blue,
            baslik: _languageService['language'] ?? '',
            altBaslik: _languageService.supportedLanguages.firstWhere(
              (lang) => lang['code'] == _languageService.currentLanguage,
            )['name']!,
            onTap: () => _dilSecimDialog(),
            renkler: renkler,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _languageService.supportedLanguages.firstWhere(
                    (lang) => lang['code'] == _languageService.currentLanguage,
                  )['flag']!,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: renkler.yaziSecondary),
              ],
            ),
          ),
          Divider(color: renkler.ayirac),

          // Theme
          _ayarSatiri(
            icon: Icons.palette,
            iconColor: renkler.vurgu,
            baslik: _languageService['theme'] ?? '',
            altBaslik:
              '${_languageService[renkler.isim] ?? renkler.isim} - '
              '${_languageService[renkler.aciklama] ?? renkler.aciklama}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TemaAyarlariSayfa(),
                ),
              );
            },
            renkler: renkler,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: renkler.vurgu,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: renkler.yaziSecondary),
              ],
            ),
          ),
          Divider(color: renkler.ayirac),

          // Prayer counters
          _ayarSatiri(
            icon: Icons.timer,
            iconColor: Colors.cyan,
            baslik: _languageService['counter_settings'] ?? '',
            altBaslik:
              _languageService['counter_settings_short'] ?? '',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SayacAyarlariSayfa(),
                ),
              );
            },
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // Widget settings
          _ayarSatiri(
            icon: Icons.widgets,
            iconColor: renkler.vurgu,
            baslik: _languageService['widget_settings'] ?? '',
            altBaslik: _languageService['background_color'] ?? '',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WidgetAyarlariSayfa(),
                ),
              );
            },
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // Privacy Policy
          _ayarSatiri(
            icon: Icons.privacy_tip,
            iconColor: renkler.vurgu,
            baslik: _languageService['privacy_policy'] ?? '',
            altBaslik: _languageService['pd_subtitle_short'] ?? '',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GizlilikPolitikasiSayfa(),
                ),
              );
            },
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // About
          _ayarSatiri(
            icon: Icons.info,
            iconColor: renkler.vurgu,
            baslik: _languageService['about'] ?? '',
            altBaslik: _languageService['about_app'] ?? '',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HakkindaSayfa()),
              );
            },
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // Verilerimi Sil (GDPR hakkı)
          _ayarSatiri(
            icon: Icons.delete_forever,
            iconColor: Colors.red,
            baslik: _languageService['delete_my_data'] ?? 'Verilerimi Sil',
            altBaslik: _languageService['delete_my_data_desc'] ?? 'Tüm yerel verilerinizi silin',
            onTap: () => _verileriSilDialog(),
            renkler: renkler,
          ),
          ],
        ),
      ),
    );
  }

  void _dilSecimDialog() {
    final renkler = _temaService.renkler;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: renkler.kartArkaPlan,
          title: Row(
            children: [
              const Icon(Icons.language, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                _languageService['select_language'] ?? '',
                style: TextStyle(color: renkler.yaziPrimary, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _languageService.supportedLanguages.map((lang) {
              final isSelected =
                  lang['code'] == _languageService.currentLanguage;
              return ListTile(
                leading: Text(
                  lang['flag']!,
                  style: const TextStyle(fontSize: 32),
                ),
                title: Text(
                  lang['name']!,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: renkler.vurgu)
                    : null,
                tileColor: isSelected ? renkler.vurgu.withOpacity(0.1) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () async {
                  await _languageService.changeLanguage(lang['code']!);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${lang['flag']} ${lang['name']} ${_languageService['selected'] ?? ''}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _languageService['close'] ?? '',
                style: TextStyle(color: renkler.vurgu),
              ),
            ),
          ],
        );
      },
    );
  }

  void _verileriSilDialog() {
    final renkler = _temaService.renkler;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: renkler.kartArkaPlan,
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
          title: Text(
            _languageService['delete_data_title'] ?? 'Verilerimi Sil',
            style: TextStyle(color: renkler.yaziPrimary),
          ),
          content: Text(
            _languageService['delete_data_message'] ??
                'Bu işlem cihazdaki tüm uygulama verilerinizi (konum, tercihler, bildirim ayarları vb.) kalıcı olarak silecektir. Uygulama ilk kurulum haline dönecektir.\n\nDevam etmek istiyor musunuz?',
            style: TextStyle(color: renkler.yaziSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _languageService['cancel'] ?? 'İptal',
                style: TextStyle(color: renkler.yaziSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _tumVerileriSil();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                _languageService['delete_data_confirm'] ?? 'Evet, Tüm Verilerimi Sil',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tumVerileriSil() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _languageService['delete_data_success'] ?? 'Tüm verileriniz başarıyla silindi',
        ),
        backgroundColor: Colors.green,
      ),
    );

    // Uygulamayı splash screen'e yönlendir (ilk kurulum akışı)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (route) => false,
    );
  }

  Widget _ayarSatiri({
    required IconData icon,
    required Color iconColor,
    required String baslik,
    required String altBaslik,
    required VoidCallback? onTap,
    required TemaRenkleri renkler,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(baslik, style: TextStyle(color: renkler.yaziPrimary)),
      subtitle: Text(
        altBaslik,
        style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
      ),
      trailing:
          trailing ?? Icon(Icons.chevron_right, color: renkler.yaziSecondary),
      onTap: onTap,
    );
  }
}
