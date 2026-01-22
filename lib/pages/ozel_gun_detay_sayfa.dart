import 'package:flutter/material.dart';
import '../services/ozel_gunler_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class OzelGunDetaySayfa extends StatefulWidget {
  final OzelGun ozelGun;
  final DateTime tarih;
  final String hicriTarih;

  const OzelGunDetaySayfa({
    super.key,
    required this.ozelGun,
    required this.tarih,
    required this.hicriTarih,
  });

  @override
  State<OzelGunDetaySayfa> createState() => _OzelGunDetaySayfaState();
}

class _OzelGunDetaySayfaState extends State<OzelGunDetaySayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final renk = _getRenk(widget.ozelGun.tur, renkler);
    final ikon = _getIkon(widget.ozelGun.tur);

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: renk,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.ozelGun.ad,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      renk,
                      renk.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    ikon,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),

          // İçerik
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih bilgisi
                  _tarihKarti(renkler, renk),
                  const SizedBox(height: 20),

                  // Açıklama
                  _baslikVeMetin(_languageService['description'] ?? 'Açıklama', widget.ozelGun.aciklama, renkler),
                  const SizedBox(height: 20),

                  // Detaylar
                  _detaylarBolumu(renkler),
                  const SizedBox(height: 20),

                  // Faziletler
                  _faziletlerBolumu(renkler),
                  const SizedBox(height: 20),

                  // Yapılması gerekenler
                  _yapilacaklarBolumu(renkler),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarihKarti(TemaRenkleri renkler, Color renk) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: renk, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_languageService['gregorian'] ?? 'Miladi'}: ${widget.tarih.day}.${widget.tarih.month}.${widget.tarih.year}',
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_languageService['hijri'] ?? 'Hicri'}: ${widget.hicriTarih}',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _baslikVeMetin(String baslik, String metin, TemaRenkleri renkler) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          metin,
          style: TextStyle(
            color: renkler.yaziSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _detaylarBolumu(TemaRenkleri renkler) {
    final detaylar = _getDetaylar(widget.ozelGun);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageService['details'] ?? 'Detaylar',
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: renkler.kartArkaPlan,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            detaylar,
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _faziletlerBolumu(TemaRenkleri renkler) {
    final faziletler = _getFaziletler(widget.ozelGun);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageService['virtues'] ?? 'Faziletleri',
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...faziletler.map((fazilet) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: renkler.vurgu,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fazilet,
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _yapilacaklarBolumu(TemaRenkleri renkler) {
    final yapilacaklar = _getYapilacaklar(widget.ozelGun);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageService['what_to_do'] ?? 'Yapılması Gerekenler',
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...yapilacaklar.asMap().entries.map((entry) {
          final index = entry.key;
          final yapilacak = entry.value;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: renkler.ayirac.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: renkler.vurgu,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    yapilacak,
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _getDetaylar(OzelGun ozelGun) {
    switch (ozelGun.ad) {
      case 'Mevlid Kandili':
        return 'Peygamber Efendimiz Hz. Muhammed (S.A.V), Hicri 571 yılında Rebîülevvel ayının 12. gecesi Mekke\'de doğmuştur. Mevlid Kandili, bu mübarek doğum gününü anmak ve kutlamak için yapılan ibadettir.';
      
      case 'Regaip Kandili':
        return 'Recep ayının ilk Cuma gecesi olan Regaip Kandili, üç ayların başlangıcıdır. "Regaip" Arapça\'da "çok değerli ve saygın şeyler" anlamına gelir. Bu gece, Ramazan ayına hazırlık ve manevi arınma gecesidir.';
      
      case 'Miraç Kandili':
        return 'Peygamber Efendimiz (S.A.V)\'in Mescid-i Haram\'dan Mescid-i Aksa\'ya, oradan da semavi yolculukla Allah\'ın huzuruna çıktığı mübarek gecedir. Bu gecede namaz ibadetinin farz kılındığı rivayet edilir.';
      
      case 'Berat Kandili':
        return 'Şaban ayının 14\'üncü gününden 15\'inci gününe geçilen gece Berat Kandili olarak bilinir. "Berat" kelimesi, "kurtulmak, temize çıkmak" anlamlarına gelir. Bu gece yapılan ibadetlerin ve tövbelerin kabul edildiğine inanılır.';
      
      case 'Kadir Gecesi':
        return 'Kur\'an-ı Kerim\'in indirilmeye başlandığı, bin aydan daha hayırlı olan mübarek gecedir. Ramazan ayının son on gününde aranır ve genellikle 27. gece olarak kabul edilir. Bu gecede melekler yeryüzüne iner ve sabaha kadar dua edenler için rahmet ve bağışlanma dilerler.';
      
      case 'Ramazan Bayramı':
        return 'Ramazan ayının ardından gelen, üç gün süren dini bayramdır. Oruç ibadetinin tamamlanmasının sevinci yaşanır. Bayram namazı kılınır, zekât-ül fıtır verilir, akrabalar ve yakınlar ziyaret edilir.';
      
      case 'Kurban Bayramı':
        return 'Hz. İbrahim\'in Allah\'ın emrine itaat ederek oğlu Hz. İsmail\'i kurban etmek istemesini, Allah\'ın bu sadakati bir koçla fidye edip kabul etmesini anma günüdür. Dört gün sürer ve kurban kesilir, akrabalar ziyaret edilir.';
      
      case 'Arefe Günü':
        return 'Kurban Bayramı\'ndan bir gün önceki gün olan Arefe günü, Hac\'da Arafat\'ta vakfe yapılan gündür. Bu gün oruç tutulması tavsiye edilir ve çok faziletlidir.';
      
      case 'Aşure Günü':
        return 'Muharrem ayının 10. günü olan Aşure günü, tarihte birçok önemli olayın yaşandığı mübarek bir gündür. Bu gün oruç tutulması ve aşure yemeği yapılması sünnet olarak bilinir.';
      
      default:
        return ozelGun.aciklama;
    }
  }

  List<String> _getFaziletler(OzelGun ozelGun) {
    switch (ozelGun.ad) {
      case 'Mevlid Kandili':
        return [
          'Bu gece yapılan ibadetlerin ve duaların kabul edileceğine inanılır',
          'Peygamber Efendimiz\'e salat ve selam getirmek çok faziletlidir',
          'Kur\'an-ı Kerim okumak ve tefekkürde bulunmak tavsiye edilir',
          'Mevlid okutmak ve dinlemek sevaptır',
        ];
      
      case 'Regaip Kandili':
        return [
          'Üç ayların başlangıcıdır ve Ramazan\'a hazırlık gecesidir',
          'Bu gecede çokça tövbe etmek ve istiğfar çekmek tavsiye edilir',
          'Yapılan ibadetlerin sevabının kat kat arttığı gündür',
          'Allah\'ın rahmetinin bol olduğu bir gecedir',
        ];
      
      case 'Miraç Kandili':
        return [
          'Peygamber Efendimiz\'in mucizevi yolculuğunu anma gecesidir',
          'Namaz ibadetinin bu gecede farz kılındığına inanılır',
          'Yapılan duaların kabul edildiği mübarek bir gecedir',
          'İbadet etmek ve Kur\'an okumak çok sevaptır',
        ];
      
      case 'Berat Kandili':
        return [
          'Günahların affedildiği ve tövbelerin kabul edildiği gecedir',
          'Bir sonraki yıla kadar hayatta kalanların isimlerinin yazıldığı gecedir',
          'Rızıkların, ecellerin ve işlerin belirlendiği gecedir',
          'Bu gecede yapılan dua ve ibadetlerin kabul edileceğine inanılır',
        ];
      
      case 'Kadir Gecesi':
        return [
          'Bin aydan daha hayırlı olan mübarek gecedir',
          'Kur\'an-ı Kerim\'in indirilmeye başlandığı gecedir',
          'Meleklerin yeryüzüne indiği ve sabaha kadar rahmet dilediği gecedir',
          'Bu gecede yapılan ibadet ve duaların özel kabulü vardır',
          'Cenab-ı Allah bu geceyi "Kadir Suresi"nde müjdelemiştir',
        ];
      
      case 'Ramazan Bayramı':
        return [
          'Bir aylık oruç ibadetinin tamamlanmasının sevinci yaşanır',
          'Bayram namazı kılınması Müslümanlar için önemli bir ibadettir',
          'Fıtır sadakası verilir ve fakirlere yardım edilir',
          'Toplumsal dayanışma ve yardımlaşma artırılır',
        ];
      
      case 'Kurban Bayramı':
        return [
          'Hz. İbrahim\'in sadakatini ve Allah\'a teslimiyetini anma günüdür',
          'Kurban kesmek Allah rızası için yapılan önemli bir ibadettir',
          'Kesilen kurbanın etleri fakirlerle paylaşılır',
          'Hac ibadeti bu günlerde yapılır',
        ];
      
      default:
        return [
          'Allah\'a dua etmek ve istiğfar çekmek tavsiye edilir',
          'Kur\'an-ı Kerim okumak ve tefekkürde bulunmak önemlidir',
          'İbadet ve zikirle vakit geçirmek faziletlidir',
        ];
    }
  }

  List<String> _getYapilacaklar(OzelGun ozelGun) {
    final turGenel = [
      'Gece boyunca namaz kılmak',
      'Kur\'an-ı Kerim okumak',
      'İstiğfar etmek ve tövbe etmek',
      'Salat-ı Tefric namazı kılmak',
      'Dua ve zikirlerde bulunmak',
    ];

    switch (ozelGun.ad) {
      case 'Ramazan Bayramı':
      case 'Kurban Bayramı':
        return [
          'Sabah erkenden gusül abdesti almak',
          'En güzel elbiselerinizi giymek',
          'Güzel koku sürünmek',
          'Bayram namazını cemaatle kılmak',
          'Akraba ve komşuları ziyaret etmek',
          'Çocuklara bayramlık vermek',
          'Fakirlere sadaka vermek',
        ];
      
      case 'Arefe Günü':
        return [
          'Arefe günü orucu tutmak',
          'Sabah namazından sonra tekbir getirmek',
          'Çokça istiğfar ve tövbe etmek',
          'Dua ile meşgul olmak',
          'Kur\'an-ı Kerim okumak',
        ];
      
      case 'Aşure Günü':
        return [
          'Aşure günü orucu tutmak',
          'Aşure yemeği hazırlamak ve dağıtmak',
          'Komşu ve akrabalara ikramda bulunmak',
          'Şükür namazı kılmak',
          'Dua ve zikirde bulunmak',
        ];
      
      default:
        return turGenel;
    }
  }

  IconData _getIkon(OzelGunTuru tur) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return Icons.celebration;
      case OzelGunTuru.kandil:
        return Icons.brightness_7;
      case OzelGunTuru.mubarekGece:
        return Icons.nights_stay;
      case OzelGunTuru.onemliGun:
        return Icons.star;
    }
  }

  Color _getRenk(OzelGunTuru tur, TemaRenkleri renkler) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return Colors.amber;
      case OzelGunTuru.kandil:
        return Colors.purpleAccent;
      case OzelGunTuru.mubarekGece:
        return Colors.tealAccent;
      case OzelGunTuru.onemliGun:
        return renkler.vurgu;
    }
  }
}
