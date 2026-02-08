import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/home_widget_service.dart';
import '../services/language_service.dart';
import '../services/widget_pin_service.dart';

/// Widget türleri ve varsayılan ayarları
class WidgetTuru {
  final String id;
  final IconData icon;
  final String varsayilanArkaPlanKey;
  final String varsayilanYaziRengiHex;
  final Color varsayilanRenk1;
  final Color varsayilanRenk2;
  final Color varsayilanYaziRengi;

  const WidgetTuru({
    required this.id,
    required this.icon,
    required this.varsayilanArkaPlanKey,
    required this.varsayilanYaziRengiHex,
    required this.varsayilanRenk1,
    required this.varsayilanRenk2,
    required this.varsayilanYaziRengi,
  });
}

class WidgetAyarlariSayfa extends StatefulWidget {
  const WidgetAyarlariSayfa({super.key});

  @override
  State<WidgetAyarlariSayfa> createState() => _WidgetAyarlariSayfaState();
}

class _WidgetAyarlariSayfaState extends State<WidgetAyarlariSayfa>
    with SingleTickerProviderStateMixin {
  final LanguageService _languageService = LanguageService();
  late TabController _tabController;

  // Her widget için ayrı ayarlar
  final Map<String, int> _secilenArkaPlanIndex = {};
  final Map<String, int> _secilenYaziRengiIndex = {};
  final Map<String, double> _seffaflik = {};
  final Map<String, bool> _seffafTema = {};

  // Değişiklik takibi için başlangıç değerleri
  final Map<String, int> _baslangicArkaPlanIndex = {};
  final Map<String, int> _baslangicYaziRengiIndex = {};
  final Map<String, double> _baslangicSeffaflik = {};
  final Map<String, bool> _baslangicSeffafTema = {};

  // Widget türleri listesi (orijinal tasarımlara göre)
  static const List<WidgetTuru> _widgetTurleri = [
    WidgetTuru(
      id: 'klasik',
      icon: Icons.wb_sunny,
      varsayilanArkaPlanKey: 'orange',
      varsayilanYaziRengiHex: 'FFFFFF',
      varsayilanRenk1: Color(0xFFFF8C42),
      varsayilanRenk2: Color(0xFFCC5522),
      varsayilanYaziRengi: Colors.white,
    ),
    WidgetTuru(
      id: 'mini',
      icon: Icons.landscape,
      varsayilanArkaPlanKey: 'sunset',
      varsayilanYaziRengiHex: '664422',
      varsayilanRenk1: Color(0xFFFFE4B5),
      varsayilanRenk2: Color(0xFFFFD0A0),
      varsayilanYaziRengi: Color(0xFF664422),
    ),
    WidgetTuru(
      id: 'glass',
      icon: Icons.blur_on,
      varsayilanArkaPlanKey: 'semi_white',
      varsayilanYaziRengiHex: '000000',
      varsayilanRenk1: Color(0x88FFFFFF),
      varsayilanRenk2: Color(0x88FFFFFF),
      varsayilanYaziRengi: Colors.black,
    ),
    WidgetTuru(
      id: 'neon',
      icon: Icons.flash_on,
      varsayilanArkaPlanKey: 'dark',
      varsayilanYaziRengiHex: '00FF88',
      varsayilanRenk1: Color(0xFF1A3A5C),
      varsayilanRenk2: Color(0xFF051525),
      varsayilanYaziRengi: Color(0xFF00FF88),
    ),
    WidgetTuru(
      id: 'cosmic',
      icon: Icons.stars,
      varsayilanArkaPlanKey: 'purple',
      varsayilanYaziRengiHex: 'FFFFFF',
      varsayilanRenk1: Color(0xFF7B1FA2),
      varsayilanRenk2: Color(0xFF4A148C),
      varsayilanYaziRengi: Colors.white,
    ),
    WidgetTuru(
      id: 'timeline',
      icon: Icons.timeline,
      varsayilanArkaPlanKey: 'dark',
      varsayilanYaziRengiHex: 'FFFFFF',
      varsayilanRenk1: Color(0xFF1A3A5C),
      varsayilanRenk2: Color(0xFF051525),
      varsayilanYaziRengi: Colors.white,
    ),
    WidgetTuru(
      id: 'zen',
      icon: Icons.spa,
      varsayilanArkaPlanKey: 'light',
      varsayilanYaziRengiHex: '212121',
      varsayilanRenk1: Color(0xFFFFF8F0),
      varsayilanRenk2: Color(0xFFFFE8D8),
      varsayilanYaziRengi: Color(0xFF212121),
    ),
    WidgetTuru(
      id: 'origami',
      icon: Icons.auto_awesome,
      varsayilanArkaPlanKey: 'light',
      varsayilanYaziRengiHex: '2D3436',
      varsayilanRenk1: Color(0xFFFFF8F0),
      varsayilanRenk2: Color(0xFFFFE8D8),
      varsayilanYaziRengi: Color(0xFF2D3436),
    ),
  ];

  List<Map<String, dynamic>> get _arkaPlanSecenekleri => [
    {
      'nameKey': 'color_orange_gradient',
      'renk1': Color(0xFFFF8C42),
      'renk2': Color(0xFFCC5522),
      'key': 'orange',
    },
    {
      'nameKey': 'color_light_cream',
      'renk1': Color(0xFFFFF8F0),
      'renk2': Color(0xFFFFE8D8),
      'key': 'light',
    },
    {
      'nameKey': 'color_dark_blue',
      'renk1': Color(0xFF1A3A5C),
      'renk2': Color(0xFF051525),
      'key': 'dark',
    },
    {
      'nameKey': 'color_sunset',
      'renk1': Color(0xFFFFE4B5),
      'renk2': Color(0xFFFFD0A0),
      'key': 'sunset',
    },
    {
      'nameKey': 'color_green',
      'renk1': Color(0xFF2E7D32),
      'renk2': Color(0xFF1B5E20),
      'key': 'green',
    },
    {
      'nameKey': 'color_purple',
      'renk1': Color(0xFF7B1FA2),
      'renk2': Color(0xFF4A148C),
      'key': 'purple',
    },
    {
      'nameKey': 'color_red',
      'renk1': Color(0xFFD32F2F),
      'renk2': Color(0xFFB71C1C),
      'key': 'red',
    },
    {
      'nameKey': 'color_blue',
      'renk1': Color(0xFF1976D2),
      'renk2': Color(0xFF0D47A1),
      'key': 'blue',
    },
    {
      'nameKey': 'color_teal',
      'renk1': Color(0xFF00ACC1),
      'renk2': Color(0xFF006064),
      'key': 'teal',
    },
    {
      'nameKey': 'color_pink',
      'renk1': Color(0xFFE91E63),
      'renk2': Color(0xFFC2185B),
      'key': 'pink',
    },
    {
      'nameKey': 'color_transparent',
      'renk1': Colors.transparent,
      'renk2': Colors.transparent,
      'key': 'transparent',
    },
    {
      'nameKey': 'color_semi_black',
      'renk1': Color(0x88000000),
      'renk2': Color(0x88000000),
      'key': 'semi_black',
    },
    {
      'nameKey': 'color_semi_white',
      'renk1': Color(0x88FFFFFF),
      'renk2': Color(0x88FFFFFF),
      'key': 'semi_white',
    },
  ];

  List<Map<String, dynamic>> get _yaziRengiSecenekleri => [
    {'nameKey': 'color_white', 'renk': Colors.white, 'hex': 'FFFFFF'},
    {'nameKey': 'color_black', 'renk': Colors.black, 'hex': '000000'},
    {'nameKey': 'color_orange', 'renk': Color(0xFFFF8C42), 'hex': 'FF8C42'},
    {'nameKey': 'color_gold', 'renk': Color(0xFFFFD700), 'hex': 'FFD700'},
    {'nameKey': 'color_light_blue', 'renk': Color(0xFFAADDFF), 'hex': 'AADDFF'},
    {'nameKey': 'color_green', 'renk': Color(0xFF4CAF50), 'hex': '4CAF50'},
    {'nameKey': 'color_red', 'renk': Color(0xFFF44336), 'hex': 'F44336'},
    {'nameKey': 'color_yellow', 'renk': Color(0xFFFFEB3B), 'hex': 'FFEB3B'},
    {'nameKey': 'color_pink', 'renk': Color(0xFFE91E63), 'hex': 'E91E63'},
    {'nameKey': 'color_purple', 'renk': Color(0xFF9C27B0), 'hex': '9C27B0'},
    {'nameKey': 'color_cyan', 'renk': Color(0xFF00BCD4), 'hex': '00BCD4'},
    {'nameKey': 'color_gray', 'renk': Color(0xFF9E9E9E), 'hex': '9E9E9E'},
    {'nameKey': 'color_brown', 'renk': Color(0xFF664422), 'hex': '664422'},
    {'nameKey': 'color_neon_green', 'renk': Color(0xFF00FF88), 'hex': '00FF88'},
    {'nameKey': 'color_dark_gray', 'renk': Color(0xFF212121), 'hex': '212121'},
    {'nameKey': 'color_graphite', 'renk': Color(0xFF2D3436), 'hex': '2D3436'},
  ];

  bool _canPinWidgets = false;

  /// Belirli bir widget'ta değişiklik var mı kontrol et
  bool _widgetDegisiklikVar(String widgetId) {
    return _secilenArkaPlanIndex[widgetId] !=
            _baslangicArkaPlanIndex[widgetId] ||
        _secilenYaziRengiIndex[widgetId] !=
            _baslangicYaziRengiIndex[widgetId] ||
        _seffaflik[widgetId] != _baslangicSeffaflik[widgetId] ||
        _seffafTema[widgetId] != _baslangicSeffafTema[widgetId];
  }

  /// Değişiklik yapılmış widget'ların ID'lerini döndür
  List<String> _degisiklikYapilanWidgetlar() {
    return _widgetTurleri
        .where((w) => _widgetDegisiklikVar(w.id))
        .map((w) => w.id)
        .toList();
  }

  /// Çıkış onay dialogu göster
  Future<bool> _cikisOnayiGoster() async {
    final degisikenWidgetlar = _degisiklikYapilanWidgetlar();
    if (degisikenWidgetlar.isEmpty) return true;

    // Aktif tab'daki widget'ı öncelikli göster
    String aktifWidgetId = _widgetTurleri[_tabController.index].id;
    String gosterilecekWidgetId = degisikenWidgetlar.contains(aktifWidgetId)
        ? aktifWidgetId
        : degisikenWidgetlar.first;
    String widgetIsmi = _getWidgetIsim(gosterilecekWidgetId);

    final sonuc = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageService['unsaved_changes'] ?? '',
        ),
        content: Text(
          '${_languageService['widget_unsaved_changes_message']?.replaceAll('{widget}', widgetIsmi) ?? ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(_languageService['discard'] ?? ''),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(_languageService['cancel'] ?? ''),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(_languageService['save'] ?? ''),
          ),
        ],
      ),
    );

    if (sonuc == 'save') {
      // Değişiklik yapılan tüm widget'ları kaydet
      for (final widgetId in degisikenWidgetlar) {
        await _widgetAyarlariniKaydet(widgetId);
      }
      return true;
    } else if (sonuc == 'discard') {
      return true;
    }
    return false; // cancel veya dialog kapatıldı
  }

  /// Widget id'sine göre yerelleştirilmiş isim döndür
  String _getWidgetIsim(String id) {
    final key = 'widget_$id';
    return _languageService[key] ?? id;
  }

  /// Widget id'sine göre yerelleştirilmiş açıklama döndür
  String _getWidgetAciklama(String id) {
    final key = 'widget_${id}_desc';
    return _languageService[key] ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _widgetTurleri.length, vsync: this);
    _ayarlariYukle();
    _checkPinSupport();
  }

  Future<void> _checkPinSupport() async {
    final canPin = await WidgetPinService.canPinWidgets();
    if (mounted) {
      setState(() {
        _canPinWidgets = canPin;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _arkaPlanKeyToIndex(String key) {
    final index = _arkaPlanSecenekleri.indexWhere((e) => e['key'] == key);
    return index >= 0 ? index : 0;
  }

  int _yaziRengiHexToIndex(String hex) {
    final index = _yaziRengiSecenekleri.indexWhere((e) => e['hex'] == hex);
    return index >= 0 ? index : 0;
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (final widget in _widgetTurleri) {
        final id = widget.id;

        // Her widget için kaydedilmiş ayarları yükle, yoksa varsayılanı kullan
        final savedArkaPlanKey = prefs.getString('widget_${id}_arkaplan_key');
        final savedYaziRengiHex = prefs.getString(
          'widget_${id}_yazi_rengi_hex',
        );

        if (savedArkaPlanKey != null) {
          _secilenArkaPlanIndex[id] = _arkaPlanKeyToIndex(savedArkaPlanKey);
        } else {
          _secilenArkaPlanIndex[id] = _arkaPlanKeyToIndex(
            widget.varsayilanArkaPlanKey,
          );
        }

        if (savedYaziRengiHex != null) {
          _secilenYaziRengiIndex[id] = _yaziRengiHexToIndex(savedYaziRengiHex);
        } else {
          _secilenYaziRengiIndex[id] = _yaziRengiHexToIndex(
            widget.varsayilanYaziRengiHex,
          );
        }

        _seffaflik[id] = (prefs.getDouble('widget_${id}_seffaflik') ?? 1.0)
            .clamp(0.3, 1.0);
        _seffafTema[id] = prefs.getBool('widget_${id}_seffaf_tema') ?? false;

        // Başlangıç değerlerini kaydet (değişiklik takibi için)
        _baslangicArkaPlanIndex[id] = _secilenArkaPlanIndex[id]!;
        _baslangicYaziRengiIndex[id] = _secilenYaziRengiIndex[id]!;
        _baslangicSeffaflik[id] = _seffaflik[id]!;
        _baslangicSeffafTema[id] = _seffafTema[id]!;
      }
    });
  }

  Future<void> _widgetAyarlariniKaydet(String widgetId) async {
    final prefs = await SharedPreferences.getInstance();

    final arkaPlanIndex = _secilenArkaPlanIndex[widgetId] ?? 0;
    final yaziRengiIndex = _secilenYaziRengiIndex[widgetId] ?? 0;
    final seffaflik = _seffaflik[widgetId] ?? 1.0;
    final seffafTema = _seffafTema[widgetId] ?? false;

    final arkaPlan = _arkaPlanSecenekleri[arkaPlanIndex];
    final yaziRengi = _yaziRengiSecenekleri[yaziRengiIndex];

    // Widget'a özel ayarları kaydet
    await prefs.setString('widget_${widgetId}_arkaplan_key', arkaPlan['key']);
    await prefs.setString(
      'widget_${widgetId}_yazi_rengi_hex',
      yaziRengi['hex'],
    );
    await prefs.setDouble('widget_${widgetId}_seffaflik', seffaflik);
    await prefs.setBool('widget_${widgetId}_seffaf_tema', seffafTema);

    // Widget verilerini güncelle
    await HomeWidgetService.updateWidgetColorsForWidget(
      widgetId: widgetId,
      arkaPlanKey: arkaPlan['key'],
      yaziRengiHex: yaziRengi['hex'],
      seffaflik: seffafTema ? 0.0 : seffaflik,
    );

    // Başlangıç değerlerini güncelle (değişiklik takibi için)
    _baslangicArkaPlanIndex[widgetId] = arkaPlanIndex;
    _baslangicYaziRengiIndex[widgetId] = yaziRengiIndex;
    _baslangicSeffaflik[widgetId] = seffaflik;
    _baslangicSeffafTema[widgetId] = seffafTema;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_getWidgetIsim(widgetId)} ${_languageService['settings_applied'] ?? ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _widgetVarsayilanaGetir(String widgetId) async {
    final widget = _widgetTurleri.firstWhere((w) => w.id == widgetId);

    setState(() {
      _secilenArkaPlanIndex[widgetId] = _arkaPlanKeyToIndex(
        widget.varsayilanArkaPlanKey,
      );
      _secilenYaziRengiIndex[widgetId] = _yaziRengiHexToIndex(
        widget.varsayilanYaziRengiHex,
      );
      _seffaflik[widgetId] = 1.0;
      _seffafTema[widgetId] = false;
    });

    await _widgetAyarlariniKaydet(widgetId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_getWidgetIsim(widget.id)} ${_languageService['reset_to_original'] ?? ''}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _tumWidgetlariVarsayilanaGetir() async {
    for (final widget in _widgetTurleri) {
      setState(() {
        _secilenArkaPlanIndex[widget.id] = _arkaPlanKeyToIndex(
          widget.varsayilanArkaPlanKey,
        );
        _secilenYaziRengiIndex[widget.id] = _yaziRengiHexToIndex(
          widget.varsayilanYaziRengiHex,
        );
        _seffaflik[widget.id] = 1.0;
        _seffafTema[widget.id] = false;
      });
      await _widgetAyarlariniKaydet(widget.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService['all_widgets_reset'] ?? '',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Widget'ı ekrana ekleme dialogu göster
  Future<void> _widgetEkranaEkleDialoguGoster(String widgetId) async {
    final widget = _widgetTurleri.firstWhere((w) => w.id == widgetId);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.add_to_home_screen,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_getWidgetIsim(widget.id)} ${_languageService['add'] ?? ''}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getWidgetIsim(widget.id)} ${_languageService['add_widget_question'] ?? ''}',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _languageService['widget_pin_warning'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService['cancel'] ?? ''),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.add, size: 18),
            label: Text(_languageService['add'] ?? ''),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Önce ayarları kaydet
      await _widgetAyarlariniKaydet(widgetId);

      // Widget'ı ekrana ekle
      final success = await WidgetPinService.pinWidget(widgetId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_getWidgetIsim(widget.id)} ${_languageService['widget_pin_sent'] ?? ''}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _languageService['widget_pin_not_supported'] ?? '',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final izinVerildi = await _cikisOnayiGoster();
        if (izinVerildi && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _languageService['widget_settings_title'] ?? '',
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _widgetTurleri
                .map(
                  (w) => Tab(
                    icon: Icon(w.icon, size: 20),
                    text: _getWidgetIsim(w.id).split(' ').first,
                  ),
                )
                .toList(),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'reset_all') {
                  _tumWidgetlariVarsayilanaGetir();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reset_all',
                  child: Row(
                    children: [
                      const Icon(Icons.restore, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _languageService['reset_all_widgets'] ?? '',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: _widgetTurleri
              .map((widget) => _buildWidgetAyarlari(widget, isDark))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildWidgetAyarlari(WidgetTuru widget, bool isDark) {
    final id = widget.id;
    final arkaPlanIndex = _secilenArkaPlanIndex[id] ?? 0;
    final yaziRengiIndex = _secilenYaziRengiIndex[id] ?? 0;
    final seffaflik = _seffaflik[id] ?? 1.0;
    final seffafTema = _seffafTema[id] ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Widget Bilgisi
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.varsayilanRenk1, widget.varsayilanRenk2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.varsayilanYaziRengi,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getWidgetIsim(widget.id),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getWidgetAciklama(widget.id),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Önizleme
        _buildOnizleme(
          id,
          isDark,
          arkaPlanIndex,
          yaziRengiIndex,
          seffaflik,
          seffafTema,
        ),
        const SizedBox(height: 24),

        // Şeffaf Tema Switch
        Card(
          child: SwitchListTile(
            title: Text(_languageService['transparent_theme'] ?? ''),
            subtitle: Text(
              _languageService['transparent_theme_description'] ?? '',
            ),
            value: seffafTema,
            onChanged: (value) {
              setState(() {
                _seffafTema[id] = value;
                if (value) {
                  _secilenArkaPlanIndex[id] = 10; // Şeffaf seçeneği
                }
              });
            },
            secondary: Icon(
              Icons.opacity,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Arka Plan Rengi Seçimi
        if (!seffafTema) ...[
          Text(
            _languageService['background_color'] ?? '',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildArkaPlanSecimi(id, arkaPlanIndex),
          const SizedBox(height: 24),

          // Şeffaflık Ayarı
          Text(
            '${_languageService['opacity'] ?? ''}: ${(seffaflik * 100).toInt()}%',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: seffaflik.clamp(0.3, 1.0),
            min: 0.3,
            max: 1.0,
            divisions: 7,
            label: '${(seffaflik * 100).toInt()}%',
            onChanged: (value) {
              setState(() {
                _seffaflik[id] = value;
              });
            },
          ),
          const SizedBox(height: 24),
        ],

        // Yazı Rengi Seçimi
        Text(
          _languageService['text_color'] ?? '',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildYaziRengiSecimi(id, yaziRengiIndex),
        const SizedBox(height: 32),

        // Bilgi
        Card(
          color: Color.fromRGBO(
            Theme.of(context).colorScheme.primaryContainer.red,
            Theme.of(context).colorScheme.primaryContainer.green,
            Theme.of(context).colorScheme.primaryContainer.blue,
            0.3,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _languageService['widget_specific_info'] ??
                      '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Varsayılana Dön Butonu
        OutlinedButton.icon(
          onPressed: () => _widgetVarsayilanaGetir(id),
          icon: const Icon(Icons.restore),
          label: Text(
            '${_getWidgetIsim(widget.id)} ${_languageService['reset_to_default'] ?? ''}',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange),
          ),
        ),
        const SizedBox(height: 12),

        // Kaydet Butonu
        ElevatedButton.icon(
          onPressed: () => _widgetAyarlariniKaydet(id),
          icon: const Icon(Icons.save),
          label: Text(_languageService['save_settings'] ?? ''),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Ekrana Ekle Butonu (Android 8.0+ destekliyorsa)
        if (_canPinWidgets)
          ElevatedButton.icon(
            onPressed: () => _widgetEkranaEkleDialoguGoster(id),
            icon: const Icon(Icons.add_to_home_screen),
            label: Text(
              _languageService['add_to_home_screen'] ?? '',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOnizleme(
    String widgetId,
    bool isDark,
    int arkaPlanIndex,
    int yaziRengiIndex,
    double seffaflik,
    bool seffafTema,
  ) {
    final arkaPlan = _arkaPlanSecenekleri[arkaPlanIndex];
    final yaziRengi = _yaziRengiSecenekleri[yaziRengiIndex]['renk'] as Color;
    final yaziRengiSecondary = Color.fromRGBO(
      yaziRengi.red,
      yaziRengi.green,
      yaziRengi.blue,
      0.7,
    );

    final Color renk1 = seffafTema
        ? Colors.transparent
        : Color.fromRGBO(
            (arkaPlan['renk1'] as Color).red,
            (arkaPlan['renk1'] as Color).green,
            (arkaPlan['renk1'] as Color).blue,
            seffaflik,
          );
    final Color renk2 = seffafTema
        ? Colors.transparent
        : Color.fromRGBO(
            (arkaPlan['renk2'] as Color).red,
            (arkaPlan['renk2'] as Color).green,
            (arkaPlan['renk2'] as Color).blue,
            seffaflik,
          );

    // Her widget türü için özel önizleme
    switch (widgetId) {
      case 'klasik':
        return _buildKlasikOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      case 'mini':
        return _buildMiniOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      case 'glass':
        return _buildGlassOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      case 'neon':
        return _buildNeonOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      case 'cosmic':
        return _buildCosmicOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      case 'timeline':
        return _buildTimelineOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      case 'zen':
        return _buildZenOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      case 'origami':
        return _buildOrigamiOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
      default:
        return _buildKlasikOnizleme(
          renk1,
          renk2,
          yaziRengi,
          yaziRengiSecondary,
          seffafTema,
          isDark,
        );
    }
  }

  String _previewText(String key) => _languageService[key] ?? '';

  String _previewWithVakit(String templateKey, String vakitKey) {
    final template = _previewText(templateKey);
    final vakit = _previewText(vakitKey);
    return template.replaceAll('{vakit}', vakit);
  }

  // ==================== KLASİK TURUNCU WİDGET ====================
  Widget _buildKlasikOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      160,
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst: Başlık ve sonraki vakit
            Row(
              children: [
                Text(
                  _previewText('widget_preview_prayer_title'),
                  style: TextStyle(
                    color: yaziRengi,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' ${_previewText('widget_preview_prayer_subtitle')}',
                  style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  _previewWithVakit(
                    'widget_preview_time_remaining_to_prayer',
                    'imsak',
                  ),
                  style: TextStyle(color: yaziRengiSecondary, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Orta: Sayaç ve Tarih
            Row(
              children: [
                Text(
                  '07:25:12',
                  style: TextStyle(
                    color: yaziRengi,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _previewText('widget_preview_hijri_date'),
                      style: TextStyle(color: yaziRengi, fontSize: 11),
                    ),
                    Text(
                      _previewText('widget_preview_city').toUpperCase(),
                      style: TextStyle(
                        color: yaziRengiSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // Alt: 6 vakit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _vakitKutusu(
                  _previewText('imsak'),
                  '05:47',
                  yaziRengi,
                  yaziRengiSecondary,
                  true,
                ),
                _vakitKutusu(
                  _previewText('gunes'),
                  '07:22',
                  yaziRengi,
                  yaziRengiSecondary,
                  false,
                ),
                _vakitKutusu(
                  _previewText('ogle'),
                  '12:30',
                  yaziRengi,
                  yaziRengiSecondary,
                  false,
                ),
                _vakitKutusu(
                  _previewText('ikindi'),
                  '15:14',
                  yaziRengi,
                  yaziRengiSecondary,
                  false,
                ),
                _vakitKutusu(
                  _previewText('aksam'),
                  '17:32',
                  yaziRengi,
                  yaziRengiSecondary,
                  false,
                ),
                _vakitKutusu(
                  _previewText('yatsi'),
                  '18:57',
                  yaziRengi,
                  yaziRengiSecondary,
                  false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vakitKutusu(
    String isim,
    String saat,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool aktif,
  ) {
    return Column(
      children: [
        Text(
          isim,
          style: TextStyle(
            color: aktif ? yaziRengi : yaziRengiSecondary,
            fontSize: 8,
          ),
        ),
        Text(
          saat,
          style: TextStyle(
            color: aktif ? yaziRengi : yaziRengiSecondary,
            fontSize: 10,
            fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ==================== MİNİ SUNSET WİDGET ====================
  Widget _buildMiniOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      120,
      Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst: Konum ve tarih
            Row(
              children: [
                Text(
                  _previewText('widget_preview_city_district'),
                  style: TextStyle(
                    color: yaziRengi,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _previewText('widget_preview_hijri_gregorian_short'),
                  style: TextStyle(color: yaziRengiSecondary, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Orta: Geri sayım
            Row(
              children: [
                Text(
                  '18:39',
                  style: TextStyle(
                    color: yaziRengi,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _previewWithVakit(
                    'widget_preview_time_remaining_to_prayer',
                    'aksam',
                  ),
                  style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
                ),
              ],
            ),
            const Spacer(),
            // Alt: Ecir barı
            Row(
              children: [
                Text(
                  _previewText('widget_preview_reward'),
                  style: TextStyle(
                    color: const Color(0xFF00C853),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: yaziRengiSecondary.withValues(alpha: 0.3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.6,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: const Color(0xFF00C853),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '60%',
                  style: TextStyle(color: const Color(0xFF00C853), fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== GLASSMORPHISM WİDGET ====================
  Widget _buildGlassOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      140,
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Üst
            Text(
              _languageService['widget_preview_now_in']?.replaceAll(
                    '{vakit}',
                    _previewText('gunes'),
                  ) ??
                  '',
              style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
            ),
            Text(
              _previewText('widget_preview_hijri_date'),
              style: TextStyle(color: yaziRengi, fontSize: 11),
            ),
            Text(
              _previewText('widget_preview_gregorian_date'),
              style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
            ),
            const Spacer(),
            // Orta
            Text(
              _previewWithVakit('widget_preview_time_to_prayer', 'ogle'),
              style: TextStyle(
                color: yaziRengi,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '02:30:45',
              style: TextStyle(
                color: yaziRengi,
                fontSize: 28,
                fontWeight: FontWeight.w200,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            // Alt: Progress
            Text(
              _languageService['widget_preview_prayer_progress'] ?? '',
              style: TextStyle(color: yaziRengiSecondary, fontSize: 8),
            ),
            const SizedBox(height: 4),
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: yaziRengiSecondary.withValues(alpha: 0.3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: yaziRengi,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Konum
            Text(
              _previewText('widget_preview_city'),
              style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== NEON GLOW WİDGET ====================
  Widget _buildNeonOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    final neonColor = yaziRengi;
    final pinkNeon = Color.lerp(yaziRengi, Colors.pink, 0.5) ?? Colors.pink;

    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      150,
      Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Üst sol: Badge
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: neonColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      _previewText('gunes'),
                      style: TextStyle(
                        color: neonColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Orta
                Text(
                  _previewText('ogle').toUpperCase(),
                  style: TextStyle(
                    color: pinkNeon,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [Shadow(color: pinkNeon, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '02:30:45',
                  style: TextStyle(
                    color: neonColor,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    shadows: [Shadow(color: neonColor, blurRadius: 15)],
                  ),
                ),
                const Spacer(),
                // Alt
                Row(
                  children: [
                    Text(
                      '⚡ ${_previewText('widget_preview_prayer_progress')}',
                      style: TextStyle(
                        color: pinkNeon,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: neonColor.withValues(alpha: 0.2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(colors: [neonColor, pinkNeon]),
                        boxShadow: [BoxShadow(color: neonColor, blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _previewText('widget_preview_city'),
                      style: TextStyle(color: yaziRengiSecondary, fontSize: 9),
                    ),
                    Text(
                      _previewText('widget_preview_hijri_date'),
                      style: TextStyle(color: yaziRengiSecondary, fontSize: 9),
                    ),
                    Text(
                      _previewText('widget_preview_gregorian_date'),
                      style: TextStyle(color: yaziRengiSecondary, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== COSMIC WİDGET ====================
  Widget _buildCosmicOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    final purpleAccent =
        Color.lerp(yaziRengi, Colors.purple, 0.3) ?? Colors.purple;

    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      150,
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Üst
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _previewText('widget_preview_city'),
                      style: TextStyle(
                        color: purpleAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _previewText('widget_preview_hijri_date'),
                      style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
                    ),
                    Text(
                      _previewText('widget_preview_gregorian_date'),
                      style: TextStyle(
                        color: yaziRengiSecondary.withValues(alpha: 0.5),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text('✧', style: TextStyle(color: Colors.cyan, fontSize: 20)),
              ],
            ),
            const Spacer(),
            // Orta
            Text(
              '✦ ${_previewText('gunes')} ✦',
              style: TextStyle(
                color: purpleAccent,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            Text(
              '02:30:45',
              style: TextStyle(
                color: yaziRengi,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: purpleAccent, blurRadius: 20)],
              ),
            ),
            Text(
              _previewWithVakit(
                'widget_preview_time_remaining_to_prayer',
                'ogle',
              ),
              style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
            ),
            const Spacer(),
            // Alt
            Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withValues(alpha: 0.3),
                    Colors.cyan.withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [Colors.purple, Colors.cyan],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TIMELINE WİDGET ====================
  Widget _buildTimelineOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    final greenAccent = const Color(0xFF4CAF50);

    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      160,
      Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Başlık
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _previewText('widget_preview_city'),
                      style: TextStyle(
                        color: yaziRengi,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _previewText('widget_preview_hijri_date'),
                      style: TextStyle(color: yaziRengiSecondary, fontSize: 10),
                    ),
                    Text(
                      _previewText('widget_preview_gregorian_date'),
                      style: TextStyle(
                        color: yaziRengiSecondary.withValues(alpha: 0.6),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _previewWithVakit('widget_preview_time_to_prayer', 'ogle'),
                      style: TextStyle(
                        color: greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '02:30:45',
                      style: TextStyle(
                        color: greenAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Ana Progress
            Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: yaziRengiSecondary.withValues(alpha: 0.3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: greenAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Vakit listesi (2 sütun)
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _timelineVakit(
                        _previewText('imsak'),
                        '05:47',
                        yaziRengi,
                        yaziRengiSecondary,
                        true,
                      ),
                      _timelineVakit(
                        _previewText('gunes'),
                        '07:22',
                        yaziRengi,
                        yaziRengiSecondary,
                        false,
                      ),
                      _timelineVakit(
                        _previewText('ogle'),
                        '12:30',
                        yaziRengi,
                        yaziRengiSecondary,
                        false,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _timelineVakit(
                        _previewText('ikindi'),
                        '15:14',
                        yaziRengi,
                        yaziRengiSecondary,
                        false,
                      ),
                      _timelineVakit(
                        _previewText('aksam'),
                        '17:32',
                        yaziRengi,
                        yaziRengiSecondary,
                        false,
                      ),
                      _timelineVakit(
                        _previewText('yatsi'),
                        '18:57',
                        yaziRengi,
                        yaziRengiSecondary,
                        false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineVakit(
    String isim,
    String saat,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool aktif,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: aktif
                  ? const Color(0xFF4CAF50)
                  : yaziRengiSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isim,
            style: TextStyle(
              color: aktif ? yaziRengi : yaziRengiSecondary,
              fontSize: 9,
            ),
          ),
          const Spacer(),
          Text(
            saat,
            style: TextStyle(
              color: aktif ? yaziRengi : yaziRengiSecondary,
              fontSize: 9,
              fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ZEN WİDGET ====================
  Widget _buildZenOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      130,
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _previewText('widget_preview_city').toUpperCase(),
              style: TextStyle(
                color: yaziRengiSecondary,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '02:30',
              style: TextStyle(
                color: yaziRengi,
                fontSize: 36,
                fontWeight: FontWeight.w200,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _previewText('ogle'),
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' ${_previewText('time_to')}',
                  style: TextStyle(color: yaziRengiSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                color: yaziRengiSecondary.withValues(alpha: 0.3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ORIGAMI WİDGET ====================
  Widget _buildOrigamiOnizleme(
    Color renk1,
    Color renk2,
    Color yaziRengi,
    Color yaziRengiSecondary,
    bool seffafTema,
    bool isDark,
  ) {
    return _buildOnizlemeContainer(
      renk1,
      renk2,
      seffafTema,
      isDark,
      150,
      Stack(
        children: [
          // Köşe katlama efekti
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    yaziRengiSecondary.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Üst
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _previewText('widget_preview_city'),
                          style: TextStyle(
                            color: yaziRengi,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'serif',
                          ),
                        ),
                        Text(
                          _previewText('widget_preview_hijri_date'),
                          style: TextStyle(
                            color: yaziRengiSecondary,
                            fontSize: 11,
                            fontFamily: 'serif',
                          ),
                        ),
                        Text(
                          _previewText('widget_preview_gregorian_date'),
                          style: TextStyle(
                            color: yaziRengiSecondary.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '◯',
                      style: TextStyle(
                        color: yaziRengi.withValues(alpha: 0.3),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Orta
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '───',
                      style: TextStyle(
                        color: yaziRengiSecondary.withValues(alpha: 0.5),
                        fontSize: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _previewWithVakit(
                        'widget_preview_prayer_time_name',
                        'gunes',
                      ),
                      style: TextStyle(
                        color: yaziRengiSecondary,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '───',
                      style: TextStyle(
                        color: yaziRengiSecondary.withValues(alpha: 0.5),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '02:30:45',
                  style: TextStyle(
                    color: yaziRengi,
                    fontSize: 30,
                    fontFamily: 'serif',
                  ),
                ),
                Text(
                  _previewWithVakit(
                    'widget_preview_time_remaining_to_prayer',
                    'ogle',
                  ),
                  style: TextStyle(
                    color: yaziRengiSecondary,
                    fontSize: 10,
                    fontFamily: 'serif',
                  ),
                ),
                const Spacer(),
                // Alt: Progress
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: yaziRengiSecondary.withValues(alpha: 0.2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: yaziRengi.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ORTAK CONTAINER ====================
  Widget _buildOnizlemeContainer(
    Color renk1,
    Color renk2,
    bool seffafTema,
    bool isDark,
    double height,
    Widget child,
  ) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: seffafTema
            ? null
            : LinearGradient(
                colors: [renk1, renk2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: seffafTema ? Colors.transparent : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          if (seffafTema)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CustomPaint(
                  painter: CheckerboardPainter(),
                  size: Size.infinite,
                ),
              ),
            ),
          ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
        ],
      ),
    );
  }

  Widget _buildArkaPlanSecimi(String widgetId, int selectedIndex) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _arkaPlanSecenekleri.length,
      itemBuilder: (context, index) {
        final secenek = _arkaPlanSecenekleri[index];
        final isSelected = selectedIndex == index;
        final isTransparent = secenek['key'] == 'transparent';

        return GestureDetector(
          onTap: () {
            setState(() {
              _secilenArkaPlanIndex[widgetId] = index;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: isTransparent
                  ? null
                  : LinearGradient(
                      colors: [secenek['renk1'], secenek['renk2']],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Stack(
              children: [
                if (isTransparent)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomPaint(
                      painter: CheckerboardPainter(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                Center(
                  child: Text(
                    (_languageService[secenek['nameKey']] ?? '').split(' ').first,
                    style: TextStyle(
                      color:
                          isTransparent ||
                              (secenek['renk1'] as Color).computeLuminance() >
                                  0.5
                          ? Colors.black
                          : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildYaziRengiSecimi(String widgetId, int selectedIndex) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _yaziRengiSecenekleri.length,
      itemBuilder: (context, index) {
        final secenek = _yaziRengiSecenekleri[index];
        final isSelected = selectedIndex == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              _secilenYaziRengiIndex[widgetId] = index;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: secenek['renk'],
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: (secenek['renk'] as Color).computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Şeffaf arka plan göstermek için kareli desen
class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 8.0;
    final paint1 = Paint()..color = Colors.grey.shade300;
    final paint2 = Paint()..color = Colors.grey.shade100;

    for (double x = 0; x < size.width; x += cellSize) {
      for (double y = 0; y < size.height; y += cellSize) {
        final isEven = ((x / cellSize) + (y / cellSize)).toInt() % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
