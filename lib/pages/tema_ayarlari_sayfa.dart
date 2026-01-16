import 'package:flutter/material.dart';
import '../services/tema_service.dart';

class TemaAyarlariSayfa extends StatefulWidget {
  const TemaAyarlariSayfa({super.key});

  @override
  State<TemaAyarlariSayfa> createState() => _TemaAyarlariSayfaState();
}

class _TemaAyarlariSayfaState extends State<TemaAyarlariSayfa>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  late TabController _tabController;

  // Özel tema için seçilen renkler
  Color _ozelArkaPlan = const Color(0xFF1B2741);
  Color _ozelKartArkaPlan = const Color(0xFF2B3151);
  Color _ozelVurgu = const Color(0xFF00BCD4);
  Color _ozelVurguSecondary = const Color(0xFF26C6DA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _temaService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        title: Text('Tema Ayarları', style: TextStyle(color: renkler.yaziPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: renkler.vurgu,
          labelColor: renkler.vurgu,
          unselectedLabelColor: renkler.yaziSecondary,
          tabs: const [
            Tab(text: 'Hazır Temalar', icon: Icon(Icons.palette)),
            Tab(text: 'Özel Tema', icon: Icon(Icons.color_lens)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHazirTemalar(renkler),
          _buildOzelTema(renkler),
        ],
      ),
    );
  }

  Widget _buildHazirTemalar(TemaRenkleri renkler) {
    return Column(
      children: [
        // Önizleme
        _buildOnizleme(renkler),
        // Tema listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: AppTema.values.length - 1, // Özel tema hariç
            itemBuilder: (context, index) {
              final tema = AppTema.values[index];
              final temaRenkleri = TemaService.temalar[tema]!;
              final secili = _temaService.mevcutTema == tema;

              return _buildTemaKarti(tema, temaRenkleri, secili);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOnizleme(TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renkler.vurgu.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(renkler.ikon, color: renkler.vurgu, size: 28),
              const SizedBox(width: 12),
              Text(
                renkler.isim,
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            renkler.aciklama,
            style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          // Örnek vakit satırı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: renkler.vurgu.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.wb_sunny, color: renkler.vurgu, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Güneş',
                      style: TextStyle(
                          color: renkler.vurgu,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
                Text('07:45',
                    style: TextStyle(
                        color: renkler.vurgu,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemaKarti(AppTema tema, TemaRenkleri temaRenkleri, bool secili) {
    return GestureDetector(
      onTap: () => _temaService.temayiDegistir(tema),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: temaRenkleri.arkaPlanGradient,
          color: temaRenkleri.arkaPlanGradient == null
              ? temaRenkleri.arkaPlan
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: secili ? temaRenkleri.vurgu : temaRenkleri.ayirac,
            width: secili ? 2 : 1,
          ),
          boxShadow: secili
              ? [
                  BoxShadow(
                    color: temaRenkleri.vurgu.withOpacity(0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: temaRenkleri.kartArkaPlan,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(temaRenkleri.ikon, color: temaRenkleri.vurgu, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    temaRenkleri.isim,
                    style: TextStyle(
                      color: temaRenkleri.yaziPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    temaRenkleri.aciklama,
                    style: TextStyle(color: temaRenkleri.yaziSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Renk örnekleri
            Row(
              children: [
                _renkDairesi(temaRenkleri.vurgu, 14),
                const SizedBox(width: 3),
                _renkDairesi(temaRenkleri.vurguSecondary, 14),
              ],
            ),
            const SizedBox(width: 10),
            if (secili)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: temaRenkleri.vurgu,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: temaRenkleri.arkaPlan, size: 16),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: temaRenkleri.ayirac, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOzelTema(TemaRenkleri renkler) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Özel tema önizleme
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _ozelKartArkaPlan,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _ozelVurgu.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Text(
                  'Özel Tema Önizleme',
                  style: TextStyle(color: _ozelVurgu, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _ozelVurgu.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: _ozelVurgu),
                      const SizedBox(width: 12),
                      Text('Örnek Vakit',
                          style: TextStyle(color: _ozelVurgu, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('12:00', style: TextStyle(color: _ozelVurguSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Hazır paletler
          Text(
            'Hazır Paletler',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: TemaService.hazirPaletler.length,
              itemBuilder: (context, index) {
                final palet = TemaService.hazirPaletler[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _ozelArkaPlan = palet['arkaPlan'] as Color;
                      _ozelKartArkaPlan = Color.lerp(_ozelArkaPlan, Colors.white, 0.08)!;
                      _ozelVurgu = palet['vurgu'] as Color;
                      _ozelVurguSecondary = Color.lerp(_ozelVurgu, Colors.white, 0.3)!;
                    });
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: palet['arkaPlan'] as Color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palet['vurgu'] as Color, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.palette, color: palet['vurgu'] as Color),
                        const SizedBox(height: 4),
                        Text(
                          palet['isim'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Renk seçiciler
          Text(
            'Renkleri Özelleştir',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildRenkSecici('Arka Plan', _ozelArkaPlan, (color) {
            setState(() {
              _ozelArkaPlan = color;
              _ozelKartArkaPlan = Color.lerp(color, Colors.white, 0.08)!;
            });
          }),
          _buildRenkSecici('Vurgu Rengi', _ozelVurgu, (color) {
            setState(() {
              _ozelVurgu = color;
              _ozelVurguSecondary = Color.lerp(color, Colors.white, 0.3)!;
            });
          }),

          const SizedBox(height: 24),

          // Renk paleti
          Text(
            'Renk Paleti',
            style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildRenkPaleti(),

          const SizedBox(height: 24),

          // Kaydet butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _temaService.ozelTemayiKaydet(
                  arkaPlan: _ozelArkaPlan,
                  kartArkaPlan: _ozelKartArkaPlan,
                  vurgu: _ozelVurgu,
                  vurguSecondary: _ozelVurguSecondary,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Özel tema kaydedildi!'),
                      backgroundColor: _ozelVurgu,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Özel Temayı Kaydet ve Uygula'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ozelVurgu,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenkSecici(String label, Color mevcutRenk, Function(Color) onChanged) {
    final renkler = _temaService.renkler;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: renkler.yaziPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showColorPicker(mevcutRenk, onChanged),
            child: Container(
              width: 50,
              height: 35,
              decoration: BoxDecoration(
                color: mevcutRenk,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenkPaleti() {
    final renkler = [
      // Kırmızılar
      const Color(0xFFE53935), const Color(0xFFD32F2F), const Color(0xFFC62828),
      // Pembeler
      const Color(0xFFEC407A), const Color(0xFFD81B60), const Color(0xFFC2185B),
      // Morlar
      const Color(0xFFAB47BC), const Color(0xFF8E24AA), const Color(0xFF7B1FA2),
      // Maviler
      const Color(0xFF42A5F5), const Color(0xFF1E88E5), const Color(0xFF1565C0),
      // Cyan
      const Color(0xFF26C6DA), const Color(0xFF00ACC1), const Color(0xFF00838F),
      // Yeşiller
      const Color(0xFF66BB6A), const Color(0xFF43A047), const Color(0xFF2E7D32),
      // Sarılar
      const Color(0xFFFFCA28), const Color(0xFFFFB300), const Color(0xFFFFA000),
      // Turuncular
      const Color(0xFFFF7043), const Color(0xFFF4511E), const Color(0xFFE64A19),
      // Kahverengiler
      const Color(0xFF8D6E63), const Color(0xFF6D4C41), const Color(0xFF4E342E),
      // Griler
      const Color(0xFF78909C), const Color(0xFF546E7A), const Color(0xFF37474F),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: renkler.map((color) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _ozelVurgu = color;
              _ozelVurguSecondary = Color.lerp(color, Colors.white, 0.3)!;
            });
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _ozelVurgu == color ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showColorPicker(Color currentColor, Function(Color) onColorSelected) {
    final List<Color> arkaPlanRenkleri = [
      const Color(0xFF1B2741), const Color(0xFF1A1A1A), const Color(0xFF0D0D1A),
      const Color(0xFF2D1B4E), const Color(0xFF1B3D2F), const Color(0xFF3E2723),
      const Color(0xFF4A1C1C), const Color(0xFF0D2137), const Color(0xFF2E2240),
      const Color(0xFF2D2133), const Color(0xFF121212), const Color(0xFF1565C0),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _temaService.renkler.kartArkaPlan,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Renk Seçin',
                style: TextStyle(
                  color: _temaService.renkler.yaziPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: arkaPlanRenkleri.map((color) {
                  return GestureDetector(
                    onTap: () {
                      onColorSelected(color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentColor == color
                              ? _temaService.renkler.vurgu
                              : Colors.white24,
                          width: currentColor == color ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _renkDairesi(Color renk, double boyut) {
    return Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        color: renk,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }
}
