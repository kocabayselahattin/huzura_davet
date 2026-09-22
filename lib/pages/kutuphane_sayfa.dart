import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import 'kuran_sayfa.dart';
import 'kuran_ses_ayarlari_sayfa.dart';
import 'dua_kutuphanesi_sayfa.dart';
import 'hadis_kutuphanesi_sayfa.dart';
import 'mezarlik_ziyareti_sayfa.dart';

/// Kütüphane: Kur'an-ı Kerim ve dua kaynaklarının toplandığı hub sayfa.
/// [ayarlar_sayfa.dart]'taki `_ayarSatiri` deseniyle aynı görünümü kullanır.
class KutuphaneSayfa extends StatelessWidget {
  const KutuphaneSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    final temaService = TemaService();
    final languageService = LanguageService();
    final renkler = temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          languageService['library_page_title'] ?? 'KÜTÜPHANE',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _kutuphaneSatiri(
                icon: Icons.auto_stories_rounded,
                iconColor: Colors.indigo,
                baslik: languageService['quran'] ?? "Kur'an-ı Kerim",
                altBaslik: languageService['library_quran_desc'] ?? '',
                renkler: renkler,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const KuranSayfa()),
                ),
              ),
              Divider(color: renkler.ayirac),
              _kutuphaneSatiri(
                icon: Icons.download_for_offline_rounded,
                iconColor: Colors.teal,
                baslik: languageService['library_audio_settings'] ?? '',
                altBaslik:
                    languageService['library_audio_settings_desc'] ?? '',
                renkler: renkler,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const KuranSesAyarlariSayfa(),
                  ),
                ),
              ),
              Divider(color: renkler.ayirac),
              _kutuphaneSatiri(
                icon: Icons.favorite_rounded,
                iconColor: Colors.pink,
                baslik: languageService['dua_library'] ?? 'Dua Kütüphanesi',
                altBaslik: languageService['dua_library_desc'] ?? '',
                renkler: renkler,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DuaKutuphanesiSayfa(),
                  ),
                ),
              ),
              Divider(color: renkler.ayirac),
              _kutuphaneSatiri(
                icon: Icons.menu_book_rounded,
                iconColor: Colors.deepPurple,
                baslik: 'Hadisler',
                altBaslik: "Riyâzü's-Sâlihîn — konu başlığına göre",
                renkler: renkler,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HadisKutuphanesiSayfa(),
                  ),
                ),
              ),
              Divider(color: renkler.ayirac),
              _kutuphaneSatiri(
                icon: Icons.local_florist_rounded,
                iconColor: Colors.brown,
                baslik: 'Mezarlık Ziyareti',
                altBaslik: 'Yâsîn, Mülk, İhlâs, Felak, Nâs...',
                renkler: renkler,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MezarlikZiyaretiSayfa(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kutuphaneSatiri({
    required IconData icon,
    required Color iconColor,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
    required TemaRenkleri renkler,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(baslik, style: TextStyle(color: renkler.yaziPrimary)),
      subtitle: Text(
        altBaslik,
        style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: renkler.yaziSecondary),
      onTap: onTap,
    );
  }
}
