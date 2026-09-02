import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/zekat_hesaplama_service.dart';

/// Zekât / fitre hesaplayıcı: nisap eşiği, altın/gümüş/nakit girişiyle
/// klasik zekât hesabı ve kişi başı miktarla fitre hesabı. Tamamen
/// çevrimdışı — güncel altın/gümüş fiyatı ve yıllık fitre miktarı canlı
/// veri olarak çekilmez, kullanıcı kendisi girer (bkz.
/// [ZekatHesaplamaService]).
class ZekatHesaplayiciSayfa extends StatefulWidget {
  const ZekatHesaplayiciSayfa({super.key});

  @override
  State<ZekatHesaplayiciSayfa> createState() => _ZekatHesaplayiciSayfaState();
}

class _ZekatHesaplayiciSayfaState extends State<ZekatHesaplayiciSayfa>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  late final TabController _tabController;

  final _altinGramCtrl = TextEditingController();
  final _altinFiyatCtrl = TextEditingController();
  final _gumusGramCtrl = TextEditingController();
  final _gumusFiyatCtrl = TextEditingController();
  final _nakitCtrl = TextEditingController();
  NisapOlcusu _nisapOlcusu = NisapOlcusu.altin;
  ZekatSonucu? _zekatSonucu;

  final _fitreKisiBasiCtrl = TextEditingController();
  final _fitreKisiSayisiCtrl = TextEditingController();
  double? _fitreSonucu;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _degerleriYukle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _altinGramCtrl.dispose();
    _altinFiyatCtrl.dispose();
    _gumusGramCtrl.dispose();
    _gumusFiyatCtrl.dispose();
    _nakitCtrl.dispose();
    _fitreKisiBasiCtrl.dispose();
    _fitreKisiSayisiCtrl.dispose();
    super.dispose();
  }

  Future<void> _degerleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    _altinGramCtrl.text = prefs.getString('zekat_altin_gram') ?? '';
    _altinFiyatCtrl.text = prefs.getString('zekat_altin_fiyat') ?? '';
    _gumusGramCtrl.text = prefs.getString('zekat_gumus_gram') ?? '';
    _gumusFiyatCtrl.text = prefs.getString('zekat_gumus_fiyat') ?? '';
    _nakitCtrl.text = prefs.getString('zekat_nakit') ?? '';
    _fitreKisiBasiCtrl.text = prefs.getString('fitre_kisi_basi') ?? '';
    _fitreKisiSayisiCtrl.text = prefs.getString('fitre_kisi_sayisi') ?? '';
    final olcut = prefs.getString('zekat_nisap_olcusu');
    if (mounted) {
      setState(() {
        _nisapOlcusu = olcut == 'gumus' ? NisapOlcusu.gumus : NisapOlcusu.altin;
      });
    }
  }

  Future<void> _degerleriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zekat_altin_gram', _altinGramCtrl.text);
    await prefs.setString('zekat_altin_fiyat', _altinFiyatCtrl.text);
    await prefs.setString('zekat_gumus_gram', _gumusGramCtrl.text);
    await prefs.setString('zekat_gumus_fiyat', _gumusFiyatCtrl.text);
    await prefs.setString('zekat_nakit', _nakitCtrl.text);
    await prefs.setString(
      'zekat_nisap_olcusu',
      _nisapOlcusu == NisapOlcusu.gumus ? 'gumus' : 'altin',
    );
    await prefs.setString('fitre_kisi_basi', _fitreKisiBasiCtrl.text);
    await prefs.setString('fitre_kisi_sayisi', _fitreKisiSayisiCtrl.text);
  }

  double _sayiyaCevir(String metin) {
    final normalize = metin.trim().replaceAll(',', '.');
    return double.tryParse(normalize) ?? 0.0;
  }

  String _ceviri(String anahtar, String yedek) {
    final deger = _languageService[anahtar];
    if (deger is String && deger.trim().isNotEmpty) return deger;
    return yedek;
  }

  void _zekatiHesapla() {
    final sonuc = ZekatHesaplamaService.hesaplaZekat(
      altinGram: _sayiyaCevir(_altinGramCtrl.text),
      altinFiyatGram: _sayiyaCevir(_altinFiyatCtrl.text),
      gumusGram: _sayiyaCevir(_gumusGramCtrl.text),
      gumusFiyatGram: _sayiyaCevir(_gumusFiyatCtrl.text),
      nakit: _sayiyaCevir(_nakitCtrl.text),
      olcut: _nisapOlcusu,
    );
    setState(() => _zekatSonucu = sonuc);
    _degerleriKaydet();
  }

  void _fitreyiHesapla() {
    final sonuc = ZekatHesaplamaService.hesaplaFitre(
      kisiBasi: _sayiyaCevir(_fitreKisiBasiCtrl.text),
      kisiSayisi: int.tryParse(_fitreKisiSayisiCtrl.text.trim()) ?? 0,
    );
    setState(() => _fitreSonucu = sonuc);
    _degerleriKaydet();
  }

  String _tlFormat(double deger) => '${deger.toStringAsFixed(2)} ₺';

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _ceviri('zakat_calculator', 'Zekât Hesaplayıcı'),
          style: TextStyle(color: renkler.yaziPrimary, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: renkler.vurgu,
          labelColor: renkler.vurgu,
          unselectedLabelColor: renkler.yaziSecondary,
          tabs: [
            Tab(text: _ceviri('zakat', 'Zekât')),
            Tab(text: _ceviri('fitre', 'Fitre')),
          ],
        ),
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: [_zekatSekmesi(renkler), _fitreSekmesi(renkler)],
          ),
        ),
      ),
    );
  }

  Widget _zekatSekmesi(TemaRenkleri renkler) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bolumBasligi(_ceviri('gold', 'Altın'), renkler),
          const SizedBox(height: 10),
          _sayiAlani(
            controller: _altinGramCtrl,
            etiket: _ceviri('gold_gram', 'Altın (gram)'),
            renkler: renkler,
          ),
          const SizedBox(height: 12),
          _sayiAlani(
            controller: _altinFiyatCtrl,
            etiket: _ceviri('gold_price_per_gram', 'Gram altın fiyatı (₺)'),
            renkler: renkler,
          ),
          const SizedBox(height: 20),
          _bolumBasligi(_ceviri('silver', 'Gümüş'), renkler),
          const SizedBox(height: 10),
          _sayiAlani(
            controller: _gumusGramCtrl,
            etiket: _ceviri('silver_gram', 'Gümüş (gram)'),
            renkler: renkler,
          ),
          const SizedBox(height: 12),
          _sayiAlani(
            controller: _gumusFiyatCtrl,
            etiket: _ceviri('silver_price_per_gram', 'Gram gümüş fiyatı (₺)'),
            renkler: renkler,
          ),
          const SizedBox(height: 20),
          _bolumBasligi(_ceviri('cash', 'Nakit'), renkler),
          const SizedBox(height: 10),
          _sayiAlani(
            controller: _nakitCtrl,
            etiket: _ceviri('cash', 'Nakit (₺)'),
            renkler: renkler,
          ),
          const SizedBox(height: 20),
          _bolumBasligi(_ceviri('nisab', 'Nisap Ölçütü'), renkler),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _olcutCipi(
                  secili: _nisapOlcusu == NisapOlcusu.altin,
                  etiket: _ceviri('nisab_basis_gold', 'Altın (85 gr)'),
                  renkler: renkler,
                  onTap: () => setState(() => _nisapOlcusu = NisapOlcusu.altin),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _olcutCipi(
                  secili: _nisapOlcusu == NisapOlcusu.gumus,
                  etiket: _ceviri('nisab_basis_silver', 'Gümüş (595 gr)'),
                  renkler: renkler,
                  onTap: () => setState(() => _nisapOlcusu = NisapOlcusu.gumus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _hesaplaButonu(_zekatiHesapla, renkler),
          if (_zekatSonucu != null) ...[
            const SizedBox(height: 20),
            _zekatSonucKarti(_zekatSonucu!, renkler),
          ],
        ],
      ),
    );
  }

  Widget _fitreSekmesi(TemaRenkleri renkler) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sayiAlani(
            controller: _fitreKisiBasiCtrl,
            etiket: _ceviri('fitre_per_person', 'Kişi başı fitre miktarı (₺)'),
            renkler: renkler,
          ),
          const SizedBox(height: 12),
          _sayiAlani(
            controller: _fitreKisiSayisiCtrl,
            etiket: _ceviri('fitre_person_count', 'Kişi sayısı'),
            renkler: renkler,
            ondalikli: false,
          ),
          const SizedBox(height: 24),
          _hesaplaButonu(_fitreyiHesapla, renkler),
          if (_fitreSonucu != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: renkler.kartArkaPlan,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ceviri('total_fitre', 'Toplam Fitre'),
                    style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tlFormat(_fitreSonucu!),
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bolumBasligi(String metin, TemaRenkleri renkler) {
    return Text(
      metin.toUpperCase(),
      style: TextStyle(
        color: renkler.yaziSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _sayiAlani({
    required TextEditingController controller,
    required String etiket,
    required TemaRenkleri renkler,
    bool ondalikli = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: ondalikli),
      inputFormatters: [
        if (ondalikli)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      style: TextStyle(color: renkler.yaziPrimary),
      decoration: InputDecoration(
        labelText: etiket,
        labelStyle: TextStyle(color: renkler.yaziSecondary),
        filled: true,
        fillColor: renkler.kartArkaPlan.withOpacity(0.4),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: renkler.vurgu.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: renkler.vurgu),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _olcutCipi({
    required bool secili,
    required String etiket,
    required TemaRenkleri renkler,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secili
              ? renkler.vurgu.withOpacity(0.15)
              : renkler.kartArkaPlan.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: secili ? renkler.vurgu : renkler.yaziSecondary.withOpacity(0.3),
            width: secili ? 2 : 1,
          ),
        ),
        child: Text(
          etiket,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secili ? renkler.vurgu : renkler.yaziSecondary,
            fontSize: 13,
            fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _hesaplaButonu(VoidCallback onTap, TemaRenkleri renkler) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: renkler.vurgu,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          _ceviri('calculate', 'Hesapla'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _zekatSonucKarti(ZekatSonucu sonuc, TemaRenkleri renkler) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sonucSatiri(
            _ceviri('total_wealth', 'Toplam Varlık'),
            _tlFormat(sonuc.toplamVarlik),
            renkler,
          ),
          const SizedBox(height: 8),
          _sonucSatiri(
            _ceviri('nisab', 'Nisap Değeri'),
            _tlFormat(sonuc.nisapDegeri),
            renkler,
          ),
          const Divider(height: 24),
          if (!sonuc.nisabaUlasti)
            Text(
              _ceviri('nisab_not_reached', 'Varlığınız nisap sınırına ulaşmıyor, zekât gerekmiyor.'),
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
            )
          else ...[
            Text(
              _ceviri('zakat_due', 'Ödenecek Zekât'),
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _tlFormat(sonuc.odenecekZekat),
              style: TextStyle(
                color: renkler.vurgu,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sonucSatiri(String etiket, String deger, TemaRenkleri renkler) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiket, style: TextStyle(color: renkler.yaziSecondary, fontSize: 13)),
        Text(
          deger,
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
