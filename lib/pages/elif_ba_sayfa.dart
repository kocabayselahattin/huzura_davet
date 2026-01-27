import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../services/tema_service.dart';
import '../services/language_service.dart';

class ElifBaSayfa extends StatefulWidget {
  const ElifBaSayfa({super.key});

  @override
  State<ElifBaSayfa> createState() => _ElifBaSayfaState();
}

class _ElifBaSayfaState extends State<ElifBaSayfa>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  final FlutterTts _flutterTts = FlutterTts();
  late TabController _tabController;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  int _selectedLetterIndex = 0;
  bool _isPlaying = false;
  int _currentCategory = 0; // 0: Tümü, 1: Temel, 2: Boğaz, 3: Dudak
  bool _isMaleVoice = true; // true: erkek, false: kadın

  final List<Color> _categoryColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVoicePreference();
    
    // Pulse animasyonu
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Scale animasyonu
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _loadVoicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMaleVoice = prefs.getBool('tts_male_voice') ?? true;
    });
    await _configureTts();
  }

  Future<void> _saveVoicePreference(bool isMale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_male_voice', isMale);
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage("ar-SA");
    await _flutterTts.setSpeechRate(0.35);
    await _flutterTts.setVolume(1.0);
    // Erkek ses için pitch 0.8-1.0, kadın ses için 1.2-1.4
    await _flutterTts.setPitch(_isMaleVoice ? 0.9 : 1.3);
    await _flutterTts.setSharedInstance(true);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: renkler.vurgu,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'ELİF-BA ÖĞRENİYORUM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      renkler.vurgu,
                      renkler.vurgu.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Dekoratif çemberler
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // İkon
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 60,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isMaleVoice ? Icons.person : Icons.person_outline,
                  color: Colors.white,
                ),
                onPressed: () => _showVoiceSettings(context),
                tooltip: _isMaleVoice ? 'Erkek Ses' : 'Kadın Ses',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.abc), text: 'Harfler'),
                Tab(icon: Icon(Icons.auto_stories), text: 'Tecvit'),
                Tab(icon: Icon(Icons.quiz), text: 'Test'),
              ],
            ),
          ),
          
          // Tab içerikleri
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildModernHarflerTab(renkler),
                _buildModernTecvitTab(renkler),
                _buildModernTestTab(renkler),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHarflerTab(TemaRenkleri renkler) {
    return Column(
      children: [
        // Kategori filtreleri
        Container(
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip('Tümü', 0, Icons.grid_view, renkler),
              _buildCategoryChip('Temel', 1, Icons.star, renkler),
              _buildCategoryChip('Boğaz', 2, Icons.circle, renkler),
              _buildCategoryChip('Dudak', 3, Icons.record_voice_over, renkler),
            ],
          ),
        ),
        
        // Harf grid'i
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _getFilteredHarfler().length,
            itemBuilder: (context, index) {
              final harf = _getFilteredHarfler()[index];
              final harfIndex = _arapHarfler.indexOf(harf);
              final categoryColor = _getCategoryColor(harf['kategori'] ?? '');
              
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedLetterIndex = harfIndex);
                  _showHarfDetayDialog(harf, categoryColor);
                  _scaleController.forward(from: 0);
                },
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
                  ),
                  child: _buildModernHarfKarti(harf, categoryColor, index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, int index, IconData icon, TemaRenkleri renkler) {
    final isSelected = _currentCategory == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : renkler.vurgu),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() => _currentCategory = index);
        },
        selectedColor: renkler.vurgu,
        checkmarkColor: Colors.white,
        backgroundColor: renkler.kartArkaPlan,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : renkler.yaziPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        elevation: isSelected ? 4 : 0,
        pressElevation: 8,
      ),
    );
  }

  Widget _buildModernHarfKarti(Map<String, String> harf, Color categoryColor, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  categoryColor.withOpacity(0.8),
                  categoryColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: categoryColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Dekoratif desen
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DotPatternPainter(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                // İçerik
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Arapça harf (büyük)
                    Text(
                      harf['harf']!,
                      style: const TextStyle(
                        fontSize: 56,
                        color: Colors.white,
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Okunuş
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        harf['okunus']!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                // Ses butonu
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      size: 16,
                      color: Colors.white,
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

  void _showHarfDetayDialog(Map<String, String> harf, Color categoryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: _temaService.renkler.arkaPlan,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  
                  // Büyük harf gösterimi
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          categoryColor.withOpacity(0.3),
                          categoryColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: categoryColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Pulse animasyonu ile harf
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.1),
                              child: Text(
                                harf['harf']!,
                                style: TextStyle(
                                  fontSize: 140,
                                  color: categoryColor,
                                  fontFamily: 'Amiri',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Ses butonu
                        ElevatedButton.icon(
                          onPressed: () => _playLetterSound(harf['harf']!),
                          icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
                          label: Text(
                            _isPlaying ? 'Durduruluyor...' : '🔊 Sesli Dinle (3x)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: categoryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bilgi kartları
                  _buildDetayKart(
                    icon: Icons.record_voice_over,
                    title: 'Okunuş',
                    content: harf['okunus']!,
                    color: Colors.blue,
                  ),
                  
                  _buildDetayKart(
                    icon: Icons.book,
                    title: 'Örnek Kelimeler',
                    content: harf['ornek']!,
                    color: Colors.green,
                  ),
                  
                  if (harf['aciklama'] != null && harf['aciklama']!.isNotEmpty)
                    _buildDetayKart(
                      icon: Icons.info,
                      title: 'Açıklama',
                      content: harf['aciklama']!,
                      color: Colors.orange,
                    ),
                  
                  // İpucu
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: categoryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb, color: categoryColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Harfi dinleyip tekrar ederek öğrenmeyi kolaylaştırabilirsiniz!',
                            style: TextStyle(
                              color: _temaService.renkler.yaziSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetayKart({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _temaService.renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    color: _temaService.renkler.yaziPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTecvitTab(TemaRenkleri renkler) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tecvitKurallari.length,
      itemBuilder: (context, index) {
        final kural = _tecvitKurallari[index];
        final color = _categoryColors[index % _categoryColors.length];
        
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 100)),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(50 * (1 - value), 0),
              child: Opacity(
                opacity: value,
                child: _buildModernTecvitKarti(kural, color),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernTecvitKarti(Map<String, String> kural, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(20),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.school, color: color, size: 24),
          ),
          title: Text(
            kural['baslik']!,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                kural['ornek']!,
                style: TextStyle(
                  color: _temaService.renkler.yaziPrimary,
                  fontSize: 24,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _temaService.renkler.kartArkaPlan,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                kural['aciklama']!,
                style: TextStyle(
                  color: _temaService.renkler.yaziPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTestTab(TemaRenkleri renkler) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animasyonlu ikon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Transform.rotate(
                    angle: value * 2 * math.pi,
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            renkler.vurgu.withOpacity(0.3),
                            renkler.vurgu.withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: renkler.vurgu.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        size: 80,
                        color: renkler.vurgu,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            
            Text(
              'Bilgilerini Test Et!',
              style: TextStyle(
                color: renkler.yaziPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Öğrendiğin harfleri ve tecvit kurallarını\ninteraktif testlerle pekiştir',
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Test butonları
            _buildTestButton(
              icon: Icons.abc,
              title: 'Harf Testi',
              subtitle: '28 Arapça harf',
              color: Colors.blue,
              onTap: () => _startTest(context),
            ),
            const SizedBox(height: 16),
            
            _buildTestButton(
              icon: Icons.auto_stories,
              title: 'Tecvit Testi',
              subtitle: '10 Temel kural',
              color: Colors.green,
              onTap: () => _startTest(context),
            ),
            const SizedBox(height: 16),
            
            _buildTestButton(
              icon: Icons.emoji_events,
              title: 'Karma Test',
              subtitle: 'Harf + Tecvit',
              color: Colors.orange,
              onTap: () => _startTest(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getFilteredHarfler() {
    if (_currentCategory == 0) return _arapHarfler;
    
    final kategori = _currentCategory == 1 
        ? 'temel' 
        : _currentCategory == 2 
            ? 'bogaz' 
            : 'dudak';
    
    return _arapHarfler.where((h) => h['kategori'] == kategori).toList();
  }

  Color _getCategoryColor(String kategori) {
    switch (kategori) {
      case 'temel':
        return Colors.green;
      case 'bogaz':
        return Colors.orange;
      case 'dudak':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  Future<void> _playLetterSound(String harf) async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      for (int i = 0; i < 3; i++) {
        await _flutterTts.speak(harf);
        if (i < 2) await Future.delayed(const Duration(milliseconds: 800));
      }
    } catch (e) {
      debugPrint('Ses çalma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ses çalınamadı'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) setState(() => _isPlaying = false);
  }

  void _showVoiceSettings(BuildContext context) {
    final renkler = _temaService.renkler;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.record_voice_over, color: renkler.vurgu),
            const SizedBox(width: 12),
            Text(
              'Ses Seçimi',
              style: TextStyle(color: renkler.yaziPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Radio<bool>(
                value: true,
                groupValue: _isMaleVoice,
                onChanged: (value) async {
                  setState(() => _isMaleVoice = true);
                  await _saveVoicePreference(true);
                  await _configureTts();
                  Navigator.pop(context);
                },
                activeColor: renkler.vurgu,
              ),
              title: Row(
                children: [
                  Icon(Icons.person, color: renkler.yaziPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Erkek Ses',
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontWeight: _isMaleVoice ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              onTap: () async {
                setState(() => _isMaleVoice = true);
                await _saveVoicePreference(true);
                await _configureTts();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Radio<bool>(
                value: false,
                groupValue: _isMaleVoice,
                onChanged: (value) async {
                  setState(() => _isMaleVoice = false);
                  await _saveVoicePreference(false);
                  await _configureTts();
                  Navigator.pop(context);
                },
                activeColor: renkler.vurgu,
              ),
              title: Row(
                children: [
                  Icon(Icons.person_outline, color: renkler.yaziPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'Kadın Ses',
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontWeight: !_isMaleVoice ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              onTap: () async {
                setState(() => _isMaleVoice = false);
                await _saveVoicePreference(false);
                await _configureTts();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startTest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ElifBaTestSayfa()),
    );
  }

  final List<Map<String, String>> _arapHarfler = [
    {
      'harf': 'ا',
      'okunus': 'Elif',
      'kategori': 'temel',
      'ornek': 'أَنَا (ene) - ben\nإِسْلَام (İslam)',
      'aciklama': 'Sessiz bir harftir. Üstündeki harekeyle okunur.',
    },
    {
      'harf': 'ب',
      'okunus': 'Be',
      'kategori': 'dudak',
      'ornek': 'بَيْت (beyt) - ev\nكِتَاب (kitab) - kitap',
      'aciklama': 'Dudak harfidir. Alt tarafında bir nokta vardır.',
    },
    {
      'harf': 'ت',
      'okunus': 'Te',
      'kategori': 'temel',
      'ornek': 'تُفَّاح (tüffah) - elma',
      'aciklama': 'Diş harfidir. Üstünde iki nokta vardır.',
    },
    {
      'harf': 'ث',
      'okunus': 'Se',
      'kategori': 'temel',
      'ornek': 'ثَلَاثَة (selase) - üç',
      'aciklama': 'İngilizce "th" harfi gibi okunur.',
    },
    {
      'harf': 'ج',
      'okunus': 'Cim',
      'kategori': 'bogaz',
      'ornek': 'جَمِيل (cemil) - güzel',
      'aciklama': 'Boğaz harfidir. Ortasında bir nokta vardır.',
    },
    {
      'harf': 'ح',
      'okunus': 'Ha',
      'kategori': 'bogaz',
      'ornek': 'حَلِيب (halip) - süt',
      'aciklama': 'Boğazdan çıkan özel bir "h" harfidir.',
    },
    {
      'harf': 'خ',
      'okunus': 'Hı',
      'kategori': 'bogaz',
      'ornek': 'خُبْز (hubz) - ekmek',
      'aciklama': 'Boğazdan gelen kalın "h" harfidir.',
    },
    {
      'harf': 'د',
      'okunus': 'Dal',
      'kategori': 'temel',
      'ornek': 'دَرْس (ders) - ders',
      'aciklama': 'Diş harfidir.',
    },
    {
      'harf': 'ذ',
      'okunus': 'Zel',
      'kategori': 'temel',
      'ornek': 'ذَهَب (zehebe) - altın',
      'aciklama': '"Th" sesi gibi okunur.',
    },
    {
      'harf': 'ر',
      'okunus': 'Re',
      'kategori': 'temel',
      'ornek': 'رَجُل (racül) - adam',
      'aciklama': 'Dil harfidir. Hafif titreşimle okunur.',
    },
    {
      'harf': 'ز',
      'okunus': 'Ze',
      'kategori': 'temel',
      'ornek': 'زَمَان (zeman) - zaman',
      'aciklama': 'Dil harfidir.',
    },
    {
      'harf': 'س',
      'okunus': 'Sin',
      'kategori': 'temel',
      'ornek': 'سَلَام (selam) - selam',
      'aciklama': 'Diş harfidir. Üç diş şeklindedir.',
    },
    {
      'harf': 'ش',
      'okunus': 'Şın',
      'kategori': 'temel',
      'ornek': 'شُكْرًا (şükran) - teşekkür',
      'aciklama': 'Diş harfidir. Üstünde üç nokta vardır.',
    },
    {
      'harf': 'ص',
      'okunus': 'Sad',
      'kategori': 'bogaz',
      'ornek': 'صَبَاح (sabah) - sabah',
      'aciklama': 'Kalın "s" harfidir.',
    },
    {
      'harf': 'ض',
      'okunus': 'Dad',
      'kategori': 'bogaz',
      'ornek': 'ضَوْء (dav) - ışık',
      'aciklama': 'Kalın "d" harfidir.',
    },
    {
      'harf': 'ط',
      'okunus': 'Tı',
      'kategori': 'bogaz',
      'ornek': 'طَالِب (talib) - öğrenci',
      'aciklama': 'Kalın "t" harfidir.',
    },
    {
      'harf': 'ظ',
      'okunus': 'Zı',
      'kategori': 'bogaz',
      'ornek': 'ظُلْم (zulm) - zulüm',
      'aciklama': 'Kalın "z" harfidir.',
    },
    {
      'harf': 'ع',
      'okunus': 'Ayın',
      'kategori': 'bogaz',
      'ornek': 'عَرَبِي (arabi) - Arap',
      'aciklama': 'Boğazdan gelen özel bir sestir.',
    },
    {
      'harf': 'غ',
      'okunus': 'Gayın',
      'kategori': 'bogaz',
      'ornek': 'غَيْر (gayr) - başka',
      'aciklama': 'Boğazdan gelen "g" harfidir.',
    },
    {
      'harf': 'ف',
      'okunus': 'Fe',
      'kategori': 'dudak',
      'ornek': 'فِي (fi) - içinde',
      'aciklama': 'Dudak harfidir.',
    },
    {
      'harf': 'ق',
      'okunus': 'Kaf',
      'kategori': 'bogaz',
      'ornek': 'قَلَم (kalem) - kalem',
      'aciklama': 'Boğazdan çıkan kalın "k" harfidir.',
    },
    {
      'harf': 'ك',
      'okunus': 'Kef',
      'kategori': 'temel',
      'ornek': 'كَلِمَة (kelime) - kelime',
      'aciklama': 'İnce "k" harfidir.',
    },
    {
      'harf': 'ل',
      'okunus': 'Lam',
      'kategori': 'temel',
      'ornek': 'لَيْلَة (leyle) - gece',
      'aciklama': 'Dil harfidir.',
    },
    {
      'harf': 'م',
      'okunus': 'Mim',
      'kategori': 'dudak',
      'ornek': 'مَاء (ma) - su',
      'aciklama': 'Dudak harfidir.',
    },
    {
      'harf': 'ن',
      'okunus': 'Nun',
      'kategori': 'temel',
      'ornek': 'نُور (nur) - ışık',
      'aciklama': 'Burun harfidir.',
    },
    {
      'harf': 'ه',
      'okunus': 'He',
      'kategori': 'temel',
      'ornek': 'هُوَ (huve) - o',
      'aciklama': 'Nefes harfidir.',
    },
    {
      'harf': 'و',
      'okunus': 'Vav',
      'kategori': 'dudak',
      'ornek': 'وَلَد (veled) - çocuk',
      'aciklama': 'Dudak harfidir.',
    },
    {
      'harf': 'ي',
      'okunus': 'Ye',
      'kategori': 'temel',
      'ornek': 'يَوْم (yevm) - gün',
      'aciklama': 'Dil harfidir.',
    },
  ];

  final List<Map<String, String>> _tecvitKurallari = [
    {
      'baslik': 'İdğam (İdgam)',
      'ornek': 'مِن رَّبِّهِمْ',
      'aciklama': 'Nun-i sakin veya tenvin sonrası belirli harfler geldiğinde birleştirilerek okunur.',
    },
    {
      'baslik': 'İhfa (Gizleme)',
      'ornek': 'مَن يَعْمَلْ',
      'aciklama': 'Nun-i sakin veya tenvin sonrası 15 harf geldiğinde gizli okunur.',
    },
    {
      'baslik': 'İklab (Çevirme)',
      'ornek': 'سَمِيعٌ بَصِيرٌ',
      'aciklama': 'Nun-i sakin veya tenvin sonrası "be" harfi geldiğinde "mim" gibi okunur.',
    },
    {
      'baslik': 'İzhar (Açıklama)',
      'ornek': 'مِنْ أَنفُسِهِمْ',
      'aciklama': 'Nun-i sakin veya tenvin sonrası boğaz harfleri geldiğinde açık okunur.',
    },
    {
      'baslik': 'Kalkale',
      'ornek': 'قَدْ - طَبْعَ',
      'aciklama': 'ق ط ب ج د harfleri sakin okunduğunda sıçratılarak telaffuz edilir.',
    },
    {
      'baslik': 'Med-i Tabii',
      'ornek': 'قَالَ - قِيلَ',
      'aciklama': '2 elif uzunluğunda normal uzatma.',
    },
    {
      'baslik': 'Med-i Lazım',
      'ornek': 'الصَّاخَّةُ',
      'aciklama': '6 elif uzunluğunda zorunlu uzatma.',
    },
    {
      'baslik': 'Gunne',
      'ornek': 'السَّمَاءِ',
      'aciklama': 'Mim ve nun harflerinin şeddeli okunuşu.',
    },
    {
      'baslik': 'Tağliz (Kalınlaştırma)',
      'ornek': 'اللَّهُ',
      'aciklama': 'Lam harfinin kalın okunması.',
    },
    {
      'baslik': 'Vakıf (Durma)',
      'ornek': 'الرَّحْمَنِ',
      'aciklama': 'Ayet sonunda veya nefes alırken dururken hareke düşer.',
    },
  ];
}

// Dekoratif nokta deseni için custom painter
class _DotPatternPainter extends CustomPainter {
  final Color color;

  _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += 20) {
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Test sayfası placeholder
class ElifBaTestSayfa extends StatelessWidget {
  const ElifBaTestSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elif-Ba Testi')),
      body: const Center(child: Text('Test sayfası yakında...')),
    );
  }
}
