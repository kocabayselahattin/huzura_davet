import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bildirim_ayarlari_sayfa.dart';
import 'il_ilce_sec_sayfa.dart';
import 'tema_ayarlari_sayfa.dart';
import 'hakkinda_sayfa.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import 'widget_ayarlari_sayfa.dart';

class AyarlarSayfa extends StatefulWidget {
  const AyarlarSayfa({super.key});

  @override
  State<AyarlarSayfa> createState() => _AyarlarSayfaState();
}

class _AyarlarSayfaState extends State<AyarlarSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  static const platform = MethodChannel('huzur_vakti/permissions');

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
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text('Ayarlar', style: TextStyle(color: renkler.yaziPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Bildirimler
          _ayarSatiri(
            icon: Icons.notifications,
            iconColor: renkler.vurgu,
            baslik: 'Bildirimler',
            altBaslik: 'Vakit bildirimlerini ayarla',
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

          // Konum Ayarları
          _ayarSatiri(
            icon: Icons.location_on,
            iconColor: renkler.vurgu,
            baslik: 'Konum',
            altBaslik: 'İl ve ilçe seçimi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IlIlceSecSayfa(),
                ),
              );
            },
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // Dil Seçimi
          _ayarSatiri(
            icon: Icons.language,
            iconColor: Colors.blue,
            baslik: 'Dil / Language',
            altBaslik: _languageService.supportedLanguages
                .firstWhere((lang) => lang['code'] == _languageService.currentLanguage)['name']!,
            onTap: () => _dilSecimDialog(),
            renkler: renkler,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _languageService.supportedLanguages
                      .firstWhere((lang) => lang['code'] == _languageService.currentLanguage)['flag']!,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: renkler.yaziSecondary),
              ],
            ),
          ),
          Divider(color: renkler.ayirac),

          // Tema
          _ayarSatiri(
            icon: Icons.palette,
            iconColor: renkler.vurgu,
            baslik: 'Tema',
            altBaslik: '${renkler.isim} - ${renkler.aciklama}',
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

          // Widget Ayarları
          _ayarSatiri(
            icon: Icons.widgets,
            iconColor: renkler.vurgu,
            baslik: 'Widget Ayarları',
            altBaslik: 'Ana ekran widget renkleri',
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

          // Pil Optimizasyonu
          _ayarSatiri(
            icon: Icons.battery_saver,
            iconColor: Colors.green,
            baslik: 'Pil Optimizasyonu',
            altBaslik: 'Arka plan işlemleri için izin ver',
            onTap: () => _pilOptimizasyonuAc(),
            renkler: renkler,
          ),
          Divider(color: renkler.ayirac),

          // Hakkında
          _ayarSatiri(
            icon: Icons.info,
            iconColor: renkler.vurgu,
            baslik: 'Hakkında',
            altBaslik: 'Uygulama bilgileri',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HakkindaSayfa(),
                ),
              );
            },
            renkler: renkler,
          ),
        ],
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
                'Dil Seçin / Select Language',
                style: TextStyle(color: renkler.yaziPrimary, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _languageService.supportedLanguages.map((lang) {
              final isSelected = lang['code'] == _languageService.currentLanguage;
              return ListTile(
                leading: Text(
                  lang['flag']!,
                  style: const TextStyle(fontSize: 32),
                ),
                title: Text(
                  lang['name']!,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${lang['flag']} ${lang['name']} seçildi'),
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
              child: Text('Kapat', style: TextStyle(color: renkler.vurgu)),
            ),
          ],
        );
      },
    );
  }

  Widget _ayarSatiri({
    required IconData icon,
    required Color iconColor,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
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
      trailing: trailing ?? Icon(Icons.chevron_right, color: renkler.yaziSecondary),
      onTap: onTap,
    );
  }

  Future<void> _pilOptimizasyonuAc() async {
    try {
      await platform.invokeMethod('openBatteryOptimizationSettings');
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pil ayarları açılamadı: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
