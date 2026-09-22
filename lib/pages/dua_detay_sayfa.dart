import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/dua_kutuphanesi_service.dart';
import '../widgets/paylasim_karti.dart';
import 'paylasim_onizleme_sayfa.dart';

/// Tek bir duanın Arapça + okunuş + meal ile tam gösterildiği detay sayfası.
/// Kur'an okuma sayfasındaki gibi yazı boyutu büyütme/küçültme desteği
/// içerir (bkz. [_fontScale]); tercih tüm dua kütüphanesi için ortak
/// saklanır (bkz. `dua_font_scale`).
class DuaDetaySayfa extends StatefulWidget {
  final DuaKaydi dua;

  const DuaDetaySayfa({super.key, required this.dua});

  @override
  State<DuaDetaySayfa> createState() => _DuaDetaySayfaState();
}

class _DuaDetaySayfaState extends State<DuaDetaySayfa> {
  final TemaService _temaService = TemaService();
  static const String _fontScaleAnahtari = 'dua_font_scale';

  double _fontScale = 1.0;
  bool _favori = false;

  @override
  void initState() {
    super.initState();
    _fontScaleYukle();
    _favoriYukle();
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

  Future<void> _favoriYukle() async {
    final favori = await DuaKutuphanesiService.favoriMi(widget.dua.id);
    if (mounted) setState(() => _favori = favori);
  }

  Future<void> _favoriDegistir() async {
    final eklendiMi = await DuaKutuphanesiService.favoriDegistir(
      widget.dua.id,
    );
    if (mounted) setState(() => _favori = eklendiMi);
  }

  void _paylas() {
    PaylasimOnizlemeSayfa.ac(
      context,
      PaylasimIcerigi(
        tur: PaylasimIcerikTuru.dua,
        baslik: widget.dua.baslik,
        metin: widget.dua.meal,
        kaynak: widget.dua.kaynak,
        arapca: widget.dua.arapca,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final dua = widget.dua;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          dua.baslik,
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
          IconButton(
            icon: Icon(
              _favori ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _favori ? Colors.pink : renkler.yaziPrimary,
            ),
            onPressed: _favoriDegistir,
            tooltip: 'Favori',
          ),
          IconButton(
            icon: Icon(Icons.share_rounded, color: renkler.yaziPrimary),
            onPressed: _paylas,
            tooltip: 'Paylaş',
          ),
        ],
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: renkler.kartArkaPlan,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: renkler.vurgu.withOpacity(0.1),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    const SizedBox(height: 16),
                    Text(
                      dua.kaynak,
                      style: TextStyle(
                        color: renkler.yaziSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
