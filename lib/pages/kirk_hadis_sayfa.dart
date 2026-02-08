import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class KirkHadisSayfa extends StatefulWidget {
  const KirkHadisSayfa({super.key});

  @override
  State<KirkHadisSayfa> createState() => _KirkHadisSayfaState();
}

class _KirkHadisSayfaState extends State<KirkHadisSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  int _seciliIndex = 0;
  final PageController _pageController = PageController();
  final ScrollController _numberScrollController = ScrollController();
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadFontScale();
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble('hadis_font_scale') ?? 1.0;
    if (mounted) {
      setState(() {
        _fontScale = scale;
      });
    }
  }

  Future<void> _saveFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hadis_font_scale', _fontScale);
  }

  void _increaseFontSize() {
    if (_fontScale < 2.0) {
      setState(() {
        _fontScale += 0.1;
      });
      _saveFontScale();
    }
  }

  void _decreaseFontSize() {
    if (_fontScale > 0.7) {
      setState(() {
        _fontScale -= 0.1;
      });
      _saveFontScale();
    }
  }

  // 40 Hadith list sourced from localization files.
  List<Map<String, String>> _getHadisler() {
    final data = _languageService['forty_hadith_list'];
    if (data is List) {
      return data.map<Map<String, String>>((item) {
        if (item is Map) {
          return {
            'no': item['no']?.toString() ?? '',
            'baslik': item['baslik']?.toString() ?? '',
            'arapca': item['arapca']?.toString() ?? '',
            'turkce': item['turkce']?.toString() ?? '',
            'kaynak': item['kaynak']?.toString() ?? '',
          };
        }
        return {
          'no': '',
          'baslik': '',
          'arapca': '',
          'turkce': '',
          'kaynak': '',
        };
      }).toList();
    }
    return const [];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _numberScrollController.dispose();
    super.dispose();
  }

  void _scrollToCenter(int index) {
    // Each button width is 48 (40 + 2*4 margin).
    const itemWidth = 48.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    _numberScrollController.animateTo(
      targetOffset.clamp(0.0, _numberScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final hadisler = _getHadisler();

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _languageService['forty_hadith'] ?? '40 HADITH',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: renkler.yaziPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: _decreaseFontSize,
            tooltip: _languageService['font_decrease'] ?? 'Decrease text',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: _increaseFontSize,
            tooltip: _languageService['font_increase'] ?? 'Increase text',
          ),
        ],
      ),
      body: hadisler.isEmpty
          ? Center(
              child: Text(
                _languageService['no_data_found'] ?? 'No data found',
                style: TextStyle(color: renkler.yaziSecondary),
              ),
            )
          : Container(
              decoration: renkler.arkaPlanGradient != null
                  ? BoxDecoration(gradient: renkler.arkaPlanGradient)
                  : null,
              child: Column(
                children: [
                  // Hadith number selector.
                  Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      controller: _numberScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: hadisler.length,
                      itemBuilder: (context, index) {
                        final isSecili = index == _seciliIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _seciliIndex = index);
                            _scrollToCenter(index);
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSecili
                                  ? renkler.vurgu
                                  : renkler.kartArkaPlan,
                              border: Border.all(
                                color: isSecili ? renkler.vurgu : renkler.ayirac,
                                width: 1,
                              ),
                              boxShadow: isSecili
                                  ? [
                                      BoxShadow(
                                        color: renkler.vurgu.withOpacity(0.3),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isSecili
                                    ? Colors.white
                                    : renkler.yaziSecondary,
                                fontWeight: isSecili
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Hadith content.
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: hadisler.length,
                      onPageChanged: (index) {
                        setState(() => _seciliIndex = index);
                        _scrollToCenter(index);
                      },
                      itemBuilder: (context, index) {
                        final hadis = hadisler[index];
                        return _buildHadisKarti(hadis, renkler);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHadisKarti(Map<String, String> hadis, TemaRenkleri renkler) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: renkler.vurgu.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: renkler.vurgu.withOpacity(0.1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hadis['no']!,
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hadis['baslik']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 24 * _fontScale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Arabic text.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: renkler.vurgu.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote, color: renkler.vurgu, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _languageService['hadith_arabic_label'] ?? 'Arabic',
                      style: TextStyle(
                        color: renkler.vurgu,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hadis['arapca']!,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 22 * _fontScale,
                    height: 2,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Translation text.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: renkler.vurguSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                        _languageService['hadith_translation_label'] ??
                          'Translation',
                      style: TextStyle(
                        color: renkler.vurguSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hadis['turkce']!,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 16 * _fontScale,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Source.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: renkler.vurgu.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_books, color: renkler.vurgu, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_languageService['hadith_source_label'] ?? 'Source'}: ${hadis['kaynak']}',
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
