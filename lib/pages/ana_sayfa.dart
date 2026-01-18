import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/premium_sayac_widget.dart';
import '../widgets/vakit_listesi_widget.dart';
import '../widgets/gunun_icerigi_widget.dart';
import '../widgets/galaksi_sayac_widget.dart';
import '../widgets/neon_sayac_widget.dart';
import '../widgets/okyanus_sayac_widget.dart';
import '../widgets/dijital_sayac_widget.dart';
import '../widgets/esmaul_husna_widget.dart';
import '../widgets/ozel_gun_popup.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import 'imsakiye_sayfa.dart';
import 'ayarlar_sayfa.dart';
import 'zikir_matik_sayfa.dart';
import 'kirk_hadis_sayfa.dart';
import 'kuran_sayfa.dart';
import 'ibadet_sayfa.dart';
import 'ozel_gunler_sayfa.dart';
import 'kible_sayfa.dart';
import 'yakin_camiler_sayfa.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  String konumBasligi = "KONUM SEÇİLMEDİ";
  final TemaService _temaService = TemaService();
  PageController? _sayacController;
  int _currentSayacIndex = 0;
  bool _sayacYuklendi = false;

  @override
  void initState() {
    super.initState();
    _loadSayacIndex();
    _konumYukle();
    _temaService.addListener(_onTemaChanged);
    // Özel gün popup kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOzelGun();
    });
  }

  Future<void> _checkOzelGun() async {
    if (mounted) {
      await checkAndShowOzelGunPopup(context);
    }
  }

  Future<void> _loadSayacIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('secili_sayac_index') ?? 0;
    if (mounted) {
      setState(() {
        _currentSayacIndex = index;
        _sayacController = PageController(viewportFraction: 0.95, initialPage: index);
        _sayacYuklendi = true;
      });
    }
  }

  Future<void> _saveSayacIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secili_sayac_index', index);
  }

  @override
  void dispose() {
    _sayacController?.dispose();
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _konumYukle() async {
    final il = await KonumService.getIl();
    final ilce = await KonumService.getIlce();

    if (il != null && ilce != null) {
      setState(() {
        konumBasligi = "$il / $ilce";
      });
    } else if (il != null) {
      setState(() {
        konumBasligi = il;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          konumBasligi.toUpperCase(),
          style: TextStyle(
            letterSpacing: 2, 
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Konum değiştir ikonu
          IconButton(
            icon: Icon(
              Icons.location_on,
              color: renkler.vurgu,
              size: 28,
            ),
            tooltip: 'Konum Değiştir',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AyarlarSayfa(),
                ),
              );
              if (result == true || result == null) {
                _konumYukle();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- KONUM UYARISI (Eğer konum seçilmemişse) ---
              if (konumBasligi == "KONUM SEÇİLMEDİ")
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Konum Seçilmedi',
                              style: TextStyle(
                                color: renkler.yaziPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Namaz vakitlerini görmek için ayarlardan il/ilçe seçin',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Colors.orange),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AyarlarSayfa(),
                            ),
                          ).then((_) => _konumYukle());
                        },
                      ),
                    ],
                  ),
                ),
              
              // --- SAYAÇ SLIDER BÖLÜMÜ ---
              SizedBox(
                height: 260,
                child: _sayacYuklendi && _sayacController != null
                    ? Column(
                        children: [
                          Expanded(
                            child: PageView(
                              controller: _sayacController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentSayacIndex = index;
                                });
                                _saveSayacIndex(index);
                              },
                              children: const [
                                DijitalSayacWidget(),
                                PremiumSayacWidget(),
                                GalaksiSayacWidget(),
                                NeonSayacWidget(),
                                OkyanusSayacWidget(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Sayaç page indicator
                          _buildPageIndicator(renkler),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),

              const SizedBox(height: 10),

              // --- ESMAUL HUSNA ---
              const EsmaulHusnaWidget(),

              const SizedBox(height: 10),

              // --- VAKİT LİSTESİ ---
              const VakitListesiWidget(),

              const SizedBox(height: 20),

              // --- GÜNÜN İÇERİĞİ ---
              const GununIcerigiWidget(),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showMenu(context);
        },
        backgroundColor: renkler.kartArkaPlan,
        child: Icon(Icons.menu, color: renkler.yaziPrimary),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildPageIndicator(TemaRenkleri renkler) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Sol ok
        GestureDetector(
          onTap: () {
            if (_currentSayacIndex > 0) {
              _sayacController?.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Icon(
            Icons.chevron_left,
            color: _currentSayacIndex > 0 
                ? renkler.vurgu 
                : renkler.yaziSecondary.withValues(alpha: 0.3),
            size: 24,
          ),
        ),
        const SizedBox(width: 8),
        // Dot indicators
        ...List.generate(5, (index) {
          final isActive = index == _currentSayacIndex;
          return GestureDetector(
            onTap: () {
              _sayacController?.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive 
                    ? renkler.vurgu 
                    : renkler.yaziSecondary.withValues(alpha: 0.3),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: renkler.vurgu.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        // Sağ ok
        GestureDetector(
          onTap: () {
            if (_currentSayacIndex < 4) {
              _sayacController?.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Icon(
            Icons.chevron_right,
            color: _currentSayacIndex < 4 
                ? renkler.vurgu 
                : renkler.yaziSecondary.withValues(alpha: 0.3),
            size: 24,
          ),
        ),
      ],
    );
  }

  void _showMenu(BuildContext context) {
    final renkler = _temaService.renkler;

    showModalBottomSheet(
      context: context,
      backgroundColor: renkler.arkaPlan,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ListTile(
                leading: Icon(Icons.schedule, color: renkler.vurgu),
                title: Text(
                  'İmsakiye',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImsakiyeSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome, color: renkler.vurgu),
                title: Text(
                  'Zikir Matik',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ZikirMatikSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.mosque, color: renkler.vurgu),
                title: Text(
                  'İbadet',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IbadetSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.explore, color: renkler.vurgu),
                title: Text(
                  'Kıble Yönü',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KibleSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.place, color: renkler.vurgu),
                title: Text(
                  'Yakındaki Camiler',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const YakinCamilerSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.celebration, color: renkler.vurgu),
                title: Text(
                  'Özel Gün ve Geceler',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OzelGunlerSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.menu_book, color: renkler.vurgu),
                title: Text(
                  '40 Hadis',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KirkHadisSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_stories, color: renkler.vurgu),
                title: Text(
                  'Kur\'an-ı Kerim',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KuranSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.settings, color: renkler.vurgu),
                title: Text(
                  'Ayarlar',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AyarlarSayfa(),
                    ),
                  );
                  _konumYukle();
                },
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}
