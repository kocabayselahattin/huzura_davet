import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class KuranSayfa extends StatefulWidget {
  const KuranSayfa({super.key});

  @override
  State<KuranSayfa> createState() => _KuranSayfaState();
}

class _KuranSayfaState extends State<KuranSayfa>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  List<Sure> _sureler = [];
  bool _yukleniyor = true;
  late TabController _tabController;
  int? _sonOkunanSureNo;
  int? _sonOkunanAyetNo;
  String? _sonOkunanSureAd;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sureleriYukle();
    _sonOkunanYeriYukle();
  }

  Future<void> _sonOkunanYeriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sonOkunanSureNo = prefs.getInt('son_okunan_sure_no');
        _sonOkunanAyetNo = prefs.getInt('son_okunan_ayet_no');
        _sonOkunanSureAd = prefs.getString('son_okunan_sure_ad');
      });
    }
  }

  void _kaldirKaldiginYerden() {
    if (_sonOkunanSureNo != null) {
      final resumeAyetNo = _getResumeAyetNo();
      final sure = _sureler.firstWhere(
        (s) => s.no == _sonOkunanSureNo,
        orElse: () => _sureler.first,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SureDetaySayfa(sure: sure, baslangicAyetNo: resumeAyetNo),
        ),
      ).then((_) => _sonOkunanYeriYukle());
    }
  }

  int? _getResumeAyetNo() {
    if (_sonOkunanAyetNo == null || _sonOkunanSureNo == null) {
      return null;
    }

    final sure = _sureler.firstWhere(
      (s) => s.no == _sonOkunanSureNo,
      orElse: () => _sureler.first,
    );

    final nextAyet = _sonOkunanAyetNo! + 1;
    if (nextAyet <= sure.ayetSayisi) {
      return nextAyet;
    }

    return sure.ayetSayisi;
  }

  int? _getCuzNoForSureAyet(int sureNo, int ayetNo) {
    for (final cuz in _cuzler) {
      final afterStart =
          (sureNo > cuz.baslangicSureNo) ||
          (sureNo == cuz.baslangicSureNo && ayetNo >= cuz.baslangicAyetNo);
      final beforeEnd =
          (sureNo < cuz.bitisSureNo) ||
          (sureNo == cuz.bitisSureNo && ayetNo <= cuz.bitisAyetNo);

      if (afterStart && beforeEnd) {
        return cuz.no;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sureleriYukle() async {
    setState(() {
      _sureler = _tumSureler;
      _yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _languageService['quran'] ?? 'HOLY QURAN',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: renkler.vurgu,
          labelColor: renkler.vurgu,
          unselectedLabelColor: renkler.yaziSecondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(text: _languageService['surahs_tab'] ?? 'SURAS'),
            Tab(text: _languageService['juzs_tab'] ?? 'JUZS'),
          ],
        ),
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: _yukleniyor
            ? Center(child: CircularProgressIndicator(color: renkler.vurgu))
            : TabBarView(
                controller: _tabController,
                children: [
                  // Surahs tab
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount:
                        _sureler.length + (_sonOkunanSureNo != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Resume card at the top
                      if (index == 0 && _sonOkunanSureNo != null) {
                        return _buildKaldiginYerdenKarti(renkler);
                      }
                      // Regular surah cards
                      final sureIndex = _sonOkunanSureNo != null
                          ? index - 1
                          : index;
                      final sure = _sureler[sureIndex];
                      return _buildSureKarti(sure, renkler);
                    },
                  ),
                  // Juz tab
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount:
                        _cuzler.length + (_sonOkunanSureNo != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Resume card at the top
                      if (index == 0 && _sonOkunanSureNo != null) {
                        return _buildKaldiginYerdenKarti(renkler);
                      }
                      // Regular juz cards
                      final cuzIndex = _sonOkunanSureNo != null
                          ? index - 1
                          : index;
                      final cuz = _cuzler[cuzIndex];
                      return _buildCuzKarti(cuz, renkler);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildKaldiginYerdenKarti(TemaRenkleri renkler) {
    final resumeAyetNo = _getResumeAyetNo();
    final cuzNo = (_sonOkunanSureNo != null && resumeAyetNo != null)
        ? _getCuzNoForSureAyet(_sonOkunanSureNo!, resumeAyetNo)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            renkler.vurgu.withOpacity(0.8),
            renkler.vurguSecondary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: renkler.vurgu.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _kaldirKaldiginYerden,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _languageService['resume_reading'] ??
                          'CONTINUE WHERE YOU LEFT OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _sonOkunanSureAd ??
                          (_languageService['chapter'] ?? 'Surah'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (resumeAyetNo != null)
                        Text(
                          '${cuzNo != null ? '${_languageService['juz'] ?? 'Juz'} $cuzNo • ' : ''}${_sonOkunanSureAd ?? (_languageService['chapter'] ?? 'Surah')} • ${_languageService['verse'] ?? 'Verse'} $resumeAyetNo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.play_circle_fill,
                  color: Colors.white.withOpacity(0.9),
                  size: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSureKarti(Sure sure, TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SureDetaySayfa(sure: sure),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Surah number
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: renkler.vurgu.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${sure.no}',
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Surah info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sure.turkceAd,
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sure.ayetSayisi} ${_languageService['verse'] ?? 'Verse'} • ${sure.indirildigiYer}',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arabic name
                Text(
                  sure.arapca,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 22,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCuzKarti(Cuz cuz, TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CuzDetaySayfa(cuz: cuz)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Juz number
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: renkler.vurgu.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${cuz.no}',
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Juz info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_languageService['juz'] ?? 'Juz'} ${cuz.no}',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cuz.baslangicSure} - ${cuz.bitisSure}',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arabic text (Juz)
                Text(
                  'جُزْءُ ${_getArabicNumber(cuz.no)}',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 20,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getArabicNumber(int number) {
    final arabicNumbers = {
      1: '١',
      2: '٢',
      3: '٣',
      4: '٤',
      5: '٥',
      6: '٦',
      7: '٧',
      8: '٨',
      9: '٩',
      10: '١٠',
      11: '١١',
      12: '١٢',
      13: '١٣',
      14: '١٤',
      15: '١٥',
      16: '١٦',
      17: '١٧',
      18: '١٨',
      19: '١٩',
      20: '٢٠',
      21: '٢١',
      22: '٢٢',
      23: '٢٣',
      24: '٢٤',
      25: '٢٥',
      26: '٢٦',
      27: '٢٧',
      28: '٢٨',
      29: '٢٩',
      30: '٣٠',
    };
    return arabicNumbers[number] ?? '$number';
  }

  // Juz list (30 juz)
  final List<Cuz> _cuzler = [
    Cuz(
      no: 1,
      baslangicSure: 'Fatiha 1',
      bitisSure: 'Bakara 141',
      baslangicSureNo: 1,
      baslangicAyetNo: 1,
      bitisSureNo: 2,
      bitisAyetNo: 141,
    ),
    Cuz(
      no: 2,
      baslangicSure: 'Bakara 142',
      bitisSure: 'Bakara 252',
      baslangicSureNo: 2,
      baslangicAyetNo: 142,
      bitisSureNo: 2,
      bitisAyetNo: 252,
    ),
    Cuz(
      no: 3,
      baslangicSure: 'Bakara 253',
      bitisSure: 'Âl-i İmrân 92',
      baslangicSureNo: 2,
      baslangicAyetNo: 253,
      bitisSureNo: 3,
      bitisAyetNo: 92,
    ),
    Cuz(
      no: 4,
      baslangicSure: 'Âl-i İmrân 93',
      bitisSure: 'Nisâ 23',
      baslangicSureNo: 3,
      baslangicAyetNo: 93,
      bitisSureNo: 4,
      bitisAyetNo: 23,
    ),
    Cuz(
      no: 5,
      baslangicSure: 'Nisâ 24',
      bitisSure: 'Nisâ 147',
      baslangicSureNo: 4,
      baslangicAyetNo: 24,
      bitisSureNo: 4,
      bitisAyetNo: 147,
    ),
    Cuz(
      no: 6,
      baslangicSure: 'Nisâ 148',
      bitisSure: 'Mâide 81',
      baslangicSureNo: 4,
      baslangicAyetNo: 148,
      bitisSureNo: 5,
      bitisAyetNo: 81,
    ),
    Cuz(
      no: 7,
      baslangicSure: 'Mâide 82',
      bitisSure: 'En\'âm 110',
      baslangicSureNo: 5,
      baslangicAyetNo: 82,
      bitisSureNo: 6,
      bitisAyetNo: 110,
    ),
    Cuz(
      no: 8,
      baslangicSure: 'En\'âm 111',
      bitisSure: 'A\'râf 87',
      baslangicSureNo: 6,
      baslangicAyetNo: 111,
      bitisSureNo: 7,
      bitisAyetNo: 87,
    ),
    Cuz(
      no: 9,
      baslangicSure: 'A\'râf 88',
      bitisSure: 'Enfâl 40',
      baslangicSureNo: 7,
      baslangicAyetNo: 88,
      bitisSureNo: 8,
      bitisAyetNo: 40,
    ),
    Cuz(
      no: 10,
      baslangicSure: 'Enfâl 41',
      bitisSure: 'Tevbe 92',
      baslangicSureNo: 8,
      baslangicAyetNo: 41,
      bitisSureNo: 9,
      bitisAyetNo: 92,
    ),
    Cuz(
      no: 11,
      baslangicSure: 'Tevbe 93',
      bitisSure: 'Hûd 5',
      baslangicSureNo: 9,
      baslangicAyetNo: 93,
      bitisSureNo: 11,
      bitisAyetNo: 5,
    ),
    Cuz(
      no: 12,
      baslangicSure: 'Hûd 6',
      bitisSure: 'Yûsuf 52',
      baslangicSureNo: 11,
      baslangicAyetNo: 6,
      bitisSureNo: 12,
      bitisAyetNo: 52,
    ),
    Cuz(
      no: 13,
      baslangicSure: 'Yûsuf 53',
      bitisSure: 'İbrâhîm 52',
      baslangicSureNo: 12,
      baslangicAyetNo: 53,
      bitisSureNo: 14,
      bitisAyetNo: 52,
    ),
    Cuz(
      no: 14,
      baslangicSure: 'Hicr 1',
      bitisSure: 'Nahl 128',
      baslangicSureNo: 15,
      baslangicAyetNo: 1,
      bitisSureNo: 16,
      bitisAyetNo: 128,
    ),
    Cuz(
      no: 15,
      baslangicSure: 'İsrâ 1',
      bitisSure: 'Kehf 74',
      baslangicSureNo: 17,
      baslangicAyetNo: 1,
      bitisSureNo: 18,
      bitisAyetNo: 74,
    ),
    Cuz(
      no: 16,
      baslangicSure: 'Kehf 75',
      bitisSure: 'Tâhâ 135',
      baslangicSureNo: 18,
      baslangicAyetNo: 75,
      bitisSureNo: 20,
      bitisAyetNo: 135,
    ),
    Cuz(
      no: 17,
      baslangicSure: 'Enbiyâ 1',
      bitisSure: 'Hac 78',
      baslangicSureNo: 21,
      baslangicAyetNo: 1,
      bitisSureNo: 22,
      bitisAyetNo: 78,
    ),
    Cuz(
      no: 18,
      baslangicSure: 'Mü\'minûn 1',
      bitisSure: 'Furkân 20',
      baslangicSureNo: 23,
      baslangicAyetNo: 1,
      bitisSureNo: 25,
      bitisAyetNo: 20,
    ),
    Cuz(
      no: 19,
      baslangicSure: 'Furkân 21',
      bitisSure: 'Neml 55',
      baslangicSureNo: 25,
      baslangicAyetNo: 21,
      bitisSureNo: 27,
      bitisAyetNo: 55,
    ),
    Cuz(
      no: 20,
      baslangicSure: 'Neml 56',
      bitisSure: 'Ankebût 45',
      baslangicSureNo: 27,
      baslangicAyetNo: 56,
      bitisSureNo: 29,
      bitisAyetNo: 45,
    ),
    Cuz(
      no: 21,
      baslangicSure: 'Ankebût 46',
      bitisSure: 'Ahzâb 30',
      baslangicSureNo: 29,
      baslangicAyetNo: 46,
      bitisSureNo: 33,
      bitisAyetNo: 30,
    ),
    Cuz(
      no: 22,
      baslangicSure: 'Ahzâb 31',
      bitisSure: 'Yâsîn 27',
      baslangicSureNo: 33,
      baslangicAyetNo: 31,
      bitisSureNo: 36,
      bitisAyetNo: 27,
    ),
    Cuz(
      no: 23,
      baslangicSure: 'Yâsîn 28',
      bitisSure: 'Zuhruf 89',
      baslangicSureNo: 36,
      baslangicAyetNo: 28,
      bitisSureNo: 43,
      bitisAyetNo: 89,
    ),
    Cuz(
      no: 24,
      baslangicSure: 'Zuhruf 90',
      bitisSure: 'Câsiye 37',
      baslangicSureNo: 43,
      baslangicAyetNo: 90,
      bitisSureNo: 45,
      bitisAyetNo: 37,
    ),
    Cuz(
      no: 25,
      baslangicSure: 'Câsiye 38',
      bitisSure: 'Zâriyât 30',
      baslangicSureNo: 45,
      baslangicAyetNo: 38,
      bitisSureNo: 51,
      bitisAyetNo: 30,
    ),
    Cuz(
      no: 26,
      baslangicSure: 'Zâriyât 31',
      bitisSure: 'Hadîd 29',
      baslangicSureNo: 51,
      baslangicAyetNo: 31,
      bitisSureNo: 57,
      bitisAyetNo: 29,
    ),
    Cuz(
      no: 27,
      baslangicSure: 'Mücâdele 1',
      bitisSure: 'Tahrîm 12',
      baslangicSureNo: 58,
      baslangicAyetNo: 1,
      bitisSureNo: 66,
      bitisAyetNo: 12,
    ),
    Cuz(
      no: 28,
      baslangicSure: 'Mülk 1',
      bitisSure: 'Mürselât 50',
      baslangicSureNo: 67,
      baslangicAyetNo: 1,
      bitisSureNo: 77,
      bitisAyetNo: 50,
    ),
    Cuz(
      no: 29,
      baslangicSure: 'Nebe\' 1',
      bitisSure: 'Burûc 22',
      baslangicSureNo: 78,
      baslangicAyetNo: 1,
      bitisSureNo: 85,
      bitisAyetNo: 22,
    ),
    Cuz(
      no: 30,
      baslangicSure: 'Târık 1',
      bitisSure: 'Nâs 6',
      baslangicSureNo: 86,
      baslangicAyetNo: 1,
      bitisSureNo: 114,
      bitisAyetNo: 6,
    ),
  ];

  // 114 Sure listesi
  final List<Sure> _tumSureler = [
    Sure(
      no: 1,
      arapca: 'الفاتحة',
      turkceAd: 'Fatiha',
      ayetSayisi: 7,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 2,
      arapca: 'البقرة',
      turkceAd: 'Bakara',
      ayetSayisi: 286,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 3,
      arapca: 'آل عمران',
      turkceAd: 'Âl-i İmrân',
      ayetSayisi: 200,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 4,
      arapca: 'النساء',
      turkceAd: 'Nisâ',
      ayetSayisi: 176,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 5,
      arapca: 'المائدة',
      turkceAd: 'Mâide',
      ayetSayisi: 120,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 6,
      arapca: 'الأنعام',
      turkceAd: 'En\'âm',
      ayetSayisi: 165,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 7,
      arapca: 'الأعراف',
      turkceAd: 'A\'râf',
      ayetSayisi: 206,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 8,
      arapca: 'الأنفال',
      turkceAd: 'Enfâl',
      ayetSayisi: 75,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 9,
      arapca: 'التوبة',
      turkceAd: 'Tevbe',
      ayetSayisi: 129,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 10,
      arapca: 'يونس',
      turkceAd: 'Yûnus',
      ayetSayisi: 109,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 11,
      arapca: 'هود',
      turkceAd: 'Hûd',
      ayetSayisi: 123,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 12,
      arapca: 'يوسف',
      turkceAd: 'Yûsuf',
      ayetSayisi: 111,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 13,
      arapca: 'الرعد',
      turkceAd: 'Ra\'d',
      ayetSayisi: 43,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 14,
      arapca: 'إبراهيم',
      turkceAd: 'İbrâhîm',
      ayetSayisi: 52,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 15,
      arapca: 'الحجر',
      turkceAd: 'Hicr',
      ayetSayisi: 99,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 16,
      arapca: 'النحل',
      turkceAd: 'Nahl',
      ayetSayisi: 128,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 17,
      arapca: 'الإسراء',
      turkceAd: 'İsrâ',
      ayetSayisi: 111,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 18,
      arapca: 'الكهف',
      turkceAd: 'Kehf',
      ayetSayisi: 110,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 19,
      arapca: 'مريم',
      turkceAd: 'Meryem',
      ayetSayisi: 98,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 20,
      arapca: 'طه',
      turkceAd: 'Tâhâ',
      ayetSayisi: 135,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 21,
      arapca: 'الأنبياء',
      turkceAd: 'Enbiyâ',
      ayetSayisi: 112,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 22,
      arapca: 'الحج',
      turkceAd: 'Hac',
      ayetSayisi: 78,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 23,
      arapca: 'المؤمنون',
      turkceAd: 'Mü\'minûn',
      ayetSayisi: 118,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 24,
      arapca: 'النور',
      turkceAd: 'Nûr',
      ayetSayisi: 64,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 25,
      arapca: 'الفرقان',
      turkceAd: 'Furkân',
      ayetSayisi: 77,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 26,
      arapca: 'الشعراء',
      turkceAd: 'Şuarâ',
      ayetSayisi: 227,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 27,
      arapca: 'النمل',
      turkceAd: 'Neml',
      ayetSayisi: 93,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 28,
      arapca: 'القصص',
      turkceAd: 'Kasas',
      ayetSayisi: 88,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 29,
      arapca: 'العنكبوت',
      turkceAd: 'Ankebût',
      ayetSayisi: 69,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 30,
      arapca: 'الروم',
      turkceAd: 'Rûm',
      ayetSayisi: 60,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 31,
      arapca: 'لقمان',
      turkceAd: 'Lokmân',
      ayetSayisi: 34,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 32,
      arapca: 'السجدة',
      turkceAd: 'Secde',
      ayetSayisi: 30,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 33,
      arapca: 'الأحزاب',
      turkceAd: 'Ahzâb',
      ayetSayisi: 73,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 34,
      arapca: 'سبأ',
      turkceAd: 'Sebe\'',
      ayetSayisi: 54,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 35,
      arapca: 'فاطر',
      turkceAd: 'Fâtır',
      ayetSayisi: 45,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 36,
      arapca: 'يس',
      turkceAd: 'Yâsîn',
      ayetSayisi: 83,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 37,
      arapca: 'الصافات',
      turkceAd: 'Sâffât',
      ayetSayisi: 182,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 38,
      arapca: 'ص',
      turkceAd: 'Sâd',
      ayetSayisi: 88,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 39,
      arapca: 'الزمر',
      turkceAd: 'Zümer',
      ayetSayisi: 75,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 40,
      arapca: 'غافر',
      turkceAd: 'Mü\'min',
      ayetSayisi: 85,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 41,
      arapca: 'فصلت',
      turkceAd: 'Fussilet',
      ayetSayisi: 54,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 42,
      arapca: 'الشورى',
      turkceAd: 'Şûrâ',
      ayetSayisi: 53,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 43,
      arapca: 'الزخرف',
      turkceAd: 'Zuhruf',
      ayetSayisi: 89,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 44,
      arapca: 'الدخان',
      turkceAd: 'Duhân',
      ayetSayisi: 59,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 45,
      arapca: 'الجاثية',
      turkceAd: 'Câsiye',
      ayetSayisi: 37,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 46,
      arapca: 'الأحقاف',
      turkceAd: 'Ahkâf',
      ayetSayisi: 35,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 47,
      arapca: 'محمد',
      turkceAd: 'Muhammed',
      ayetSayisi: 38,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 48,
      arapca: 'الفتح',
      turkceAd: 'Fetih',
      ayetSayisi: 29,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 49,
      arapca: 'الحجرات',
      turkceAd: 'Hucurât',
      ayetSayisi: 18,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 50,
      arapca: 'ق',
      turkceAd: 'Kâf',
      ayetSayisi: 45,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 51,
      arapca: 'الذاريات',
      turkceAd: 'Zâriyât',
      ayetSayisi: 60,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 52,
      arapca: 'الطور',
      turkceAd: 'Tûr',
      ayetSayisi: 49,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 53,
      arapca: 'النجم',
      turkceAd: 'Necm',
      ayetSayisi: 62,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 54,
      arapca: 'القمر',
      turkceAd: 'Kamer',
      ayetSayisi: 55,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 55,
      arapca: 'الرحمن',
      turkceAd: 'Rahmân',
      ayetSayisi: 78,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 56,
      arapca: 'الواقعة',
      turkceAd: 'Vâkıa',
      ayetSayisi: 96,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 57,
      arapca: 'الحديد',
      turkceAd: 'Hadîd',
      ayetSayisi: 29,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 58,
      arapca: 'المجادلة',
      turkceAd: 'Mücâdele',
      ayetSayisi: 22,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 59,
      arapca: 'الحشر',
      turkceAd: 'Haşr',
      ayetSayisi: 24,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 60,
      arapca: 'الممتحنة',
      turkceAd: 'Mümtehine',
      ayetSayisi: 13,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 61,
      arapca: 'الصف',
      turkceAd: 'Saf',
      ayetSayisi: 14,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 62,
      arapca: 'الجمعة',
      turkceAd: 'Cuma',
      ayetSayisi: 11,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 63,
      arapca: 'المنافقون',
      turkceAd: 'Münâfikûn',
      ayetSayisi: 11,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 64,
      arapca: 'التغابن',
      turkceAd: 'Teğâbün',
      ayetSayisi: 18,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 65,
      arapca: 'الطلاق',
      turkceAd: 'Talâk',
      ayetSayisi: 12,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 66,
      arapca: 'التحريم',
      turkceAd: 'Tahrîm',
      ayetSayisi: 12,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 67,
      arapca: 'الملك',
      turkceAd: 'Mülk',
      ayetSayisi: 30,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 68,
      arapca: 'القلم',
      turkceAd: 'Kalem',
      ayetSayisi: 52,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 69,
      arapca: 'الحاقة',
      turkceAd: 'Hâkka',
      ayetSayisi: 52,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 70,
      arapca: 'المعارج',
      turkceAd: 'Meâric',
      ayetSayisi: 44,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 71,
      arapca: 'نوح',
      turkceAd: 'Nûh',
      ayetSayisi: 28,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 72,
      arapca: 'الجن',
      turkceAd: 'Cin',
      ayetSayisi: 28,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 73,
      arapca: 'المزمل',
      turkceAd: 'Müzzemmil',
      ayetSayisi: 20,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 74,
      arapca: 'المدثر',
      turkceAd: 'Müddessir',
      ayetSayisi: 56,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 75,
      arapca: 'القيامة',
      turkceAd: 'Kıyâme',
      ayetSayisi: 40,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 76,
      arapca: 'الإنسان',
      turkceAd: 'İnsân',
      ayetSayisi: 31,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 77,
      arapca: 'المرسلات',
      turkceAd: 'Mürselât',
      ayetSayisi: 50,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 78,
      arapca: 'النبأ',
      turkceAd: 'Nebe\'',
      ayetSayisi: 40,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 79,
      arapca: 'النازعات',
      turkceAd: 'Nâziât',
      ayetSayisi: 46,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 80,
      arapca: 'عبس',
      turkceAd: 'Abese',
      ayetSayisi: 42,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 81,
      arapca: 'التكوير',
      turkceAd: 'Tekvîr',
      ayetSayisi: 29,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 82,
      arapca: 'الانفطار',
      turkceAd: 'İnfitâr',
      ayetSayisi: 19,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 83,
      arapca: 'المطففين',
      turkceAd: 'Mutaffifîn',
      ayetSayisi: 36,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 84,
      arapca: 'الانشقاق',
      turkceAd: 'İnşikâk',
      ayetSayisi: 25,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 85,
      arapca: 'البروج',
      turkceAd: 'Bürûc',
      ayetSayisi: 22,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 86,
      arapca: 'الطارق',
      turkceAd: 'Târık',
      ayetSayisi: 17,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 87,
      arapca: 'الأعلى',
      turkceAd: 'A\'lâ',
      ayetSayisi: 19,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 88,
      arapca: 'الغاشية',
      turkceAd: 'Gâşiye',
      ayetSayisi: 26,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 89,
      arapca: 'الفجر',
      turkceAd: 'Fecr',
      ayetSayisi: 30,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 90,
      arapca: 'البلد',
      turkceAd: 'Beled',
      ayetSayisi: 20,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 91,
      arapca: 'الشمس',
      turkceAd: 'Şems',
      ayetSayisi: 15,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 92,
      arapca: 'الليل',
      turkceAd: 'Leyl',
      ayetSayisi: 21,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 93,
      arapca: 'الضحى',
      turkceAd: 'Duhâ',
      ayetSayisi: 11,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 94,
      arapca: 'الشرح',
      turkceAd: 'İnşirâh',
      ayetSayisi: 8,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 95,
      arapca: 'التين',
      turkceAd: 'Tîn',
      ayetSayisi: 8,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 96,
      arapca: 'العلق',
      turkceAd: 'Alak',
      ayetSayisi: 19,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 97,
      arapca: 'القدر',
      turkceAd: 'Kadir',
      ayetSayisi: 5,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 98,
      arapca: 'البينة',
      turkceAd: 'Beyyine',
      ayetSayisi: 8,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 99,
      arapca: 'الزلزلة',
      turkceAd: 'Zilzâl',
      ayetSayisi: 8,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 100,
      arapca: 'العاديات',
      turkceAd: 'Âdiyât',
      ayetSayisi: 11,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 101,
      arapca: 'القارعة',
      turkceAd: 'Kâria',
      ayetSayisi: 11,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 102,
      arapca: 'التكاثر',
      turkceAd: 'Tekâsür',
      ayetSayisi: 8,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 103,
      arapca: 'العصر',
      turkceAd: 'Asr',
      ayetSayisi: 3,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 104,
      arapca: 'الهمزة',
      turkceAd: 'Hümeze',
      ayetSayisi: 9,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 105,
      arapca: 'الفيل',
      turkceAd: 'Fîl',
      ayetSayisi: 5,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 106,
      arapca: 'قريش',
      turkceAd: 'Kureyş',
      ayetSayisi: 4,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 107,
      arapca: 'الماعون',
      turkceAd: 'Mâûn',
      ayetSayisi: 7,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 108,
      arapca: 'الكوثر',
      turkceAd: 'Kevser',
      ayetSayisi: 3,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 109,
      arapca: 'الكافرون',
      turkceAd: 'Kâfirûn',
      ayetSayisi: 6,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 110,
      arapca: 'النصر',
      turkceAd: 'Nasr',
      ayetSayisi: 3,
      indirildigiYer: 'Medine',
    ),
    Sure(
      no: 111,
      arapca: 'المسد',
      turkceAd: 'Tebbet',
      ayetSayisi: 5,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 112,
      arapca: 'الإخلاص',
      turkceAd: 'İhlâs',
      ayetSayisi: 4,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 113,
      arapca: 'الفلق',
      turkceAd: 'Felak',
      ayetSayisi: 5,
      indirildigiYer: 'Mekke',
    ),
    Sure(
      no: 114,
      arapca: 'الناس',
      turkceAd: 'Nâs',
      ayetSayisi: 6,
      indirildigiYer: 'Mekke',
    ),
  ];
}

class Sure {
  final int no;
  final String arapca;
  final String turkceAd;
  final int ayetSayisi;
  final String indirildigiYer;

  Sure({
    required this.no,
    required this.arapca,
    required this.turkceAd,
    required this.ayetSayisi,
    required this.indirildigiYer,
  });
}

// Juz model
class Cuz {
  final int no;
  final String baslangicSure;
  final String bitisSure;
  final int baslangicSureNo;
  final int baslangicAyetNo;
  final int bitisSureNo;
  final int bitisAyetNo;

  Cuz({
    required this.no,
    required this.baslangicSure,
    required this.bitisSure,
    required this.baslangicSureNo,
    required this.baslangicAyetNo,
    required this.bitisSureNo,
    required this.bitisAyetNo,
  });
}

// Surah detail page
class SureDetaySayfa extends StatefulWidget {
  final Sure sure;
  final int? baslangicAyetNo;
  final int? bitisAyetNo;

  const SureDetaySayfa({
    super.key,
    required this.sure,
    this.baslangicAyetNo,
    this.bitisAyetNo,
  });

  @override
  State<SureDetaySayfa> createState() => _SureDetaySayfaState();
}

class _SureDetaySayfaState extends State<SureDetaySayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  final ScrollController _scrollController = ScrollController();
  List<Ayet> _ayetler = [];
  bool _yukleniyor = true;
  String _hata = '';
  double _fontScale = 1.0;
  bool _okumaModu = false; // false: theme colors, true: black & white mode
  int? _gorunenAyetNo;

  @override
  void initState() {
    super.initState();
    _ayetleriYukle();
    _loadFontScale();
    _loadOkumaModu();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _kaydetSonOkunanYer();
    super.dispose();
  }

  void _onScroll() {
    // Capture the first visible verse (simplified)
    if (_ayetler.isNotEmpty) {
      final scrollOffset = _scrollController.offset;
      // Each verse card is roughly 200-300px tall
      final tahminiIndex = (scrollOffset / 250).floor();
      final yeniAyetNo = tahminiIndex < _ayetler.length
          ? _ayetler[tahminiIndex].no
          : _ayetler.last.no;

      if (_gorunenAyetNo != yeniAyetNo) {
        _gorunenAyetNo = yeniAyetNo;
      }
    }
  }

  Future<void> _kaydetSonOkunanYer() async {
    if (_gorunenAyetNo != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('son_okunan_sure_no', widget.sure.no);
      await prefs.setInt('son_okunan_ayet_no', _gorunenAyetNo!);
      await prefs.setString('son_okunan_sure_ad', widget.sure.turkceAd);
    }
  }

  void _scrollToBaslangicAyet() {
    if (widget.baslangicAyetNo != null && _ayetler.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ayetIndex = _ayetler.indexWhere(
          (a) => a.no == widget.baslangicAyetNo,
        );
        if (ayetIndex >= 0 && _scrollController.hasClients) {
          // Each verse card is roughly 250px + header
          final position = ayetIndex * 250.0;
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  List<Ayet> _filtreAyetler(List<Ayet> ayetler) {
    if (ayetler.isEmpty) return ayetler;

    final baslangic = widget.baslangicAyetNo ?? ayetler.first.no;
    final bitis = widget.bitisAyetNo ?? ayetler.last.no;

    return ayetler.where((a) => a.no >= baslangic && a.no <= bitis).toList();
  }

  Future<void> _loadOkumaModu() async {
    final prefs = await SharedPreferences.getInstance();
    final okumaModu = prefs.getBool('okuma_modu') ?? false;
    if (mounted) {
      setState(() {
        _okumaModu = okumaModu;
      });
    }
  }

  Future<void> _saveOkumaModu() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('okuma_modu', _okumaModu);
  }

  void _toggleOkumaModu() {
    setState(() {
      _okumaModu = !_okumaModu;
    });
    _saveOkumaModu();
  }

  Color get _arkaPlanRengi {
    if (_okumaModu) {
      return Colors.white;
    }
    return _temaService.renkler.arkaPlan;
  }

  Color get _yaziRengi {
    if (_okumaModu) {
      return Colors.black87;
    }
    return _temaService.renkler.yaziPrimary;
  }

  Color get _yaziSecondaryRengi {
    if (_okumaModu) {
      return Colors.black54;
    }
    return _temaService.renkler.yaziSecondary;
  }

  Color get _vurguRengi {
    if (_okumaModu) {
      return Colors.black;
    }
    return _temaService.renkler.vurgu;
  }

  Color get _kartRengi {
    if (_okumaModu) {
      return Colors.grey.shade50;
    }
    return _temaService.renkler.kartArkaPlan;
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    // Store font scale per surah
    final scale = prefs.getDouble('sure_${widget.sure.no}_font_scale') ?? 1.0;
    if (mounted) {
      setState(() {
        _fontScale = scale;
      });
    }
  }

  Future<void> _saveFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sure_${widget.sure.no}_font_scale', _fontScale);
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

  Future<void> _ayetleriYukle() async {
    // Preloaded data for short surahs
    final hazirAyetler = _getHazirAyetler(widget.sure.no);
    if (hazirAyetler.isNotEmpty) {
      setState(() {
        _ayetler = _filtreAyetler(hazirAyetler);
        _yukleniyor = false;
      });
      _scrollToBaslangicAyet();
      return;
    }

    // Attempt to fetch from API
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.alquran.cloud/v1/surah/${widget.sure.no}/editions/ar.alafasy,tr.ates,tr.transliteration',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          final editions = data['data'] as List;
          final arapca = editions[0]['ayahs'] as List;
          final turkce = editions[1]['ayahs'] as List;
          final okunusEdition = editions.length > 2
              ? editions[2]['ayahs'] as List
              : null;

          setState(() {
            final tumAyetler = List.generate(arapca.length, (i) {
              return Ayet(
                no: arapca[i]['numberInSurah'],
                arapca: arapca[i]['text'],
                okunus: okunusEdition != null ? okunusEdition[i]['text'] : '',
                meal: turkce[i]['text'],
              );
            });
            _ayetler = _filtreAyetler(tumAyetler);
            _yukleniyor = false;
          });
          _scrollToBaslangicAyet();
        }
      } else {
        setState(() {
          _hata =
              _languageService['verses_load_failed'] ?? 'Verses could not be loaded';
          _yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        _hata =
            _languageService['connection_error_check_internet'] ??
            'Connection error: Please check your internet connection';
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: _arkaPlanRengi,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.sure.turkceAd,
              style: TextStyle(fontSize: 14, color: _yaziRengi),
            ),
            Text(
              widget.sure.arapca,
              style: TextStyle(
                fontSize: 16,
                color: _vurguRengi,
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: _okumaModu ? Colors.white : Colors.transparent,
        elevation: _okumaModu ? 1 : 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _yaziRengi),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.palette_outlined, color: _yaziRengi),
            tooltip: _languageService['reading_mode'] ?? 'Okuma Modu',
            onSelected: (value) {
              if (value == 'toggle') {
                _toggleOkumaModu();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      _okumaModu
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: _okumaModu ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _languageService['black_white_mode'] ?? 'Black & White Mode',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                enabled: false,
                child: Padding(
                  padding: EdgeInsets.only(left: 32),
                  child: Text(
                      _languageService['reading_mode_desc'] ??
                        'Eases reading',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.text_decrease, color: _yaziRengi),
            onPressed: _decreaseFontSize,
            tooltip: _languageService['font_decrease'] ?? 'Decrease Font',
          ),
          IconButton(
            icon: Icon(Icons.text_increase, color: _yaziRengi),
            onPressed: _increaseFontSize,
            tooltip: _languageService['font_increase'] ?? 'Increase Font',
          ),
        ],
      ),
      body: Container(
        decoration: _okumaModu
            ? null
            : (renkler.arkaPlanGradient != null
                  ? BoxDecoration(gradient: renkler.arkaPlanGradient)
                  : null),
        child: _yukleniyor
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _vurguRengi),
                    const SizedBox(height: 16),
                    Text(
                        _languageService['verses_loading'] ??
                          'Loading verses...',
                      style: TextStyle(color: _yaziSecondaryRengi),
                    ),
                  ],
                ),
              )
            : _hata.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: _vurguRengi, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _hata,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _yaziRengi, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _yukleniyor = true;
                            _hata = '';
                          });
                          _ayetleriYukle();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _vurguRengi,
                        ),
                        child: Text(
                          _languageService['try_again'] ?? 'Try Again',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _ayetler.length + 1, // +1 for Besmele
                itemBuilder: (context, index) {
                  if (index == 0 &&
                      widget.sure.no != 1 &&
                      widget.sure.no != 9) {
                    // Basmalah (except Al-Fatiha and At-Tawbah)
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: renkler.vurgu.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: renkler.vurgu,
                          fontSize: 26 * _fontScale,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    );
                  }

                  final ayetIndex = widget.sure.no != 1 && widget.sure.no != 9
                      ? index - 1
                      : index;
                  if (ayetIndex < 0 || ayetIndex >= _ayetler.length) {
                    return const SizedBox();
                  }

                  final ayet = _ayetler[ayetIndex];
                  return _buildAyetKarti(ayet, renkler);
                },
              ),
      ),
    );
  }

  Widget _buildAyetKarti(Ayet ayet, TemaRenkleri renkler) {
    // Hide recitation/translation for Arabic or Persian
    final currentLang = _languageService.currentLanguage;
    final hideTranslation = currentLang == 'ar' || currentLang == 'fa';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kartRengi,
        borderRadius: BorderRadius.circular(16),
        border: _okumaModu ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: _okumaModu
            ? []
            : [
                BoxShadow(
                  color: renkler.vurgu.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verse number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _okumaModu
                  ? Colors.grey.shade100
                  : renkler.vurgu.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _vurguRengi,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${ayet.no}',
                    style: TextStyle(
                      color: _okumaModu ? Colors.white : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_languageService['verse'] ?? 'Verse'} ${ayet.no}',
                  style: TextStyle(
                    color: _okumaModu ? Colors.black87 : renkler.vurgu,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Arabic
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              ayet.arapca,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _yaziRengi,
                fontSize: 24 * _fontScale,
                height: 2,
                fontFamily: 'Amiri',
              ),
            ),
          ),

          // Recitation - shown for non-Arabic/Persian languages
          if (ayet.okunus.isNotEmpty && !hideTranslation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: _okumaModu
                  ? Colors.grey.shade50
                  : renkler.vurguSecondary.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _languageService['recitation'] ?? 'Recitation',
                    style: TextStyle(
                      color: _okumaModu
                          ? Colors.black54
                          : renkler.vurguSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ayet.okunus,
                    style: TextStyle(
                      color: _yaziRengi,
                      fontSize: 14 * _fontScale,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // Translation - shown for non-Arabic/Persian languages
          if (!hideTranslation && ayet.meal.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _languageService['translation'] ?? 'Translation',
                    style: TextStyle(
                      color: _okumaModu ? Colors.black87 : renkler.vurgu,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ayet.meal,
                    style: TextStyle(
                      color: _yaziRengi,
                      fontSize: 15 * _fontScale,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Preset short surahs data
  List<Ayet> _getHazirAyetler(int sureNo) {
    final languageCode = _languageService.currentLanguage;
    final includeMeal = languageCode != 'ar' && languageCode != 'fa';
    final data = _languageService['short_surah_data'];
    if (data is Map) {
      final sureData = data[sureNo.toString()];
      if (sureData is List) {
        return sureData
          .whereType<Map<String, dynamic>>()
            .map((item) {
              final noValue = item['no'];
              final no = noValue is int
                  ? noValue
                  : int.tryParse(noValue?.toString() ?? '') ?? 0;
              return Ayet(
                no: no,
                arapca: item['arapca']?.toString() ?? '',
                okunus: item['okunus']?.toString() ?? '',
                meal: includeMeal ? (item['meal']?.toString() ?? '') : '',
              );
            })
            .where((ayet) => ayet.no > 0)
            .toList();
      }
    }
    return [];
  }
}

class Ayet {
  final int no;
  final String arapca;
  final String okunus;
  final String meal;

  Ayet({
    required this.no,
    required this.arapca,
    required this.okunus,
    required this.meal,
  });
}

class _CuzSureSegment {
  final Sure sure;
  final int baslangicAyet;
  final int bitisAyet;

  const _CuzSureSegment({
    required this.sure,
    required this.baslangicAyet,
    required this.bitisAyet,
  });
}

// Cüz Detay Sayfası
class CuzDetaySayfa extends StatefulWidget {
  final Cuz cuz;

  const CuzDetaySayfa({super.key, required this.cuz});

  @override
  State<CuzDetaySayfa> createState() => _CuzDetaySayfaState();
}

class _CuzDetaySayfaState extends State<CuzDetaySayfa> {
  final TemaService _temaService = TemaService();

  List<_CuzSureSegment> _getCuzSureleri() {
    final tumSureler = _KuranSayfaState()._tumSureler;

    int baslangicIndex = tumSureler.indexWhere(
      (s) => s.no == widget.cuz.baslangicSureNo,
    );
    int bitisIndex = tumSureler.indexWhere(
      (s) => s.no == widget.cuz.bitisSureNo,
    );

    if (baslangicIndex == -1) baslangicIndex = 0;
    if (bitisIndex == -1) bitisIndex = tumSureler.length - 1;

    final sureler = tumSureler.sublist(baslangicIndex, bitisIndex + 1);

    return sureler.map((sure) {
      final baslangicAyet = sure.no == widget.cuz.baslangicSureNo
          ? widget.cuz.baslangicAyetNo
          : 1;
      final bitisAyet = sure.no == widget.cuz.bitisSureNo
          ? widget.cuz.bitisAyetNo
          : sure.ayetSayisi;
      return _CuzSureSegment(
        sure: sure,
        baslangicAyet: baslangicAyet,
        bitisAyet: bitisAyet,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final cuzSureleri = _getCuzSureleri();

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          'CÜZ ${widget.cuz.no}',
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
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: Column(
          children: [
            // Cüz bilgi kartı
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    renkler.vurgu.withOpacity(0.3),
                    renkler.vurgu.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'جُزْءُ ${_getArabicNumber(widget.cuz.no)}',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 32,
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.cuz.baslangicSure} - ${widget.cuz.bitisSure}',
                    style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${cuzSureleri.length} Sure',
                    style: TextStyle(
                      color: renkler.yaziSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Sureler listesi
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: cuzSureleri.length,
                itemBuilder: (context, index) {
                  final segment = cuzSureleri[index];
                  return _buildCuzSureKarti(segment, renkler);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuzSureKarti(_CuzSureSegment segment, TemaRenkleri renkler) {
    final sure = segment.sure;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SureDetaySayfa(
                  sure: sure,
                  baslangicAyetNo: segment.baslangicAyet,
                  bitisAyetNo: segment.bitisAyet,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Sure numarası
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: renkler.vurgu.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${sure.no}',
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sure bilgisi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sure.turkceAd,
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${segment.baslangicAyet}-${segment.bitisAyet} Ayet',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arapça
                Text(
                  sure.arapca,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 20,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getArabicNumber(int number) {
    final arabicNumbers = {
      1: '١',
      2: '٢',
      3: '٣',
      4: '٤',
      5: '٥',
      6: '٦',
      7: '٧',
      8: '٨',
      9: '٩',
      10: '١٠',
      11: '١١',
      12: '١٢',
      13: '١٣',
      14: '١٤',
      15: '١٥',
      16: '١٦',
      17: '١٧',
      18: '١٨',
      19: '١٩',
      20: '٢٠',
      21: '٢١',
      22: '٢٢',
      23: '٢٣',
      24: '٢٤',
      25: '٢٥',
      26: '٢٦',
      27: '٢٧',
      28: '٢٨',
      29: '٢٩',
      30: '٣٠',
    };
    return arabicNumbers[number] ?? '$number';
  }
}
