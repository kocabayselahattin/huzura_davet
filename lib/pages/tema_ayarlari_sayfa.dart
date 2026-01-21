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
  Color _ozelYaziPrimary = Colors.white;
  Color _ozelYaziSecondary = const Color(0xFFB0BEC5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final mevcut = _temaService.renkler;
    _ozelArkaPlan = mevcut.arkaPlan;
    _ozelKartArkaPlan = mevcut.kartArkaPlan;
    _ozelVurgu = mevcut.vurgu;
    _ozelVurguSecondary = mevcut.vurguSecondary;
    _ozelYaziPrimary = mevcut.yaziPrimary;
    _ozelYaziSecondary = mevcut.yaziSecondary;
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
        title: Text(
          'Tema Ayarları',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
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
        children: [_buildHazirTemalar(renkler), _buildOzelTema(renkler)],
      ),
    );
  }

  Widget _buildHazirTemalar(TemaRenkleri renkler) {
    return Column(
      children: [
        _buildFontSecimi(renkler),
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
                  child: Text(
                    'Güneş',
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '07:45',
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                  ),
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
              child: Icon(
                temaRenkleri.ikon,
                color: temaRenkleri.vurgu,
                size: 24,
              ),
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
                    style: TextStyle(
                      color: temaRenkleri.yaziSecondary,
                      fontSize: 11,
                    ),
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
                child: Icon(
                  Icons.check,
                  color: temaRenkleri.arkaPlan,
                  size: 16,
                ),
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
          _buildFontSecimi(renkler),
          const SizedBox(height: 16),
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
                  style: TextStyle(
                    color: _ozelVurgu,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                      Text(
                        'Örnek Vakit',
                        style: TextStyle(
                          color: _ozelYaziPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '12:00',
                        style: TextStyle(color: _ozelYaziSecondary),
                      ),
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
            height: 180,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: TemaService.hazirPaletler.length,
              itemBuilder: (context, index) {
                final palet = TemaService.hazirPaletler[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _ozelArkaPlan = palet['arkaPlan'] as Color;
                      _ozelKartArkaPlan = Color.lerp(
                        _ozelArkaPlan,
                        Colors.white,
                        0.08,
                      )!;
                      _ozelVurgu = palet['vurgu'] as Color;
                      _ozelVurguSecondary = Color.lerp(
                        _ozelVurgu,
                        Colors.white,
                        0.3,
                      )!;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: palet['arkaPlan'] as Color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _ozelArkaPlan == palet['arkaPlan']
                            ? (palet['vurgu'] as Color)
                            : (palet['vurgu'] as Color).withOpacity(0.5),
                        width: _ozelArkaPlan == palet['arkaPlan'] ? 3 : 2,
                      ),
                      boxShadow: _ozelArkaPlan == palet['arkaPlan']
                          ? [
                              BoxShadow(
                                color: (palet['vurgu'] as Color).withOpacity(
                                  0.4,
                                ),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: palet['vurgu'] as Color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (palet['vurgu'] as Color).withOpacity(
                                  0.5,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            palet['isim'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
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
          _buildRenkSecici('Yazı Rengi', _ozelYaziPrimary, (color) {
            setState(() {
              _ozelYaziPrimary = color;
            });
          }),
          _buildRenkSecici('Yazı İkincil', _ozelYaziSecondary, (color) {
            setState(() {
              _ozelYaziSecondary = color;
            });
          }),

          const SizedBox(height: 20),

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
                  yaziPrimary: _ozelYaziPrimary,
                  yaziSecondary: _ozelYaziSecondary,
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
          // Alt boşluk (telefon tuşlarına denk gelmemesi için)
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRenkSecici(
    String label,
    Color mevcutRenk,
    Function(Color) onChanged,
  ) {
    final renkler = _temaService.renkler;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showColorPicker(mevcutRenk, onChanged),
            child: Container(
              width: 45,
              height: 32,
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

  Widget _buildFontSecimi(TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('Yazı Tipi', style: TextStyle(color: renkler.yaziPrimary)),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _temaService.fontFamily,
              dropdownColor: renkler.kartArkaPlan,
              style: TextStyle(color: renkler.yaziPrimary),
              items: TemaService.fontFamilies
                  .map(
                    (font) => DropdownMenuItem(value: font, child: Text(font)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _temaService.fontuDegistir(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenkPaleti() {
    final renkler = [
      // Kırmızılar & Bordolar
      const Color(0xFFFF1744), const Color(0xFFE53935), const Color(0xFFD32F2F),
      const Color(0xFFC62828), const Color(0xFFB71C1C), const Color(0xFF8B0000),
      // Pembeler & Rose
      const Color(0xFFFF4081), const Color(0xFFEC407A), const Color(0xFFD81B60),
      const Color(0xFFC2185B), const Color(0xFFB76E79), const Color(0xFFE91E63),
      // Morlar & Lavantalar
      const Color(0xFFAA00FF), const Color(0xFFAB47BC), const Color(0xFF8E24AA),
      const Color(0xFF7B1FA2), const Color(0xFF6A1B9A), const Color(0xFF4A148C),
      // Indigo & Derin Mor
      const Color(0xFF7C4DFF), const Color(0xFF651FFF), const Color(0xFF536DFE),
      const Color(0xFF3D5AFE), const Color(0xFF304FFE), const Color(0xFF1A237E),
      // Maviler
      const Color(0xFF448AFF), const Color(0xFF42A5F5), const Color(0xFF1E88E5),
      const Color(0xFF1565C0), const Color(0xFF0D47A1), const Color(0xFF0288D1),
      // Cyan & Turkuaz
      const Color(0xFF00FFFF), const Color(0xFF00E5FF), const Color(0xFF26C6DA),
      const Color(0xFF00ACC1), const Color(0xFF00838F), const Color(0xFF006064),
      // Teal & Deniz Yeşili
      const Color(0xFF64FFDA), const Color(0xFF1DE9B6), const Color(0xFF00BFA5),
      const Color(0xFF009688), const Color(0xFF00796B), const Color(0xFF004D40),
      // Yeşiller
      const Color(0xFF00FF41), const Color(0xFF00E676), const Color(0xFF66BB6A),
      const Color(0xFF43A047), const Color(0xFF2E7D32), const Color(0xFF1B5E20),
      // Lime & Fıstık Yeşili
      const Color(0xFFC6FF00), const Color(0xFFAEEA00), const Color(0xFF9E9D24),
      const Color(0xFF8BC34A), const Color(0xFF689F38), const Color(0xFF558B2F),
      // Sarılar & Altın
      const Color(0xFFFFFF00), const Color(0xFFFFD700), const Color(0xFFFFCA28),
      const Color(0xFFFFB300), const Color(0xFFFFA000), const Color(0xFFFF8F00),
      // Turuncular
      const Color(0xFFFFAB40), const Color(0xFFFF9100), const Color(0xFFFF7043),
      const Color(0xFFF4511E), const Color(0xFFE64A19), const Color(0xFFBF360C),
      // Kahverengiler & Bronz
      const Color(0xFFCD7F32), const Color(0xFFA1887F), const Color(0xFF8D6E63),
      const Color(0xFF6D4C41), const Color(0xFF4E342E), const Color(0xFF3E2723),
      // Griler & Metalik
      const Color(0xFFE5E4E2), const Color(0xFFB0BEC5), const Color(0xFF78909C),
      const Color(0xFF546E7A), const Color(0xFF455A64), const Color(0xFF37474F),
      // Neon Özel
      const Color(0xFFFF00FF), const Color(0xFF9D00FF), const Color(0xFFFF6B6B),
      const Color(0xFF00FFFF), const Color(0xFFB388FF), const Color(0xFFEA80FC),
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
    // Tüm renkler - arka plan ve vurgu renkleri birleştirilmiş
    final List<Color> tumRenkler = [
      // Siyahlar & Karanlık
      const Color(0xFF000000), const Color(0xFF0D0D0D), const Color(0xFF121212),
      const Color(0xFF1A1A1A), const Color(0xFF1C1C1E), const Color(0xFF212121),
      // Mavi Tonları
      const Color(0xFF0A192F), const Color(0xFF0A1628), const Color(0xFF1B2741),
      const Color(0xFF0D2137), const Color(0xFF141B21), const Color(0xFF1565C0),
      // Mor & Mor-Mavi
      const Color(0xFF0B0B1A), const Color(0xFF14081F), const Color(0xFF150A1F),
      const Color(0xFF1E1A26), const Color(0xFF2D1B4E), const Color(0xFF2E1F47),
      // Yeşil Tonları
      const Color(0xFF081A12), const Color(0xFF0D1F0D), const Color(0xFF0A140A),
      const Color(0xFF142021), const Color(0xFF1B3D2F), const Color(0xFF2E3D1B),
      // Kırmızı & Bordo
      const Color(0xFF1A0A0F), const Color(0xFF1A080A), const Color(0xFF3E1A1A),
      const Color(0xFF4A1C1C), const Color(0xFF3D2429), const Color(0xFF2D1B2D),
      // Kahverengi & Toprak
      const Color(0xFF1A1215), const Color(0xFF1F1710), const Color(0xFF211A17),
      const Color(0xFF2D1F14), const Color(0xFF1A1408), const Color(0xFF3E2723),
      // Parlak Renkler
      const Color(0xFFFF1744), const Color(0xFFE53935), const Color(0xFFD32F2F),
      const Color(0xFFFF4081), const Color(0xFFEC407A), const Color(0xFFE91E63),
      const Color(0xFFAA00FF), const Color(0xFF7B1FA2), const Color(0xFF6A1B9A),
      const Color(0xFF7C4DFF), const Color(0xFF651FFF), const Color(0xFF304FFE),
      const Color(0xFF448AFF), const Color(0xFF1E88E5), const Color(0xFF0288D1),
      const Color(0xFF00FFFF), const Color(0xFF00E5FF), const Color(0xFF26C6DA),
      const Color(0xFF64FFDA), const Color(0xFF1DE9B6), const Color(0xFF00BFA5),
      const Color(0xFF00FF41), const Color(0xFF00E676), const Color(0xFF43A047),
      const Color(0xFFC6FF00), const Color(0xFFAEEA00), const Color(0xFF8BC34A),
      const Color(0xFFFFFF00), const Color(0xFFFFD700), const Color(0xFFFFCA28),
      const Color(0xFFFFAB40), const Color(0xFFFF9100), const Color(0xFFFF7043),
      // Beyaz ve Gri tonları
      const Color(0xFFFFFFFF), const Color(0xFFFAFAFA), const Color(0xFFE0E0E0),
      const Color(0xFFB0BEC5), const Color(0xFF78909C), const Color(0xFF455A64),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _temaService.renkler.kartArkaPlan,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sürükleme çubuğu
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Renk Seçin',
                    style: TextStyle(
                      color: _temaService.renkler.yaziPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Seçili renk önizleme
                  Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Renk grid'i
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: tumRenkler.length,
                      itemBuilder: (context, index) {
                        final color = tumRenkler[index];
                        final isSelected = currentColor.value == color.value;
                        return GestureDetector(
                          onTap: () {
                            onColorSelected(color);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white24,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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
