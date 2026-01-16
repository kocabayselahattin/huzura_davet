import 'package:flutter/material.dart';
import 'dart:math';
import '../services/tema_service.dart';

class GununIcerigiWidget extends StatefulWidget {
  const GununIcerigiWidget({super.key});

  @override
  State<GununIcerigiWidget> createState() => _GununIcerigiWidgetState();
}

class _GununIcerigiWidgetState extends State<GununIcerigiWidget> {
  final TemaService _temaService = TemaService();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Ayet listesi
  static const List<Map<String, String>> _ayetler = [
    {'ayet': 'Şüphesiz namaz, hayâsızlıktan ve kötülükten alıkoyar.', 'kaynak': 'Ankebût, 45'},
    {'ayet': 'Sabır ve namaz ile Allah\'tan yardım isteyin.', 'kaynak': 'Bakara, 45'},
    {'ayet': 'O, göklerin ve yerin nurudur.', 'kaynak': 'Nûr, 35'},
    {'ayet': 'Allah\'ı çokça zikredin ki kurtuluşa eresiniz.', 'kaynak': 'Cuma, 10'},
    {'ayet': 'Bana dua edin, size karşılık vereyim.', 'kaynak': 'Mü\'min, 60'},
    {'ayet': 'Muhakkak ki zorlukla beraber kolaylık vardır.', 'kaynak': 'İnşirah, 6'},
    {'ayet': 'Kim Allah\'a tevekkül ederse, O ona yeter.', 'kaynak': 'Talâk, 3'},
    {'ayet': 'Rabbiniz\'den mağfiret dileyin. O çok bağışlayıcıdır.', 'kaynak': 'Nûh, 10'},
    {'ayet': 'Namazı dosdoğru kılın, zekâtı verin.', 'kaynak': 'Bakara, 43'},
    {'ayet': 'Allah sabredenleri sever.', 'kaynak': 'Âl-i İmrân, 146'},
    {'ayet': 'Rahmetim her şeyi kuşatmıştır.', 'kaynak': 'A\'râf, 156'},
    {'ayet': 'O, kullarına karşı çok şefkatlidir.', 'kaynak': 'Şûrâ, 19'},
    {'ayet': 'Rabbim! Beni namaza devam eden kıl.', 'kaynak': 'İbrâhîm, 40'},
    {'ayet': 'Güzel söz O\'na yükselir.', 'kaynak': 'Fâtır, 10'},
    {'ayet': 'Allah\'ın yardımı ve fetih geldiğinde...', 'kaynak': 'Nasr, 1'},
    {'ayet': 'De ki: Rabbim! İlmimi artır.', 'kaynak': 'Tâhâ, 114'},
    {'ayet': 'Allah\'ın nimetlerini saymaya kalksanız sayamazsınız.', 'kaynak': 'Nahl, 18'},
    {'ayet': 'Allah mutlaka işlerinizde kolaylık diler.', 'kaynak': 'Bakara, 185'},
    {'ayet': 'Şüphesiz Allah, adaleti emreder.', 'kaynak': 'Nahl, 90'},
    {'ayet': 'Rahman olan Allah\'ın kulları, yeryüzünde tevazu ile yürürler.', 'kaynak': 'Furkân, 63'},
    {'ayet': 'Kim bir iyilik yaparsa, karşılığını görür.', 'kaynak': 'Zilzâl, 7'},
    {'ayet': 'Allah\'a ve Resûlüne itaat edin.', 'kaynak': 'Enfâl, 1'},
    {'ayet': 'Biz seni âlemlere ancak rahmet olarak gönderdik.', 'kaynak': 'Enbiyâ, 107'},
    {'ayet': 'Allah dilediğine hesapsız rızık verir.', 'kaynak': 'Bakara, 212'},
    {'ayet': 'Allah\'ın rahmetinden umut kesmeyin.', 'kaynak': 'Zümer, 53'},
    {'ayet': 'İyiliğin karşılığı ancak iyiliktir.', 'kaynak': 'Rahmân, 60'},
    {'ayet': 'Allah\'tan korkun ve doğru söz söyleyin.', 'kaynak': 'Ahzâb, 70'},
    {'ayet': 'Her nefis ölümü tadacaktır.', 'kaynak': 'Âl-i İmrân, 185'},
    {'ayet': 'Sana ölüm gelinceye kadar Rabbine ibadet et.', 'kaynak': 'Hicr, 99'},
    {'ayet': 'O, bağışlayandır, çok sevendir.', 'kaynak': 'Burûc, 14'},
  ];

  // Dua listesi
  static const List<Map<String, String>> _dualar = [
    {'dua': 'Rabbim! Bana, ana-babama ve müminlere mağfiret et.', 'kaynak': 'İbrâhîm, 41'},
    {'dua': 'Ey kalpleri çeviren Rabbim! Kalbimi dinin üzere sabit kıl.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Göğsümü aç, işimi kolaylaştır.', 'kaynak': 'Tâhâ, 25-26'},
    {'dua': 'Allah\'ım! Senden faydalı ilim, temiz rızık ve kabul olunan amel isterim.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Beni şükredenlerden eyle.', 'kaynak': 'Neml, 19'},
    {'dua': 'Allah\'ım! Sen affedicisin, affı seversin, beni affet.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Beni yalnız bırakma, Sen varislerin en hayırlısısın.', 'kaynak': 'Enbiyâ, 89'},
    {'dua': 'Allah\'ım! Senden hidayet, takva, iffet ve zenginlik isterim.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Beni salihler arasına kat.', 'kaynak': 'Şuarâ, 83'},
    {'dua': 'Allah\'ım! Kalbimi ve amelimi ıslah et.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Bana rahmetinle muamele et.', 'kaynak': 'Kehf, 10'},
    {'dua': 'Allah\'ım! Dinimde, dünyamda ve ahiretimde beni afiyet içinde kıl.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! İlmimi artır.', 'kaynak': 'Tâhâ, 114'},
    {'dua': 'Allah\'ım! Acizlikten, tembellikten, korkaklıktan Sana sığınırım.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Beni ve zürriyetimi namaz kılanlardan eyle.', 'kaynak': 'İbrâhîm, 40'},
    {'dua': 'Allah\'ım! Günahlarımı bağışla, rızkımı genişlet.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Bize dünyada iyilik, ahirette iyilik ver, cehennem azabından koru.', 'kaynak': 'Bakara, 201'},
    {'dua': 'Allah\'ım! Hayırlı işlerde bana yardım et.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Beni müslüman olarak öldür ve salihler arasına kat.', 'kaynak': 'Yûsuf, 101'},
    {'dua': 'Allah\'ım! Senden sağlık ve afiyet isterim.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Kötülüklerden beni koru.', 'kaynak': 'Mü\'min, 9'},
    {'dua': 'Allah\'ım! Hayrımda bereketimi artır.', 'kaynak': 'Hadis'},
    {'dua': 'Hasbiyallahu la ilahe illa Hu, aleyhi tevekkeltü.', 'kaynak': 'Tevbe, 129'},
    {'dua': 'Allah\'ım! Sen benim Rabbimsin, Senden başka ilah yoktur.', 'kaynak': 'Seyyidü\'l-İstiğfar'},
    {'dua': 'Rabbim! Şeytanların vesveselerinden Sana sığınırım.', 'kaynak': 'Mü\'minûn, 97'},
    {'dua': 'Allah\'ım! Halimi en güzel hale çevir.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Bana sabır ver, müslüman olarak canımı al.', 'kaynak': 'A\'râf, 126'},
    {'dua': 'Allah\'ım! Sen afiyettesin, afiyet Sendendir.', 'kaynak': 'Hadis'},
    {'dua': 'Rabbim! Senden başka günahları kim bağışlar?', 'kaynak': 'Âl-i İmrân, 135'},
    {'dua': 'Allah\'ım! Ömrümü hayırla tamamla.', 'kaynak': 'Hadis'},
  ];

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Map<String, String> _getGununAyeti() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % _ayetler.length;
    return _ayetler[index];
  }

  Map<String, String> _getGununDuasi() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = (dayOfYear + 7) % _dualar.length; // Farklı sıralama için +7
    return _dualar[index];
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final gununAyeti = _getGununAyeti();
    final gununDuasi = _getGununDuasi();
    
    return Column(
      children: [
        // Başlık ve sayfa göstergesi
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GÜNÜN İÇERİĞİ',
                style: TextStyle(
                  color: renkler.yaziSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              // Sayfa göstergesi
              Row(
                children: [
                  _buildPageIndicator(0, renkler),
                  const SizedBox(width: 6),
                  _buildPageIndicator(1, renkler),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Kaydırılabilir içerik
        SizedBox(
          height: 180,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildIcerikKart(
                baslik: 'GÜNÜN AYETİ',
                icerik: gununAyeti['ayet']!,
                kaynak: gununAyeti['kaynak']!,
                ikon: Icons.menu_book_rounded,
                renkler: renkler,
              ),
              _buildIcerikKart(
                baslik: 'GÜNÜN DUASI',
                icerik: gununDuasi['dua']!,
                kaynak: gununDuasi['kaynak']!,
                ikon: Icons.favorite_rounded,
                renkler: renkler,
              ),
            ],
          ),
        ),
        
        // Kaydırma ipucu
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swipe,
                color: renkler.yaziSecondary.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Kaydırarak diğer içeriği görün',
                style: TextStyle(
                  color: renkler.yaziSecondary.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(int index, TemaRenkleri renkler) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? renkler.vurgu : renkler.yaziSecondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildIcerikKart({
    required String baslik,
    required String icerik,
    required String kaynak,
    required IconData ikon,
    required TemaRenkleri renkler,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            renkler.kartArkaPlan,
            renkler.kartArkaPlan.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: renkler.vurgu.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ikon,
                  color: renkler.vurgu,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                baslik,
                style: TextStyle(
                  color: renkler.vurgu,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // İçerik
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                '"$icerik"',
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 15,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Kaynak
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: renkler.vurgu.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '— $kaynak',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}