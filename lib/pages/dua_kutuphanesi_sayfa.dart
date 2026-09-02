import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/dua_kutuphanesi_service.dart';
import 'dua_detay_sayfa.dart';
import 'dua_kategori_sayfa.dart';
import 'genel_dualar_sayfa.dart';

/// Kütüphane > Dua Kütüphanesi: dualar kategori halinde listelenir (ör.
/// "Ezan Duası", "Nazar Duası", "Yemek Duası"). Tek duası olan kategoriler
/// tıklanınca doğrudan o duayı, birden fazla duası olanlar (yemek, uyku
/// gibi) ise hepsini alt alta gösterir (bkz. [DuaKategoriSayfa]).
/// AppBar'daki kalp ikonu, kategoriden bağımsız favori duaları düz liste
/// halinde gösterir (bkz. [DuaDetaySayfa]).
class DuaKutuphanesiSayfa extends StatefulWidget {
  const DuaKutuphanesiSayfa({super.key});

  @override
  State<DuaKutuphanesiSayfa> createState() => _DuaKutuphanesiSayfaState();
}

class _DuaKutuphanesiSayfaState extends State<DuaKutuphanesiSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  Set<String> _favoriIdleri = {};
  bool _sadeceFavoriler = false;

  @override
  void initState() {
    super.initState();
    _favorileriYukle();
  }

  Future<void> _favorileriYukle() async {
    final favoriler = await DuaKutuphanesiService.favoriIdleri();
    if (mounted) setState(() => _favoriIdleri = favoriler);
  }

  String _ceviri(String anahtar, String yedek) {
    final deger = _languageService[anahtar];
    if (deger is String && deger.trim().isNotEmpty) return deger;
    return yedek;
  }

  String _kategoriBasligi(String kategori) {
    final ad = _ceviri('dua_category_$kategori', kategori);
    final duaKelimesi = _ceviri('dua_word', 'Duası');
    return '$ad $duaKelimesi';
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _ceviri('dua_library_title', 'DUA KÜTÜPHANESİ'),
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
        actions: [
          IconButton(
            icon: Icon(
              _sadeceFavoriler
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _sadeceFavoriler ? Colors.pink : renkler.yaziPrimary,
            ),
            tooltip: _ceviri('dua_favorites', 'Favorilerim'),
            onPressed: () =>
                setState(() => _sadeceFavoriler = !_sadeceFavoriler),
          ),
        ],
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SafeArea(
          top: false,
          child: _sadeceFavoriler ? _favoriListesi(renkler) : _kategoriListesi(renkler),
        ),
      ),
    );
  }

  Widget _kategoriListesi(TemaRenkleri renkler) {
    return FutureBuilder<List<DuaKaydi>>(
      future: DuaKutuphanesiService.tumDualar(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: renkler.vurgu));
        }
        final tumDualar = snapshot.data ?? const [];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: DuaKutuphanesiService.kategoriler.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _genelDualarOgesi(context, renkler);
            final kategori = DuaKutuphanesiService.kategoriler[index - 1];
            final dualar = tumDualar.where((d) => d.kategori == kategori).toList();
            return _kategoriOgesi(kategori, dualar, renkler);
          },
        );
      },
    );
  }

  Widget _favoriListesi(TemaRenkleri renkler) {
    return FutureBuilder<List<DuaKaydi>>(
      future: DuaKutuphanesiService.favoriDualar(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: renkler.vurgu));
        }
        final dualar = snapshot.data ?? const [];
        if (dualar.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _ceviri('dua_no_favorites', 'Henüz favori dua eklemedin'),
                textAlign: TextAlign.center,
                style: TextStyle(color: renkler.yaziSecondary),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: dualar.length,
          itemBuilder: (context, index) => _duaListeOgesi(dualar[index], renkler),
        );
      },
    );
  }

  Widget _genelDualarOgesi(BuildContext context, TemaRenkleri renkler) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renkler.vurgu.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GenelDualarSayfa()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: renkler.vurgu, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _ceviri('genel_dualar_title', 'Genel Dualar'),
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: renkler.yaziSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kategoriOgesi(
    String kategori,
    List<DuaKaydi> dualar,
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
          onTap: dualar.isEmpty
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DuaKategoriSayfa(
                      kategoriBaslik: _kategoriBasligi(kategori),
                      dualar: dualar,
                    ),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _kategoriBasligi(kategori),
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: renkler.yaziSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _duaListeOgesi(DuaKaydi dua, TemaRenkleri renkler) {
    final favori = _favoriIdleri.contains(dua.id);
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
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DuaDetaySayfa(dua: dua)),
            );
            _favorileriYukle();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    favori
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: favori ? Colors.pink : renkler.yaziSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _favoriDegistir(dua),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dua.baslik,
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: renkler.yaziSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _favoriDegistir(DuaKaydi dua) async {
    final eklendiMi = await DuaKutuphanesiService.favoriDegistir(dua.id);
    if (!mounted) return;
    setState(() {
      if (eklendiMi) {
        _favoriIdleri.add(dua.id);
      } else {
        _favoriIdleri.remove(dua.id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          eklendiMi
              ? _ceviri('dua_added_to_favorites', 'Favorilere eklendi')
              : _ceviri('dua_removed_from_favorites', 'Favorilerden çıkarıldı'),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
