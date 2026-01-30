import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../widgets/dijital_sayac_widget.dart';
import '../widgets/premium_sayac_widget.dart';
import '../widgets/galaksi_sayac_widget.dart';
import '../widgets/neon_sayac_widget.dart';
import '../widgets/okyanus_sayac_widget.dart';
import '../widgets/minimal_sayac_widget.dart';
import '../widgets/retro_sayac_widget.dart';
import '../widgets/aurora_sayac_widget.dart';
import '../widgets/kristal_sayac_widget.dart';
import '../widgets/volkanik_sayac_widget.dart';
import '../widgets/zen_sayac_widget.dart';
import '../widgets/siber_sayac_widget.dart';
import '../widgets/gece_sayac_widget.dart';
import '../widgets/matrix_sayac_widget.dart';
import '../widgets/nefes_sayac_widget.dart';
import '../widgets/geometrik_sayac_widget.dart';
import '../widgets/tesla_sayac_widget.dart';
import '../widgets/islami_sayac_widget.dart';
import '../widgets/kalem_sayac_widget.dart';
import '../widgets/nur_sayac_widget.dart';
import '../widgets/hilal_sayac_widget.dart';
import '../widgets/mihrap_sayac_widget.dart';
import '../widgets/gundonumu_sayac_widget.dart';

class SayacAyarlariSayfa extends StatefulWidget {
  const SayacAyarlariSayfa({super.key});

  @override
  State<SayacAyarlariSayfa> createState() => _SayacAyarlariSayfaState();
}

class _SayacAyarlariSayfaState extends State<SayacAyarlariSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  int _seciliSayacIndex = 0;
  int _currentPreviewIndex = 0; // Şu an önizlenen sayaç
  final PageController _previewController = PageController(
    viewportFraction: 1.0,
  );

  // Sayaç bilgileri - Gündönümü en başta (index eski sırayı korur)
  final List<Map<String, dynamic>> _sayaclar = [
    {
      'id': 'gundonumu',
      'icon': Icons.change_circle_outlined,
      'color': const Color(0xFF5E60CE),
      'index': 22,
    },
    {
      'id': 'islami',
      'icon': Icons.mosque,
      'color': const Color(0xFF1B5E20),
      'index': 0,
    },
    {
      'id': 'kalem',
      'icon': Icons.edit,
      'color': const Color(0xFF2D6A4F),
      'index': 1,
    },
    {
      'id': 'nur',
      'icon': Icons.wb_sunny,
      'color': const Color(0xFF00BCD4),
      'index': 2,
    },
    {
      'id': 'hilal',
      'icon': Icons.nights_stay,
      'color': const Color(0xFF415A77),
      'index': 3,
    },
    {
      'id': 'mihrap',
      'icon': Icons.architecture,
      'color': const Color(0xFF5D4037),
      'index': 4,
    },
    {
      'id': 'dijital',
      'icon': Icons.access_time,
      'color': Colors.cyan,
      'index': 5,
    },
    {
      'id': 'premium',
      'icon': Icons.star,
      'color': Colors.amber,
      'index': 6,
    },
    {
      'id': 'galaksi',
      'icon': Icons.auto_awesome,
      'color': Colors.purple,
      'index': 7,
    },
    {
      'id': 'neon',
      'icon': Icons.lightbulb,
      'color': Colors.green,
      'index': 8,
    },
    {
      'id': 'okyanus',
      'icon': Icons.water,
      'color': Colors.blue,
      'index': 9,
    },
    {
      'id': 'minimal',
      'icon': Icons.crop_square,
      'color': Colors.grey,
      'index': 10,
    },
    {
      'id': 'retro',
      'icon': Icons.tv,
      'color': const Color(0xFF00FF41),
      'index': 11,
    },
    {
      'id': 'aurora',
      'icon': Icons.nights_stay,
      'color': const Color(0xFF00D4AA),
      'index': 12,
    },
    {
      'id': 'kristal',
      'icon': Icons.diamond_outlined,
      'color': const Color(0xFF64B5F6),
      'index': 13,
    },
    {
      'id': 'volkanik',
      'icon': Icons.local_fire_department,
      'color': const Color(0xFFFF6B35),
      'index': 14,
    },
    {
      'id': 'zen',
      'icon': Icons.spa,
      'color': const Color(0xFF4A6741),
      'index': 15,
    },
    {
      'id': 'siber',
      'icon': Icons.memory,
      'color': const Color(0xFFFF00FF),
      'index': 16,
    },
    {
      'id': 'gece',
      'icon': Icons.nightlight_round,
      'color': const Color(0xFF1E3A5F),
      'index': 17,
    },
    {
      'id': 'matrix',
      'icon': Icons.terminal,
      'color': const Color(0xFF00FF41),
      'index': 18,
    },
    {
      'id': 'nefes',
      'icon': Icons.air,
      'color': const Color(0xFF6B5B95),
      'index': 19,
    },
    {
      'id': 'geometrik',
      'icon': Icons.hexagon_outlined,
      'color': const Color(0xFFFFD700),
      'index': 20,
    },
    {
      'id': 'tesla',
      'icon': Icons.bolt,
      'color': const Color(0xFF00D4FF),
      'index': 21,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSeciliSayac();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _previewController.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSeciliSayac() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIndex = prefs.getInt('secili_sayac_index') ?? 0;
    final displayIndex = _sayaclar.indexWhere(
      (sayac) => sayac['index'] == storedIndex,
    );
    final resolvedIndex = displayIndex == -1 ? 0 : displayIndex;
    if (mounted) {
      setState(() {
        _seciliSayacIndex = resolvedIndex;
        _currentPreviewIndex = resolvedIndex;
      });
      // Preview'ı seçili sayaca getir
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_previewController.hasClients) {
          _previewController.jumpToPage(resolvedIndex);
        }
      });
    }
  }

  Future<void> _saveSeciliSayac(int index) async {
    final actualIndex = _sayaclar[index]['index'] as int? ?? 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secili_sayac_index', actualIndex);
    // Sayaç temasını güncelle
    await _temaService.sayacTemasiGuncelle(actualIndex);
    setState(() {
      _seciliSayacIndex = index;
    });
  }

  String _getSayacName(String id) {
    switch (id) {
      case 'dijital':
        return _languageService['counter_digital'] ?? 'Dijital';
      case 'premium':
        return _languageService['counter_premium'] ?? 'Premium';
      case 'galaksi':
        return _languageService['counter_galaxy'] ?? 'Galaksi';
      case 'neon':
        return _languageService['counter_neon'] ?? 'Neon';
      case 'okyanus':
        return _languageService['counter_ocean'] ?? 'Okyanus';
      case 'minimal':
        return _languageService['counter_minimal'] ?? 'Minimal';
      case 'retro':
        return _languageService['counter_retro'] ?? 'Retro';
      case 'aurora':
        return _languageService['counter_aurora'] ?? 'Aurora';
      case 'kristal':
        return _languageService['counter_kristal'] ?? 'Kristal';
      case 'volkanik':
        return _languageService['counter_volkanik'] ?? 'Volkanik';
      case 'zen':
        return _languageService['counter_zen'] ?? 'Zen';
      case 'siber':
        return _languageService['counter_siber'] ?? 'Siber';
      case 'gece':
        return _languageService['counter_gece'] ?? 'Gece';
      case 'matrix':
        return _languageService['counter_matrix'] ?? 'Matrix';
      case 'nefes':
        return _languageService['counter_nefes'] ?? 'Nefes';
      case 'geometrik':
        return _languageService['counter_geometrik'] ?? 'Geometrik';
      case 'tesla':
        return _languageService['counter_tesla'] ?? 'Tesla';
      case 'islami':
        return _languageService['counter_islami'] ?? 'İslami';
      case 'kalem':
        return 'Kalem';
      case 'nur':
        return 'Nur';
      case 'hilal':
        return 'Hilal';
      case 'mihrap':
        return 'Mihrap';
      case 'gundonumu':
        return 'Gün Dönümü';
      default:
        return id;
    }
  }

  String _getSayacDesc(String id) {
    switch (id) {
      case 'dijital':
        return _languageService['counter_digital_desc'] ??
            'Minimalist dijital tasarım';
      case 'premium':
        return _languageService['counter_premium_desc'] ??
            'Şık ve modern tasarım';
      case 'galaksi':
        return _languageService['counter_galaxy_desc'] ??
            'Uzay temalı animasyonlu tasarım';
      case 'neon':
        return _languageService['counter_neon_desc'] ??
            'Neon ışıklı canlı tasarım';
      case 'okyanus':
        return _languageService['counter_ocean_desc'] ??
            'Dalga animasyonlu huzurlu tasarım';
      case 'minimal':
        return _languageService['counter_minimal_desc'] ??
            'Sade ve şık beyaz tasarım';
      case 'retro':
        return _languageService['counter_retro_desc'] ??
            'Nostaljik LCD ekran tarzı';
      case 'aurora':
        return _languageService['counter_aurora_desc'] ??
            'Kuzey ışıkları efektli tasarım';
      case 'kristal':
        return _languageService['counter_kristal_desc'] ??
            'Cam ve kristal efektli zarif tasarım';
      case 'volkanik':
        return _languageService['counter_volkanik_desc'] ??
            'Ateş ve lav efektli enerji dolu tasarım';
      case 'zen':
        return _languageService['counter_zen_desc'] ??
            'Japon bahçesi esintisi, huzurlu tasarım';
      case 'siber':
        return _languageService['counter_siber_desc'] ??
            'Cyberpunk tarzı fütüristik tasarım';
      case 'gece':
        return _languageService['counter_gece_desc'] ??
            'Ay ve yıldızlı gece gökyüzü tasarımı';
      case 'matrix':
        return _languageService['counter_matrix_desc'] ??
            'Matrix filmi tarzı düşen kod efektli';
      case 'nefes':
        return _languageService['counter_nefes_desc'] ??
            'Meditasyon temalı sakinleştirici tasarım';
      case 'geometrik':
        return _languageService['counter_geometrik_desc'] ??
            'Sacred Geometry mistik desenler';
      case 'tesla':
        return _languageService['counter_tesla_desc'] ??
            'Elektrik ve enerji temalı dinamik tasarım';
      case 'islami':
        return _languageService['counter_islami_desc'] ??
            'Hilal, yıldız ve İslami geometrik desenler';
      case 'kalem':
        return 'İlim ve bereket temalı, Hicri/Miladi takvimli';
      case 'nur':
        return 'Işık efektli, Hicri/Miladi takvimli';
      case 'hilal':
        return 'Yıldızlı gece, Hicri/Miladi takvimli';
      case 'mihrap':
        return 'Cami mimarisi temalı, Hicri/Miladi takvimli';
      case 'gundonumu':
        return 'Elips üzerinde 24 saat ve vakit göstergeleri';
      default:
        return '';
    }
  }

  // Sadece görünür sayaç widget'ını oluştur (performans için)
  Widget _buildSayacWidget(int index, bool isActive) {
    // isActive=false ise boş placeholder göster - veri yükleme yok
    if (!isActive) {
      return const SizedBox.shrink();
    }

    final id = _sayaclar[index]['id'] as String? ?? 'islami';

    // isActive=true ise widget'ı oluştur ve veri yükle
    switch (id) {
      case 'gundonumu':
        return const GundonumuSayacWidget();
      case 'islami':
        return const IslamiSayacWidget();
      case 'kalem':
        return const KalemSayacWidget();
      case 'nur':
        return const NurSayacWidget();
      case 'hilal':
        return const HilalSayacWidget();
      case 'mihrap':
        return const MihrapSayacWidget();
      case 'dijital':
        return const DijitalSayacWidget();
      case 'premium':
        return const PremiumSayacWidget();
      case 'galaksi':
        return const GalaksiSayacWidget();
      case 'neon':
        return const NeonSayacWidget();
      case 'okyanus':
        return const OkyanusSayacWidget();
      case 'minimal':
        return const MinimalSayacWidget();
      case 'retro':
        return const RetroSayacWidget();
      case 'aurora':
        return const AuroraSayacWidget();
      case 'kristal':
        return const KristalSayacWidget();
      case 'volkanik':
        return const VolkanikSayacWidget();
      case 'zen':
        return const ZenSayacWidget();
      case 'siber':
        return const SiberSayacWidget();
      case 'gece':
        return const GeceSayacWidget();
      case 'matrix':
        return const MatrixSayacWidget();
      case 'nefes':
        return const NefesSayacWidget();
      case 'geometrik':
        return const GeometrikSayacWidget();
      case 'tesla':
        return const TeslaSayacWidget();
      default:
        return const IslamiSayacWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _languageService['counter_settings'] ?? 'Vakit Sayaçları',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: Column(
        children: [
          // Açıklama
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _languageService['counter_settings_desc'] ??
                  'Ana ekranda gösterilecek vakit sayacını seçin. Kaydırarak diğer sayaçları önizleyebilirsiniz.',
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

          // Sayaç Önizleme - Sadece görünür sayaç aktif
          SizedBox(
            height: 240,
            child: PageView.builder(
              controller: _previewController,
              itemCount: _sayaclar.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPreviewIndex = index;
                });
              },
              itemBuilder: (context, index) {
                // Sadece mevcut sayfa aktif, diğerleri için placeholder
                final isActive = index == _currentPreviewIndex;
                return _buildSayacWidget(index, isActive);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Sayaç Seçim Listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sayaclar.length,
              itemBuilder: (context, index) {
                final sayac = _sayaclar[index];
                final isSelected = index == _seciliSayacIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? renkler.vurgu.withOpacity(0.15)
                        : renkler.kartArkaPlan,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? renkler.vurgu : renkler.ayirac,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: renkler.vurgu.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: ListTile(
                    onTap: () {
                      _saveSeciliSayac(index);
                      _previewController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (sayac['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        sayac['icon'] as IconData,
                        color: sayac['color'] as Color,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      _getSayacName(sayac['id'] as String),
                      style: TextStyle(
                        color: renkler.yaziPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      _getSayacDesc(sayac['id'] as String),
                      style: TextStyle(
                        color: renkler.yaziSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: renkler.vurgu,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          )
                        : Icon(
                            Icons.radio_button_unchecked,
                            color: renkler.yaziSecondary,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
