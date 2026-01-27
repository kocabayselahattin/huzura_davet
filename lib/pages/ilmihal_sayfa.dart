import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import '../services/tema_service.dart';

class IlmihalSayfa extends StatefulWidget {
  const IlmihalSayfa({super.key});

  @override
  State<IlmihalSayfa> createState() => _IlmihalSayfaState();
}

class _IlmihalSayfaState extends State<IlmihalSayfa>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  late TabController _tabController;
  bool _yukleniyor = true;
  String? _hata;
  bool _indirmeGerekli = true;
  bool _indiriliyor = false;
  double _indirmeIlerlemesi = 0.0;
  Map<String, List<IlmihalKonu>> _icerikler = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _ilmihaliKontrolEt();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _ilmihaliKontrolEt() async {
    setState(() => _yukleniyor = true);
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ilmihal_data.json');
      
      if (await file.exists()) {
        await _kayitliIcerigiYukle(file);
        setState(() {
          _indirmeGerekli = false;
          _yukleniyor = false;
        });
      } else {
        setState(() {
          _indirmeGerekli = true;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        _indirmeGerekli = true;
        _yukleniyor = false;
      });
    }
  }

  Future<void> _kayitliIcerigiYukle(File file) async {
    try {
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = json.decode(jsonString);
      
      _icerikler = {};
      for (String kategori in data.keys) {
        final List<dynamic> jsonList = data[kategori];
        _icerikler[kategori] = jsonList.map((item) => IlmihalKonu.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('İçerik yükleme hatası: $e');
    }
  }

  Future<void> _ilmihaliIndir() async {
    setState(() {
      _indiriliyor = true;
      _hata = null;
      _indirmeIlerlemesi = 0.0;
    });

    try {
      // Simülasyon: Gerçek uygulamada API'den çekilecek
      for (double i = 0; i <= 1.0; i += 0.1) {
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() => _indirmeIlerlemesi = i);
      }
      
      _icerikler = {
        'iman': _getImanKonulari(),
        'ibadet': _getIbadetKonulari(),
        'abdest': _getAbdestKonulari(),
        'namaz': _getNamazKonulari(),
        'oruc': _getOrucKonulari(),
        'zekat': _getZekatKonulari(),
        'hac': _getHacKonulari(),
        'ahlak': _getAhlakKonulari(),
      };
      
      // Dosya sistemine kaydet
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ilmihal_data.json');
      
      final Map<String, dynamic> data = {};
      for (String kategori in _icerikler.keys) {
        data[kategori] = _icerikler[kategori]!.map((k) => k.toJson()).toList();
      }
      
      await file.writeAsString(json.encode(data));
      
      setState(() {
        _indiriliyor = false;
        _indirmeGerekli = false;
      });
    } catch (e) {
      setState(() {
        _indiriliyor = false;
        _hata = 'İndirme başarısız: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    if (_yukleniyor) {
      return Scaffold(
        backgroundColor: renkler.arkaPlan,
        body: Center(child: CircularProgressIndicator(color: renkler.vurgu)),
      );
    }

    if (_indirmeGerekli) {
      return _buildIndirmeEkrani(renkler);
    }

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: renkler.vurgu,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'İSLAM İLMİHALİ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [renkler.vurgu, renkler.vurgu.withOpacity(0.7)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.library_books,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                letterSpacing: 0.3,
              ),
              tabs: const [
                Tab(text: 'İman'),
                Tab(text: 'İbadet'),
                Tab(text: 'Abdest'),
                Tab(text: 'Namaz'),
                Tab(text: 'Oruç'),
                Tab(text: 'Zekat'),
                Tab(text: 'Hac'),
                Tab(text: 'Ahlak'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKonuListesi(_icerikler['iman'] ?? [], renkler),
                _buildKonuListesi(_icerikler['ibadet'] ?? [], renkler),
                _buildKonuListesi(_icerikler['abdest'] ?? [], renkler),
                _buildKonuListesi(_icerikler['namaz'] ?? [], renkler),
                _buildKonuListesi(_icerikler['oruc'] ?? [], renkler),
                _buildKonuListesi(_icerikler['zekat'] ?? [], renkler),
                _buildKonuListesi(_icerikler['hac'] ?? [], renkler),
                _buildKonuListesi(_icerikler['ahlak'] ?? [], renkler),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndirmeEkrani(TemaRenkleri renkler) {
    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: const Text('İslam İlmihali', style: TextStyle(color: Colors.white)),
        backgroundColor: renkler.vurgu,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: renkler.vurgu.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_download,
                  size: 100,
                  color: renkler.vurgu,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'İçerik İndirmesi Gerekli',
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'İslam İlmihali içeriğini kullanmak için\nönce indirmeniz gerekmektedir.\n\nBoyut: ~2 MB',
                style: TextStyle(
                  color: renkler.yaziSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (_indiriliyor) ...[
                SizedBox(
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    value: _indirmeIlerlemesi,
                    backgroundColor: renkler.kartArkaPlan,
                    valueColor: AlwaysStoppedAnimation<Color>(renkler.vurgu),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'İndiriliyor... %${(_indirmeIlerlemesi * 100).toInt()}',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 14,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _ilmihaliIndir,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: renkler.vurgu,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'İndir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              if (_hata != null) ...[
                const SizedBox(height: 20),
                Text(
                  _hata!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKonuListesi(List<IlmihalKonu> konular, TemaRenkleri renkler) {
    if (konular.isEmpty) {
      return Center(
        child: Text(
          'İçerik yükleniyor...',
          style: TextStyle(color: renkler.yaziSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: konular.length,
      itemBuilder: (context, index) {
        final konu = konular[index];
        return _buildKonuKarti(konu, renkler, index);
      },
    );
  }

  Widget _buildKonuKarti(IlmihalKonu konu, TemaRenkleri renkler, int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.cyan,
      Colors.pink,
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            konu.baslik,
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: renkler.kartArkaPlan,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...konu.icerik.map((paragraf) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      paragraf,
                      style: TextStyle(
                        color: renkler.yaziPrimary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  )),
                  if (konu.ayetler.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: konu.ayetler.map((ayet) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '📖 $ayet',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // İMAN KONULARI - Daha kapsamlı
  List<IlmihalKonu> _getImanKonulari() {
    return [
      IlmihalKonu(
        baslik: 'İman Nedir?',
        icerik: [
          'İman, Allah\'ın varlığını, birliğini, peygamberlerini, meleklerini, kitaplarını, ahiret gününü ve kaderi kalben tasdik edip dil ile ikrar etmektir.',
          'İman İslam dininin temelidir. Müslüman olmanın ilk şartıdır. İman olmadan ibadetler kabul edilmez.',
          'İmanın artması ve eksilmesi mümkündür. Günah işlemekle azalır, ibadet ve itaatle artar.',
        ],
        ayetler: [
          '"Resûl, Rabbinden kendisine indirilen (vahyin tamamın)a iman etti, müminler de (iman ettiler). Her biri; Allah\'a, meleklerine, kitaplarına ve peygamberlerine iman ettiler..." (Bakara, 2/285)',
        ],
      ),
      IlmihalKonu(
        baslik: 'İmanın Şartları',
        icerik: [
          '1. Allah\'a İman: Bir ve tek olan Allah\'ın varlığına ve birliğine inanmak. Allah\'ın her türlü noksanlıktan uzak, sonsuz güç ve kudret sahibi olduğuna iman etmek.',
          '2. Meleklere İman: Allah\'ın yarattığı nurdan varlıklar olan meleklere inanmak. Melekler Allah\'ın emirlerine itaat eder, asla isyan etmezler.',
          '3. Kitaplara İman: Allah\'ın peygamberlerine indirdiği tüm kutsal kitaplara inanmak. Tevrat, Zebur, İncil ve Kur\'an gibi.',
          '4. Peygamberlere İman: Allah\'ın insanlara hidayet için gönderdiği tüm elçilere inanmak. İlk peygamber Hz. Adem, son peygamber Hz. Muhammed\'dir (s.a.v).',
          '5. Ahiret Gününe İman: Ölümden sonra tekrar dirilip hesaba çekilme gününe inanmak. Cennet ve cehennemin varlığına iman etmek.',
          '6. Kadere İman: İyisiyle kötüsüyle her şeyin Allah\'ın takdiri ve dilemesi ile olduğuna inanmak.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Kelime-i Tevhid',
        icerik: [
          'Lâ ilâhe illallah Muhammedün Resûlullah',
          'Anlamı: Allah\'tan başka ilah yoktur, Hz. Muhammed O\'nun elçisidir.',
          'Bu kelime İslam\'ın temelidir ve Müslüman olmanın ilk şartıdır. Bu kelimeyi kalben inanarak ve dil ile söyleyerek Müslüman olunur.',
        ],
        ayetler: [
          '"Allah kendisinden başka ilah olmadığına şahitlik etti, melekler ve ilim sahipleri de adaletle durarak şahitlik ettiler. O\'ndan başka ilah yoktur. O Azîz\'dir, Hakîm\'dir." (Al-i İmran, 3/18)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Allah\'ın Sıfatları',
        icerik: [
          'Allah\'ın zati sıfatları: Vücud (Var oluş), Kıdem (Ezelîlik), Beka (Ebedîlik), Muhalefetün lil havadis (Yaratılmışlara benzemezlik), Kıyam bi nefsih (Kendi kendine var olma), Vahdaniyet (Bir olma).',
          'Allah\'ın subuti sıfatları: Hayat (Diri olma), İlim (Bilgi), Semi (İşitme), Basar (Görme), İrade (Dileme), Kudret (Güç), Kelam (Söz), Tekvin (Yaratma).',
          'Allah hiçbir şeye muhtaç değildir, hiçbir şey O\'na benzemez. O\'nun ne başlangıcı ne de sonu vardır.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Tevhid Çeşitleri',
        icerik: [
          'Tevhid-i Rububiyet: Allah\'ın tek yaratıcı, tek rızık veren, tek hüküm koyan olduğuna inanmak.',
          'Tevhid-i Uluhiyet: Allah\'tan başka hiç kimseye ibadet edilmeyeceğine inanmak. Tüm ibadetlerin yalnızca Allah için yapılması.',
          'Tevhid-i Esma ve Sıfat: Allah\'ın isim ve sıfatlarının eşsiz olduğuna, hiçbir yaratığın O\'nun gibi olmadığına inanmak.',
        ],
        ayetler: [],
      ),
    ];
  }

  // İBADET KONULARI
  List<IlmihalKonu> _getIbadetKonulari() {
    return [
      IlmihalKonu(
        baslik: 'İbadet Nedir?',
        icerik: [
          'İbadet, Allah\'ın rızasını kazanmak için O\'nun emir ve yasaklarına uygun olarak yapılan her türlü söz ve davranıştır.',
          'İbadet sadece namaz, oruç gibi şeyleri değil, Allah rızası için yapılan tüm iyi işleri kapsar. Anne-babaya iyilik, komşuluk hakları, helal kazanç da ibadettir.',
        ],
        ayetler: [
          '"Ben cinleri ve insanları ancak bana ibadet etsinler diye yarattım." (Zariyat, 51/56)',
        ],
      ),
      IlmihalKonu(
        baslik: 'İbadetlerin Şartları',
        icerik: [
          '1. İhlâs: İbadeti sadece Allah için yapmak, gösteriş ve riyadan uzak durmak.',
          '2. İttiba: Peygamber Efendimiz\'in (s.a.v) gösterdiği şekilde ibadet etmek.',
          '3. Niyet: İbadeti yaparken kalbî niyet etmek.',
          '4. Helal kazanç: İbadetlerin kabul olması için helal yoldan kazanmak ve helal lokma yemek.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'İslam\'ın Beş Şartı',
        icerik: [
          '1. Kelime-i Şehadet getirmek: Lâ ilâhe illallah Muhammedün Resûlullah demek.',
          '2. Namaz kılmak: Günde beş vakit namazı vaktinde kılmak.',
          '3. Zekat vermek: Zenginlerin mallarından fakirlere pay ayırması.',
          '4. Ramazan orucunu tutmak: Ramazan ayında oruç tutmak.',
          '5. Hac: Gücü yeten Müslümanların ömründe bir kez Kâbe\'yi ziyaret etmesi.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Dua ve Zikir',
        icerik: [
          'Dua, kulun Allah\'a yalvarıp yakarmak suretiyle dilekte bulunmasıdır. Dua ibadetin özüdür.',
          'Zikir, Allah\'ı anmak, O\'nun isimlerini ve sıfatlarını okumaktır. Kalp huzuru zikir ile elde edilir.',
          'En faziletli zikirler: Sübhanallah, Elhamdülillah, Allahü Ekber, Lâ ilâhe illallah.',
        ],
        ayetler: [
          '"Ey iman edenler! Allah\'ı çok zikredin." (Ahzab, 33/41)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Tövbe',
        icerik: [
          'Tövbe, işlenen günahlardan pişman olup bir daha o günaha dönmemek üzere Allah\'a yönelmektir.',
          'Tövbenin şartları: Günahı bırakmak, işlenen günahtan pişman olmak, bir daha o günaha dönmemek.',
          'Eğer günah bir kulun hakkını çiğnemekse, önce o kişiden helallik almak gerekir.',
        ],
        ayetler: [
          '"Ey iman edenler! Allah\'a samimi olarak tövbe edin." (Tahrim, 66/8)',
        ],
      ),
    ];
  }

  // ABDEST KONULARI
  List<IlmihalKonu> _getAbdestKonulari() {
    return [
      IlmihalKonu(
        baslik: 'Abdest Nedir?',
        icerik: [
          'Abdest, namaz ve benzeri ibadetler için belli uzuvları belirli şekilde yıkayarak temizlenmektir.',
          'Abdest, namazın sahih olması için şarttır. Abdestsiz namaz kılınamaz.',
        ],
        ayetler: [
          '"Ey iman edenler! Namaza kalkacağınız zaman yüzlerinizi, dirseklere kadar ellerinizi yıkayın. Başlarınızı mesh edin, ayaklarınızı da topuklara kadar yıkayın..." (Maide, 5/6)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Abdestin Farzları',
        icerik: [
          '1. Yüzü yıkamak: Saç bitiminden çene altına, bir kulaktan diğer kulağa kadar olan bölgeyi bir kere yıkamak farz, üç kere yıkamak sünnettir.',
          '2. Elleri dirsekle beraber yıkamak: Her iki eli dirseklerle birlikte bir kere yıkamak farz, üç kere sünnettir.',
          '3. Başın dörtte birini mesh etmek: Islak elle başın en az dörtte birini mesh etmek farzdır.',
          '4. Ayakları topuklarla beraber yıkamak: Her iki ayağı topuklarıyla birlikte bir kere yıkamak farz, üç kere sünnettir.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Abdestin Sünnetleri',
        icerik: [
          '1. Niyet etmek: Kalben abdest almaya niyet etmek.',
          '2. Besmele çekmek: Abdeste başlarken "Bismillâhirrahmânirrahîm" demek.',
          '3. Elleri yıkamak: Abdeste başlarken üç defa elleri bileklere kadar yıkamak.',
          '4. Misvak kullanmak: Dişleri fırçalamak veya misvak kullanmak.',
          '5. Mazmaza ve istinşak: Ağza ve buruna su vermek.',
          '6. Başın tamamını mesh etmek: Islak elle başın tamamını mesh etmek.',
          '7. Kulakları mesh etmek: Her iki kulağın içini ve arkasını mesh etmek.',
          '8. Tertip: Organları sırasıyla yıkamak.',
          '9. Devam (Muvâlât): Organları arka arkaya, aralarında uzun aralık vermeden yıkamak.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Abdesti Bozan Şeyler',
        icerik: [
          '1. Ön ve arka taraftan herhangi bir şey çıkması (idrar, dışkı, yel vb.)',
          '2. Ağızdan mide bulandırıcı şey gelmesi (kusma - ağız dolusu)',
          '3. Vücuttan kan, irin vb. akması (yara yerinden akan kan)',
          '4. Uyumak (sırt ve böğür üzerine yatarak uyumak abdesti bozar)',
          '5. Bayılmak, sarhoş olmak, aklın gitmesi',
          '6. Namaz esnasında yüksek sesle gülmek (kahkaha atmak)',
          '7. Büyük abdest gerektiren hallerin oluşması',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Abdestte Kerahet Zamanları',
        icerik: [
          'Abdest almak her zaman müstehaptır, ancak bazı zamanlarda mekruh olur:',
          '1. Güneş doğarken abdest almak',
          '2. Güneş batarken abdest almak',
          '3. Güneş tam tepede iken abdest almak',
          'Bu vakitlerde abdest alınırsa sahih olur ama mekruh olur.',
        ],
        ayetler: [],
      ),
    ];
  }

  // NAMAZ KONULARI - Çok daha kapsamlı
  List<IlmihalKonu> _getNamazKonulari() {
    return [
      IlmihalKonu(
        baslik: 'Namaz Nedir ve Önemi',
        icerik: [
          'Namaz, belirli şartlar ve rükünlerle Allahü Teâlâ\'ya karşı yapılan bedenî ve kalbî bir ibadettir.',
          'Namaz İslam\'ın direğidir. Hz. Peygamber (s.a.v) Miraç gecesinde namaz farz kılınmıştır.',
          'Namaz kılan ile kılmayan arasındaki fark küfür ile İslam arasındaki farktır.',
          'Namaz, kulun Rabbine en yakın olduğu andır. Kıyamet gününde ilk sorulacak ibadet namazdır.',
        ],
        ayetler: [
          '"Namazı dosdoğru kılın, zekâtı verin..." (Bakara, 2/43)',
          '"Namazı kılın, çünkü namaz müminler üzerine vakitleri belli bir farzdır." (Nisa, 4/103)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Namazın Şartları',
        icerik: [
          'Namazın 7 şartı vardır:',
          '1. Hadesten taharet (temizlik): Abdest veya gusül abdesti almış olmak.',
          '2. Necasetten taharet: Beden, elbise ve namaz kılınacak yerin temiz olması.',
          '3. Avret yerini örtmek: Erkekler göbekten dize kadar, kadınlar el, ayak ve yüz dışında tüm vücudu örtmeli.',
          '4. Kıbleye yönelmek: Kâbe\'ye doğru yönelmek (özürsüz olarak).',
          '5. Vakit girmesi: Her namazın belirli bir vakti vardır, o vakit girmedikçe o namaz kılınamaz.',
          '6. Niyet: Hangi namazı kılacağını kalben niyet etmek.',
          '7. İftitah tekbiri: "Allahü ekber" diyerek namaza başlamak.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Namazın Rükünleri',
        icerik: [
          'Namazın 6 rüknü vardır:',
          '1. İftitah tekbiri: Eller yukarı kaldırılarak "Allahü ekber" denmesi.',
          '2. Kıyam: Farz namazlarda ayakta durmak (özürsüz olarak).',
          '3. Kıraat: Fatiha suresini okumak.',
          '4. Rüku: Eğilmek ve "Sübhâne Rabbiye\'l-azîm" demek.',
          '5. Secde: İki defa secde etmek ve "Sübhâne Rabbiye\'l-a\'lâ" demek.',
          '6. Ka\'de-i ahire: Son oturuşta Ettehıyyatü okumak.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Namazın Vacipleri',
        icerik: [
          'Namazın vacipleri:',
          '1. Her rekatta Fatiha suresini okumak',
          '2. İlk iki rekatta Fatihadan sonra zam-ı sure (ayrıca bir sure veya en az 3 ayet) okumak',
          '3. Önce rükü, sonra secde yapmak (tertip - sıra)',
          '4. Her rükün için kısa süreli durgunluk (tuma\'nine)',
          '5. İlk oturuş (Ka\'de-i ûlâ) - Üç ve dört rekatlı namazlarda ikinci rekatte oturmak',
          '6. Her iki oturuşta da Ettehıyyatü okumak',
          '7. Vitir namazında kunut duası okumak',
          '8. İki bayram namazında altışar tekbir',
          '9. İmamın Cuma ve bayram namazlarında hutbe okuması',
          '10. Cuma namazının cemaatle kılınması',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Namazın Sünnetleri',
        icerik: [
          'Namazın sünnetleri:',
          '1. Açılış duası (Sübhaneke) okumak',
          '2. Euzü-besmele çekmek',
          '3. Fatiha sonrası âmin demek',
          '4. Rükûda eller dizlere konur, baş ve sırt düz tutulur',
          '5. Rükûda ve secdede tesbihat (en az 3 defa)',
          '6. Kıyamda eller göbek altında bağlanır',
          '7. Secdeye giderken önce dizler, sonra eller, en son baş yere değer',
          '8. Secdeden kalkarken önce baş, sonra eller, en son dizler kalkar',
          '9. İki secde arasında oturuş',
          '10. Son oturuşta salavat getirmek',
          '11. İki tarafa selam vermek',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Beş Vakit Namaz Vakitleri',
        icerik: [
          '1. Sabah (İmsak) Namazı: Tan yerinin ağarmaya başlamasından güneşin doğmasına kadar.',
          '2. Öğle Namazı: Güneşin tepe noktasından geçip batıya doğru kayması ile başlar, her şeyin gölgesi kendisi kadar oluncaya kadar devam eder.',
          '3. İkindi Namazı: Her şeyin gölgesi kendisi kadar olduğunda başlar, güneş batıncaya kadar devam eder.',
          '4. Akşam Namazı: Güneşin batmasıyla başlar, şafağın kaybolmasına kadar devam eder.',
          '5. Yatsı Namazı: Şafağın kaybolmasıyla başlar, gece yarısına kadar devam eder.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Sehiv Secdesi',
        icerik: [
          'Namaz kılarken unutarak bir vacip terk edilirse veya farz yanlış yerine yapılırsa sehiv secdesi gerekir.',
          'Sehiv secdesi, namazın sonunda selamdan önce veya sonra yapılan iki secdedir.',
          'Eğer vacip namazın başında unutulduysa, sehiv secdesi selamdan önce yapılır.',
          'Eğer vacip namazın sonunda unutulduysa, sehiv secdesi selamdan sonra yapılır.',
        ],
        ayetler: [],
      ),
    ];
  }

  // ORUÇ KONULARI
  List<IlmihalKonu> _getOrucKonulari() {
    return [
      IlmihalKonu(
        baslik: 'Oruç Nedir ve Fazileti',
        icerik: [
          'Oruç, sahur vaktinden akşama kadar olan sürede yemek, içmek ve cinsel ilişkiden uzak durmaktır.',
          'Ramazan ayında oruç tutmak her Müslüman\'a farzdır. Oruç, nefsi terbiye etmenin ve takva sahibi olmanın yoludur.',
          'Ramazan, Kur\'an\'ın indirildiği mübarek bir aydır. Bu ayda sevap kat kat artar.',
        ],
        ayetler: [
          '"Ey iman edenler! Oruç, sizden öncekilere farz kılındığı gibi, size de farz kılındı. Umulur ki korunursunuz." (Bakara, 2/183)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Orucun Farzları',
        icerik: [
          'Orucun 2 farzı vardır:',
          '1. Niyet: Gece veya sahurda Ramazan orucunu tutmaya niyet etmek.',
          '2. Tutmak (İmsak): İmsak vaktinden akşama (iftara) kadar yemek, içmek ve cinsel ilişkiden uzak durmak.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Orucu Bozan Şeyler',
        icerik: [
          '1. Kasıtlı olarak yemek veya içmek',
          '2. Ağızdan mideye bir şey göndermek (yiyecek, içecek, ilaç vb.)',
          '3. Kasıtlı olarak kusmak (ağız dolusu)',
          '4. Cinsel ilişkide bulunmak',
          '5. Haksız yere kan almak (şırınga, ameliyat vb.)',
          '6. Kadınların hayız ve nifas halinde olmaları',
          '7. İğne ile ilaç almak (damar içi)',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Orucu Bozmayan Şeyler',
        icerik: [
          '1. Unutarak yemek veya içmek',
          '2. Zorlama ile yemek veya içmek',
          '3. Misvak kullanmak',
          '4. Burna su çekmek (boğaza kaçmadıkça)',
          '5. İstemsiz olarak kusmak',
          '6. Kan vermek (az miktarda)',
          '7. Göze damla damlatmak',
          '8. Kulağa damla damlatmak',
          '9. Merhem sürmek',
          '10. Koku koklamak',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Oruç Tutamayacak Olanlar',
        icerik: [
          '1. Hasta olanlar: Ciddi hastalığı olanlar oruç tutmayabilir, iyileşince kaza eder. İyileşme ihtimali yoksa her gün bir fakiri doyurur (fidye).',
          '2. Yolcular: Belirli mesafede (90 km) yolculuk yapanlar orucu kaza edebilir.',
          '3. Yaşlılar: Güç yetiremeyecek derecede yaşlı olanlar her gün bir fakiri doyurur (fidye).',
          '4. Hamile ve emziren kadınlar: Kendilerine veya çocuklarına zarar verirse tutmayabilir, sonra kaza eder.',
          '5. Hayızlı ve loğusa kadınlar: O dönemde oruç tutamaz, temiz olduktan sonra kaza eder.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Ramazan\'ın Özel Geceler',
        icerik: [
          'Kadir Gecesi: Ramazan\'ın son on gününün tek gecelerinden birinde olan bu gece, bin aydan daha hayırlıdır.',
          'Kadir gecesi ibadetler, dualar, Kur\'an tilaveti ve tövbe için en mübarek gecedir.',
          'Bu gece hangi gece olduğu kesin bilinmez, ancak 27. gece olma ihtimali yüksektir.',
        ],
        ayetler: [
          '"Kadir gecesi bin aydan daha hayırlıdır." (Kadr, 97/3)',
        ],
      ),
    ];
  }

  // ZEKAT KONULARI
  List<IlmihalKonu> _getZekatKonulari() {
    return [
      IlmihalKonu(
        baslik: 'Zekat Nedir ve Hikmeti',
        icerik: [
          'Zekat, belirli mallardan belirli miktarda Allah rızası için fakirlere verilen maldır.',
          'Zekat İslam\'ın beş temel esasından biridir ve zengin Müslümanlara farzdır.',
          'Zekat, toplumda servetin adil paylaşımını sağlar, fakir ile zengin arasındaki uçurumu kapatır.',
          'Zekat vermek, malı temizler, arttırır ve bereketlendirir.',
        ],
        ayetler: [
          '"Namazı kılın, zekâtı verin..." (Bakara, 2/43)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Zekatın Şartları',
        icerik: [
          '1. Müslüman olmak: Zekat sadece Müslümanlara farzdır.',
          '2. Hür olmak: Köle üzerine zekat farz değildir.',
          '3. Akıllı ve baliğ olmak: Çocuk ve deli üzerine zekat farz değildir (ancak malları için veli verir).',
          '4. Nisap miktarı mala sahip olmak: Belirli bir miktar mala sahip olmak.',
          '5. Malın üzerinden bir yıl (kamerî) geçmesi: Hayvan ve para için.',
          '6. Malın artı (ihtiyaç fazlası) olması: Temel ihtiyaçların üzerinde mal.',
          '7. Malın tam mülkiyette olması: Borç, rehin gibi durumlar olmamalı.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Zekat Verilecek Mallar ve Nisapları',
        icerik: [
          '1. Altın: 85 gram altına zekat verilir. %2.5 (kırkta bir) oranında.',
          '2. Gümüş: 595 gram gümüşe zekat verilir. %2.5 oranında.',
          '3. Para (Nakit): Üzerinden bir yıl geçen, 85 gram altın veya 595 gram gümüş değerindeki paraya zekat verilir. %2.5 oranında.',
          '4. Ticaret malları: Alınıp satılmak için edinilen mallara zekat verilir. Yıl sonunda piyasa değeri hesaplanır ve %2.5 verilir.',
          '5. Hayvanlar: Deve, sığır, koyun/keçi gibi belirli hayvanlardan zekat verilir (nisap miktarları farklıdır).',
          '6. Tarım ürünleri: Buğday, arpa, hurma gibi ürünlerden öşür veya nisf-ı öşür (1/10 veya 1/20) verilir.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Zekat Verilecek Kimseler',
        icerik: [
          'Kur\'an-ı Kerim\'de zekatın verileceği 8 sınıf belirtilmiştir:',
          '1. Fakirler (Fukara): Temel ihtiyaçlarını karşılayamayan kimseler.',
          '2. Miskinler (Mesakin): Hiçbir şeyi olmayan, son derece muhtaç olanlar.',
          '3. Zekat memurları (Amilin): Zekat toplama ve dağıtma işiyle görevli olanlar.',
          '4. Kalpleri İslam\'a ısındırılacak olanlar (Muellefe-i kulub).',
          '5. Köleler (Rikab): Azat edilecek köleler (günümüzde yok).',
          '6. Borçlular (Garimîn): Borcunu ödeyemeyecek durumda olanlar.',
          '7. Allah yolunda olanlar (Fi sebilillah): Cihad edenler, ilim talebeleri vb.',
          '8. Yolda kalanlar (İbni sebil): Yolculukta sıkıntıya düşen kimseler.',
        ],
        ayetler: [
          '"Sadakalar (zekâtlar) ancak fakirler, düşkünler, zekât toplayan memurlar, kalpleri İslâm\'a ısındırılacak olanlar, (özgürlüğüne kavuşturulacak) köleler, borçlular, Allah yolunda cihad edenler ve yolda kalmış yolcular içindir..." (Tevbe, 9/60)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Zekat Verilmeyecek Kimseler',
        icerik: [
          '1. Anne-baba ve dedeler: Zekat usul ve fürua (anne-baba, dede-nine, çocuk, torun) verilmez.',
          '2. Eş: Koca hanımına, hanım kocasına zekat veremez.',
          '3. Zenginler: Nisap miktarı mala sahip olanlara zekat verilmez.',
          '4. Müslüman olmayanlar: Zekat sadece Müslümanlara verilir.',
          '5. Haşimoğulları: Hz. Peygamber\'in (s.a.v) soyu olan Haşimoğullarına zekat verilmez.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Fitre (Sadaka-i Fıtr)',
        icerik: [
          'Fitre, Ramazan bayramında verilen bir sadakadır. Her Müslümana vaciptir.',
          'Fitre miktarı: Bir günlük temel gıda maddesi (buğday, arpa vb.) veya bunun karşılığı para.',
          'Fitre, bayram namazından önce verilmelidir. Bayram namazından sonra verilirse sadaka olur, fitre olmaz.',
          'Fitre, aile reisinin kendisi ve bakmakla yükümlü olduğu kişiler (eş, çocuklar) adına vermesi gerekir.',
        ],
        ayetler: [],
      ),
    ];
  }

  // HAC KONULARI - YENİ EKLENDİ
  List<IlmihalKonu> _getHacKonulari() {
    return [
      IlmihalKonu(
        baslik: 'Hac Nedir ve Önemi',
        icerik: [
          'Hac, İslam\'ın beş şartından biridir. Mali ve bedeni gücü yeten her Müslüman\'a ömründe bir kez haccetmek farzdır.',
          'Hac, Zilhicce ayının belirli günlerinde Kâbe\'yi ziyaret etmek ve belirli ibadetleri yerine getirmektir.',
          'Hac, Hz. İbrahim (a.s) ve Hz. İsmail\'in (a.s) sünnetidir.',
        ],
        ayetler: [
          '"İnsanların Beyt\'e (Kâbe\'ye) haccetmesi, yoluna güç yetirebilenlere Allah için bir borçtur..." (Al-i İmran, 3/97)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Haccın Farzları',
        icerik: [
          'Haccın 3 farzı vardır:',
          '1. İhram: Hacca niyet ederek ihram giysisini giymek.',
          '2. Vakfe (Arafat\'ta durmak): Zilhicce ayının 9. günü Arafat\'ta durmak.',
          '3. Ziyaret tavafı: Kurban bayramında Kâbe\'yi 7 kez tavaf etmek.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Haccın Vacipleri',
        icerik: [
          '1. Sa\'y: Safa ile Merve tepeleri arasında 7 kez gidip gelmek.',
          '2. Müzdelife\'de vakfe: Kurban bayramının arefesinde Müzdelife\'de durmak.',
          '3. Cemrelere taş atmak: Şeytanı taşlamayı temsilen belirli yerlere taş atmak.',
          '4. Tıraş olmak veya saç kısaltmak: İhramdan çıkarken.',
          '5. Veda tavafı: Mekke\'den ayrılmadan önce Kâbe\'yi tavaf etmek.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Umre',
        icerik: [
          'Umre, yılın her zamanında yapılabilen küçük hac olarak adlandırılır.',
          'Umrenin rükünleri: İhram, tavaf ve sa\'y.',
          'Umre hacdan ayrı, bağımsız bir ibadettir. Hac farz, umre ise sünnettir.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Hac Çeşitleri',
        icerik: [
          '1. İfrad Haccı: Sadece hac yapmak, umre yapmamak.',
          '2. Kıran Haccı: Hac ve umreyi birlikte niyet edip yapmak.',
          '3. Temettu Haccı: Önce umre yapıp ihramdan çıkmak, sonra hac için tekrar ihrama girmek.',
        ],
        ayetler: [],
      ),
    ];
  }

  // AHLAK KONULARI - YENİ EKLENDİ
  List<IlmihalKonu> _getAhlakKonulari() {
    return [
      IlmihalKonu(
        baslik: 'İslam Ahlakı',
        icerik: [
          'Ahlak, insanın iç dünyasındaki güzel ve kötü özelliklerin tamamıdır.',
          'Hz. Peygamber (s.a.v) en güzel ahlaka sahip insandı. "Ben güzel ahlakı tamamlamak için gönderildim" buyurmuştur.',
          'İslam, hem Allah\'a karşı hem de insanlara karşı güzel ahlakı emreder.',
        ],
        ayetler: [
          '"Şüphesiz sen yüce bir ahlak üzeresin." (Kalem, 68/4)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Anne-Babaya İyilik',
        icerik: [
          'Anne ve babaya iyilik etmek, onlara saygılı olmak ve itaat etmek farzdır.',
          'Anne-babanın rızası Allah\'ın rızasıdır, gazabı ise Allah\'ın gazabıdır.',
          'Hz. Peygamber (s.a.v): "Cennet annelerin ayakları altındadır" buyurmuştur.',
          'Yaşlı anne-babaya "öf" bile denmemeli, onlara yumuşak söz söylenmeli ve merhamet gösterilmelidir.',
        ],
        ayetler: [
          '"Rabbin, yalnız kendisine kulluk etmenizi, anne-babanıza da iyilik etmenizi emretti..." (İsra, 17/23)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Komşuluk Hakları',
        icerik: [
          'Komşuya iyilik etmek, ona zarar vermemek İslam\'ın emridir.',
          'Hz. Peygamber (s.a.v): "Komşusu açken tok yatan bizden değildir" buyurmuştur.',
          'Komşunun 40 evi sağdaki, 40 evi soldaki, 40 evi arkasındaki ve 40 evi önündeki evlerdir.',
          'Komşuya yardım etmek, onun sıkıntısını gidermek, hatalarını affetmek gerekir.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Doğruluk ve Emanet',
        icerik: [
          'Doğru sözlü olmak müminin en önemli özelliklerindendir. Yalan söylemek haramdır.',
          'Emanete hıyanet etmemek, güvenilir olmak iman gereğidir.',
          'Hz. Peygamber (s.a.v) henüz peygamber olmadan önce bile "el-Emin" (güvenilir) lakabıyla anılırdı.',
        ],
        ayetler: [
          '"Ey iman edenler! Allah\'a karşı gelmekten sakının ve doğrularla birlikte olun." (Tevbe, 9/119)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Sabır ve Şükür',
        icerik: [
          'Sabır, sıkıntılara göğüs germek, Allah\'ın kaderine razı olmaktır.',
          'Şükür, Allah\'ın nimetlerine karşı minnet duymak ve O\'na hamd etmektir.',
          'Sabır ve şükür, müminlerin en önemli iki özelliğidir.',
          'Sıkıntıda sabır, bollukta şükür göstermek gerekir.',
        ],
        ayetler: [
          '"Ey iman edenler! Sabır ve namazla Allah\'tan yardım isteyin..." (Bakara, 2/153)',
        ],
      ),
      IlmihalKonu(
        baslik: 'Öfke ve Hiddet',
        icerik: [
          'Öfkeyi kontrol etmek, kuvvetli olmanın işaretidir.',
          'Hz. Peygamber (s.a.v): "Güçlü kimse, güreşte rakibini yenen değil, öfkelendiğinde nefsine hakim olandır" buyurmuştur.',
          'Öfkelenince abdest almak, oturmak veya uzanmak öfkeyi yatıştırır.',
        ],
        ayetler: [],
      ),
      IlmihalKonu(
        baslik: 'Helal Kazanç',
        icerik: [
          'Helal yoldan kazanmak, haramdan uzak durmak her Müslüman\'ın görevidir.',
          'Faiz, rüşvet, hırsızlık, dolandırıcılık haramdır.',
          'Alışverişte hile yapmamak, ölçü ve tartıda adil olmak gerekir.',
          'Haram kazançla yapılan ibadetler kabul edilmez.',
        ],
        ayetler: [
          '"Ey insanlar! Yeryüzünde helal ve temiz olanlardan yeyin..." (Bakara, 2/168)',
        ],
      ),
    ];
  }
}

class IlmihalKonu {
  final String baslik;
  final List<String> icerik;
  final List<String> ayetler;

  IlmihalKonu({
    required this.baslik,
    required this.icerik,
    required this.ayetler,
  });

  Map<String, dynamic> toJson() {
    return {
      'baslik': baslik,
      'icerik': icerik,
      'ayetler': ayetler,
    };
  }

  factory IlmihalKonu.fromJson(Map<String, dynamic> json) {
    return IlmihalKonu(
      baslik: json['baslik'],
      icerik: List<String>.from(json['icerik']),
      ayetler: List<String>.from(json['ayetler']),
    );
  }
}
