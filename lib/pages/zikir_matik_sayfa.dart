import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';
import '../services/vibration_service.dart';
import '../services/language_service.dart';
import '../services/tema_service.dart';

class ZikirMatikSayfa extends StatefulWidget {
  const ZikirMatikSayfa({super.key});

  @override
  State<ZikirMatikSayfa> createState() => _ZikirMatikSayfaState();
}

class _ZikirMatikSayfaState extends State<ZikirMatikSayfa>
    with TickerProviderStateMixin {
  final LanguageService _languageService = LanguageService();
  final TemaService _temaService = TemaService();
  int _sayac = 0;
  int _hedef = 33;
  int _toplamTur = 0;
  bool _titresimAcik = true;

  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  final List<int> _hedefler = [33, 99, 100, 500, 1000];
  
  // Varsayılan zikirler
  List<Map<String, String>> get _varsayilanZikirler => [
    {'isim': _languageService['subhanallah'], 'anlam': _languageService['subhanallah_meaning'], 'varsayilan': 'true'},
    {'isim': _languageService['alhamdulillah'], 'anlam': _languageService['alhamdulillah_meaning'], 'varsayilan': 'true'},
    {'isim': _languageService['allahu_akbar'], 'anlam': _languageService['allahu_akbar_meaning'], 'varsayilan': 'true'},
    {'isim': _languageService['la_ilaha_illallah'], 'anlam': _languageService['la_ilaha_illallah_meaning'], 'varsayilan': 'true'},
    {'isim': _languageService['astaghfirullah'], 'anlam': _languageService['astaghfirullah_meaning'], 'varsayilan': 'true'},
    {'isim': _languageService['la_hawla'], 'anlam': _languageService['la_hawla_meaning'], 'varsayilan': 'true'},
  ];
  
  // Kullanıcının özel zikirleri
  List<Map<String, String>> _ozelZikirler = [];
  
  // Tüm zikirler (varsayılan + özel)
  List<Map<String, String>> get _zikirler => [..._varsayilanZikirler, ..._ozelZikirler];
  
  int _secilenZikirIndex = 0;

  @override
  void initState() {
    super.initState();
    _languageService.addListener(_onLanguageChanged);
    _temaService.addListener(_onLanguageChanged);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    
    _verileriYukle();
  }
  
  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Özel zikirleri yükle
    final ozelZikirlerJson = prefs.getString('ozel_zikirler');
    if (ozelZikirlerJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(ozelZikirlerJson);
        _ozelZikirler = decoded.map((e) => Map<String, String>.from(e)).toList();
      } catch (e) {
        _ozelZikirler = [];
      }
    }
    
    setState(() {
      _sayac = prefs.getInt('zikir_sayac') ?? 0;
      _hedef = prefs.getInt('zikir_hedef') ?? 33;
      _toplamTur = prefs.getInt('zikir_toplam_tur') ?? 0;
      _secilenZikirIndex = prefs.getInt('zikir_secilen_index') ?? 0;
      _titresimAcik = prefs.getBool('zikir_titresim') ?? true;
      
      // Seçilen index geçerli mi kontrol et
      if (_secilenZikirIndex >= _zikirler.length) {
        _secilenZikirIndex = 0;
      }
    });
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zikir_sayac', _sayac);
    await prefs.setInt('zikir_hedef', _hedef);
    await prefs.setInt('zikir_toplam_tur', _toplamTur);
    await prefs.setInt('zikir_secilen_index', _secilenZikirIndex);
    await prefs.setBool('zikir_titresim', _titresimAcik);
  }
  
  Future<void> _ozelZikirleriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ozel_zikirler', jsonEncode(_ozelZikirler));
  }

  @override
  void dispose() {
    _languageService.removeListener(_onLanguageChanged);
    _temaService.removeListener(_onLanguageChanged);
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _artir() async {
    if (_titresimAcik) {
      await VibrationService.light();
    }
    
    _pulseController.forward().then((_) => _pulseController.reverse());
    _rippleController.forward(from: 0.0);

    setState(() {
      _sayac++;
      if (_sayac >= _hedef) {
        _toplamTur++;
        _sayac = 0;
        if (_titresimAcik) {
          _turTamamTitresim();
        }
      }
    });
    _verileriKaydet();
  }
  
  Future<void> _turTamamTitresim() async {
    await VibrationService.heavy();
    await Future.delayed(const Duration(milliseconds: 150));
    await VibrationService.heavy();
  }

  void _sifirla() async {
    if (_titresimAcik) {
      await VibrationService.medium();
    }
    setState(() {
      _sayac = 0;
    });
    _verileriKaydet();
  }

  void _tamSifirla() async {
    if (_titresimAcik) {
      await VibrationService.heavy();
    }
    setState(() {
      _sayac = 0;
      _toplamTur = 0;
    });
    _verileriKaydet();
  }
  
  void _zikirEkleDialog() {
    final isimController = TextEditingController();
    final anlamController = TextEditingController();
    final renkler = _temaService.renkler;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        title: Text(
          _languageService['add_custom_dhikr'] ?? 'Özel Zikir Ekle',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: isimController,
                style: TextStyle(color: renkler.yaziPrimary),
                decoration: InputDecoration(
                  labelText: _languageService['dhikr_name'] ?? 'Zikir Adı',
                  labelStyle: TextStyle(color: renkler.yaziSecondary),
                  hintText: 'Örn: Sübhanallahi ve bihamdihi',
                  hintStyle: TextStyle(color: renkler.yaziSecondary.withOpacity(0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: renkler.vurgu.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: renkler.vurgu),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: anlamController,
                style: TextStyle(color: renkler.yaziPrimary),
                decoration: InputDecoration(
                  labelText: _languageService['meaning'] ?? 'Anlamı',
                  labelStyle: TextStyle(color: renkler.yaziSecondary),
                  hintText: 'Örn: Allah\'ı hamd ile tesbih ederim',
                  hintStyle: TextStyle(color: renkler.yaziSecondary.withOpacity(0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: renkler.vurgu.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: renkler.vurgu),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _languageService['cancel'] ?? 'İptal',
              style: TextStyle(color: renkler.yaziSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (isimController.text.trim().isNotEmpty) {
                setState(() {
                  _ozelZikirler.add({
                    'isim': isimController.text.trim(),
                    'anlam': anlamController.text.trim().isEmpty 
                        ? '-' 
                        : anlamController.text.trim(),
                    'varsayilan': 'false',
                  });
                });
                _ozelZikirleriKaydet();
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_languageService['dhikr_added'] ?? 'Zikir eklendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: renkler.vurgu,
            ),
            child: Text(
              _languageService['add'] ?? 'Ekle',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  void _zikirSil(int index) {
    final gercekIndex = index - _varsayilanZikirler.length;
    if (gercekIndex < 0) return;
    
    final renkler = _temaService.renkler;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        title: Text(
          _languageService['delete_dhikr'] ?? 'Zikri Sil',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        content: Text(
          '${_ozelZikirler[gercekIndex]['isim']} ${_languageService['confirm_delete_dhikr'] ?? 'zikrini silmek istediğinize emin misiniz?'}',
          style: TextStyle(color: renkler.yaziSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _languageService['cancel'] ?? 'İptal',
              style: TextStyle(color: renkler.yaziSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _ozelZikirler.removeAt(gercekIndex);
                if (_secilenZikirIndex >= _zikirler.length) {
                  _secilenZikirIndex = 0;
                }
              });
              _ozelZikirleriKaydet();
              _verileriKaydet();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              _languageService['delete'] ?? 'Sil',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _sayac / _hedef;

    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      appBar: AppBar(
        title: Text(_languageService['dhikr'] ?? 'Zikir Matik'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _zikirEkleDialog,
            tooltip: _languageService['add_custom_dhikr'] ?? 'Özel Zikir Ekle',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _tamSifirla,
            tooltip: _languageService['reset'] ?? 'Sıfırla',
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune),
            tooltip: _languageService['target'] ?? 'Hedef Seç',
            onSelected: (value) {
              setState(() {
                _hedef = value;
                _sayac = 0;
              });
              _verileriKaydet();
            },
            itemBuilder: (context) => _hedefler
                .map((h) => PopupMenuItem(
                      value: h,
                      child: Text(
                        '$h',
                        style: TextStyle(
                          fontWeight: _hedef == h ? FontWeight.bold : FontWeight.normal,
                          color: _hedef == h ? Colors.cyanAccent : null,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _zikirler.length + 1,
              itemBuilder: (context, index) {
                if (index == _zikirler.length) {
                  return GestureDetector(
                    onTap: _zikirEkleDialog,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.cyanAccent, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            _languageService['add'] ?? 'Ekle',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final isSelected = index == _secilenZikirIndex;
                final isCustom = _zikirler[index]['varsayilan'] == 'false';
                
                return GestureDetector(
                  onTap: () {
                    setState(() => _secilenZikirIndex = index);
                    _verileriKaydet();
                  },
                  onLongPress: isCustom ? () => _zikirSil(index) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.cyanAccent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.cyanAccent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _zikirler[index]['isim']!,
                              style: TextStyle(
                                color: isSelected ? Colors.cyanAccent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _zikirler[index]['anlam']!,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.cyanAccent.withOpacity(0.7)
                                    : Colors.white54,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        if (isCustom)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoChip(Icons.loop, '$_toplamTur ${_languageService['rounds'] ?? 'Tur'}'),
                const SizedBox(width: 16),
                _infoChip(Icons.flag, '${_languageService['target'] ?? 'Hedef'}: $_hedef'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _titresimAcik = !_titresimAcik);
                      _verileriKaydet();
                      if (_titresimAcik) HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _titresimAcik 
                            ? Colors.cyanAccent.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _titresimAcik ? Colors.cyanAccent : Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _titresimAcik ? Icons.vibration : Icons.vibration_outlined,
                            color: _titresimAcik ? Colors.cyanAccent : Colors.white54,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _titresimAcik 
                                ? (_languageService['vibration_on'] ?? 'Titreşim Açık')
                                : (_languageService['vibration_off'] ?? 'Titreşim Kapalı'),
                            style: TextStyle(
                              color: _titresimAcik ? Colors.cyanAccent : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _artir,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _rippleAnimation]),
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_rippleAnimation.value > 0)
                          Container(
                            width: 260 + (_rippleAnimation.value * 60),
                            height: 260 + (_rippleAnimation.value * 60),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(1 - _rippleAnimation.value),
                                width: 3,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CustomPaint(
                            painter: _CircleProgressPainter(
                              progress: progress,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              progressColor: Colors.cyanAccent,
                              strokeWidth: 8,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2B3151), Color(0xFF1B2741)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_sayac',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    _zikirler[_secilenZikirIndex]['isim']!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (_sayac > 0) {
                      if (_titresimAcik) HapticFeedback.lightImpact();
                      setState(() => _sayac--);
                      _verileriKaydet();
                    }
                  },
                ),
                _controlButton(icon: Icons.refresh, onTap: _sifirla, isLarge: true),
                _controlButton(icon: Icons.add, onTap: _artir),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _controlButton({required IconData icon, required VoidCallback onTap, bool isLarge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isLarge ? 70 : 56,
        height: isLarge ? 70 : 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 2),
        ),
        child: Icon(icon, color: Colors.cyanAccent, size: isLarge ? 32 : 24),
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
