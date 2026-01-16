import 'package:flutter/material.dart';
import '../widgets/pasta_sayac_widget.dart';
import '../widgets/vakit_listesi_widget.dart';
import '../widgets/gunun_icerigi_widget.dart';
import '../widgets/yarim_daire_sayac_widget.dart';
import 'imsakiye_sayfa.dart';
import 'ayarlar_sayfa.dart';

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741), // Görseldeki koyu mavi ton
      appBar: AppBar(
        title: const Text("İSTANBUL", style: TextStyle(letterSpacing: 3)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- SAYAÇ SLIDER BÖLÜMÜ ---
            // Bu alan sağa kaydırılabilir sayaçları barındırır.
            SizedBox(
              height: 240, // Yarım daire için ayarlandı
              child: PageView(
                controller: PageController(
                  viewportFraction: 0.95,
                ), // Yan sayfaları hafif hissettirir
                children: [
                  const PastaSayacWidget(), // Senin yarım dairesel tasarımın
                  const YarimDaireSayacWidget(), // Yarım daire geri sayım
                  _ucuncuSayac(), // Sağa kaydırınca gelecek 3. sayaç
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --- VAKİT LİSTESİ ---
            const VakitListesiWidget(),

            const SizedBox(height: 20),

            // --- GÜNÜN İÇERİĞİ (AYET/HADİS/DUA) ---
            const GununIcerigiWidget(),

            const SizedBox(height: 50),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showMenu(context);
        },
        backgroundColor: const Color(0xFF2B3151),
        child: const Icon(Icons.menu, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B2741),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.white),
                title: const Text('İmsakiye', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ImsakiyeSayfa()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.white),
                title: const Text('Zikir Matik', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Zikir Matik sayfasına git
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text('Ayarlar', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AyarlarSayfa()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Örnek ek sayaçlar (İleride bunları 'diger_sayaclar.dart' içine taşıyabiliriz)
  Widget _ucuncuSayac() {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: const Center(
        child: Text(
          "İftara Kalan Süre (Yakında)",
          style: TextStyle(color: Colors.cyanAccent),
        ),
      ),
    );
  }
}
