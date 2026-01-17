import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bildirim_ayarlari_sayfa.dart';
import 'il_ilce_sec_sayfa.dart';
import 'tema_ayarlari_sayfa.dart';
import 'widget_ayarlari_sayfa.dart';
import '../services/tema_service.dart';

class AyarlarSayfa extends StatefulWidget {
  const AyarlarSayfa({super.key});

  @override
  State<AyarlarSayfa> createState() => _AyarlarSayfaState();
}

class _AyarlarSayfaState extends State<AyarlarSayfa> {
  final TemaService _temaService = TemaService();
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
              showAboutDialog(
                context: context,
                applicationName: 'Huzur Vakti',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Tüm hakları saklıdır.',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Namaz vakitlerini takip etmenizi ve günlük ibadetlerinizi kolaylaştırmanızı sağlayan bir uygulama.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
            renkler: renkler,
          ),
        ],
      ),
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
