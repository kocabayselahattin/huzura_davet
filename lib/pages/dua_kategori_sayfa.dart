import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/dua_kutuphanesi_service.dart';
import '../widgets/paylasim_karti.dart';
import 'paylasim_onizleme_sayfa.dart';

/// Bir kategorideki (ör. "Yemek Duası") tüm duaları alt alta gösteren sayfa.
/// Kategori tek bir duadan oluşuyorsa (ör. Ezan, Nazar) tek kart gösterilir;
/// birden fazla duası olan kategorilerde (yemek, uyku, ...) hepsi art arda
/// listelenir. Yazı boyutu tüm dua kütüphanesi için ortak saklanır (bkz.
/// [DuaDetaySayfa] ile aynı `dua_font_scale` anahtarı).
class DuaKategoriSayfa extends StatefulWidget {
  final String kategoriBaslik;
  final List<DuaKaydi> dualar;

  const DuaKategoriSayfa({
    super.key,
    required this.kategoriBaslik,
    required this.dualar,
  });

  @override
  State<DuaKategoriSayfa> createState() => _DuaKategoriSayfaState();
}

class _DuaKategoriSayfaState extends State<DuaKategoriSayfa> {
  final TemaService _temaService = TemaService();
  static const String _fontScaleAnahtari = 'dua_font_scale';

  double _fontScale = 1.0;
  Set<String> _favoriIdleri = {};

  @override
  void initState() {
    super.initState();
    _fontScaleYukle();
    _favorileriYukle();
  }

  Future<void> _fontScaleYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble(_fontScaleAnahtari) ?? 1.0;
    if (mounted) setState(() => _fontScale = scale);
  }

  Future<void> _fontScaleKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleAnahtari, _fontScale);
  }

  void _fontBuyut() {
    if (_fontScale < 2.0) {
      setState(() => _fontScale += 0.1);
      _fontScaleKaydet();
    }
  }

  void _fontKucult() {
    if (_fontScale > 0.7) {
      setState(() => _fontScale -= 0.1);
      _fontScaleKaydet();
    }
  }

  Future<void> _favorileriYukle() async {
    final favoriler = await DuaKutuphanesiService.favoriIdleri();
    if (mounted) setState(() => _favoriIdleri = favoriler);
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
  }

  void _paylas(DuaKaydi dua) {
    PaylasimOnizlemeSayfa.ac(
      context,
      PaylasimIcerigi(
        tur: PaylasimIcerikTuru.dua,
        baslik: dua.baslik,
        metin: dua.meal,
        kaynak: dua.kaynak,
        arapca: dua.arapca,
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
        actions: [
          IconButton(
            icon: Icon(Icons.text_decrease, color: renkler.yaziPrimary),
            onPressed: _fontKucult,
            tooltip: 'Yazıyı Küçült',
          ),
          IconButton(
            icon: Icon(Icons.text_increase, color: renkler.yaziPrimary),
            onPressed: _fontBuyut,
            tooltip: 'Yazıyı Büyüt',
          ),
        ],
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SafeArea(
          top: false,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.dualar.length,
            itemBuilder: (context, index) =>
                _duaBlogu(widget.dualar[index], renkler),
          ),
        ),
      ),
    );
  }

  Widget _duaBlogu(DuaKaydi dua, TemaRenkleri renkler) {
    final favori = _favoriIdleri.contains(dua.id);
    final tekDua = widget.dualar.length == 1;
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
          if (!tekDua && dua.baslik != widget.kategoriBaslik)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                dua.baslik,
                style: TextStyle(
                  color: renkler.vurgu,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (dua.arapca.isNotEmpty) ...[
            Text(
              dua.arapca,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: renkler.yaziPrimary,
                fontSize: 24 * _fontScale,
                fontFamily: 'Amiri',
                height: 2,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (dua.okunus.isNotEmpty) ...[
            Text(
              'Okunuşu',
              style: TextStyle(
                color: renkler.vurguSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dua.okunus,
              style: TextStyle(
                color: renkler.yaziPrimary,
                fontSize: 15 * _fontScale,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Meali',
            style: TextStyle(
              color: renkler.vurgu,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dua.meal,
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16 * _fontScale,
              height: 1.6,
            ),
          ),
          if (dua.kaynak.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              dua.kaynak,
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
                onPressed: () => _favoriDegistir(dua),
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: renkler.vurgu, size: 20),
                onPressed: () => _paylas(dua),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
