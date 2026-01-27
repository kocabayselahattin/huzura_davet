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
      final sure = _sureler.firstWhere(
        (s) => s.no == _sonOkunanSureNo,
        orElse: () => _sureler.first,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SureDetaySayfa(
            sure: sure,
            baslangicAyetNo: _sonOkunanAyetNo,
          ),
        ),
      ).then((_) => _sonOkunanYeriYukle());
    }
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
          _languageService['quran'] ?? 'KUR\'AN-I KERİM',
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
          tabs: const [
            Tab(text: 'SURELER'),
            Tab(text: 'CÜZLER'),
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
                  // Sureler Tab
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sureler.length + (_sonOkunanSureNo != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // İlk sırada "Kaldığınız Yerden" kartı
                      if (index == 0 && _sonOkunanSureNo != null) {
                        return _buildKaldiginYerdenKarti(renkler);
                      }
                      // Normal sure kartları
                      final sureIndex = _sonOkunanSureNo != null ? index - 1 : index;
                      final sure = _sureler[sureIndex];
                      return _buildSureKarti(sure, renkler);
                    },
                  ),
                  // Cüzler Tab
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cuzler.length + (_sonOkunanSureNo != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // İlk sırada "Kaldığınız Yerden" kartı
                      if (index == 0 && _sonOkunanSureNo != null) {
                        return _buildKaldiginYerdenKarti(renkler);
                      }
                      // Normal cüz kartları
                      final cuzIndex = _sonOkunanSureNo != null ? index - 1 : index;
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
                      const Text(
                        'KALDIĞINIZ YERDEN DEVAM EDİN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _sonOkunanSureAd ?? 'Sure',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_sonOkunanAyetNo != null)
                        Text(
                          'Ayet ${_sonOkunanAyetNo}',
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
                        '${sure.ayetSayisi} ayet • ${sure.indirildigiYer}',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arapça isim
                Text(
                  sure.arapca,
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
            // Cüz detay sayfasına git
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CuzDetaySayfa(cuz: cuz),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Cüz numarası
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
                // Cüz bilgisi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CÜZ ${cuz.no}',
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
                // Arapça yazı (Juz)
                Text(
                  'جُزْءُ ${_getArabicNumber(cuz.no)}',
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
      1: '١', 2: '٢', 3: '٣', 4: '٤', 5: '٥',
      6: '٦', 7: '٧', 8: '٨', 9: '٩', 10: '١٠',
      11: '١١', 12: '١٢', 13: '١٣', 14: '١٤', 15: '١٥',
      16: '١٦', 17: '١٧', 18: '١٨', 19: '١٩', 20: '٢٠',
      21: '٢١', 22: '٢٢', 23: '٢٣', 24: '٢٤', 25: '٢٥',
      26: '٢٦', 27: '٢٧', 28: '٢٨', 29: '٢٩', 30: '٣٠',
    };
    return arabicNumbers[number] ?? '$number';
  }

  // Cüzler listesi (30 cüz)
  final List<Cuz> _cuzler = [
    Cuz(no: 1, baslangicSure: 'Fatiha', bitisSure: 'Bakara 141'),
    Cuz(no: 2, baslangicSure: 'Bakara 142', bitisSure: 'Bakara 252'),
    Cuz(no: 3, baslangicSure: 'Bakara 253', bitisSure: 'Âl-i İmrân 92'),
    Cuz(no: 4, baslangicSure: 'Âl-i İmrân 93', bitisSure: 'Nisâ 23'),
    Cuz(no: 5, baslangicSure: 'Nisâ 24', bitisSure: 'Nisâ 147'),
    Cuz(no: 6, baslangicSure: 'Nisâ 148', bitisSure: 'Mâide 81'),
    Cuz(no: 7, baslangicSure: 'Mâide 82', bitisSure: 'En\'âm 110'),
    Cuz(no: 8, baslangicSure: 'En\'âm 111', bitisSure: 'A\'râf 87'),
    Cuz(no: 9, baslangicSure: 'A\'râf 88', bitisSure: 'Enfâl 40'),
    Cuz(no: 10, baslangicSure: 'Enfâl 41', bitisSure: 'Tevbe 92'),
    Cuz(no: 11, baslangicSure: 'Tevbe 93', bitisSure: 'Hûd 5'),
    Cuz(no: 12, baslangicSure: 'Hûd 6', bitisSure: 'Yûsuf 52'),
    Cuz(no: 13, baslangicSure: 'Yûsuf 53', bitisSure: 'İbrâhîm 52'),
    Cuz(no: 14, baslangicSure: 'Hicr 1', bitisSure: 'Nahl 128'),
    Cuz(no: 15, baslangicSure: 'İsrâ 1', bitisSure: 'Kehf 74'),
    Cuz(no: 16, baslangicSure: 'Kehf 75', bitisSure: 'Tâhâ 135'),
    Cuz(no: 17, baslangicSure: 'Enbiyâ 1', bitisSure: 'Hac 78'),
    Cuz(no: 18, baslangicSure: 'Mü\'minûn 1', bitisSure: 'Furkân 20'),
    Cuz(no: 19, baslangicSure: 'Furkân 21', bitisSure: 'Neml 55'),
    Cuz(no: 20, baslangicSure: 'Neml 56', bitisSure: 'Ankebût 45'),
    Cuz(no: 21, baslangicSure: 'Ankebût 46', bitisSure: 'Ahzâb 30'),
    Cuz(no: 22, baslangicSure: 'Ahzâb 31', bitisSure: 'Yâsîn 27'),
    Cuz(no: 23, baslangicSure: 'Yâsîn 28', bitisSure: 'Zuhruf 89'),
    Cuz(no: 24, baslangicSure: 'Zuhruf 90', bitisSure: 'Câsiye 37'),
    Cuz(no: 25, baslangicSure: 'Câsiye 38', bitisSure: 'Zâriyât 30'),
    Cuz(no: 26, baslangicSure: 'Zâriyât 31', bitisSure: 'Hadîd 29'),
    Cuz(no: 27, baslangicSure: 'Mücâdele 1', bitisSure: 'Tahrîm 12'),
    Cuz(no: 28, baslangicSure: 'Mülk 1', bitisSure: 'Mürselât 50'),
    Cuz(no: 29, baslangicSure: 'Nebe\' 1', bitisSure: 'Burûc 22'),
    Cuz(no: 30, baslangicSure: 'Târık 1', bitisSure: 'Nâs 6'),
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

// Cüz modeli
class Cuz {
  final int no;
  final String baslangicSure;
  final String bitisSure;

  Cuz({
    required this.no,
    required this.baslangicSure,
    required this.bitisSure,
  });
}

// Sure detay sayfası
class SureDetaySayfa extends StatefulWidget {
  final Sure sure;
  final int? baslangicAyetNo;

  const SureDetaySayfa({
    super.key,
    required this.sure,
    this.baslangicAyetNo,
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
  bool _okumaModu = false; // false: Tema Renkleri, true: Siyah-Beyaz Mod
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
    // Görünen ilk ayeti yakala (basitleştirilmiş versiyon)
    if (_ayetler.isNotEmpty) {
      final scrollOffset = _scrollController.offset;
      // Her ayet kartı yaklaşık 200-300 piksel yüksekliğinde
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
          // Her ayet kartı yaklaşık 250 piksel + header
          final position = ayetIndex * 250.0;
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
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
    // Her sure için ayrı font scale kaydı
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
    // Kısa sureler için hazır veri
    final hazirAyetler = _getHazirAyetler(widget.sure.no);
    if (hazirAyetler.isNotEmpty) {
      setState(() {
        _ayetler = hazirAyetler;
        _yukleniyor = false;
      });
      _scrollToBaslangicAyet();
      return;
    }

    // API'den çekme girişimi
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
            _ayetler = List.generate(arapca.length, (i) {
              return Ayet(
                no: arapca[i]['numberInSurah'],
                arapca: arapca[i]['text'],
                okunus: okunusEdition != null ? okunusEdition[i]['text'] : '',
                meal: turkce[i]['text'],
              );
            });
            _yukleniyor = false;
          });
          _scrollToBaslangicAyet();
        }
      } else {
        setState(() {
          _hata = 'Ayetler yüklenemedi';
          _yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        _hata = 'Bağlantı hatası: Lütfen internet bağlantınızı kontrol edin';
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
            tooltip: 'Okuma Modu',
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
                      _okumaModu ? Icons.check_box : Icons.check_box_outline_blank,
                      color: _okumaModu ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Siyah-Beyaz Mod'),
                  ],
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                child: Padding(
                  padding: EdgeInsets.only(left: 32),
                  child: Text(
                    'Okumayı rahatlatır',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.text_decrease, color: _yaziRengi),
            onPressed: _decreaseFontSize,
            tooltip: 'Yazı Küçült',
          ),
          IconButton(
            icon: Icon(Icons.text_increase, color: _yaziRengi),
            onPressed: _increaseFontSize,
            tooltip: 'Yazı Büyüt',
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
                      'Ayetler yükleniyor...',
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
                        child: Text(_languageService['try_again'] ?? 'Tekrar Dene'),
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
                    // Besmele (Fatiha ve Tevbe hariç)
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
                  if (ayetIndex < 0 || ayetIndex >= _ayetler.length)
                    return const SizedBox();

                  final ayet = _ayetler[ayetIndex];
                  return _buildAyetKarti(ayet, renkler);
                },
              ),
      ),
    );
  }

  Widget _buildAyetKarti(Ayet ayet, TemaRenkleri renkler) {
    // Arapça veya Farsça dil seçiliyse okunuş ve meal gizlenecek
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
                BoxShadow(color: renkler.vurgu.withOpacity(0.05), blurRadius: 8),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ayet numarası
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
                  'Ayet ${ayet.no}',
                  style: TextStyle(
                    color: _okumaModu ? Colors.black87 : renkler.vurgu,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Arapça
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

          // Okunuş - Arapça/Farsça dışındaki dillerde göster
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
                    'Okunuş',
                    style: TextStyle(
                      color: _okumaModu ? Colors.black54 : renkler.vurguSecondary,
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

          // Meal - Arapça/Farsça dışındaki dillerde göster
          if (!hideTranslation)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meal',
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

  // Popüler kısa sureler için hazır veri
  List<Ayet> _getHazirAyetler(int sureNo) {
    final hazirSureler = {
      1: [
        // Fatiha
        Ayet(
          no: 1,
          arapca: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          okunus: 'Bismillâhirrahmânirrahîm',
          meal: 'Rahmân ve Rahîm olan Allah\'ın adıyla.',
        ),
        Ayet(
          no: 2,
          arapca: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
          okunus: 'Elhamdulillâhi rabbil\'âlemîn',
          meal: 'Hamd, âlemlerin Rabbi Allah\'a mahsustur.',
        ),
        Ayet(
          no: 3,
          arapca: 'الرَّحْمَٰنِ الرَّحِيمِ',
          okunus: 'Errahmânirrahîm',
          meal: 'O, Rahmân\'dır, Rahîm\'dir.',
        ),
        Ayet(
          no: 4,
          arapca: 'مَالِكِ يَوْمِ الدِّينِ',
          okunus: 'Mâliki yevmiddîn',
          meal: 'Din gününün sahibidir.',
        ),
        Ayet(
          no: 5,
          arapca: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
          okunus: 'İyyâke na\'budu ve iyyâke nesteîn',
          meal: 'Yalnız sana ibadet ederiz ve yalnız senden yardım dileriz.',
        ),
        Ayet(
          no: 6,
          arapca: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
          okunus: 'İhdinassırâtal mustakîm',
          meal: 'Bizi doğru yola ilet.',
        ),
        Ayet(
          no: 7,
          arapca:
              'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
          okunus:
              'Sırâtallezîne en\'amte aleyhim ğayril mağdûbi aleyhim veleddâllîn',
          meal:
              'Kendilerine nimet verdiklerinin yoluna; gazaba uğrayanların ve sapıkların yoluna değil.',
        ),
      ],
      112: [
        // İhlas
        Ayet(
          no: 1,
          arapca: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
          okunus: 'Kul huvallâhu ehad',
          meal: 'De ki: O Allah birdir.',
        ),
        Ayet(
          no: 2,
          arapca: 'اللَّهُ الصَّمَدُ',
          okunus: 'Allâhussamed',
          meal:
              'Allah Samed\'dir. (Her şey O\'na muhtaçtır, O hiçbir şeye muhtaç değildir.)',
        ),
        Ayet(
          no: 3,
          arapca: 'لَمْ يَلِدْ وَلَمْ يُولَدْ',
          okunus: 'Lem yelid ve lem yûled',
          meal: 'O doğurmamıştır ve doğurulmamıştır.',
        ),
        Ayet(
          no: 4,
          arapca: 'وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
          okunus: 'Ve lem yekun lehû kufuven ehad',
          meal: 'Ve O\'nun hiçbir dengi yoktur.',
        ),
      ],
      113: [
        // Felak
        Ayet(
          no: 1,
          arapca: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',
          okunus: 'Kul eûzu birabbil felak',
          meal: 'De ki: Sabahın Rabbine sığınırım.',
        ),
        Ayet(
          no: 2,
          arapca: 'مِنْ شَرِّ مَا خَلَقَ',
          okunus: 'Min şerri mâ halak',
          meal: 'Yarattığı şeylerin şerrinden,',
        ),
        Ayet(
          no: 3,
          arapca: 'وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ',
          okunus: 'Ve min şerri ğâsikın izâ vekab',
          meal: 'Karanlığı çöktüğü zaman gecenin şerrinden,',
        ),
        Ayet(
          no: 4,
          arapca: 'وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ',
          okunus: 'Ve min şerrinneffâsâti fil ukad',
          meal: 'Düğümlere üfleyen kadınların şerrinden,',
        ),
        Ayet(
          no: 5,
          arapca: 'وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
          okunus: 'Ve min şerri hâsidin izâ hased',
          meal: 'Ve haset ettiği zaman hasetçinin şerrinden.',
        ),
      ],
      114: [
        // Nas
        Ayet(
          no: 1,
          arapca: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ',
          okunus: 'Kul eûzu birabbinnâs',
          meal: 'De ki: İnsanların Rabbine sığınırım.',
        ),
        Ayet(
          no: 2,
          arapca: 'مَلِكِ النَّاسِ',
          okunus: 'Melikinnâs',
          meal: 'İnsanların Melikine (hükümdarına),',
        ),
        Ayet(
          no: 3,
          arapca: 'إِلَٰهِ النَّاسِ',
          okunus: 'İlâhinnâs',
          meal: 'İnsanların İlahına,',
        ),
        Ayet(
          no: 4,
          arapca: 'مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ',
          okunus: 'Min şerril vesvâsil hannâs',
          meal: 'Sinsi vesvesecinin şerrinden,',
        ),
        Ayet(
          no: 5,
          arapca: 'الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ',
          okunus: 'Ellezî yuvesvisu fî sudûrinnâs',
          meal: 'O ki insanların göğüslerine vesvese verir,',
        ),
        Ayet(
          no: 6,
          arapca: 'مِنَ الْجِنَّةِ وَالنَّاسِ',
          okunus: 'Minel cinneti vennâs',
          meal: 'Gerek cinlerden, gerek insanlardan.',
        ),
      ],
      108: [
        // Kevser
        Ayet(
          no: 1,
          arapca: 'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ',
          okunus: 'İnnâ a\'taynâkel kevser',
          meal: 'Şüphesiz biz sana Kevser\'i verdik.',
        ),
        Ayet(
          no: 2,
          arapca: 'فَصَلِّ لِرَبِّكَ وَانْحَرْ',
          okunus: 'Fesalli lirabbike venhar',
          meal: 'O halde Rabbin için namaz kıl ve kurban kes.',
        ),
        Ayet(
          no: 3,
          arapca: 'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ',
          okunus: 'İnne şânieke huvel ebter',
          meal: 'Doğrusu sana buğzeden, soyu kesik olanın ta kendisidir.',
        ),
      ],
      103: [
        // Asr
        Ayet(
          no: 1,
          arapca: 'وَالْعَصْرِ',
          okunus: 'Vel asr',
          meal: 'Asra yemin olsun ki,',
        ),
        Ayet(
          no: 2,
          arapca: 'إِنَّ الْإِنْسَانَ لَفِي خُسْرٍ',
          okunus: 'İnnel insâne lefî husr',
          meal: 'İnsan gerçekten ziyan içindedir.',
        ),
        Ayet(
          no: 3,
          arapca:
              'إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّبْرِ',
          okunus:
              'İllellezîne âmenû ve amilûssâlihâti ve tevâsav bilhakkı ve tevâsav bissabr',
          meal:
              'Ancak iman edip salih ameller işleyenler, birbirlerine hakkı tavsiye edenler ve birbirlerine sabrı tavsiye edenler başka.',
        ),
      ],
      110: [
        // Nasr
        Ayet(
          no: 1,
          arapca: 'إِذَا جَاءَ نَصْرُ اللَّهِ وَالْفَتْحُ',
          okunus: 'İzâ câe nasrullâhi vel feth',
          meal: 'Allah\'ın yardımı ve fetih geldiği zaman,',
        ),
        Ayet(
          no: 2,
          arapca:
              'وَرَأَيْتَ النَّاسَ يَدْخُلُونَ فِي دِينِ اللَّهِ أَفْوَاجًا',
          okunus: 'Ve raeytennâse yedhulûne fî dînillâhi efvâcâ',
          meal:
              'Ve insanların bölük bölük Allah\'ın dinine girdiklerini gördüğün zaman,',
        ),
        Ayet(
          no: 3,
          arapca:
              'فَسَبِّحْ بِحَمْدِ رَبِّكَ وَاسْتَغْفِرْهُ إِنَّهُ كَانَ تَوَّابًا',
          okunus: 'Fesebbih bihamdi rabbike vestağfirh, innehû kâne tevvâbâ',
          meal:
              'Rabbine hamd ederek tesbih et ve O\'ndan bağışlama dile. Çünkü O, tevbeleri çok kabul edendir.',
        ),
      ],
      109: [
        // Kafirun
        Ayet(
          no: 1,
          arapca: 'قُلْ يَا أَيُّهَا الْكَافِرُونَ',
          okunus: 'Kul yâ eyyuhel kâfirûn',
          meal: 'De ki: Ey kâfirler!',
        ),
        Ayet(
          no: 2,
          arapca: 'لَا أَعْبُدُ مَا تَعْبُدُونَ',
          okunus: 'Lâ a\'budu mâ ta\'budûn',
          meal: 'Ben sizin taptıklarınıza tapmam.',
        ),
        Ayet(
          no: 3,
          arapca: 'وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ',
          okunus: 'Ve lâ entum âbidûne mâ a\'bud',
          meal: 'Siz de benim taptığıma tapıcılar değilsiniz.',
        ),
        Ayet(
          no: 4,
          arapca: 'وَلَا أَنَا عَابِدٌ مَا عَبَدْتُمْ',
          okunus: 'Ve lâ ene âbidun mâ abedtum',
          meal: 'Ben de sizin taptıklarınıza tapacak değilim.',
        ),
        Ayet(
          no: 5,
          arapca: 'وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ',
          okunus: 'Ve lâ entum âbidûne mâ a\'bud',
          meal: 'Siz de benim taptığıma tapıcılar değilsiniz.',
        ),
        Ayet(
          no: 6,
          arapca: 'لَكُمْ دِينُكُمْ وَلِيَ دِينِ',
          okunus: 'Lekum dînukum veliye dîn',
          meal: 'Sizin dininiz size, benim dinim bana.',
        ),
      ],
      97: [
        // Kadir
        Ayet(
          no: 1,
          arapca: 'إِنَّا أَنْزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ',
          okunus: 'İnnâ enzelnâhu fî leyletil kadr',
          meal: 'Şüphesiz biz onu (Kur\'an\'ı) Kadir gecesinde indirdik.',
        ),
        Ayet(
          no: 2,
          arapca: 'وَمَا أَدْرَاكَ مَا لَيْلَةُ الْقَدْرِ',
          okunus: 'Ve mâ edrâke mâ leyletul kadr',
          meal: 'Kadir gecesinin ne olduğunu sen bilir misin?',
        ),
        Ayet(
          no: 3,
          arapca: 'لَيْلَةُ الْقَدْرِ خَيْرٌ مِنْ أَلْفِ شَهْرٍ',
          okunus: 'Leyletul kadri hayrun min elfi şehr',
          meal: 'Kadir gecesi, bin aydan daha hayırlıdır.',
        ),
        Ayet(
          no: 4,
          arapca:
              'تَنَزَّلُ الْمَلَائِكَةُ وَالرُّوحُ فِيهَا بِإِذْنِ رَبِّهِمْ مِنْ كُلِّ أَمْرٍ',
          okunus:
              'Tenezzelul melâiketu verrûhu fîhâ bi izni rabbihim min kulli emr',
          meal:
              'Melekler ve Ruh (Cebrail), Rablerinin izniyle her türlü iş için o gecede iner.',
        ),
        Ayet(
          no: 5,
          arapca: 'سَلَامٌ هِيَ حَتَّىٰ مَطْلَعِ الْفَجْرِ',
          okunus: 'Selâmun hiye hattâ matlaıl fecr',
          meal:
              'O gece, tan yeri ağarıncaya kadar bir selamdır (esenlik ve güvenliktir).',
        ),
      ],
      105: [
        // Fil
        Ayet(
          no: 1,
          arapca: 'أَلَمْ تَرَ كَيْفَ فَعَلَ رَبُّكَ بِأَصْحَابِ الْفِيلِ',
          okunus: 'Elem tera keyfe feale rabbuke bi ashâbil fîl',
          meal: 'Rabbinin fil sahiplerine ne yaptığını görmedin mi?',
        ),
        Ayet(
          no: 2,
          arapca: 'أَلَمْ يَجْعَلْ كَيْدَهُمْ فِي تَضْلِيلٍ',
          okunus: 'Elem yec\'al keydehum fî tadlîl',
          meal: 'Onların tuzaklarını boşa çıkarmadı mı?',
        ),
        Ayet(
          no: 3,
          arapca: 'وَأَرْسَلَ عَلَيْهِمْ طَيْرًا أَبَابِيلَ',
          okunus: 'Ve ersele aleyhim tayran ebâbîl',
          meal: 'Onların üzerine sürü sürü kuşlar gönderdi.',
        ),
        Ayet(
          no: 4,
          arapca: 'تَرْمِيهِمْ بِحِجَارَةٍ مِنْ سِجِّيلٍ',
          okunus: 'Termîhim bi hicâretin min siccîl',
          meal: 'Onlara pişmiş çamurdan taşlar atıyorlardı.',
        ),
        Ayet(
          no: 5,
          arapca: 'فَجَعَلَهُمْ كَعَصْفٍ مَأْكُولٍ',
          okunus: 'Fecealehum keasfin me\'kûl',
          meal: 'Sonunda onları yenilmiş ekin yaprağı gibi yaptı.',
        ),
      ],
    };

    return hazirSureler[sureNo] ?? [];
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

// Cüz Detay Sayfası
class CuzDetaySayfa extends StatefulWidget {
  final Cuz cuz;

  const CuzDetaySayfa({
    super.key,
    required this.cuz,
  });

  @override
  State<CuzDetaySayfa> createState() => _CuzDetaySayfaState();
}

class _CuzDetaySayfaState extends State<CuzDetaySayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  bool _yukleniyor = false;

  // Cüzdeki sureleri al
  List<Sure> _getCuzSureleri() {
    // Cüzün başlangıç ve bitiş surelerini parse et
    final baslangic = widget.cuz.baslangicSure.split(' ')[0];
    final bitis = widget.cuz.bitisSure.split(' ')[0];
    
    // Tüm sureleri al
    final tumSureler = _KuranSayfaState()._tumSureler;
    
    // Başlangıç ve bitiş sure indexlerini bul
    int baslangicIndex = tumSureler.indexWhere((s) => s.turkceAd == baslangic);
    int bitisIndex = tumSureler.indexWhere((s) => s.turkceAd == bitis);
    
    if (baslangicIndex == -1) baslangicIndex = 0;
    if (bitisIndex == -1) bitisIndex = tumSureler.length - 1;
    
    // Cüzdeki sureleri döndür
    return tumSureler.sublist(baslangicIndex, bitisIndex + 1);
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
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 14,
                    ),
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
                  final sure = cuzSureleri[index];
                  return _buildSureKarti(sure, renkler);
                },
              ),
            ),
          ],
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
                        '${sure.indirildigiYer} • ${sure.ayetSayisi} Ayet',
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
      1: '١', 2: '٢', 3: '٣', 4: '٤', 5: '٥',
      6: '٦', 7: '٧', 8: '٨', 9: '٩', 10: '١٠',
      11: '١١', 12: '١٢', 13: '١٣', 14: '١٤', 15: '١٥',
      16: '١٦', 17: '١٧', 18: '١٨', 19: '١٩', 20: '٢٠',
      21: '٢١', 22: '٢٢', 23: '٢٣', 24: '٢٤', 25: '٢٥',
      26: '٢٦', 27: '٢٧', 28: '٢٨', 29: '٢٩', 30: '٣٠',
    };
    return arabicNumbers[number] ?? '$number';
  }
}
