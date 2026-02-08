import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class HakkindaSayfa extends StatefulWidget {
  const HakkindaSayfa({super.key});

  @override
  State<HakkindaSayfa> createState() => _HakkindaSayfaState();
}

class _HakkindaSayfaState extends State<HakkindaSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
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
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: renkler.vurgu,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _languageService['about'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      renkler.vurgu,
                      renkler.vurgu.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App logo and name
                  _uygulamaBilgisi(renkler),
                  const SizedBox(height: 24),

                  // Description
                  _baslikVeMetin(
                    _languageService['what_is_huzur_vakti'] ?? '',
                    _languageService['about_desc'] ?? '',
                    renkler,
                  ),
                  const SizedBox(height: 24),

                  // Features
                  _ozelliklerBolumu(renkler),
                  const SizedBox(height: 24),

                  // Important notes
                  _onemliNotlar(renkler),
                  const SizedBox(height: 24),

                  // Contact
                  _iletisimBolumu(renkler),
                  const SizedBox(height: 24),

                  // Version and copyright
                  _altBilgi(renkler),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uygulamaBilgisi(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            renkler.vurgu.withValues(alpha: 0.2),
            renkler.vurgu.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renkler.vurgu.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: renkler.vurgu,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _languageService['app_name'] ?? '',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _languageService['prayer_times_assistant'] ?? '',
            style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${_languageService['version'] ?? ''} 1.0.0+1',
            style: TextStyle(
              color: renkler.yaziSecondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _baslikVeMetin(String baslik, String metin, TemaRenkleri renkler) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          metin,
          style: TextStyle(
            color: renkler.yaziSecondary,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _ozelliklerBolumu(TemaRenkleri renkler) {
    final ozellikler = [
      // Core features
      {
        'ikon': Icons.access_time,
        'renk': Colors.blue,
        'baslik': _languageService['feature_prayer_times'] ?? '',
        'aciklama':
          _languageService['feature_prayer_times_desc'] ?? '',
      },
      {
        'ikon': Icons.calendar_month,
        'renk': Colors.green,
        'baslik': _languageService['feature_imsakiye'] ?? '',
        'aciklama':
          _languageService['feature_imsakiye_desc'] ?? '',
      },
      {
        'ikon': Icons.alarm,
        'renk': Colors.red,
        'baslik':
          _languageService['feature_notifications'] ?? '',
        'aciklama':
          _languageService['feature_notifications_desc'] ?? '',
      },
      {
        'ikon': Icons.do_not_disturb_on,
        'renk': Colors.amber,
        'baslik':
          _languageService['feature_auto_silent'] ?? '',
        'aciklama':
          _languageService['feature_auto_silent_desc'] ?? '',
      },
      {
        'ikon': Icons.explore,
        'renk': Colors.green,
        'baslik': _languageService['feature_qibla'] ?? '',
        'aciklama':
          _languageService['feature_qibla_desc'] ?? '',
      },
      {
        'ikon': Icons.mosque,
        'renk': Colors.lightGreen,
        'baslik':
          _languageService['feature_nearby_mosques'] ?? '',
        'aciklama':
          _languageService['feature_nearby_mosques_desc'] ?? '',
      },
      {
        'ikon': Icons.menu_book,
        'renk': Colors.deepOrange,
        'baslik': _languageService['feature_content'] ?? '',
        'aciklama':
          _languageService['feature_content_desc'] ?? '',
      },
      {
        'ikon': Icons.blur_circular,
        'renk': Colors.purple,
        'baslik': _languageService['feature_dhikr'] ?? '',
        'aciklama':
          _languageService['feature_dhikr_desc'] ?? '',
      },
      {
        'ikon': Icons.auto_awesome,
        'renk': Colors.indigo,
        'baslik': _languageService['feature_special_days'] ?? '',
        'aciklama':
          _languageService['feature_special_days_desc'] ?? '',
      },
      {
        'ikon': Icons.date_range,
        'renk': Colors.deepOrange,
        'baslik':
          _languageService['feature_dual_calendar'] ?? '',
        'aciklama':
          _languageService['feature_dual_calendar_desc'] ?? '',
      },
      {
        'ikon': Icons.palette,
        'renk': Colors.pinkAccent,
        'baslik': _languageService['feature_themes'] ?? '',
        'aciklama':
          _languageService['feature_themes_desc'] ?? '',
      },
      {
        'ikon': Icons.language,
        'renk': Colors.blueGrey,
        'baslik': _languageService['feature_languages'] ?? '',
        'aciklama':
          _languageService['feature_languages_desc'] ?? '',
      },
      {
        'ikon': Icons.location_city,
        'renk': Colors.blue,
        'baslik':
          _languageService['feature_multiple_locations'] ?? '',
        'aciklama':
          _languageService['feature_multiple_locations_desc'] ?? '',
      },
      {
        'ikon': Icons.timer,
        'renk': Colors.cyan,
        'baslik': _languageService['feature_counters'] ?? '',
        'aciklama':
          _languageService['feature_counters_desc'] ?? '',
      },
      {
        'ikon': Icons.widgets,
        'renk': Colors.pink,
        'baslik':
          _languageService['feature_widgets'] ?? '',
        'aciklama':
          _languageService['feature_widgets_desc'] ?? '',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageService['features'] ?? '',
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...ozellikler.map(
          (ozellik) => _ozellikKarti(
            renkler,
            ozellik['ikon'] as IconData,
            ozellik['renk'] as Color,
            ozellik['baslik'] as String,
            ozellik['aciklama'] as String,
          ),
        ),
      ],
    );
  }

  Widget _ozellikKarti(
    TemaRenkleri renkler,
    IconData ikon,
    Color renk,
    String baslik,
    String aciklama,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renkler.ayirac.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, color: renk, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aciklama,
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onemliNotlar(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[700], size: 24),
              const SizedBox(width: 12),
              Text(
                _languageService['important_info'] ?? '',
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _notSatiri(
            '• ${_languageService['diyanet_data_note'] ?? ''}',
            renkler,
          ),
          _notSatiri(
            '• ${_languageService['battery_optimization_note'] ?? ''}',
            renkler,
          ),
          _notSatiri(
            '• ${_languageService['location_permission_note'] ?? ''}',
            renkler,
          ),
          _notSatiri(
            '• ${_languageService['internet_note'] ?? ''}',
            renkler,
          ),
        ],
      ),
    );
  }

  Widget _notSatiri(String metin, TemaRenkleri renkler) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        metin,
        style: TextStyle(
          color: renkler.yaziSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _iletisimBolumu(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService['contact_support'] ?? '',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _iletisimSatiri(
            Icons.email,
            _languageService['email'] ?? '',
            ' ',
            renkler,
          ),
          _iletisimSatiri(
            Icons.web,
            _languageService['web'] ?? '',
            ' ',
            renkler,
          ),
          _iletisimSatiri(
            Icons.bug_report,
            _languageService['bug_report'] ?? '',
            ' ',
            renkler,
          ),
        ],
      ),
    );
  }

  Widget _iletisimSatiri(
    IconData ikon,
    String baslik,
    String deger,
    TemaRenkleri renkler,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(ikon, color: renkler.vurgu, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
                ),
                Text(
                  deger,
                  style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _altBilgi(TemaRenkleri renkler) {
    return Column(
      children: [
        Divider(color: renkler.ayirac),
        const SizedBox(height: 16),

        // Play Store button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () {
              // Play Store link (currently disabled)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _languageService['coming_soon_playstore'] ?? '',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.shop, size: 20),
            label: Text(
              _languageService['rate_on_playstore'] ?? '',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          '© 2026 ${_languageService['app_name'] ?? ''}',
          style: TextStyle(
            color: renkler.yaziSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _languageService['all_rights_reserved'] ?? '',
          style: TextStyle(
            color: renkler.yaziSecondary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _languageService['for_allah'] ?? '',
          style: TextStyle(
            color: renkler.vurgu,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _languageService['developer_name'] ?? '',
          style: TextStyle(
            color: renkler.yaziSecondary.withValues(alpha: 0.6),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
