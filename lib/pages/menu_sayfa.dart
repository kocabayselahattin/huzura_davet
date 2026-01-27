import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import 'imsakiye_sayfa.dart';
import 'zikir_matik_sayfa.dart';
import 'ibadet_sayfa.dart';
import 'kible_sayfa.dart';
import 'yakin_camiler_sayfa.dart';
import 'ozel_gunler_sayfa.dart';
import 'kirk_hadis_sayfa.dart';
import 'kuran_sayfa.dart';
import 'ayarlar_sayfa.dart';
import 'hakkinda_sayfa.dart';

class MenuSayfa extends StatefulWidget {
  const MenuSayfa({super.key});

  @override
  State<MenuSayfa> createState() => _MenuSayfaState();
}

class _MenuSayfaState extends State<MenuSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: renkler.vurgu,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'MENÜ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      renkler.vurgu,
                      renkler.vurgu.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Dekoratif desen
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPatternPainter(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // İkon
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Icon(
                          Icons.apps,
                          size: 60,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Menü içeriği
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildListDelegate([
                _buildMenuCard(
                  icon: Icons.schedule,
                  title: _languageService['calendar'] ?? 'İmsakiye',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ImsakiyeSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.auto_awesome,
                  title: _languageService['dhikr'] ?? 'Zikir Matik',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ZikirMatikSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.mosque,
                  title: _languageService['worship'] ?? 'İbadet',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const IbadetSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.explore,
                  title: _languageService['qibla'] ?? 'Kıble Yönü',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KibleSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.place,
                  title: _languageService['nearby_mosques'] ?? 'Yakın Camiler',
                  color: Colors.red,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const YakinCamilerSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.celebration,
                  title: _languageService['special_days'] ?? 'Özel Günler',
                  color: Colors.pink,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OzelGunlerSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.menu_book,
                  title: _languageService['hadith'] ?? '40 Hadis',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KirkHadisSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.auto_stories,
                  title: _languageService['quran'] ?? 'Kur\'an-ı Kerim',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KuranSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.settings,
                  title: _languageService['settings'] ?? 'Ayarlar',
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AyarlarSayfa()),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.info,
                  title: _languageService['about'] ?? 'Hakkında',
                  color: Colors.amber,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HakkindaSayfa()),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Grid pattern painter
class _GridPatternPainter extends CustomPainter {
  final Color color;

  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Çizgi deseni
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
