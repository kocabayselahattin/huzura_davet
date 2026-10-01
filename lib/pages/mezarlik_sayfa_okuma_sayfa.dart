import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/kuran_veri_service.dart';
import 'kuran_sayfa.dart';

/// Bir sureyi ayet ayet kartlara bölmeden, Mushaf sayfası gibi tek bir akan
/// metin halinde gösterir — mezarlık ziyaretinde hızlı ve kesintisiz okuma
/// için. Sadece Arapça metin gösterilir (okunuş/meal yok); her ayetin
/// sonunda küçük bir ayet numarası işareti (۝) bulunur.
class MezarlikSayfaOkumaSayfa extends StatefulWidget {
  final Sure sure;

  const MezarlikSayfaOkumaSayfa({super.key, required this.sure});

  @override
  State<MezarlikSayfaOkumaSayfa> createState() =>
      _MezarlikSayfaOkumaSayfaState();
}

class _MezarlikSayfaOkumaSayfaState extends State<MezarlikSayfaOkumaSayfa> {
  final TemaService _temaService = TemaService();
  static const List<String> _rakamlar = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  double _fontScale = 1.0;
  List<Map<String, dynamic>> _ayetler = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    await KuranVeriService.yukle();
    if (!mounted) return;
    setState(() {
      _ayetler = KuranVeriService.sureAyetleri(widget.sure.no);
      _yukleniyor = false;
    });
  }

  String _arapcaRakam(int sayi) {
    return sayi
        .toString()
        .split('')
        .map((c) => _rakamlar[int.parse(c)])
        .join();
  }

  void _fontBuyut() {
    if (_fontScale < 2.0) setState(() => _fontScale += 0.1);
  }

  void _fontKucult() {
    if (_fontScale > 0.7) setState(() => _fontScale -= 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          widget.sure.turkceAd,
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
          child: _yukleniyor
              ? Center(child: CircularProgressIndicator(color: renkler.vurgu))
              : SingleChildScrollView(
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
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: RichText(
                        textAlign: TextAlign.justify,
                        text: TextSpan(
                          children: [
                            for (final ham in _ayetler) ...[
                              TextSpan(
                                text: '${ham['arapca'] ?? ''} ',
                                style: TextStyle(
                                  color: renkler.yaziPrimary,
                                  fontSize: 22 * _fontScale,
                                  fontFamily: 'Amiri',
                                  height: 2.1,
                                ),
                              ),
                              TextSpan(
                                text: '۝${_arapcaRakam(ham['no'] as int? ?? 0)} ',
                                style: TextStyle(
                                  color: renkler.vurgu,
                                  fontSize: 16 * _fontScale,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
