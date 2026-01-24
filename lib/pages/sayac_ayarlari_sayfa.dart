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

  // Sayaç bilgileri
  final List<Map<String, dynamic>> _sayaclar = [
    {'id': 'dijital', 'icon': Icons.access_time, 'color': Colors.cyan},
    {'id': 'premium', 'icon': Icons.star, 'color': Colors.amber},
    {'id': 'galaksi', 'icon': Icons.auto_awesome, 'color': Colors.purple},
    {'id': 'neon', 'icon': Icons.lightbulb, 'color': Colors.green},
    {'id': 'okyanus', 'icon': Icons.water, 'color': Colors.blue},
    {'id': 'minimal', 'icon': Icons.crop_square, 'color': Colors.grey},
    {'id': 'retro', 'icon': Icons.tv, 'color': const Color(0xFF00FF41)},
    {'id': 'aurora', 'icon': Icons.nights_stay, 'color': const Color(0xFF00D4AA)},
    {'id': 'kristal', 'icon': Icons.diamond_outlined, 'color': const Color(0xFF64B5F6)},
    {'id': 'volkanik', 'icon': Icons.local_fire_department, 'color': const Color(0xFFFF6B35)},
    {'id': 'zen', 'icon': Icons.spa, 'color': const Color(0xFF4A6741)},
    {'id': 'siber', 'icon': Icons.memory, 'color': const Color(0xFFFF00FF)},
    {'id': 'gece', 'icon': Icons.nightlight_round, 'color': const Color(0xFF1E3A5F)},
    {'id': 'matrix', 'icon': Icons.terminal, 'color': const Color(0xFF00FF41)},
    {'id': 'nefes', 'icon': Icons.air, 'color': const Color(0xFF6B5B95)},
    {'id': 'geometrik', 'icon': Icons.hexagon_outlined, 'color': const Color(0xFFFFD700)},
    {'id': 'tesla', 'icon': Icons.bolt, 'color': const Color(0xFF00D4FF)},
    {'id': 'islami', 'icon': Icons.mosque, 'color': const Color(0xFF1B5E20)},
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
    final index = prefs.getInt('secili_sayac_index') ?? 0;
    if (mounted) {
      setState(() {
        _seciliSayacIndex = index;
        _currentPreviewIndex = index;
      });
      // Preview'ı seçili sayaca getir
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_previewController.hasClients) {
          _previewController.jumpToPage(index);
        }
      });
    }
  }

  Future<void> _saveSeciliSayac(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secili_sayac_index', index);
    // Sayaç temasını güncelle
    await _temaService.sayacTemasiGuncelle(index);
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
      default:
        return '';
    }
  }

  // Sadece görünür sayaç widget'ını oluştur (performans için)
  Widget _buildSayacWidget(int index, bool isActive) {
    // isActive=false ise boş placeholder göster
    if (!isActive) {
      return const SizedBox.shrink();
    }
    
    switch (index) {
      case 0:
        return const DijitalSayacWidget();
      case 1:
        return const PremiumSayacWidget();
      case 2:
        return const GalaksiSayacWidget();
      case 3:
        return const NeonSayacWidget();
      case 4:
        return const OkyanusSayacWidget();
      case 5:
        return const MinimalSayacWidget();
      case 6:
        return const RetroSayacWidget();
      case 7:
        return const AuroraSayacWidget();
      case 8:
        return const KristalSayacWidget();
      case 9:
        return const VolkanikSayacWidget();
      case 10:
        return const ZenSayacWidget();
      case 11:
        return const SiberSayacWidget();
      case 12:
        return const GeceSayacWidget();
      case 13:
        return const MatrixSayacWidget();
      case 14:
        return const NefesSayacWidget();
      case 15:
        return const GeometrikSayacWidget();
      case 16:
        return const TeslaSayacWidget();
      case 17:
        return const IslamiSayacWidget();
      default:
        return const DijitalSayacWidget();
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
