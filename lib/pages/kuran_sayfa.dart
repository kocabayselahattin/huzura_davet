import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/kuran_veri_service.dart';
import '../services/kuran_ses_service.dart';
import '../services/hatim_plan_service.dart';
import '../services/arapca_font_ayarlari.dart';
import 'hatim_plani_sayfa.dart';
import '../widgets/paylasim_karti.dart';
import 'paylasim_onizleme_sayfa.dart';

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
  List<HatimPlani> _hatimPlanlari = [];

  final TextEditingController _aramaController = TextEditingController();
  String _aramaSorgusu = '';
  List<Sure> _aramaSureSonuclari = [];
  List<_AyetAramaSonucu> _aramaAyetSonuclari = [];
  String _arapcaFont = ArapcaFontAyarlari.varsayilanFont;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sureleriYukle();
    _sonOkunanYeriYukle();
    _hatimPlaniYukle();
    _arapcaFontuYukle();
    // Ayet metninde arama yapabilmek için Kur'an verisi önceden yüklenir;
    // henüz yüklenmemişse arama sadece sure adlarında çalışır.
    KuranVeriService.yukle().then((_) {
      if (mounted && _aramaSorgusu.isNotEmpty) _aramayiUygula();
    });
  }

  Future<void> _hatimPlaniYukle() async {
    final planlar = await HatimPlanService.tumPlanlar();
    if (mounted) setState(() => _hatimPlanlari = planlar);
  }

  Future<void> _arapcaFontuYukle() async {
    final font = await ArapcaFontAyarlari.yukle();
    if (mounted) setState(() => _arapcaFont = font);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aramaController.dispose();
    super.dispose();
  }

  /// Türkçe'ye özgü büyük/küçük harf kurallarını (İ/i, I/ı) doğru uygulayan
  /// karşılaştırma anahtarı üretir. Karakter sayısını değiştirmediği için
  /// eşleşen aralığı orijinal metinde de doğrudan kullanabiliriz.
  String _turkceKucult(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  void _aramaDegisti(String sorgu) {
    setState(() {
      _aramaSorgusu = sorgu.trim();
      _aramayiUygula();
    });
  }

  void _aramayiUygula() {
    if (_aramaSorgusu.isEmpty) {
      _aramaSureSonuclari = [];
      _aramaAyetSonuclari = [];
      return;
    }

    final q = _turkceKucult(_aramaSorgusu);

    _aramaSureSonuclari = _tumSureler
        .where((s) => _turkceKucult(s.turkceAd).contains(q))
        .toList();

    final ayetSonuclari = <_AyetAramaSonucu>[];
    if (KuranVeriService.yuklendiMi) {
      for (final sure in _tumSureler) {
        for (final a in KuranVeriService.sureAyetleri(sure.no)) {
          final meal = a['meal']?.toString() ?? '';
          if (!_turkceKucult(meal).contains(q)) continue;
          final ayetNo = a['no'] is int
              ? a['no'] as int
              : int.tryParse(a['no']?.toString() ?? '') ?? 0;
          ayetSonuclari.add(
            _AyetAramaSonucu(sure: sure, ayetNo: ayetNo, meal: meal),
          );
          // Çok yaygın kelimelerde (ör. "Allah") binlerce sonuç oluşmasın.
          if (ayetSonuclari.length >= 100) break;
        }
        if (ayetSonuclari.length >= 100) break;
      }
    }
    _aramaAyetSonuclari = ayetSonuclari;
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

  /// Kayıtlı konumu yok sayıp Kur'an'ın başından (Fatiha) okumaya başlar.
  void _kaldiginYerdenBastanBasla() {
    final fatiha = _sureler.firstWhere(
      (s) => s.no == 1,
      orElse: () => _sureler.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SureDetaySayfa(sure: fatiha)),
    ).then((_) => _sonOkunanYeriYukle());
  }

  /// "Kaldığın yerden devam et" kartını kaldırır. Kaydı geri alınamaz
  /// şekilde sildiği için önce kullanıcıdan onay istenir.
  Future<void> _kaldiginYerdenIptalOnayla() async {
    final renkler = _temaService.renkler;
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        title: Text(
          _languageService['resume_reading_cancel'] ?? 'Kaydı Sil',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        content: Text(
          _languageService['resume_reading_cancel_confirm'] ??
              'Kaldığın yer kaydını silmek istediğine emin misin?',
          style: TextStyle(color: renkler.yaziSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_languageService['cancel'] ?? 'Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _languageService['resume_reading_cancel'] ?? 'Kaydı Sil',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (onay != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('son_okunan_sure_no');
    await prefs.remove('son_okunan_ayet_no');
    await prefs.remove('son_okunan_sure_ad');
    if (!mounted) return;
    setState(() {
      _sonOkunanSureNo = null;
      _sonOkunanAyetNo = null;
      _sonOkunanSureAd = null;
    });
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: _buildAramaAlani(renkler),
            ),
            Expanded(
              child: _yukleniyor
                  ? Center(
                      child: CircularProgressIndicator(color: renkler.vurgu),
                    )
                  : _aramaSorgusu.isNotEmpty
                  ? _buildAramaSonuclari(renkler)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Surahs tab
                        ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount:
                              _sureler.length +
                              1 +
                              (_sonOkunanSureNo != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Tüm hatim planları tek bir bölümde, en üstte.
                            if (index == 0) {
                              return _buildHatimPlanlariBolumu(renkler);
                            }
                            final kalanIndex = index - 1;
                            // Resume card, hemen altında.
                            if (kalanIndex == 0 && _sonOkunanSureNo != null) {
                              return _buildKaldiginYerdenKarti(renkler);
                            }
                            // Regular surah cards
                            final sureIndex =
                                kalanIndex - (_sonOkunanSureNo != null ? 1 : 0);
                            final sure = _sureler[sureIndex];
                            return _buildSureKarti(sure, renkler);
                          },
                        ),
                        // Juz tab
                        ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount:
                              _cuzler.length +
                              (_sonOkunanSureNo != null ? 1 : 0),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAramaAlani(TemaRenkleri renkler) {
    return Container(
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: TextField(
        controller: _aramaController,
        onChanged: _aramaDegisti,
        style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText:
              _languageService['search_quran_hint'] ??
              'Sure adı veya ayet içinde ara...',
          hintStyle: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: renkler.yaziSecondary),
          suffixIcon: _aramaSorgusu.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: renkler.yaziSecondary),
                  onPressed: () {
                    _aramaController.clear();
                    _aramaDegisti('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAramaSonuclari(TemaRenkleri renkler) {
    final ayetlerHazir = KuranVeriService.yuklendiMi;

    if (_aramaSureSonuclari.isEmpty && _aramaAyetSonuclari.isEmpty) {
      if (!ayetlerHazir) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: renkler.vurgu),
                const SizedBox(height: 12),
                Text(
                  _languageService['search_verses_indexing'] ??
                      "Loading Quran data to search verses...",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Text(
          _languageService['search_no_results'] ?? 'No results found',
          style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_aramaSureSonuclari.isNotEmpty) ...[
          _buildAramaBolumBasligi(
            _languageService['search_surahs_section'] ?? 'SURAHS',
            renkler,
          ),
          ..._aramaSureSonuclari.map((s) => _buildSureKarti(s, renkler)),
        ],
        if (_aramaAyetSonuclari.isNotEmpty) ...[
          _buildAramaBolumBasligi(
            _languageService['search_verses_section'] ?? 'VERSES',
            renkler,
          ),
          ..._aramaAyetSonuclari.map((r) => _buildAyetSonucKarti(r, renkler)),
        ],
        if (!ayetlerHazir)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _languageService['search_verses_indexing'] ??
                  "Loading Quran data to search verses...",
              textAlign: TextAlign.center,
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildAramaBolumBasligi(String baslik, TemaRenkleri renkler) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        baslik,
        style: TextStyle(
          color: renkler.yaziSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildAyetSonucKarti(_AyetAramaSonucu sonuc, TemaRenkleri renkler) {
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
                  sure: sonuc.sure,
                  baslangicAyetNo: sonuc.ayetNo,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sonuc.sure.turkceAd} ${sonuc.ayetNo}',
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildVurgulanmisMeal(sonuc.meal, renkler),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Meal metninde arama kelimesinin geçtiği kısmı vurgulayarak, çok uzun
  /// ayetlerde eşleşmenin etrafından kısa bir bağlam gösterir.
  Widget _buildVurgulanmisMeal(String meal, TemaRenkleri renkler) {
    final q = _turkceKucult(_aramaSorgusu);
    final mealKucuk = _turkceKucult(meal);
    final eslesmeIndex = q.isEmpty ? -1 : mealKucuk.indexOf(q);

    if (eslesmeIndex < 0) {
      return Text(
        meal,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: renkler.yaziPrimary, fontSize: 14, height: 1.4),
      );
    }

    const baglamUzunlugu = 60;
    final baslangic = (eslesmeIndex - baglamUzunlugu).clamp(0, meal.length);
    final bitis = (eslesmeIndex + q.length + baglamUzunlugu).clamp(
      0,
      meal.length,
    );

    final oncesi =
        (baslangic > 0 ? '…' : '') + meal.substring(baslangic, eslesmeIndex);
    final eslesen = meal.substring(eslesmeIndex, eslesmeIndex + q.length);
    final sonrasi =
        meal.substring(eslesmeIndex + q.length, bitis) +
        (bitis < meal.length ? '…' : '');

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: renkler.yaziPrimary, fontSize: 14, height: 1.4),
        children: [
          TextSpan(text: oncesi),
          TextSpan(
            text: eslesen,
            style: TextStyle(
              color: renkler.vurgu,
              fontWeight: FontWeight.bold,
              backgroundColor: renkler.vurgu.withOpacity(0.15),
            ),
          ),
          TextSpan(text: sonrasi),
        ],
      ),
    );
  }

  /// Tüm hatim planlarını (varsa) ve yeni plan ekleme seçeneğini tek bir
  /// bölümde toplar. Hiç plan yoksa büyük, tek bir davet kartı gösterilir
  /// (ilk tasarımdaki gibi, sade ve dikkat çekici); plan(lar) varsa hepsi
  /// aynı çerçeve içinde kompakt satırlar halinde listelenir ve en altta
  /// "Yeni Hatim Planı Ekle" satırı yer alır. Böylece birden fazla plan
  /// (ör. Ramazan + senelik) aynı anda çalışabilir ama ekran karışmaz.
  Widget _buildHatimPlanlariBolumu(TemaRenkleri renkler) {
    if (_hatimPlanlari.isEmpty) {
      return _buildHatimDavetKarti(renkler);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renkler.vurgu.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: renkler.vurgu, size: 20),
                const SizedBox(width: 8),
                Text(
                  _languageService['hatim_plan_section_title'] ??
                      'Hatim Planlarım',
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          for (final plan in _hatimPlanlari)
            _buildHatimPlaniSatiri(plan, renkler),
          _buildYeniPlanEkleSatiri(renkler),
        ],
      ),
    );
  }

  /// Hiç plan yokken gösterilen tek, büyük davet kartı.
  Widget _buildHatimDavetKarti(TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renkler.vurgu.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HatimPlaniSayfa()),
            ).then((_) => _hatimPlaniYukle());
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: renkler.vurgu.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: renkler.vurgu,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _languageService['hatim_plan_entry_title_new'] ??
                            'Hatim Planı Oluştur',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _languageService['hatim_plan_entry_desc_new'] ??
                            'Günde ne kadar okuyacağını seç, uygulama seni takip etsin.',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: renkler.yaziSecondary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Birleşik bölüm içindeki tek bir planın kompakt satırı: adı + bugünün
  /// hedefi. Alarm saati her planda bağımsızdır (plan ayarlarından
  /// değiştirilir), o yüzden burada tekrar gösterilmez.
  Widget _buildHatimPlaniSatiri(HatimPlani plan, TemaRenkleri renkler) {
    final hedef = HatimPlanService.gunlukHedef(plan);
    final aciklama =
        (_languageService['hatim_plan_entry_desc_active'] ??
                'Bugünün hedefi: {hedef}')
            .replaceAll('{hedef}', hedef.etiket);
    final sonMu = plan == _hatimPlanlari.last;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HatimPlaniSayfa(planId: plan.id),
            ),
          ).then((_) => _hatimPlaniYukle());
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: renkler.vurgu.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      plan.turu == HatimPlanTuru.ramazan
                          ? Icons.nights_stay_rounded
                          : Icons.menu_book_rounded,
                      color: renkler.vurgu,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.ad,
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          aciklama,
                          style: TextStyle(
                            color: renkler.yaziSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: renkler.yaziSecondary,
                    size: 24,
                  ),
                ],
              ),
              if (!sonMu)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Divider(
                    height: 1,
                    color: renkler.yaziSecondary.withOpacity(0.15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Birleşik bölümün altında, mevcut plan satırlarından görsel olarak
  /// ayrılan, daha sade "yeni plan ekle" satırı (kendi başına büyük bir
  /// kart değil).
  Widget _buildYeniPlanEkleSatiri(TemaRenkleri renkler) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HatimPlaniSayfa()),
          ).then((_) => _hatimPlaniYukle());
        },
        child: Container(
          decoration: BoxDecoration(
            color: renkler.vurgu.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: renkler.vurgu,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                _languageService['hatim_plan_entry_title_add'] ??
                    'Yeni Hatim Planı Ekle',
                style: TextStyle(
                  color: renkler.vurgu,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              onTap: _kaldirKaldiginYerden,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _languageService['resume_reading_no_plan_note'] ??
                  'Bu, herhangi bir hatim planına bağlı olmadan yaptığın genel okumanın ilerlemesidir.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildKucukAksiyonButonu(
                    ikon: Icons.replay_rounded,
                    etiket:
                        _languageService['resume_reading_restart'] ??
                        'Baştan Başla',
                    onTap: _kaldiginYerdenBastanBasla,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKucukAksiyonButonu(
                    ikon: Icons.close_rounded,
                    etiket:
                        _languageService['resume_reading_cancel'] ?? 'İptal',
                    onTap: _kaldiginYerdenIptalOnayla,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKucukAksiyonButonu({
    required IconData ikon,
    required String etiket,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  etiket,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
                    fontFamily: _arapcaFont,
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
                    fontFamily: _arapcaFont,
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

  List<Sure> get _tumSureler => sureListesi;
}

// 114 Sure listesi
const List<Sure> sureListesi = [
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

/// Ayet metninde arama sonucu: eşleşen ayetin sure bilgisiyle birlikte.
class _AyetAramaSonucu {
  final Sure sure;
  final int ayetNo;
  final String meal;

  _AyetAramaSonucu({
    required this.sure,
    required this.ayetNo,
    required this.meal,
  });
}

class Sure {
  final int no;
  final String arapca;
  final String turkceAd;
  final int ayetSayisi;
  final String indirildigiYer;

  const Sure({
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

  /// Verildiyse, okuma ilerlemesi genel "kaldığın yer" kaydına ek olarak bu
  /// hatim planına da işlenir (bkz. HatimPlanService.ilerlemeGuncelle).
  final String? hatimPlanId;

  /// Hatim planından okunurken günün hedefi (bkz. HatimPlanService.
  /// gunlukHedef). [bitisAyetNo] verilmemişse ve hedef bu surede bitiyorsa,
  /// görünüm surenin tamamı yerine tam olarak günün hedefine kadar sınırlanır
  /// — kullanıcı o gün kaç sayfa okuması gerekiyorsa yalnızca o kadarını
  /// görür. Hedefe ulaşıldıktan sonra "Devam Et" ile Mushaf'ın gerçek sayfa
  /// sınırlarına göre birer sayfa eklenir (bkz. _buildDevamEtButonu).
  final int? hedefSureNo;
  final int? hedefAyetNo;

  const SureDetaySayfa({
    super.key,
    required this.sure,
    this.baslangicAyetNo,
    this.bitisAyetNo,
    this.hatimPlanId,
    this.hedefSureNo,
    this.hedefAyetNo,
  });

  @override
  State<SureDetaySayfa> createState() => _SureDetaySayfaState();
}

/// Bir ayeti, hangi sureye ait olduğuyla birlikte tutar. Hatim planından
/// okurken görünüm birden fazla sureye yayılabildiğinden (bkz.
/// _SureDetaySayfaState), düz ayet listesinin her öğesi kaynağını bilmek
/// zorundadır.
class _SureAyet {
  final int sureNo;
  final Ayet ayet;
  const _SureAyet(this.sureNo, this.ayet);
}

/// Okuma listesindeki bir öğe: bir sureye geçiş başlığı, bir besmele bloğu
/// ya da tek bir ayet kartı. Birden fazla sureye yayılan hatim planı
/// okumalarında listeyi oluşturmak için kullanılır (bkz.
/// _renderListesiOlustur).
class _OkumaOgesi {
  final int? sureBasligi;
  final bool besmele;
  final _SureAyet? ayet;

  const _OkumaOgesi.baslik(int sureNo)
    : sureBasligi = sureNo,
      besmele = false,
      ayet = null;
  const _OkumaOgesi.besmeleBlok()
    : sureBasligi = null,
      besmele = true,
      ayet = null;
  const _OkumaOgesi.ayetKarti(_SureAyet a)
    : sureBasligi = null,
      besmele = false,
      ayet = a;
}

class _SureDetaySayfaState extends State<SureDetaySayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  final ScrollController _scrollController = ScrollController();

  // Bu okuma oturumuna dahil sureler (sırayla) ve her birinin tüm ayetleri.
  // Hatim planı dışı normal okumada tek elemanlıdır; hatim planından
  // okurken günün hedefi (ör. 1 cüz, N sayfa) birden fazla sureye
  // yayılıyorsa hepsi burada birikir — kullanıcı "Devam Et"e basmadan
  // günün tüm hedefini tek seferde görür (bkz. _ayetleriYukle, _sayfaEkle).
  List<Sure> _sureSegmentleri = [];
  final Map<int, List<Ayet>> _sureAyetleriMap = {};
  int _etkinBitisSureNo = 0;
  int _etkinBitisAyetNo = 0;
  // Hatim planından okurken görünüm tam olarak kaldığın ayetten başlar,
  // öncesi hiç yüklenmez. "Öncesini Göster" ile kullanıcı isterse geriye
  // doğru (Mushaf sayfa sınırına göre) genişletebilir; bu iki alan o anki
  // etkin başlangıcı tutar (bkz. _oncekiSayfayiEkle).
  int _etkinBaslangicSureNo = 0;
  int _etkinBaslangicAyetNo = 0;

  // Görüntülenen (baslangic/bitis'e göre filtrelenmiş), sureleri birlikte
  // taşıyan düz ayet listesi. _duzListeOlustur() ile üretilir.
  List<_SureAyet> _ayetler = [];
  // ListView'de fiilen render edilen öğe dizisi (sure başlığı / besmele /
  // ayet kartı) — _ayetler her değiştiğinde _renderListesiOlustur() ile
  // yeniden üretilir.
  List<_OkumaOgesi> _renderOgeleri = [];

  bool _yukleniyor = true;
  String _hata = '';
  double _fontScale = 1.0;
  bool _okumaModu = false; // false: theme colors, true: black & white mode
  String _arapcaFont = ArapcaFontAyarlari.varsayilanFont;
  bool _okunusGizli = false;
  bool _mealGizli = false;
  int? _gorunenSureNo;
  int? _gorunenAyetNo;

  // "Kaldığın yer" ekranın EN ÜSTÜNDE görünen ayete göre belirlenir (aksi
  // halde uzun ayet kartlarında piksel bazlı tahmin ekranın altındaki bir
  // ayeti işaret edip ilerlemeyi olduğundan fazla ilerletebilir). Her ayet
  // kartının gerçek ekran konumu, bu GlobalKey'ler üzerinden ölçülür (bkz.
  // _enUsttekiAyetiBul). _listeKey, ListView'in (dolayısıyla görünür
  // alanın) üst kenarını referans almak için kullanılır.
  final GlobalKey _listeKey = GlobalKey();
  final Map<String, GlobalKey> _ayetAnahtarlari = {};
  Timer? _kaydirmaDurdurmaZamanlayicisi;

  GlobalKey _ayetAnahtari(int sureNo, int ayetNo) =>
      _ayetAnahtarlari.putIfAbsent('$sureNo:$ayetNo', () => GlobalKey());

  // Sesli okuma
  final AudioPlayer _sesOynatici = AudioPlayer();
  int? _calanSureNo;
  int? _calanAyetNo;
  bool _sesYukleniyor = false;
  // true iken bir ayet bitince otomatik olarak sıradaki ayete geçilir;
  // kullanıcı çalan ayete tekrar basıp durdurunca false yapılır.
  bool _otomatikDevamEt = false;
  bool _sureIndirilmis = false;
  bool _sureIndiriliyor = false;
  int _indirmeTamamlanan = 0;
  int _indirmeToplam = 0;

  @override
  void initState() {
    super.initState();
    _ayetleriYukle();
    _loadFontScale();
    _loadOkumaModu();
    _loadArapcaFont();
    _loadGosterimAyarlari();
    _scrollController.addListener(_onScroll);
    _sesIndirmeDurumunuKontrolEt();
    _sesOynatici.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_otomatikDevamEt && _calanSureNo != null && _calanAyetNo != null) {
        final index = _ayetler.indexWhere(
          (sa) => sa.sureNo == _calanSureNo && sa.ayet.no == _calanAyetNo,
        );
        if (index != -1 && index + 1 < _ayetler.length) {
          final sonraki = _ayetler[index + 1];
          _ayetiCal(sonraki.ayet, sonraki.sureNo);
          return;
        }
      }
      _otomatikDevamEt = false;
      setState(() => _calanAyetNo = null);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _kaydirmaDurdurmaZamanlayicisi?.cancel();
    // Ekrandan ayrılmadan hemen önce son bir kez daha en üstteki ayeti
    // ölçmeyi dene (kaydırma durduktan sonraki 200ms'lik gecikme henüz
    // dolmadan geri dönülmüş olabilir); render ağacı hâlâ ayaktaysa bu
    // en güncel değeri yakalar, değilse zaten en son ölçülen değer kalır.
    _enUsttekiAyetiBul();
    _scrollController.dispose();
    _kaydetSonOkunanYer();
    _sesOynatici.dispose();
    super.dispose();
  }

  Future<void> _sesIndirmeDurumunuKontrolEt() async {
    final indirilmis = await KuranSesService.sureTamIndirilmisMi(
      widget.sure.no,
    );
    if (mounted) setState(() => _sureIndirilmis = indirilmis);
  }

  /// Tek bir ayete tıklandığında çağrılır: aynı ayet çalıyorsa tamamen
  /// durdurur, değilse o ayetten başlayıp sure bitene (ya da kullanıcı
  /// durdurana) kadar sırayla otomatik devam eden bir okuma başlatır.
  Future<void> _ayetiCalDurdur(Ayet ayet, int sureNo) async {
    if (_calanSureNo == sureNo && _calanAyetNo == ayet.no) {
      _otomatikDevamEt = false;
      await _sesOynatici.stop();
      if (mounted) setState(() => _calanAyetNo = null);
      return;
    }

    _otomatikDevamEt = true;
    await _ayetiCal(ayet, sureNo);
  }

  Future<void> _ayetiCal(Ayet ayet, int sureNo) async {
    setState(() {
      _sesYukleniyor = true;
      _calanSureNo = sureNo;
      _calanAyetNo = ayet.no;
    });
    _calanAyeteKaydir(sureNo, ayet.no);

    try {
      final sonuc = await KuranSesService.calmaKaynagi(sureNo, ayet.no);

      // Ayet indirilmemişse akıştan (CDN'den) çalınacak; internet yoksa
      // sessizce başarısız olmak yerine kullanıcıyı önceden bilgilendir.
      if (!sonuc.yerel && !await _internetVarMi()) {
        if (mounted) {
          _otomatikDevamEt = false;
          setState(() => _calanAyetNo = null);
          _internetYokUyarisiGoster();
        }
        return;
      }

      await _sesOynatici.stop();
      await _sesOynatici.play(
        sonuc.yerel ? DeviceFileSource(sonuc.kaynak) : UrlSource(sonuc.kaynak),
      );
    } catch (e) {
      if (mounted) {
        _otomatikDevamEt = false;
        setState(() => _calanAyetNo = null);
        _internetYokUyarisiGoster();
      }
    } finally {
      if (mounted) setState(() => _sesYukleniyor = false);
    }
  }

  /// Otomatik sıradaki ayete geçilirken, o ayet ekranda görünmüyorsa
  /// kullanıcının hangi ayetin okunduğunu takip edebilmesi için yumuşakça
  /// oraya kaydırır.
  void _calanAyeteKaydir(int sureNo, int ayetNo) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anahtar = _ayetAnahtarlari['$sureNo:$ayetNo'];
      final ctx = anahtar?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    });
  }

  /// Kısa bir DNS sorgusuyla internet bağlantısını yoklar. VPN/kısıtlı
  /// ağlarda yanlış negatif vermemesi için gerçek CDN adresine bakar.
  Future<bool> _internetVarMi() async {
    try {
      final sonuc = await InternetAddress.lookup(
        'cdn.islamic.network',
      ).timeout(const Duration(seconds: 4));
      return sonuc.isNotEmpty && sonuc.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _internetYokUyarisiGoster() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _languageService['connection_error_check_internet'] ??
              'Connection error: Please check your internet connection',
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _sureyiIndir() async {
    setState(() {
      _sureIndiriliyor = true;
      _indirmeTamamlanan = 0;
      _indirmeToplam = _ayetler.length;
    });

    await KuranSesService.sureyiIndir(
      widget.sure.no,
      ilerleme: (tamamlanan, toplam) {
        if (!mounted) return;
        setState(() {
          _indirmeTamamlanan = tamamlanan;
          _indirmeToplam = toplam;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _sureIndiriliyor = false;
      _sureIndirilmis = true;
    });
  }

  Future<void> _sureSesiniSil() async {
    await KuranSesService.sureyiSil(widget.sure.no);
    if (mounted) setState(() => _sureIndirilmis = false);
  }

  /// Kaydırma her hareket ettiğinde tetiklenir; asıl ölçüm (GlobalKey'lerle
  /// gerçek render konumlarını okumak) ucuz olmadığından her piksel için
  /// değil, kaydırma ~200ms durduktan sonra bir kez yapılır (bkz.
  /// _enUsttekiAyetiBul).
  void _onScroll() {
    _kaydirmaDurdurmaZamanlayicisi?.cancel();
    _kaydirmaDurdurmaZamanlayicisi = Timer(
      const Duration(milliseconds: 200),
      _enUsttekiAyetiBul,
    );
  }

  /// Ekranın en üstünde (gerçekte) görünen ayeti, her ayet kartına iliştirilen
  /// GlobalKey'lerin render konumlarını [_listeKey] (ListView'in, dolayısıyla
  /// görünür alanın üst kenarı) ile karşılaştırarak bulur. Piksel bazlı bir
  /// tahmin yerine gerçek layout kullanıldığından, ayet kartlarının boyu
  /// (Arapça + okunuş + meal uzunluğuna göre değişir) fark etmeksizin doğru
  /// sonuç verir — "kaldığın yer" ekranın altındaki değil, üstündeki ayete
  /// göre kaydedilir.
  void _enUsttekiAyetiBul() {
    if (_ayetler.isEmpty) return;
    final viewportBox =
        _listeKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) return;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;

    for (final e in _ayetler) {
      final anahtar = _ayetAnahtarlari['${e.sureNo}:${e.ayet.no}'];
      final kutu = anahtar?.currentContext?.findRenderObject();
      if (kutu is! RenderBox || !kutu.attached) continue;
      final ustKenar = kutu.localToGlobal(Offset.zero).dy;
      final altKenar = ustKenar + kutu.size.height;
      if (altKenar > viewportTop) {
        if (_gorunenSureNo != e.sureNo || _gorunenAyetNo != e.ayet.no) {
          _gorunenSureNo = e.sureNo;
          _gorunenAyetNo = e.ayet.no;
        }
        return;
      }
    }
  }

  Future<void> _kaydetSonOkunanYer() async {
    // _gorunenSureNo/_gorunenAyetNo normalde _enUsttekiAyetiBul() ile
    // (kaydırma durunca, ilk yüklemede ve dispose'da) güncel tutulur; bkz.
    // orada. Yalnızca ölçüm hiç yapılamamışsa (ör. render ağacı henüz hazır
    // değilken çok hızlı çıkılırsa) burada bir yedek değere düşülür.
    int? sureNo = _gorunenSureNo;
    int? ayetNo = _gorunenAyetNo;
    if ((sureNo == null || ayetNo == null) && _ayetler.isNotEmpty) {
      final tamamiGorunuyor =
          _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 0;
      final secilen = tamamiGorunuyor ? _ayetler.last : _ayetler.first;
      sureNo = secilen.sureNo;
      ayetNo = secilen.ayet.no;
    }

    if (sureNo != null && ayetNo != null) {
      // Bu okuma bir hatim planından başlatıldıysa (bkz. "Kaldığın Yerden
      // Oku" butonu), ilerleme YALNIZCA o plana işlenir. "Kaldığınız Yerden
      // Devam Edin" genel kaydı, hatim planlarından bağımsız serbest okuma
      // için ayrı bir yer tutucudur; plan içi okuma onu güncellemez, aksi
      // halde hangi hatim planından okunduğu belirsizleşir ve genel kayıt
      // planın ilerlemesini tekrarlamış olur.
      if (widget.hatimPlanId != null) {
        await HatimPlanService.ilerlemeGuncelle(
          widget.hatimPlanId!,
          sureNo,
          ayetNo,
        );
        return;
      }

      final sureAdi = _sureSegmentleri
          .firstWhere((s) => s.no == sureNo, orElse: () => widget.sure)
          .turkceAd;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('son_okunan_sure_no', sureNo);
      await prefs.setInt('son_okunan_ayet_no', ayetNo);
      await prefs.setString('son_okunan_sure_ad', sureAdi);
    }
  }

  void _scrollToBaslangicAyet() {
    if (widget.baslangicAyetNo != null && _ayetler.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ayetIndex = _ayetler.indexWhere(
          (e) =>
              e.sureNo == widget.sure.no && e.ayet.no == widget.baslangicAyetNo,
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
        _enUsttekiAyetiBul();
      });
    } else if (_ayetler.isNotEmpty) {
      // Kaydırma gerekmeyecek kısa içerik (ör. Fatiha) için de "kaldığın
      // yer" bilgisi ilk anda kaydedilebilsin diye bir kare sonra ölçülür.
      WidgetsBinding.instance.addPostFrameCallback((_) => _enUsttekiAyetiBul());
    }
  }

  /// [_sureSegmentleri] + [_sureAyetleriMap] + geçerli sınırlardan
  /// ([widget.baslangicAyetNo], [_etkinBitisSureNo]/[_etkinBitisAyetNo])
  /// görüntülenecek düz ayet listesini üretir. Yükleme sonrası ve
  /// "Devam Et" ile yeni bir sayfa eklendiğinde yeniden çağrılır.
  List<_SureAyet> _duzListeOlustur() {
    final liste = <_SureAyet>[];
    for (int i = 0; i < _sureSegmentleri.length; i++) {
      final sure = _sureSegmentleri[i];
      final tumAyetler = _sureAyetleriMap[sure.no];
      if (tumAyetler == null || tumAyetler.isEmpty) continue;

      final ilkSegment = i == 0;
      final sonSegment = i == _sureSegmentleri.length - 1;
      final baslangic = ilkSegment ? _etkinBaslangicAyetNo : 1;
      final bitis = sonSegment ? _etkinBitisAyetNo : tumAyetler.last.no;

      for (final a in tumAyetler) {
        if (a.no < baslangic || a.no > bitis) continue;
        liste.add(_SureAyet(sure.no, a));
      }
    }
    return liste;
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

  Future<void> _loadArapcaFont() async {
    final font = await ArapcaFontAyarlari.yukle();
    if (mounted) setState(() => _arapcaFont = font);
  }

  void _arapcaFontuSec(String fontFamily) {
    setState(() => _arapcaFont = fontFamily);
    ArapcaFontAyarlari.kaydet(fontFamily);
  }

  Future<void> _loadGosterimAyarlari() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _okunusGizli = prefs.getBool('kuran_okunus_gizli') ?? false;
      _mealGizli = prefs.getBool('kuran_meal_gizli') ?? false;
    });
  }

  void _toggleOkunusGizli() {
    setState(() => _okunusGizli = !_okunusGizli);
    SharedPreferences.getInstance().then(
      (p) => p.setBool('kuran_okunus_gizli', _okunusGizli),
    );
  }

  void _toggleMealGizli() {
    setState(() => _mealGizli = !_mealGizli);
    SharedPreferences.getInstance().then(
      (p) => p.setBool('kuran_meal_gizli', _mealGizli),
    );
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

  List<Ayet> _hamVeriyiAyetlereDonustur(List<Map<String, dynamic>> ham) {
    return ham
        .map(
          (a) => Ayet(
            no: a['no'] is int
                ? a['no'] as int
                : int.tryParse(a['no']?.toString() ?? '') ?? 0,
            arapca: a['arapca']?.toString() ?? '',
            okunus: a['okunus']?.toString() ?? '',
            meal: a['meal']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<void> _ayetleriYukle() async {
    // Cihazda gömülü tam Kur'an verisi (Elmalılı Hamdi Yazır meali) — internet
    // gerektirmez, her sure için kullanılabilir. Açılışta arka planda
    // yüklendiği için burada hazır olması beklenir (yüklüyse anında döner).
    await KuranVeriService.yukle();

    if (!KuranVeriService.yuklendiMi) {
      return _ayetleriYukleYedek();
    }

    // Hatim planından okunuyorsa ve günün hedefi başka bir surede
    // bitiyorsa, kullanıcı "Devam Et"e basmadan günün hedefinin tamamını
    // (birden fazla sureye yayılsa bile) tek seferde görür; hedefe
    // ulaştıktan sonra "Devam Et" yalnızca gerçek Mushaf sayfa sınırına
    // göre fazladan okuma sunar (bkz. _sayfaEkle).
    final hedefSureNo = widget.bitisAyetNo == null ? widget.hedefSureNo : null;
    final bitisSureNo = (hedefSureNo != null && hedefSureNo > widget.sure.no)
        ? hedefSureNo
        : widget.sure.no;

    final segmentler = <Sure>[];
    final harita = <int, List<Ayet>>{};
    for (int s = widget.sure.no; s <= bitisSureNo; s++) {
      final ham = KuranVeriService.sureAyetleri(s);
      if (ham.isEmpty) break;
      final sure = s == widget.sure.no
          ? widget.sure
          : sureListesi.firstWhere((x) => x.no == s, orElse: () => widget.sure);
      segmentler.add(sure);
      harita[s] = _hamVeriyiAyetlereDonustur(ham);
    }

    if (segmentler.isEmpty) {
      return _ayetleriYukleYedek();
    }

    final sonSure = segmentler.last;
    final sonAyetler = harita[sonSure.no]!;
    final etkinBitisAyet =
        widget.bitisAyetNo ??
        (hedefSureNo != null && sonSure.no == hedefSureNo
            ? widget.hedefAyetNo!
            : sonAyetler.last.no);

    setState(() {
      _sureSegmentleri = segmentler;
      _sureAyetleriMap
        ..clear()
        ..addAll(harita);
      _etkinBaslangicSureNo = widget.sure.no;
      _etkinBaslangicAyetNo = widget.baslangicAyetNo ?? 1;
      _etkinBitisSureNo = sonSure.no;
      _etkinBitisAyetNo = etkinBitisAyet;
      _ayetler = _duzListeOlustur();
      _renderOgeleri = _renderListesiOlustur();
      _yukleniyor = false;
    });
    _scrollToBaslangicAyet();
  }

  /// Yerel Kur'an verisi yüklenememişse (aşırı nadir) düşülen tekil-sure
  /// yedek yol: dil dosyasındaki hazır ayetler, olmazsa API. Çoklu sure
  /// desteklemez; hatim planından okurken bile o an açık olan tek sureyi
  /// gösterir.
  Future<void> _ayetleriYukleYedek() async {
    final hazirAyetler = _getHazirAyetler(widget.sure.no);
    if (hazirAyetler.isNotEmpty) {
      _tekSureYukle(hazirAyetler);
      return;
    }

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

          final tumAyetler = List.generate(arapca.length, (i) {
            return Ayet(
              no: arapca[i]['numberInSurah'],
              arapca: arapca[i]['text'],
              okunus: okunusEdition != null ? okunusEdition[i]['text'] : '',
              meal: turkce[i]['text'],
            );
          });
          _tekSureYukle(tumAyetler);
        }
      } else {
        setState(() {
          _hata =
              _languageService['verses_load_failed'] ??
              'Verses could not be loaded';
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

  void _tekSureYukle(List<Ayet> tumAyetler) {
    setState(() {
      _sureSegmentleri = [widget.sure];
      _sureAyetleriMap
        ..clear()
        ..[widget.sure.no] = tumAyetler;
      _etkinBaslangicSureNo = widget.sure.no;
      _etkinBaslangicAyetNo = widget.baslangicAyetNo ?? 1;
      _etkinBitisSureNo = widget.sure.no;
      _etkinBitisAyetNo = widget.bitisAyetNo ?? tumAyetler.last.no;
      _ayetler = _duzListeOlustur();
      _renderOgeleri = _renderListesiOlustur();
      _yukleniyor = false;
    });
    _scrollToBaslangicAyet();
  }

  /// Geri gidilmeden önce kaldığın yeri kaydeder. dispose() içindeki
  /// fire-and-forget çağrı, kullanıcı hemen ardından "Kaldığın Yerden Oku"ya
  /// bastığında henüz tamamlanmamış olabilir (SharedPreferences yazımı bir
  /// sonraki karede biter, ama sayfa zaten kapanmış ve okuma yeniden
  /// açılmıştır) — bu yarış durumu, eski konumun gösterilmesine yol açar.
  /// PopScope ile pop işlemi, kayıt bitene kadar geciktirilir.
  Future<void> _kaydedipGeriDon() async {
    await _kaydetSonOkunanYer();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _kaydedipGeriDon();
      },
      child: Scaffold(
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
                  fontFamily: _arapcaFont,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: _okumaModu ? Colors.white : Colors.transparent,
          elevation: _okumaModu ? 1 : 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _yaziRengi),
            onPressed: _kaydedipGeriDon,
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.palette_outlined, color: _yaziRengi),
              tooltip: _languageService['reading_mode'] ?? 'Okuma Modu',
              onSelected: (value) {
                if (value == 'toggle') {
                  _toggleOkumaModu();
                } else if (value == 'toggle_okunus') {
                  _toggleOkunusGizli();
                } else if (value == 'toggle_meal') {
                  _toggleMealGizli();
                } else if (value.startsWith('font_')) {
                  _arapcaFontuSec(value.substring('font_'.length));
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
                        _languageService['black_white_mode'] ??
                            'Black & White Mode',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  enabled: false,
                  child: Padding(
                    padding: EdgeInsets.only(left: 32),
                    child: Text(
                      _languageService['reading_mode_desc'] ?? 'Eases reading',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'toggle_okunus',
                  child: Row(
                    children: [
                      Icon(
                        _okunusGizli
                            ? Icons.check_box_outline_blank
                            : Icons.check_box,
                        color: _okunusGizli ? Colors.grey : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text('Okunuşu Göster'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_meal',
                  child: Row(
                    children: [
                      Icon(
                        _mealGizli
                            ? Icons.check_box_outline_blank
                            : Icons.check_box,
                        color: _mealGizli ? Colors.grey : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text('Meali Göster'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Arapça Yazı Tipi',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                ...ArapcaFontAyarlari.secenekler.map(
                  (secenek) => PopupMenuItem(
                    value: 'font_${secenek.fontFamily}',
                    child: Row(
                      children: [
                        Icon(
                          _arapcaFont == secenek.fontFamily
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _arapcaFont == secenek.fontFamily
                              ? Colors.green
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(secenek.isim),
                              Text(
                                secenek.aciklama,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
            _buildSesIndirmeButonu(),
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
              : Builder(
                  builder: (context) {
                    final ogeler = _renderOgeleri;
                    final oncekiVarMi = _oncekiSayfaGosterilsinMi;
                    final ustOfset = oncekiVarMi ? 1 : 0;
                    return ListView.builder(
                      key: _listeKey,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount:
                          ustOfset +
                          ogeler.length +
                          (widget.hatimPlanId != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (oncekiVarMi && index == 0) {
                          return _buildOncekiSayfaButonu(renkler);
                        }
                        final gercekIndex = index - ustOfset;
                        if (gercekIndex >= ogeler.length) {
                          return _buildDevamEtButonu(renkler);
                        }

                        final oge = ogeler[gercekIndex];
                        if (oge.besmele) {
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
                                fontFamily: _arapcaFont,
                              ),
                            ),
                          );
                        }
                        if (oge.sureBasligi != null) {
                          return _buildSureBasligi(oge.sureBasligi!, renkler);
                        }
                        final sureAyet = oge.ayet!;
                        return _buildAyetKarti(
                          sureAyet.ayet,
                          sureAyet.sureNo,
                          renkler,
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  /// [_ayetler] düz listesindeki sure geçişlerinden, ekranda gösterilecek
  /// öğe dizisini (sure başlığı / besmele / ayet kartı) üretir. Hatim
  /// planı dışı normal okumada tek bir sure segmenti olduğundan, davranış
  /// öncekiyle aynıdır.
  List<_OkumaOgesi> _renderListesiOlustur() {
    final liste = <_OkumaOgesi>[];
    int? oncekiSure;
    for (final e in _ayetler) {
      if (e.sureNo != oncekiSure) {
        if (oncekiSure != null) {
          liste.add(_OkumaOgesi.baslik(e.sureNo));
        }
        if (e.sureNo != 1 && e.sureNo != 9) {
          liste.add(const _OkumaOgesi.besmeleBlok());
        }
        oncekiSure = e.sureNo;
      }
      liste.add(_OkumaOgesi.ayetKarti(e));
    }
    return liste;
  }

  Widget _buildSureBasligi(int sureNo, TemaRenkleri renkler) {
    final sure = sureListesi.firstWhere(
      (s) => s.no == sureNo,
      orElse: () => widget.sure,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: renkler.vurgu.withOpacity(0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Text(
                  sure.turkceAd,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  sure.arapca,
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 15,
                    fontFamily: _arapcaFont,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Divider(color: renkler.vurgu.withOpacity(0.3))),
        ],
      ),
    );
  }

  Widget _buildTamamlandiKarti(TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: renkler.vurgu.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.celebration_rounded, color: renkler.vurgu, size: 32),
          const SizedBox(height: 8),
          Text(
            _languageService['hatim_plan_completed'] ??
                'Tebrikler, hatmini tamamladın! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevamButonGovdesi({
    required TemaRenkleri renkler,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: renkler.vurgu.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: renkler.vurgu.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baslik,
                        style: TextStyle(
                          color: renkler.vurgu,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        altBaslik,
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: renkler.vurgu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kullanıcı isterse Mushaf'ın gerçek sayfa sınırlarına göre birer sayfa
  /// daha okuyabilir. Görünülen aralık ([_ayetleriYukle]) zaten günün tüm
  /// hedefini (birden fazla sureye yayılsa bile) içerdiğinden, bu buton
  /// yalnızca hedefin ötesine "fazladan" okumak için kullanılır. Yeni
  /// sayfa farklı bir surede bitiyorsa o sure(ler) sessizce yüklenip
  /// listeye eklenir — sayfa değiştirmeden aynı ekranda devam edilir.
  Widget _buildDevamEtButonu(TemaRenkleri renkler) {
    if (!KuranVeriService.sayfaVerisiHazirMi) {
      return _buildTamamlandiKarti(renkler);
    }

    final suankiSayfa = KuranVeriService.sayfaNoForSureAyet(
      _etkinBitisSureNo,
      _etkinBitisAyetNo,
    );
    final sonrakiSayfa = suankiSayfa + 1;
    if (sonrakiSayfa > KuranVeriService.toplamSayfaSayisi) {
      return _buildTamamlandiKarti(renkler);
    }

    final sayfaBitis = KuranVeriService.sayfaBitisi(sonrakiSayfa);

    return _buildDevamButonGovdesi(
      renkler: renkler,
      baslik: _languageService['hatim_plan_add_one_page'] ?? 'Devam Et',
      altBaslik:
          (_languageService['hatim_plan_add_one_page_desc'] ??
                  '{sayfa}. sayfayı ekle')
              .replaceAll('{sayfa}', '$sonrakiSayfa'),
      onTap: () => _sayfaEkle(sayfaBitis),
    );
  }

  void _sayfaEkle(List<int> sayfaBitis) {
    _gorunenSureNo = _etkinBitisSureNo;
    _gorunenAyetNo = _etkinBitisAyetNo;
    _kaydetSonOkunanYer();

    setState(() {
      for (int s = _etkinBitisSureNo; s <= sayfaBitis[0]; s++) {
        if (_sureAyetleriMap.containsKey(s)) continue;
        final ham = KuranVeriService.sureAyetleri(s);
        if (ham.isEmpty) continue;
        _sureAyetleriMap[s] = _hamVeriyiAyetlereDonustur(ham);
        _sureSegmentleri.add(
          sureListesi.firstWhere((x) => x.no == s, orElse: () => widget.sure),
        );
      }
      _etkinBitisSureNo = sayfaBitis[0];
      _etkinBitisAyetNo = sayfaBitis[1];
      _ayetler = _duzListeOlustur();
      _renderOgeleri = _renderListesiOlustur();
    });
  }

  /// Hatim planından okurken görünüm tam olarak kaldığın ayetten başlar;
  /// öncesini görmek isteyenler için listenin en üstünde gösterilen bu
  /// buton, Mushaf'ın gerçek sayfa sınırına göre bir önceki sayfayı
  /// geriye doğru ekler (bkz. _buildDevamEtButonu'nun ileri yönlü eşi).
  /// Fatiha'ya (Kur'an'ın başına) ulaşılınca kaybolur.
  bool get _oncekiSayfaGosterilsinMi =>
      widget.hatimPlanId != null &&
      (_etkinBaslangicSureNo > 1 || _etkinBaslangicAyetNo > 1);

  Widget _buildOncekiSayfaButonu(TemaRenkleri renkler) {
    if (!KuranVeriService.sayfaVerisiHazirMi) return const SizedBox.shrink();

    final suankiSayfa = KuranVeriService.sayfaNoForSureAyet(
      _etkinBaslangicSureNo,
      _etkinBaslangicAyetNo,
    );
    final oncekiSayfa = suankiSayfa - 1;
    if (oncekiSayfa < 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _oncekiSayfayiEkle(oncekiSayfa),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: renkler.vurgu.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: renkler.vurgu.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_upward_rounded, color: renkler.vurgu),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _languageService['hatim_plan_show_previous'] ??
                            'Öncesini Göster',
                        style: TextStyle(
                          color: renkler.vurgu,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (_languageService['hatim_plan_show_previous_desc'] ??
                                '{sayfa}. sayfayı ekle')
                            .replaceAll('{sayfa}', '$oncekiSayfa'),
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _oncekiSayfayiEkle(int oncekiSayfa) {
    final sayfaBaslangic = KuranVeriService.sayfaBaslangici(oncekiSayfa);
    final eskiPiksel = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final eskiUzunluk = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    setState(() {
      final yeniSegmentler = <Sure>[];
      for (int s = sayfaBaslangic[0]; s < _etkinBaslangicSureNo; s++) {
        if (!_sureAyetleriMap.containsKey(s)) {
          final ham = KuranVeriService.sureAyetleri(s);
          if (ham.isEmpty) continue;
          _sureAyetleriMap[s] = _hamVeriyiAyetlereDonustur(ham);
        }
        yeniSegmentler.add(
          sureListesi.firstWhere((x) => x.no == s, orElse: () => widget.sure),
        );
      }
      _sureSegmentleri = [...yeniSegmentler, ..._sureSegmentleri];
      _etkinBaslangicSureNo = sayfaBaslangic[0];
      _etkinBaslangicAyetNo = sayfaBaslangic[1];
      _ayetler = _duzListeOlustur();
      _renderOgeleri = _renderListesiOlustur();
    });

    // Yeni içerik en üste eklendi; kullanıcı hâlâ aynı ayetlere bakıyor
    // olsun diye kaydırma konumu, eklenen içeriğin yüksekliği kadar
    // kaydırılır (aksi halde liste büyüdüğünde görünüm otomatik en tepeye,
    // yani az önce eklenen sayfaya zıplar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final yeniUzunluk = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(eskiPiksel + (yeniUzunluk - eskiUzunluk));
    });
  }

  Widget _buildSesIndirmeButonu() {
    // İndirme yalnızca ilk sure için çalışır (bkz. _sureyiIndir); görünüm
    // birden fazla sureye yayıldığında (hatim planı, "Devam Et" ile
    // genişletilmiş) yanıltıcı olmaması için gizlenir.
    if (_sureSegmentleri.length > 1) return const SizedBox.shrink();

    if (_sureIndiriliyor) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                color: _vurguRengi,
                value: _indirmeToplam > 0
                    ? _indirmeTamamlanan / _indirmeToplam
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        _sureIndirilmis ? Icons.download_done : Icons.download_outlined,
        color: _sureIndirilmis ? Colors.green : _yaziRengi,
      ),
      tooltip: _sureIndirilmis
          ? (_languageService['audio_downloaded'] ?? 'Ses indirildi')
          : (_languageService['download_audio'] ?? 'Sesli okuyuşu indir'),
      onPressed: _sureIndirilmis ? _sureSesiniSilOnayla : _sureyiIndir,
    );
  }

  Future<void> _sureSesiniSilOnayla() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService['delete_audio'] ?? 'Ses dosyalarını sil'),
        content: Text(
          _languageService['delete_audio_confirm'] ??
              'Bu surenin indirilen ses dosyaları cihazdan silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService['cancel'] ?? 'Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_languageService['delete'] ?? 'Sil'),
          ),
        ],
      ),
    );
    if (onay == true) {
      await _sureSesiniSil();
    }
  }

  /// Ayeti paylaşım önizlemesinde açar. Kart, ayet olduğu için besmele ile
  /// başlar; kaynak "Sure adı, ayet no" biçiminde yazılır.
  void _ayetiPaylas(Ayet ayet, int sureNo) {
    final sureAdi = sureListesi
        .firstWhere((s) => s.no == sureNo, orElse: () => widget.sure)
        .turkceAd;
    PaylasimOnizlemeSayfa.ac(
      context,
      PaylasimIcerigi(
        tur: PaylasimIcerikTuru.ayet,
        baslik: _languageService['quran'] ?? 'Kur\'an-ı Kerim',
        metin: ayet.meal,
        kaynak: '$sureAdi, ${ayet.no}',
        arapca: ayet.arapca,
      ),
    );
  }

  Widget _buildAyetKarti(Ayet ayet, int sureNo, TemaRenkleri renkler) {
    // Hide recitation/translation for Arabic or Persian
    final currentLang = _languageService.currentLanguage;
    final dilNedeniyleGizli = currentLang == 'ar' || currentLang == 'fa';
    final okunusGorunsun =
        !dilNedeniyleGizli && !_okunusGizli && ayet.okunus.isNotEmpty;
    final mealGorunsun =
        !dilNedeniyleGizli && !_mealGizli && ayet.meal.isNotEmpty;

    final buAyetCaliyor = _calanSureNo == sureNo && _calanAyetNo == ayet.no;

    return Container(
      key: _ayetAnahtari(sureNo, ayet.no),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: buAyetCaliyor ? _vurguRengi.withOpacity(0.08) : _kartRengi,
        borderRadius: BorderRadius.circular(16),
        border: buAyetCaliyor
            ? Border.all(color: _vurguRengi, width: 1.5)
            : (_okumaModu ? Border.all(color: Colors.grey.shade200) : null),
        boxShadow: buAyetCaliyor
            ? [BoxShadow(color: _vurguRengi.withOpacity(0.25), blurRadius: 12)]
            : (_okumaModu
                  ? []
                  : [
                      BoxShadow(
                        color: renkler.vurgu.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ]),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _ayetiCalDurdur(ayet, sureNo),
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
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _ayetiPaylas(ayet, sureNo),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.share_rounded,
                      color: _okumaModu ? Colors.black54 : renkler.vurgu,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _ayetiCalDurdur(ayet, sureNo),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child:
                        _calanSureNo == sureNo &&
                            _calanAyetNo == ayet.no &&
                            _sesYukleniyor
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _vurguRengi,
                            ),
                          )
                        : Icon(
                            _calanSureNo == sureNo && _calanAyetNo == ayet.no
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            color:
                                _calanSureNo == sureNo &&
                                    _calanAyetNo == ayet.no
                                ? _vurguRengi
                                : (_okumaModu ? Colors.black54 : renkler.vurgu),
                            size: 22,
                          ),
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
                fontFamily: _arapcaFont,
              ),
            ),
          ),

          // Recitation - shown for non-Arabic/Persian languages
          if (okunusGorunsun)
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
          if (mealGorunsun)
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
        ),
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
  String _arapcaFont = ArapcaFontAyarlari.varsayilanFont;

  @override
  void initState() {
    super.initState();
    ArapcaFontAyarlari.yukle().then((font) {
      if (mounted) setState(() => _arapcaFont = font);
    });
  }

  List<_CuzSureSegment> _getCuzSureleri() {
    final tumSureler = sureListesi;

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
                      fontFamily: _arapcaFont,
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
                    fontFamily: _arapcaFont,
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
