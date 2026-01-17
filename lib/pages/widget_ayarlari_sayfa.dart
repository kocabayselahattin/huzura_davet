import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/home_widget_service.dart';

class WidgetAyarlariSayfa extends StatefulWidget {
  const WidgetAyarlariSayfa({super.key});

  @override
  State<WidgetAyarlariSayfa> createState() => _WidgetAyarlariSayfaState();
}

class _WidgetAyarlariSayfaState extends State<WidgetAyarlariSayfa> {
  // Arka plan renkleri
  int _secilenArkaPlanIndex = 0;
  
  // Yazı renkleri
  int _secilenYaziRengiIndex = 0;
  
  // Şeffaflık
  double _seffaflik = 1.0;
  bool _seffafTema = false;

  final List<Map<String, dynamic>> _arkaPlanSecenekleri = [
    {'isim': 'Turuncu Gradient', 'renk1': Color(0xFFFF8C42), 'renk2': Color(0xFFCC5522), 'key': 'orange'},
    {'isim': 'Açık Krem', 'renk1': Color(0xFFFFF8F0), 'renk2': Color(0xFFFFE8D8), 'key': 'light'},
    {'isim': 'Koyu Mavi', 'renk1': Color(0xFF1A3A5C), 'renk2': Color(0xFF051525), 'key': 'dark'},
    {'isim': 'Gün Batımı', 'renk1': Color(0xFFFFE4B5), 'renk2': Color(0xFFFFD0A0), 'key': 'sunset'},
    {'isim': 'Yeşil', 'renk1': Color(0xFF2E7D32), 'renk2': Color(0xFF1B5E20), 'key': 'green'},
    {'isim': 'Mor', 'renk1': Color(0xFF7B1FA2), 'renk2': Color(0xFF4A148C), 'key': 'purple'},
    {'isim': 'Kırmızı', 'renk1': Color(0xFFD32F2F), 'renk2': Color(0xFFB71C1C), 'key': 'red'},
    {'isim': 'Mavi', 'renk1': Color(0xFF1976D2), 'renk2': Color(0xFF0D47A1), 'key': 'blue'},
    {'isim': 'Turkuaz', 'renk1': Color(0xFF00ACC1), 'renk2': Color(0xFF006064), 'key': 'teal'},
    {'isim': 'Pembe', 'renk1': Color(0xFFE91E63), 'renk2': Color(0xFFC2185B), 'key': 'pink'},
    {'isim': 'Şeffaf', 'renk1': Colors.transparent, 'renk2': Colors.transparent, 'key': 'transparent'},
    {'isim': 'Yarı Şeffaf Siyah', 'renk1': Color(0x88000000), 'renk2': Color(0x88000000), 'key': 'semi_black'},
    {'isim': 'Yarı Şeffaf Beyaz', 'renk1': Color(0x88FFFFFF), 'renk2': Color(0x88FFFFFF), 'key': 'semi_white'},
  ];

  final List<Map<String, dynamic>> _yaziRengiSecenekleri = [
    {'isim': 'Beyaz', 'renk': Colors.white, 'hex': 'FFFFFF'},
    {'isim': 'Siyah', 'renk': Colors.black, 'hex': '000000'},
    {'isim': 'Turuncu', 'renk': Color(0xFFFF8C42), 'hex': 'FF8C42'},
    {'isim': 'Altın', 'renk': Color(0xFFFFD700), 'hex': 'FFD700'},
    {'isim': 'Açık Mavi', 'renk': Color(0xFFAADDFF), 'hex': 'AADDFF'},
    {'isim': 'Yeşil', 'renk': Color(0xFF4CAF50), 'hex': '4CAF50'},
    {'isim': 'Kırmızı', 'renk': Color(0xFFF44336), 'hex': 'F44336'},
    {'isim': 'Sarı', 'renk': Color(0xFFFFEB3B), 'hex': 'FFEB3B'},
    {'isim': 'Pembe', 'renk': Color(0xFFE91E63), 'hex': 'E91E63'},
    {'isim': 'Mor', 'renk': Color(0xFF9C27B0), 'hex': '9C27B0'},
    {'isim': 'Cyan', 'renk': Color(0xFF00BCD4), 'hex': '00BCD4'},
    {'isim': 'Gri', 'renk': Color(0xFF9E9E9E), 'hex': '9E9E9E'},
  ];

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _secilenArkaPlanIndex = prefs.getInt('widget_arkaplan_index') ?? 0;
      _secilenYaziRengiIndex = prefs.getInt('widget_yazi_rengi_index') ?? 0;
      _seffaflik = prefs.getDouble('widget_seffaflik') ?? 1.0;
      _seffafTema = prefs.getBool('widget_seffaf_tema') ?? false;
    });
  }

  Future<void> _ayarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('widget_arkaplan_index', _secilenArkaPlanIndex);
    await prefs.setInt('widget_yazi_rengi_index', _secilenYaziRengiIndex);
    await prefs.setDouble('widget_seffaflik', _seffaflik);
    await prefs.setBool('widget_seffaf_tema', _seffafTema);
    
    // Widget verilerini güncelle
    final arkaPlan = _arkaPlanSecenekleri[_secilenArkaPlanIndex];
    final yaziRengi = _yaziRengiSecenekleri[_secilenYaziRengiIndex];
    
    await HomeWidgetService.updateWidgetColors(
      arkaPlanKey: arkaPlan['key'],
      yaziRengiHex: yaziRengi['hex'],
      seffaflik: _seffafTema ? 0.0 : _seffaflik,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Widget ayarları kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Ayarları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _ayarlariKaydet,
            tooltip: 'Kaydet',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Önizleme
          _buildOnizleme(isDark),
          const SizedBox(height: 24),
          
          // Şeffaf Tema Switch
          Card(
            child: SwitchListTile(
              title: const Text('Şeffaf Tema'),
              subtitle: const Text('Arka planı tamamen şeffaf yapar'),
              value: _seffafTema,
              onChanged: (value) {
                setState(() {
                  _seffafTema = value;
                  if (value) {
                    _secilenArkaPlanIndex = 10; // Şeffaf seçeneği
                  }
                });
              },
              secondary: Icon(
                Icons.opacity,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Arka Plan Rengi Seçimi
          if (!_seffafTema) ...[
            Text(
              'Arka Plan Rengi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildArkaPlanSecimi(),
            const SizedBox(height: 24),
            
            // Şeffaflık Ayarı
            Text(
              'Şeffaflık: ${(_seffaflik * 100).toInt()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Slider(
              value: _seffaflik,
              min: 0.3,
              max: 1.0,
              divisions: 7,
              label: '${(_seffaflik * 100).toInt()}%',
              onChanged: (value) {
                setState(() {
                  _seffaflik = value;
                });
              },
            ),
            const SizedBox(height: 24),
          ],
          
          // Yazı Rengi Seçimi
          Text(
            'Yazı Rengi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildYaziRengiSecimi(),
          const SizedBox(height: 32),
          
          // Kaydet Butonu
          ElevatedButton.icon(
            onPressed: _ayarlariKaydet,
            icon: const Icon(Icons.save),
            label: const Text('Ayarları Kaydet ve Uygula'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          
          // Bilgi
          Card(
            color: Color.fromRGBO(
              theme.colorScheme.primaryContainer.red,
              theme.colorScheme.primaryContainer.green,
              theme.colorScheme.primaryContainer.blue,
              0.3,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ayarları kaydettikten sonra widget\'ı ana ekranınızdan kaldırıp tekrar ekleyin.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnizleme(bool isDark) {
    final arkaPlan = _arkaPlanSecenekleri[_secilenArkaPlanIndex];
    final yaziRengi = _yaziRengiSecenekleri[_secilenYaziRengiIndex]['renk'] as Color;
    
    final Color renk1 = _seffafTema 
        ? Colors.transparent 
        : Color.fromRGBO(
            (arkaPlan['renk1'] as Color).red,
            (arkaPlan['renk1'] as Color).green,
            (arkaPlan['renk1'] as Color).blue,
            _seffaflik,
          );
    final Color renk2 = _seffafTema 
        ? Colors.transparent 
        : Color.fromRGBO(
            (arkaPlan['renk2'] as Color).red,
            (arkaPlan['renk2'] as Color).green,
            (arkaPlan['renk2'] as Color).blue,
            _seffaflik,
          );
    
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: _seffafTema 
            ? null 
            : LinearGradient(
                colors: [renk1, renk2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: _seffafTema ? Colors.transparent : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Şeffaf tema için arka plan deseni
          if (_seffafTema)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CustomPaint(
                  painter: CheckerboardPainter(),
                  size: Size.infinite,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Önizleme',
                  style: TextStyle(
                    color: Color.fromRGBO(yaziRengi.red, yaziRengi.green, yaziRengi.blue, 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Öğle Namazına',
                      style: TextStyle(
                        color: yaziRengi,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'İstanbul',
                      style: TextStyle(
                        color: Color.fromRGBO(yaziRengi.red, yaziRengi.green, yaziRengi.blue, 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '02:30:45',
                  style: TextStyle(
                    color: yaziRengi,
                    fontSize: 32,
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

  Widget _buildArkaPlanSecimi() {
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
        final isSelected = _secilenArkaPlanIndex == index;
        final isTransparent = secenek['key'] == 'transparent';
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _secilenArkaPlanIndex = index;
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
                    secenek['isim'].split(' ').first,
                    style: TextStyle(
                      color: isTransparent || (secenek['renk1'] as Color).computeLuminance() > 0.5
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

  Widget _buildYaziRengiSecimi() {
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
        final isSelected = _secilenYaziRengiIndex == index;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _secilenYaziRengiIndex = index;
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
