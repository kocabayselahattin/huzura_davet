import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';

class KirkHadisSayfa extends StatefulWidget {
  const KirkHadisSayfa({super.key});

  @override
  State<KirkHadisSayfa> createState() => _KirkHadisSayfaState();
}

class _KirkHadisSayfaState extends State<KirkHadisSayfa> {
  final TemaService _temaService = TemaService();
  int _seciliIndex = 0;
  final PageController _pageController = PageController();
  final ScrollController _numberScrollController = ScrollController();
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadFontScale();
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble('hadis_font_scale') ?? 1.0;
    if (mounted) {
      setState(() {
        _fontScale = scale;
      });
    }
  }

  Future<void> _saveFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hadis_font_scale', _fontScale);
  }

  void _increaseFontSize() {
    if (_fontScale < 2.0) {
      setState(() {
        _fontScale += 0.1;
      });
      _saveFontScale();
    }
  }

  void _decreaseFontSize() {
    if (_fontScale > 0.7) {
      setState(() {
        _fontScale -= 0.1;
      });
      _saveFontScale();
    }
  }

  // 40 Hadis - Kaynak: Kırk Hadis (İmam Nevevi)
  final List<Map<String, String>> _hadisler = [
    {
      'no': '1',
      'baslik': 'Ameller Niyetlere Göredir',
      'arapca':
          'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى',
      'turkce':
          'Ameller niyetlere göredir. Herkes için ancak niyet ettiği vardır.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '2',
      'baslik': 'İslam, İman ve İhsan',
      'arapca':
          'الْإِسْلَامُ أَنْ تَشْهَدَ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ',
      'turkce':
          'İslam; Allah\'tan başka ilah olmadığına ve Muhammed\'in Allah\'ın elçisi olduğuna şehadet etmen, namazı kılman, zekatı vermen, Ramazan orucunu tutman ve gücün yeterse Beyt\'i hac etmendir.',
      'kaynak': 'Müslim',
    },
    {
      'no': '3',
      'baslik': 'İslamın Beş Şartı',
      'arapca': 'بُنِيَ الْإِسْلَامُ عَلَى خَمْسٍ',
      'turkce':
          'İslam beş esas üzerine bina edilmiştir: Allah\'tan başka ilah olmadığına ve Muhammed\'in O\'nun kulu ve elçisi olduğuna şehadet etmek, namaz kılmak, zekat vermek, Beyt\'i hac etmek ve Ramazan orucunu tutmak.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '4',
      'baslik': 'Yaratılış ve Ruh',
      'arapca':
          'إِنَّ أَحَدَكُمْ يُجْمَعُ خَلْقُهُ فِي بَطْنِ أُمِّهِ أَرْبَعِينَ يَوْمًا',
      'turkce':
          'Sizden birinizin yaratılışı, annesinin karnında kırk gün nutfe olarak toplanır, sonra aynı süre içinde alaka (kan pıhtısı) olur, sonra yine aynı süre içinde mudğa (et parçası) olur. Sonra ona melek gönderilir ve ruh üflenir.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '5',
      'baslik': 'Bidatler',
      'arapca':
          'مَنْ أَحْدَثَ فِي أَمْرِنَا هَذَا مَا لَيْسَ مِنْهُ فَهُوَ رَدٌّ',
      'turkce': 'Kim bu dinimizde olmayan bir şey ihdas ederse, o reddedilir.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '6',
      'baslik': 'Helal ve Haram',
      'arapca': 'إِنَّ الْحَلَالَ بَيِّنٌ وَإِنَّ الْحَرَامَ بَيِّنٌ',
      'turkce':
          'Helal açıktır, haram da açıktır. Bu ikisinin arasında çoğu insanların bilmediği şüpheli şeyler vardır. Kim şüpheli şeylerden sakınırsa, dinini ve ırzını korumuş olur.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '7',
      'baslik': 'Nasihat',
      'arapca': 'الدِّينُ النَّصِيحَةُ',
      'turkce':
          'Din nasihattir. Kime dedik: Allah\'a, Kitabına, Resulüne, Müslümanların imamlarına ve tüm Müslümanlara.',
      'kaynak': 'Müslim',
    },
    {
      'no': '8',
      'baslik': 'Müslüman Kanı',
      'arapca':
          'أُمِرْتُ أَنْ أُقَاتِلَ النَّاسَ حَتَّى يَشْهَدُوا أَنْ لَا إِلَهَ إِلَّا اللَّهُ',
      'turkce':
          'İnsanlar "La ilahe illallah, Muhammedün Resulullah" deyinceye, namaz kılıncaya ve zekat verinceye kadar onlarla savaşmam emredildi. Bunları yaptıkları zaman kanlarını ve mallarını benden korumuş olurlar.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '9',
      'baslik': 'Kolaylık',
      'arapca':
          'مَا نَهَيْتُكُمْ عَنْهُ فَاجْتَنِبُوهُ وَمَا أَمَرْتُكُمْ بِهِ فَأْتُوا مِنْهُ مَا اسْتَطَعْتُمْ',
      'turkce':
          'Size yasakladığım şeylerden kaçının, emrettiğim şeyleri de gücünüz yettiğince yapın. Sizden öncekileri çok soru sormaları ve peygamberlerine muhalefet etmeleri helak etmiştir.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '10',
      'baslik': 'Temiz Kazanç',
      'arapca': 'إِنَّ اللَّهَ طَيِّبٌ لَا يَقْبَلُ إِلَّا طَيِّبًا',
      'turkce':
          'Allah temizdir, ancak temiz olanı kabul eder. Allah, müminlere de peygamberlerine emrettiğini emretmiştir.',
      'kaynak': 'Müslim',
    },
    {
      'no': '11',
      'baslik': 'Şüpheli Şeyler',
      'arapca': 'دَعْ مَا يَرِيبُكَ إِلَى مَا لَا يَرِيبُكَ',
      'turkce': 'Seni şüphelendiren şeyi bırak, şüphelendirmeyene geç.',
      'kaynak': 'Tirmizi, Nesai',
    },
    {
      'no': '12',
      'baslik': 'Malayani',
      'arapca': 'مِنْ حُسْنِ إِسْلَامِ الْمَرْءِ تَرْكُهُ مَا لَا يَعْنِيهِ',
      'turkce':
          'Kişinin İslam\'ının güzelliğinden biri, kendisini ilgilendirmeyen şeyleri terk etmesidir.',
      'kaynak': 'Tirmizi',
    },
    {
      'no': '13',
      'baslik': 'Müslüman Kardeşliği',
      'arapca':
          'لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ',
      'turkce':
          'Sizden biriniz kendisi için sevdiğini kardeşi için de sevmedikçe (gerçek) iman etmiş olmaz.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '14',
      'baslik': 'Müslüman Kanının Dokunulmazlığı',
      'arapca': 'لَا يَحِلُّ دَمُ امْرِئٍ مُسْلِمٍ إِلَّا بِإِحْدَى ثَلَاثٍ',
      'turkce':
          'Müslüman bir kişinin kanı ancak üç durumda helal olur: Evli olup zina eden, cana karşı can ve dinini terk edip cemaatten ayrılan.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '15',
      'baslik': 'Güzel Söz',
      'arapca':
          'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الْآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
      'turkce':
          'Allah\'a ve ahiret gününe iman eden, ya hayır söylesin ya da sussun. Allah\'a ve ahiret gününe iman eden komşusuna ikram etsin. Allah\'a ve ahiret gününe iman eden misafirine ikram etsin.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '16',
      'baslik': 'Kızgınlık',
      'arapca': 'لَا تَغْضَبْ',
      'turkce':
          'Bir adam Peygamber\'e (s.a.v) "Bana nasihat et" dedi. Peygamber (s.a.v) "Kızma" buyurdu. Adam birkaç kere sordu, her seferinde "Kızma" buyurdu.',
      'kaynak': 'Buhari',
    },
    {
      'no': '17',
      'baslik': 'İhsan',
      'arapca': 'إِنَّ اللَّهَ كَتَبَ الْإِحْسَانَ عَلَى كُلِّ شَيْءٍ',
      'turkce':
          'Allah her şeye ihsanı yazmıştır. Öldürdüğünüz zaman güzel öldürün, kestiğiniz zaman güzel kesin. Biriniz bıçağını bilesin ve hayvanını rahatlatsın.',
      'kaynak': 'Müslim',
    },
    {
      'no': '18',
      'baslik': 'Takva',
      'arapca': 'اتَّقِ اللَّهِ حَيْثُمَا كُنْتَ',
      'turkce':
          'Nerede olursan ol Allah\'tan kork. Kötülüğün ardından iyilik yap ki onu silsin. İnsanlara güzel ahlakla muamele et.',
      'kaynak': 'Tirmizi',
    },
    {
      'no': '19',
      'baslik': 'Allah\'ın Koruması',
      'arapca': 'احْفَظِ اللَّهَ يَحْفَظْكَ',
      'turkce':
          'Allah\'ı koru ki Allah seni korusun. Allah\'ı koru ki O\'nu karşında bulasın. İstediğinde Allah\'tan iste. Yardım istediğinde Allah\'tan yardım iste.',
      'kaynak': 'Tirmizi',
    },
    {
      'no': '20',
      'baslik': 'Haya',
      'arapca':
          'إِنَّ مِمَّا أَدْرَكَ النَّاسُ مِنْ كَلَامِ النُّبُوَّةِ الْأُولَى إِذَا لَمْ تَسْتَحِ فَاصْنَعْ مَا شِئْتَ',
      'turkce':
          'İnsanların ilk peygamberlik sözlerinden edindikleri şeylerden biri de şudur: Utanmazsan dilediğini yap.',
      'kaynak': 'Buhari',
    },
    {
      'no': '21',
      'baslik': 'İstikamet',
      'arapca': 'قُلْ آمَنْتُ بِاللَّهِ ثُمَّ اسْتَقِمْ',
      'turkce': '"Allah\'a inandım" de, sonra dosdoğru ol.',
      'kaynak': 'Müslim',
    },
    {
      'no': '22',
      'baslik': 'Cennete Götüren Ameller',
      'arapca': 'أَرَأَيْتَ إِذَا صَلَّيْتُ الْمَكْتُوبَاتِ وَصُمْتُ رَمَضَانَ',
      'turkce':
          'Farz namazları kılarsam, Ramazan orucunu tutarsam, helali helal, haramı haram sayarsam cennete girer miyim? Peygamber (s.a.v) "Evet" buyurdu.',
      'kaynak': 'Müslim',
    },
    {
      'no': '23',
      'baslik': 'Temizlik ve Namaz',
      'arapca': 'الطُّهُورُ شَطْرُ الْإِيمَانِ',
      'turkce':
          'Temizlik imanın yarısıdır. "Elhamdülillah" mizanı doldurur. "Subhanallah" ve "Elhamdülillah" göklerle yer arasını doldurur. Namaz nurdur.',
      'kaynak': 'Müslim',
    },
    {
      'no': '24',
      'baslik': 'Zulmün Haramlığı',
      'arapca':
          'يَا عِبَادِي إِنِّي حَرَّمْتُ الظُّلْمَ عَلَى نَفْسِي وَجَعَلْتُهُ بَيْنَكُمْ مُحَرَّمًا فَلَا تَظَالَمُوا',
      'turkce':
          'Ey kullarım! Ben zulmü kendime haram kıldım, onu aranızda da haram kıldım. Öyleyse birbirinize zulmetmeyin.',
      'kaynak': 'Müslim (Kudsi Hadis)',
    },
    {
      'no': '25',
      'baslik': 'Sadaka',
      'arapca': 'كُلُّ سُلَامَى مِنَ النَّاسِ عَلَيْهِ صَدَقَةٌ',
      'turkce':
          'İnsanın her eklemi için sadaka gerekir. İki kişi arasında adaletle hükmetmen sadakadır. Bir kişiye bineğine binmesinde yardım etmen sadakadır. Güzel söz sadakadır. Namaza atılan her adım sadakadır. Yoldan eziyet veren şeyi kaldırman sadakadır.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '26',
      'baslik': 'İyilik ve Günah',
      'arapca': 'الْبِرُّ حُسْنُ الْخُلُقِ وَالْإِثْمُ مَا حَاكَ فِي صَدْرِكَ',
      'turkce':
          'İyilik güzel ahlaktır. Günah ise içinde tereddüt uyandıran ve insanların bilmesini istemediğin şeydir.',
      'kaynak': 'Müslim',
    },
    {
      'no': '27',
      'baslik': 'Kalp',
      'arapca': 'الْبِرُّ مَا اطْمَأَنَّ إِلَيْهِ الْقَلْبُ',
      'turkce':
          'İyilik, kalbin mutmain olduğu ve nefsin rahat ettiği şeydir. Günah ise kalpte tereddüt uyandıran ve insanlar fetva verse de göğüste gidip gelen şeydir.',
      'kaynak': 'Ahmed, Darimi',
    },
    {
      'no': '28',
      'baslik': 'Sünnet',
      'arapca':
          'عَلَيْكُمْ بِسُنَّتِي وَسُنَّةِ الْخُلَفَاءِ الرَّاشِدِينَ الْمَهْدِيِّينَ',
      'turkce':
          'Size sünnetime ve hidayete erdirilmiş raşit halifelerin sünnetine sarılmanızı tavsiye ederim. Buna azı dişlerinizle sımsıkı sarılın. Sonradan icat edilen şeylerden sakının.',
      'kaynak': 'Ebu Davud, Tirmizi',
    },
    {
      'no': '29',
      'baslik': 'Cennetin Yolu',
      'arapca':
          'يَا رَسُولَ اللَّهِ أَخْبِرْنِي بِعَمَلٍ يُدْخِلُنِي الْجَنَّةَ',
      'turkce':
          'Beni cennete sokacak ve cehennemden uzaklaştıracak bir amel söyle. Peygamber (s.a.v): Allah\'a ibadet et, O\'na hiçbir şeyi ortak koşma, namazı kıl, zekatı ver ve akraba ile ilişkini devam ettir.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '30',
      'baslik': 'Allah\'ın Sınırları',
      'arapca': 'إِنَّ اللَّهَ فَرَضَ فَرَائِضَ فَلَا تُضَيِّعُوهَا',
      'turkce':
          'Allah bazı farzları emretti, onları zayi etmeyin. Bazı sınırlar koydu, onları aşmayın. Bazı şeyleri haram kıldı, onları ihlal etmeyin. Bazı şeyleri de unutmadan size rahmet olarak bildirmedi, onları araştırmayın.',
      'kaynak': 'Darakutni',
    },
    {
      'no': '31',
      'baslik': 'Zühd',
      'arapca': 'ازْهَدْ فِي الدُّنْيَا يُحِبَّكَ اللَّهُ',
      'turkce':
          'Dünyaya karşı zahit ol ki Allah seni sevsin. İnsanların elindekine karşı zahit ol ki insanlar seni sevsin.',
      'kaynak': 'İbn Mace',
    },
    {
      'no': '32',
      'baslik': 'Zarar Vermeme',
      'arapca': 'لَا ضَرَرَ وَلَا ضِرَارَ',
      'turkce': 'Zarar vermek de zarar görmek de yoktur.',
      'kaynak': 'İbn Mace, Ahmed',
    },
    {
      'no': '33',
      'baslik': 'Delil',
      'arapca':
          'لَوْ يُعْطَى النَّاسُ بِدَعْوَاهُمْ لَادَّعَى رِجَالٌ أَمْوَالَ قَوْمٍ وَدِمَاءَهُمْ',
      'turkce':
          'İnsanlara sırf iddialarıyla verilseydi, bazı insanlar başkalarının mallarını ve canlarını iddia ederdi. Fakat delil iddia edene, yemin de inkâr edene düşer.',
      'kaynak': 'Beyhaki',
    },
    {
      'no': '34',
      'baslik': 'Münkeri Değiştirme',
      'arapca': 'مَنْ رَأَى مِنْكُمْ مُنْكَرًا فَلْيُغَيِّرْهُ بِيَدِهِ',
      'turkce':
          'Sizden kim bir münker görürse onu eliyle değiştirsin. Buna gücü yetmezse diliyle, buna da gücü yetmezse kalbiyle. Bu da imanın en zayıfıdır.',
      'kaynak': 'Müslim',
    },
    {
      'no': '35',
      'baslik': 'Müslüman Kardeşliği',
      'arapca': 'لَا تَحَاسَدُوا وَلَا تَنَاجَشُوا وَلَا تَبَاغَضُوا',
      'turkce':
          'Birbirinizi kıskanmayın, birbirinize düşmanlık etmeyin, birbirinize sırt çevirmeyin. Allah\'ın kulları kardeş olun. Müslüman Müslümanın kardeşidir; ona zulmetmez, onu yalnız bırakmaz, onu küçümsemez.',
      'kaynak': 'Müslim',
    },
    {
      'no': '36',
      'baslik': 'İhtiyaç Giderme',
      'arapca':
          'مَنْ نَفَّسَ عَنْ مُؤْمِنٍ كُرْبَةً مِنْ كُرَبِ الدُّنْيَا نَفَّسَ اللَّهُ عَنْهُ كُرْبَةً مِنْ كُرَبِ يَوْمِ الْقِيَامَةِ',
      'turkce':
          'Kim bir müminin dünya sıkıntılarından birini giderirse, Allah da onun kıyamet günü sıkıntılarından birini giderir. Kim bir zorluk içindekine kolaylık gösterirse, Allah da ona dünya ve ahirette kolaylık gösterir.',
      'kaynak': 'Müslim',
    },
    {
      'no': '37',
      'baslik': 'Sevap ve Günah',
      'arapca': 'إِنَّ اللَّهَ كَتَبَ الْحَسَنَاتِ وَالسَّيِّئَاتِ',
      'turkce':
          'Allah hasenatı ve seyyiatı yazdı. Kim bir hasene yapmaya niyet eder de yapmazsa, Allah bunu tam bir hasene olarak yazar. Niyet edip yaparsa, on mislinden yedi yüz misline kadar yazar.',
      'kaynak': 'Buhari, Müslim',
    },
    {
      'no': '38',
      'baslik': 'Allah Dostları',
      'arapca': 'مَنْ عَادَى لِي وَلِيًّا فَقَدْ آذَنْتُهُ بِالْحَرْبِ',
      'turkce':
          'Kim benim bir velime düşmanlık ederse, ona savaş açmışım demektir. Kulum bana en çok farzlarla yaklaşır. Kulum nafilelerle de bana yaklaşmaya devam eder, ta ki onu severim.',
      'kaynak': 'Buhari (Kudsi Hadis)',
    },
    {
      'no': '39',
      'baslik': 'Hata ve Unutma',
      'arapca':
          'إِنَّ اللَّهَ تَجَاوَزَ لِي عَنْ أُمَّتِي الْخَطَأَ وَالنِّسْيَانَ وَمَا اسْتُكْرِهُوا عَلَيْهِ',
      'turkce':
          'Allah benim ümmetimden hata, unutma ve zorla yaptırılanları bağışlamıştır.',
      'kaynak': 'İbn Mace',
    },
    {
      'no': '40',
      'baslik': 'Dünyada Yabancı Ol',
      'arapca': 'كُنْ فِي الدُّنْيَا كَأَنَّكَ غَرِيبٌ أَوْ عَابِرُ سَبِيلٍ',
      'turkce':
          'Dünyada bir garip veya bir yolcu gibi ol. İbn Ömer derdi ki: Akşama erişince sabahı bekleme, sabaha erişince akşamı bekleme. Sağlığından hastalığın için, hayatından ölümün için (azık) al.',
      'kaynak': 'Buhari',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _numberScrollController.dispose();
    super.dispose();
  }

  void _scrollToCenter(int index) {
    // Her butonun genişliği 48 (40 + 2*4 margin)
    const itemWidth = 48.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    _numberScrollController.animateTo(
      targetOffset.clamp(0.0, _numberScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          '40 HADİS',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: renkler.yaziPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: _decreaseFontSize,
            tooltip: 'Yazı Küçült',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: _increaseFontSize,
            tooltip: 'Yazı Büyüt',
          ),
        ],
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: Column(
          children: [
            // Hadis numarası seçici
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                controller: _numberScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 40,
                itemBuilder: (context, index) {
                  final isSecili = index == _seciliIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _seciliIndex = index);
                      _scrollToCenter(index);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSecili ? renkler.vurgu : renkler.kartArkaPlan,
                        border: Border.all(
                          color: isSecili ? renkler.vurgu : renkler.ayirac,
                          width: 1,
                        ),
                        boxShadow: isSecili
                            ? [
                                BoxShadow(
                                  color: renkler.vurgu.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isSecili
                              ? Colors.white
                              : renkler.yaziSecondary,
                          fontWeight: isSecili
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Hadis içeriği
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _hadisler.length,
                onPageChanged: (index) {
                  setState(() => _seciliIndex = index);
                  _scrollToCenter(index);
                },
                itemBuilder: (context, index) {
                  final hadis = _hadisler[index];
                  return _buildHadisKarti(hadis, renkler);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHadisKarti(Map<String, String> hadis, TemaRenkleri renkler) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: renkler.vurgu.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: renkler.vurgu.withOpacity(0.1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hadis['no']!,
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hadis['baslik']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 24 * _fontScale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Arapça metin
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: renkler.vurgu.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote, color: renkler.vurgu, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Arapça',
                      style: TextStyle(
                        color: renkler.vurgu,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hadis['arapca']!,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 22 * _fontScale,
                    height: 2,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Türkçe metin
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: renkler.kartArkaPlan,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: renkler.vurguSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Türkçe Meali',
                      style: TextStyle(
                        color: renkler.vurguSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hadis['turkce']!,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 16 * _fontScale,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Kaynak
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: renkler.vurgu.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_books, color: renkler.vurgu, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Kaynak: ${hadis['kaynak']}',
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
