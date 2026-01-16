import 'package:flutter/material.dart';
import '../widgets/pasta_sayac_widget.dart';
import '../widgets/vakit_listesi_widget.dart';
import '../widgets/gunun_icerigi_widget.dart';

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
                  _ikinciSayac(), // Sağa kaydırınca gelecek 2. sayaç
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
    );
  }

  // Örnek ek sayaçlar (İleride bunları 'diger_sayaclar.dart' içine taşıyabiliriz)
  Widget _ikinciSayac() {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: const Center(
        child: Text(
          "Dijital Geri Sayım (Yakında)",
          style: TextStyle(color: Colors.cyanAccent),
        ),
      ),
    );
  }

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
