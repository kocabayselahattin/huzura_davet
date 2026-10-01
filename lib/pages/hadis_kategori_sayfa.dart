import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/hadis_kutuphanesi_service.dart';
import '../widgets/paylasim_karti.dart';
import 'paylasim_onizleme_sayfa.dart';

/// Bir konu başlığındaki (ör. "Cömertlik") tüm hadisleri alt alta gösterir.
class HadisKategoriSayfa extends StatefulWidget {
  final String kategoriBaslik;
  final List<HadisKaydi> hadisler;

  const HadisKategoriSayfa({
    super.key,
    required this.kategoriBaslik,
    required this.hadisler,
  });

  @override
  State<HadisKategoriSayfa> createState() => _HadisKategoriSayfaState();
}

class _HadisKategoriSayfaState extends State<HadisKategoriSayfa> {
  final TemaService _temaService = TemaService();
  Set<String> _favoriIdleri = {};

  @override
  void initState() {
    super.initState();
    _favorileriYukle();
  }

  Future<void> _favorileriYukle() async {
    final favoriler = await HadisKutuphanesiService.favoriIdleri();
    if (mounted) setState(() => _favoriIdleri = favoriler);
  }

  Future<void> _favoriDegistir(HadisKaydi hadis) async {
    final eklendiMi = await HadisKutuphanesiService.favoriDegistir(hadis.id);
    if (!mounted) return;
    setState(() {
      if (eklendiMi) {
        _favoriIdleri.add(hadis.id);
      } else {
        _favoriIdleri.remove(hadis.id);
      }
    });
  }

  void _paylas(HadisKaydi hadis) {
    PaylasimOnizlemeSayfa.ac(
      context,
      PaylasimIcerigi(
        tur: PaylasimIcerikTuru.hadis,
        baslik: hadis.kategori,
        metin: hadis.metin,
        kaynak: hadis.kaynak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          widget.kategoriBaslik,
          style: TextStyle(fontSize: 15, color: renkler.yaziPrimary),
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
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.hadisler.length,
            itemBuilder: (context, index) =>
                _hadisKarti(widget.hadisler[index], renkler),
          ),
        ),
      ),
    );
  }

  Widget _hadisKarti(HadisKaydi hadis, TemaRenkleri renkler) {
    final favori = _favoriIdleri.contains(hadis.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hadis.metin,
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16,
              height: 1.6,
            ),
          ),
          if (hadis.kaynak.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              hadis.kaynak,
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  favori
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: favori ? Colors.pink : renkler.yaziSecondary,
                  size: 20,
                ),
                onPressed: () => _favoriDegistir(hadis),
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: renkler.vurgu, size: 20),
                onPressed: () => _paylas(hadis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
