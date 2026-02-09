import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class IbadetSayfa extends StatefulWidget {
  const IbadetSayfa({super.key});

  @override
  State<IbadetSayfa> createState() => _IbadetSayfaState();
}

class _IbadetSayfaState extends State<IbadetSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onChanged);
    _languageService.addListener(_onChanged);
    _loadFontScale();
  }

  @override
  void dispose() {
    _temaService.removeListener(_onChanged);
    _languageService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontScale = prefs.getDouble('ibadet_font_scale') ?? 1.0;
    });
  }

  Future<void> _saveFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ibadet_font_scale', _fontScale);
  }

  void _increaseFontSize() {
    if (_fontScale < 1.5) {
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

  static List<String> _items(
    LanguageService lang,
    String key,
    List<String> fallback,
  ) {
    final data = lang[key];
    if (data is List) {
      return data.map((item) => item.toString()).toList();
    }
    return fallback;
  }

  static List<_IbadetContent> _getIcerikler(LanguageService lang) => [
    _IbadetContent(
      title: lang['prayer'] ?? '',
      subtitle:
          lang['prayer_desc'] ?? '',
      icon: Icons.mosque,
      sections: [
        _IbadetSection(
          title: lang['prayer_summary'] ?? '',
          items: _items(lang, 'ibadet_prayer_summary_items', const []),
        ),
        _IbadetSection(
          title: lang['prayer_conditions'] ?? '',
          items: _items(lang, 'ibadet_prayer_conditions_items', const []),
        ),
        _IbadetSection(
          title: lang['prayer_wajib'] ?? '',
          items: _items(lang, 'ibadet_prayer_wajib_items', const []),
        ),
        _IbadetSection(
          title: lang['prayer_sunnah'] ?? '',
          items: _items(lang, 'ibadet_prayer_sunnah_items', const []),
        ),
        _IbadetSection(
          title: lang['how_to_pray'] ?? '',
          items: _items(lang, 'ibadet_how_to_pray_items', const []),
        ),
      ],
    ),
    _IbadetContent(
      title: lang['32_farz'] ?? '',
      subtitle:
          lang['32_farz_desc'] ?? '',
      icon: Icons.format_list_numbered,
      sections: [
        _IbadetSection(
          title: lang['faith_conditions'] ?? '',
          items: _items(lang, 'ibadet_32_faith_conditions_items', const []),
        ),
        _IbadetSection(
          title: lang['islam_conditions'] ?? '',
          items: _items(lang, 'ibadet_32_islam_conditions_items', const []),
        ),
        _IbadetSection(
          title: lang['wudu_farz'] ?? '',
          items: _items(lang, 'ibadet_32_wudu_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['ghusl_farz'] ?? '',
          items: _items(lang, 'ibadet_32_ghusl_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['tayammum_farz'] ?? '',
          items: _items(lang, 'ibadet_32_tayammum_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['prayer_farz'] ?? '',
          items: _items(lang, 'ibadet_32_prayer_farz_items', const []),
        ),
      ],
    ),
    _IbadetContent(
      title: lang['54_farz'] ?? '',
      subtitle:
          lang['54_farz_desc'] ?? '',
      icon: Icons.checklist,
      sections: [
        _IbadetSection(
          title: lang['faith_conditions'] ?? '',
          items: _items(lang, 'ibadet_faith_conditions_items', const []),
        ),
        _IbadetSection(
          title: lang['islam_conditions'] ?? '',
          items: _items(lang, 'ibadet_islam_conditions_items', const []),
        ),
        _IbadetSection(
          title: lang['wudu_farz'] ?? '',
          items: _items(lang, 'ibadet_wudu_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['ghusl_farz'] ?? '',
          items: _items(lang, 'ibadet_ghusl_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['tayammum_farz'] ?? '',
          items: _items(lang, 'ibadet_tayammum_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['prayer_farz'] ?? '',
          items: _items(lang, 'ibadet_prayer_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['heart_farz'] ?? '',
          items: _items(lang, 'ibadet_heart_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['tongue_farz'] ?? '',
          items: _items(lang, 'ibadet_tongue_farz_items', const []),
        ),
        _IbadetSection(
          title: lang['body_farz'] ?? '',
          items: _items(lang, 'ibadet_body_farz_items', const []),
        ),
      ],
    ),
    _IbadetContent(
      title: lang['friday_prayer'] ?? '',
      subtitle: lang['friday_prayer_desc'] ?? '',
      icon: Icons.calendar_today,
      sections: [
        _IbadetSection(
          title: lang['friday_importance'] ?? '',
          items: _items(lang, 'ibadet_friday_importance_items', const []),
        ),
        _IbadetSection(
          title: lang['friday_conditions'] ?? '',
          items: _items(lang, 'ibadet_friday_conditions_items', const []),
        ),
        _IbadetSection(
          title: lang['friday_how_to_pray'] ?? '',
          items: _items(lang, 'ibadet_friday_how_to_pray_items', const []),
        ),
        _IbadetSection(
          title: lang['friday_etiquette'] ?? '',
          items: _items(lang, 'ibadet_friday_etiquette_items', const []),
        ),
      ],
    ),
    _IbadetContent(
      title: lang['funeral_prayer'] ?? '',
      subtitle: lang['funeral_prayer_desc'] ?? '',
      icon: Icons.brightness_3,
      sections: [
        _IbadetSection(
          title: lang['funeral_importance'] ?? '',
          items: _items(lang, 'ibadet_funeral_importance_items', const []),
        ),
        _IbadetSection(
          title: lang['funeral_conditions'] ?? '',
          items: _items(lang, 'ibadet_funeral_conditions_items', const []),
        ),
        _IbadetSection(
          title: lang['funeral_how_to_pray'] ?? '',
          items: _items(lang, 'ibadet_funeral_how_to_pray_items', const []),
        ),
        _IbadetSection(
          title: lang['funeral_dua'] ?? '',
          items: _items(lang, 'ibadet_funeral_dua_items', const []),
        ),
        _IbadetSection(
          title: lang['funeral_steps'] ?? '',
          items: _items(lang, 'ibadet_funeral_steps_items', const []),
        ),
      ],
    ),
    _IbadetContent(
      title: lang['wudu'] ?? '',
      subtitle: lang['wudu_desc'] ?? '',
      icon: Icons.water_drop,
      sections: [
        _IbadetSection(
          title: lang['wudu_farz'] ?? '',
          items: _items(lang, 'ibadet_wudu_farz_detail_items', const []),
        ),
        _IbadetSection(
          title: lang['wudu_sunnah'] ?? '',
          items: _items(lang, 'ibadet_wudu_sunnah_items', const []),
        ),
        _IbadetSection(
          title: lang['wudu_breakers'] ?? '',
          items: _items(lang, 'ibadet_wudu_breakers_items', const []),
        ),
        _IbadetSection(
          title: lang['wudu_how'] ?? '',
          items: _items(lang, 'ibadet_wudu_how_items', const []),
        ),
      ],
    ),
    _IbadetContent(
      title: lang['tayammum'] ?? '',
      subtitle:
          lang['tayammum_desc'] ?? '',
      icon: Icons.landscape,
      sections: [
        _IbadetSection(
          title: lang['tayammum_when'] ?? '',
          items: _items(lang, 'ibadet_tayammum_when_items', const []),
        ),
        _IbadetSection(
          title: lang['tayammum_farz'] ?? '',
          items: _items(lang, 'ibadet_tayammum_farz_detail_items', const []),
        ),
        _IbadetSection(
          title: lang['tayammum_how'] ?? '',
          items: _items(lang, 'ibadet_tayammum_how_items', const []),
        ),
        _IbadetSection(
          title: lang['tayammum_breakers'] ?? '',
          items: _items(lang, 'ibadet_tayammum_breakers_items', const []),
        ),
      ],
    ),
    _IbadetContent(
      title: lang['prayer_duas'] ?? '',
      subtitle:
          lang['prayer_duas_desc'] ?? '',
      icon: Icons.menu_book,
      sections: [
        _IbadetSection(
          title: lang['ibadet_fatiha_title'] ?? '',
          items: _items(lang, 'ibadet_fatiha_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_inshirah_title'] ?? '',
          items: _items(lang, 'ibadet_inshirah_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_tin_title'] ?? '',
          items: _items(lang, 'ibadet_tin_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_alak_title'] ?? '',
          items: _items(lang, 'ibadet_alak_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_kadir_title'] ?? '',
          items: _items(lang, 'ibadet_kadir_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_beyyine_title'] ?? '',
          items: _items(lang, 'ibadet_beyyine_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_zilzal_title'] ?? '',
          items: _items(lang, 'ibadet_zilzal_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_adiyat_title'] ?? '',
          items: _items(lang, 'ibadet_adiyat_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_karia_title'] ?? '',
          items: _items(lang, 'ibadet_karia_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_tekasur_title'] ?? '',
          items: _items(lang, 'ibadet_tekasur_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_asr_title'] ?? '',
          items: _items(lang, 'ibadet_asr_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_humeze_title'] ?? '',
          items: _items(lang, 'ibadet_humeze_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_fil_title'] ?? '',
          items: _items(lang, 'ibadet_fil_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_kureys_title'] ?? '',
          items: _items(lang, 'ibadet_kureys_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_maun_title'] ?? '',
          items: _items(lang, 'ibadet_maun_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_kevser_title'] ?? '',
          items: _items(lang, 'ibadet_kevser_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_kafirun_title'] ?? '',
          items: _items(lang, 'ibadet_kafirun_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_nasr_title'] ?? '',
          items: _items(lang, 'ibadet_nasr_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_tebbet_title'] ?? '',
          items: _items(lang, 'ibadet_tebbet_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_ihlas_title'] ?? '',
          items: _items(lang, 'ibadet_ihlas_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_felak_title'] ?? '',
          items: _items(lang, 'ibadet_felak_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_nas_title'] ?? '',
          items: _items(lang, 'ibadet_nas_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_subhaneke_title'] ?? '',
          items: _items(lang, 'ibadet_subhaneke_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_ettehiyyat_title'] ?? '',
          items: _items(lang, 'ibadet_ettehiyyat_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_salli_barik_title'] ?? '',
          items: _items(lang, 'ibadet_salli_barik_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_ruku_secde_title'] ?? '',
          items: _items(lang, 'ibadet_ruku_secde_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_rabbena_title'] ?? '',
          items: _items(lang, 'ibadet_rabbena_items', const []),
        ),
        _IbadetSection(
          title: lang['ibadet_kunut_title'] ?? '',
          items: _items(lang, 'ibadet_kunut_items', const []),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final icerikler = _getIcerikler(_languageService);

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
        actions: [
          // Decrease font size.
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: _decreaseFontSize,
            tooltip: _languageService['decrease_font'] ?? '',
          ),
          // Increase font size.
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: _increaseFontSize,
            tooltip: _languageService['increase_font'] ?? '',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: icerikler.length,
        itemBuilder: (context, index) {
          final content = icerikler[index];
          return _IbadetCard(
            content: content,
            renkler: renkler,
            fontScale: _fontScale,
          );
        },
      ),
    );
  }
}

class _IbadetCard extends StatelessWidget {
  final _IbadetContent content;
  final TemaRenkleri renkler;
  final double fontScale;

  const _IbadetCard({
    required this.content,
    required this.renkler,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: renkler.kartArkaPlan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: renkler.vurgu.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(content.icon, color: renkler.vurgu),
        ),
        title: Text(
          content.title,
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          content.subtitle,
          style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: renkler.yaziSecondary),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _IbadetDetaySayfa(
                content: content,
                initialFontScale: fontScale,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IbadetDetaySayfa extends StatefulWidget {
  final _IbadetContent content;
  final double initialFontScale;

  const _IbadetDetaySayfa({required this.content, this.initialFontScale = 1.0});

  @override
  State<_IbadetDetaySayfa> createState() => _IbadetDetaySayfaState();
}

class _IbadetDetaySayfaState extends State<_IbadetDetaySayfa> {
  late double _fontScale;
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _fontScale = widget.initialFontScale;
    _loadFontScale();
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ibadet_detail_font_scale_${widget.content.title}';
    setState(() {
      _fontScale = prefs.getDouble(key) ?? 1.0;
    });
  }

  Future<void> _saveFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ibadet_detail_font_scale_${widget.content.title}';
    await prefs.setDouble(key, _fontScale);
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

  @override
  Widget build(BuildContext context) {
    final temaService = TemaService();
    final renkler = temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          widget.content.title,
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
        actions: [
          // Font kÃ¼Ã§Ã¼lt
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: _decreaseFontSize,
            tooltip: _languageService['decrease_font'] ?? '',
          ),
          // Font Ã¶lÃ§eÄŸi gÃ¶stergesi
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: renkler.vurgu.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(_fontScale * 100).round()}%',
                style: TextStyle(
                  color: renkler.vurgu,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Font bÃ¼yÃ¼t
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: _increaseFontSize,
            tooltip: _languageService['increase_font'] ?? '',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  renkler.vurgu.withOpacity(0.2),
                  renkler.vurgu.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(widget.content.icon, color: renkler.vurgu, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.content.subtitle,
                    style: TextStyle(
                      color: renkler.yaziSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...widget.content.sections.map(
            (section) => _IbadetSectionCard(
              section: section,
              renkler: renkler,
              fontScale: _fontScale,
            ),
          ),
        ],
      ),
    );
  }
}

class _IbadetSectionCard extends StatelessWidget {
  final _IbadetSection section;
  final TemaRenkleri renkler;
  final double fontScale;

  static final RegExp _arabicRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  static const String _bullet = '\u2022';
  static const String _okunusuLabel = 'Okunu\u015Fu:';
  static const String _anlamiLabel = 'Anlam\u0131:';

  const _IbadetSectionCard({
    required this.section,
    required this.renkler,
    required this.fontScale,
  });

  static bool _isArabic(String text) => _arabicRegex.hasMatch(text);

  static String _normalizeLabel(String text) {
    var normalized = text.trimLeft();
    if (normalized.startsWith(_bullet)) {
      normalized = normalized.substring(_bullet.length).trimLeft();
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renkler.ayirac),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          iconColor: renkler.vurgu,
          collapsedIconColor: renkler.vurgu,
          title: Text(
            section.title,
            style: TextStyle(
              color: renkler.vurgu,
              fontWeight: FontWeight.bold,
              fontSize: 16 * fontScale,
            ),
          ),
          children: [
            ...section.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: item.isEmpty
                    ? const SizedBox(height: 8)
                    : item.startsWith('---')
                    ? Divider(color: renkler.ayirac, height: 24)
                    : _isArabic(item)
                    ? Container(
                        width: double.infinity,
                        alignment: Alignment.centerRight,
                        child: SelectableText(
                          item,
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontWeight: FontWeight.normal,
                            height: 1.5,
                            fontSize: 18 * fontScale,
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!item.startsWith(' ') &&
                              !item.startsWith(_bullet) &&
                              !RegExp(r'^\d+\.').hasMatch(item) &&
                              !item.contains(':') &&
                              item.length < 50)
                            const SizedBox()
                          else if (item.startsWith(_bullet) ||
                              item.startsWith(' '))
                            const SizedBox()
                          else if (!RegExp(r'^\d+\.').hasMatch(item))
                            Text(
                              '$_bullet ',
                              style: TextStyle(
                                color: renkler.vurgu,
                                fontSize: 14 * fontScale,
                              ),
                            ),
                          Expanded(
                            child: SelectableText(
                              item,
                              style: TextStyle(
                                color:
                                    _normalizeLabel(item).contains(':') &&
                                        !_normalizeLabel(
                                          item,
                                        ).startsWith(_okunusuLabel) &&
                                        !_normalizeLabel(
                                          item,
                                        ).startsWith(_anlamiLabel)
                                    ? renkler.yaziPrimary.withOpacity(0.9)
                                    : renkler.yaziPrimary,
                                fontWeight:
                                    (_normalizeLabel(item).contains(':') &&
                                            _normalizeLabel(item).length < 40) ||
                                        _normalizeLabel(
                                          item,
                                        ).startsWith(_okunusuLabel) ||
                                        _normalizeLabel(
                                          item,
                                        ).startsWith(_anlamiLabel)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                height: 1.5,
                                fontSize: 14 * fontScale,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IbadetContent {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_IbadetSection> sections;

  const _IbadetContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sections,
  });
}

class _IbadetSection {
  final String title;
  final List<String> items;

  const _IbadetSection({required this.title, required this.items});
}



