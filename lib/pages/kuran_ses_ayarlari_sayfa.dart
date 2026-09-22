import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/kuran_ses_service.dart';
import 'kuran_sayfa.dart' show Sure, sureListesi;

/// Kütüphane > Sesli Kur'an İndirme Ayarları: okuyucu seçimi ve surelerin
/// toplu/tekli indirilmesi. Burada seçilen okuyucu ve indirilen sesler,
/// [KuranSesService] üzerinden normal Kur'an okuma sayfasında (SureDetaySayfa)
/// otomatik olarak kullanılır — ek bir adım gerekmez.
class KuranSesAyarlariSayfa extends StatefulWidget {
  const KuranSesAyarlariSayfa({super.key});

  @override
  State<KuranSesAyarlariSayfa> createState() => _KuranSesAyarlariSayfaState();
}

class _KuranSesAyarlariSayfaState extends State<KuranSesAyarlariSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  final AudioPlayer _onizlemeOynatici = AudioPlayer();

  String _aktifOkuyucuId = KuranSesService.varsayilanOkuyucuId;
  String? _calanOnizlemeId;
  bool _durumYukleniyor = true;
  final Set<int> _indirilenSureler = {};

  bool _tumuIndiriliyor = false;
  int _tumuTamamlanan = 0;

  final Map<int, bool> _sureIndiriliyor = {};
  final Map<int, ({int tamamlanan, int toplam})> _sureIlerleme = {};

  @override
  void initState() {
    super.initState();
    _baslangicDurumunuYukle();
  }

  @override
  void dispose() {
    _onizlemeOynatici.dispose();
    super.dispose();
  }

  Future<void> _baslangicDurumunuYukle() async {
    final okuyucuId = await KuranSesService.aktifOkuyucuId();
    if (mounted) setState(() => _aktifOkuyucuId = okuyucuId);
    await _indirmeDurumunuYenile();
  }

  Future<void> _indirmeDurumunuYenile() async {
    if (mounted) setState(() => _durumYukleniyor = true);
    final sonuclar = await Future.wait(
      sureListesi.map(
        (s) => KuranSesService.sureTamIndirilmisMi(
          s.no,
          okuyucuId: _aktifOkuyucuId,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _indirilenSureler
        ..clear()
        ..addAll([
          for (var i = 0; i < sureListesi.length; i++)
            if (sonuclar[i]) sureListesi[i].no,
        ]);
      _durumYukleniyor = false;
    });
  }

  String _ceviri(String anahtar, String yedek) {
    final deger = _languageService[anahtar];
    if (deger is String && deger.trim().isNotEmpty) return deger;
    return yedek;
  }

  Future<void> _onizlemeCal(String okuyucuId) async {
    if (_calanOnizlemeId == okuyucuId) {
      await _onizlemeOynatici.stop();
      setState(() => _calanOnizlemeId = null);
      return;
    }
    try {
      await _onizlemeOynatici.stop();
      await _onizlemeOynatici.play(
        UrlSource(KuranSesService.onizlemeUrl(okuyucuId)),
      );
      setState(() => _calanOnizlemeId = okuyucuId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _ceviri(
                'reciter_preview_error',
                'Okuyucu önizlemesi çalınamadı, internetini kontrol et',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _okuyucuSecimiGoster() async {
    await _onizlemeOynatici.stop();
    if (!mounted) return;
    final renkler = _temaService.renkler;
    final secilen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: renkler.kartArkaPlan,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _ceviri('select_reciter', 'Okuyucu Seç'),
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: KuranSesService.okuyucular.map((okuyucu) {
                          final secili = okuyucu.id == _aktifOkuyucuId;
                          final caliyor = _calanOnizlemeId == okuyucu.id;
                          return ListTile(
                            leading: Icon(
                              secili
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: secili
                                  ? renkler.vurgu
                                  : renkler.yaziSecondary,
                            ),
                            title: Text(
                              okuyucu.ad,
                              style: TextStyle(color: renkler.yaziPrimary),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                caliyor
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_circle_outline,
                                color: renkler.vurgu,
                              ),
                              onPressed: () async {
                                await _onizlemeCal(okuyucu.id);
                                setSheetState(() {});
                              },
                            ),
                            onTap: () => Navigator.pop(sheetContext, okuyucu.id),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    await _onizlemeOynatici.stop();
    if (mounted) setState(() => _calanOnizlemeId = null);

    if (secilen != null && secilen != _aktifOkuyucuId) {
      await KuranSesService.aktifOkuyucuAyarla(secilen);
      if (!mounted) return;
      setState(() => _aktifOkuyucuId = secilen);
      await _indirmeDurumunuYenile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _ceviri(
              'reciter_changed_note',
              'Okuyucu değiştirildi. Kur\'an sayfasındaki dinleme ve indirme artık bu okuyucuyu kullanacak.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _sureyiIndir(Sure sure) async {
    setState(() {
      _sureIndiriliyor[sure.no] = true;
      _sureIlerleme[sure.no] = (tamamlanan: 0, toplam: sure.ayetSayisi);
    });
    await KuranSesService.sureyiIndir(
      sure.no,
      okuyucuId: _aktifOkuyucuId,
      ilerleme: (tamamlanan, toplam) {
        if (!mounted) return;
        setState(() {
          _sureIlerleme[sure.no] = (tamamlanan: tamamlanan, toplam: toplam);
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _sureIndiriliyor[sure.no] = false;
      _indirilenSureler.add(sure.no);
    });
  }

  Future<void> _sureSesiniSil(Sure sure) async {
    await KuranSesService.sureyiSil(sure.no, okuyucuId: _aktifOkuyucuId);
    if (!mounted) return;
    setState(() => _indirilenSureler.remove(sure.no));
  }

  Future<void> _tumunuIndirOnayla() async {
    final renkler = _temaService.renkler;
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        title: Text(
          _ceviri('download_all_quran', "Tüm Kur'an'ı İndir"),
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        content: Text(
          _ceviri(
            'download_all_quran_confirm',
            "Seçili okuyucuyla Kur'an'ın tamamı (114 sure) indirilecek. Bu işlem internet kullanır ve biraz zaman alabilir. Devam edilsin mi?",
          ),
          style: TextStyle(color: renkler.yaziSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_ceviri('cancel', 'Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_ceviri('download_all_quran', "Tüm Kur'an'ı İndir")),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await _tumunuIndir();
  }

  Future<void> _tumunuIndir() async {
    setState(() {
      _tumuIndiriliyor = true;
      _tumuTamamlanan = 0;
    });

    for (final sure in sureListesi) {
      if (!mounted) return;
      if (!_indirilenSureler.contains(sure.no)) {
        await _sureyiIndir(sure);
      }
      if (!mounted) return;
      setState(() => _tumuTamamlanan++);
    }

    if (mounted) setState(() => _tumuIndiriliyor = false);
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final aktifOkuyucu = KuranSesService.okuyucular.firstWhere(
      (o) => o.id == _aktifOkuyucuId,
      orElse: () => KuranSesService.okuyucular.first,
    );

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _ceviri('library_audio_settings', 'Sesli Kur\'an İndirme Ayarları'),
          style: TextStyle(color: renkler.yaziPrimary, fontSize: 15),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _okuyucuSecimiGoster,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: renkler.kartArkaPlan,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: renkler.vurgu.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.record_voice_over_rounded,
                              color: renkler.vurgu),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _ceviri('reciter', 'Okuyucu'),
                                  style: TextStyle(
                                    color: renkler.yaziSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  aktifOkuyucu.ad,
                                  style: TextStyle(
                                    color: renkler.yaziPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_rounded,
                              color: renkler.vurgu, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _tumuIndiriliyor
                            ? null
                            : _tumunuIndirOnayla,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: renkler.vurgu,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _tumuIndiriliyor
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                  value: sureListesi.isNotEmpty
                                      ? _tumuTamamlanan / sureListesi.length
                                      : null,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _tumuIndiriliyor
                              ? '${_ceviri('downloading_all_quran', 'İndiriliyor')} ($_tumuTamamlanan/${sureListesi.length})'
                              : _ceviri(
                                  'download_all_quran',
                                  "Tüm Kur'an'ı İndir",
                                ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _durumYukleniyor
                    ? Center(
                        child: CircularProgressIndicator(color: renkler.vurgu),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: sureListesi.length,
                        itemBuilder: (context, index) =>
                            _sureSatiri(sureListesi[index], renkler),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sureSatiri(Sure sure, TemaRenkleri renkler) {
    final indirildi = _indirilenSureler.contains(sure.no);
    final indiriliyor = _sureIndiriliyor[sure.no] ?? false;
    final ilerleme = _sureIlerleme[sure.no];

    Widget trailing;
    if (indiriliyor) {
      trailing = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: renkler.vurgu,
          value: (ilerleme != null && ilerleme.toplam > 0)
              ? ilerleme.tamamlanan / ilerleme.toplam
              : null,
        ),
      );
    } else {
      trailing = IconButton(
        icon: Icon(
          indirildi ? Icons.download_done : Icons.download_outlined,
          color: indirildi ? Colors.green : renkler.yaziSecondary,
        ),
        onPressed: () =>
            indirildi ? _sureSesiniSil(sure) : _sureyiIndir(sure),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: renkler.vurgu.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${sure.no}',
            style: TextStyle(
              color: renkler.vurgu,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          sure.turkceAd,
          style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
        ),
        trailing: trailing,
      ),
    );
  }
}
