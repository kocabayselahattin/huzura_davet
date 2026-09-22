import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import 'kuran_sayfa.dart';
import 'mezarlik_sayfa_okuma_sayfa.dart';

/// Kütüphane > Mezarlık Ziyareti: kabir ziyaretinde okunması âdet olan
/// sureleri ve sünnete uygun ziyaret adabını listeler. Her sure iki
/// biçimde açılabilir: [SureDetaySayfa] ile ayet ayet, veya
/// [MezarlikSayfaOkumaSayfa] ile Mushaf sayfası gibi tek akan metin
/// halinde (ayet kartlarına bölünmeden) — mezarlıkta hızlı okuma için.
class MezarlikZiyaretiSayfa extends StatelessWidget {
  const MezarlikZiyaretiSayfa({super.key});

  static const List<int> _sureNolari = [1, 36, 67, 112, 113, 114];

  static const List<String> _ziyaretAdimlari = [
    'Mezarlığa girmeden önce abdestli olmaya özen göster ve niyetini yalnızca Allah rızası için ölüleri anmak ve ibret almak olarak belirle.',
    'Girişte kıbleye yönelmeden, kabir ehline selam ver (aşağıdaki ziyaret duası).',
    'Kabirlerin üzerine basmamaya, oturmamaya ve onlara yaslanmamaya dikkat et.',
    'Yâsîn, Fâtiha, İhlâs, Felâk, Nâs gibi sureleri oku ve sevabını mezarlıktaki müminlere bağışla.',
    'Ölüler için dua ve istiğfarda bulun; onları hayırla an.',
    'Yüksek sesle ağlama, feryat etme ve yas âdetlerinden kaçın; sabır ve teslimiyet içinde ol.',
    'Ziyaretin asıl amacının ölümü ve ahireti hatırlamak olduğunu unutma.',
  ];

  static const String _ziyaretDuasiArapca =
      'اَلسَّلَامُ عَلَيْكُمْ أَهْلَ الدِّيَارِ مِنَ الْمُؤْمِنٖينَ وَالْمُسْلِمٖينَ وَإِنَّا إِنْ شَاءَ اللَّهُ بِكُمْ لَاحِقُونَ نَسْأَلُ اللَّهَ لَنَا وَلَكُمُ الْعَافِيَةَ';
  static const String _ziyaretDuasiOkunus =
      "Esselâmü aleyküm ehled diyâri minel mü'minîne vel müslimîn, ve innâ inşâallahü biküm lâhikûn. Nes'elüllahe lenâ ve leküml âfiyeh";
  static const String _ziyaretDuasiMeal =
      "Ey mü'min ve müslüman kabir halkı! Size selam olsun. İnşallah biz de size kavuşacağız. Allah'tan bizim ve sizin için afiyet dileriz.";
  static const String _ziyaretDuasiKaynak = 'Müslim, Cenâiz, 35';

  @override
  Widget build(BuildContext context) {
    final temaService = TemaService();
    final renkler = temaService.renkler;
    final sureler = _sureNolari
        .map((no) => sureListesi.firstWhere((s) => s.no == no))
        .toList();

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          'MEZARLIK ZİYARETİ',
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ziyaretDuasiKarti(renkler),
              const SizedBox(height: 10),
              _ziyaretAdabiKarti(renkler),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Okunacak Sureler',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...sureler.map(
                (sure) => _sureOgesi(context, sure, renkler),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ziyaretDuasiKarti(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waving_hand_rounded, color: renkler.vurgu, size: 18),
              const SizedBox(width: 8),
              Text(
                'Girişte Okunacak Selam Duası',
                style: TextStyle(
                  color: renkler.vurgu,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _ziyaretDuasiArapca,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 19,
              fontFamily: 'Amiri',
              height: 1.9,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _ziyaretDuasiOkunus,
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ziyaretDuasiMeal,
            style: TextStyle(color: renkler.yaziPrimary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            _ziyaretDuasiKaynak,
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ziyaretAdabiKarti(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: renkler.vurgu, size: 18),
              const SizedBox(width: 8),
              Text(
                'Sünnete Uygun Ziyaret Adabı',
                style: TextStyle(
                  color: renkler.vurgu,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _ziyaretAdimlari.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: renkler.vurgu.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: renkler.vurgu,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _ziyaretAdimlari[i],
                      style: TextStyle(
                        color: renkler.yaziPrimary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sureOgesi(BuildContext context, Sure sure, TemaRenkleri renkler) {
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
          onTap: () => _okumaSecimiGoster(context, sure),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sure.turkceAd,
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  sure.arapca,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 16,
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: renkler.yaziSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _okumaSecimiGoster(BuildContext context, Sure sure) {
    final renkler = TemaService().renkler;
    showModalBottomSheet(
      context: context,
      backgroundColor: renkler.kartArkaPlan,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                sure.turkceAd,
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.menu_book_rounded, color: renkler.vurgu),
              title: Text(
                'Sayfa Halinde Oku',
                style: TextStyle(color: renkler.yaziPrimary),
              ),
              subtitle: Text(
                'Ayetlere bölünmeden, Mushaf gibi akan tek metin — mezarlıkta okuması kolay',
                style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MezarlikSayfaOkumaSayfa(sure: sure),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.view_agenda_rounded, color: renkler.vurgu),
              title: Text(
                'Ayet Ayet Oku',
                style: TextStyle(color: renkler.yaziPrimary),
              ),
              subtitle: Text(
                'Her ayet ayrı kartta, okunuş/meal seçenekleriyle',
                style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SureDetaySayfa(sure: sure),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
