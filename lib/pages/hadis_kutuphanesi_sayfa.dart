import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/hadis_kutuphanesi_service.dart';
import 'hadis_kategori_sayfa.dart';

/// Kütüphane > Hadisler: Riyâzü's-Sâlihîn'den derlenen hadisler, konu
/// başlığına göre (Cömertlik, Kibir ve Gurur, Tevazu ve Şefkat, ...) dikey
/// bir liste hâlinde gösterilir. AppBar'ın altındaki arama kutusu hadis
/// metni, konu başlığı veya kaynağına göre anlık filtreleme yapar.
class HadisKutuphanesiSayfa extends StatefulWidget {
  const HadisKutuphanesiSayfa({super.key});

  @override
  State<HadisKutuphanesiSayfa> createState() => _HadisKutuphanesiSayfaState();
}

class _HadisKutuphanesiSayfaState extends State<HadisKutuphanesiSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  final TextEditingController _aramaController = TextEditingController();

  String _aramaMetni = '';

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  String _ceviri(String anahtar, String yedek) {
    final deger = _languageService[anahtar];
    if (deger is String && deger.trim().isNotEmpty) return deger;
    return yedek;
  }

  List<HadisKaydi> _filtrele(List<HadisKaydi> hadisler, String aranan) {
    final q = aranan.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return hadisler.where((h) {
      return h.metin.toLowerCase().contains(q) ||
          h.kategori.toLowerCase().contains(q) ||
          h.kaynak.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          'HADİSLER',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _aramaKutusu(renkler),
              ),
              Expanded(
                child: _aramaMetni.trim().isNotEmpty
                    ? _aramaSonuclari(renkler)
                    : _kategoriListesi(renkler),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aramaKutusu(TemaRenkleri renkler) {
    return TextField(
      controller: _aramaController,
      onChanged: (deger) => setState(() => _aramaMetni = deger),
      style: TextStyle(color: renkler.yaziPrimary),
      decoration: InputDecoration(
        hintText: _ceviri('hadis_search_hint', 'Hadis ara...'),
        hintStyle: TextStyle(color: renkler.yaziSecondary),
        prefixIcon: Icon(Icons.search_rounded, color: renkler.yaziSecondary),
        suffixIcon: _aramaMetni.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded, color: renkler.yaziSecondary),
                onPressed: () {
                  _aramaController.clear();
                  setState(() => _aramaMetni = '');
                },
              )
            : null,
        filled: true,
        fillColor: renkler.kartArkaPlan,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _kategoriListesi(TemaRenkleri renkler) {
    return FutureBuilder<List<MapEntry<String, int>>>(
      future: HadisKutuphanesiService.kategoriler(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: renkler.vurgu),
          );
        }
        final kategoriler = snapshot.data ?? const [];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: kategoriler.length,
          itemBuilder: (context, index) {
            final girdi = kategoriler[index];
            return _kategoriOgesi(context, girdi.key, girdi.value, renkler);
          },
        );
      },
    );
  }

  Widget _aramaSonuclari(TemaRenkleri renkler) {
    return FutureBuilder<List<HadisKaydi>>(
      future: HadisKutuphanesiService.tumHadisler(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: renkler.vurgu));
        }
        final sonuclar = _filtrele(snapshot.data ?? const [], _aramaMetni);
        if (sonuclar.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _ceviri('search_no_results', 'Sonuç bulunamadı'),
                textAlign: TextAlign.center,
                style: TextStyle(color: renkler.yaziSecondary),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: sonuclar.length,
          itemBuilder: (context, index) =>
              _sonucOgesi(context, sonuclar[index], renkler),
        );
      },
    );
  }

  Widget _sonucOgesi(BuildContext context, HadisKaydi hadis, TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HadisKategoriSayfa(
                kategoriBaslik: hadis.kategori,
                hadisler: [hadis],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hadis.kategori,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hadis.metin,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kategoriOgesi(
    BuildContext context,
    String kategori,
    int sayi,
    TemaRenkleri renkler,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final dualar = await HadisKutuphanesiService.kategoriyeGoreHadisler(
              kategori,
            );
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HadisKategoriSayfa(
                  kategoriBaslik: kategori,
                  hadisler: dualar,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kategori,
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$sayi',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: renkler.yaziSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
