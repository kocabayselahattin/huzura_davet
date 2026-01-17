import 'package:flutter/material.dart';
import 'dart:async';
import '../services/tema_service.dart';

class EsmaulHusnaWidget extends StatefulWidget {
  const EsmaulHusnaWidget({super.key});

  @override
  State<EsmaulHusnaWidget> createState() => _EsmaulHusnaWidgetState();
}

class _EsmaulHusnaWidgetState extends State<EsmaulHusnaWidget> 
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _midnightTimer;
  DateTime? _lastDate;

  static const List<Map<String, String>> _esmaulHusna = [
    {'arapca': 'الله', 'turkce': 'Allah', 'anlam': 'Bütün isimlerin vasıflarını içine alan öz adı'},
    {'arapca': 'الرَّحْمَنُ', 'turkce': 'Er-Rahman', 'anlam': 'Dünyada bütün mahlûkata merhamet eden, şefkat gösteren'},
    {'arapca': 'الرَّحِيمُ', 'turkce': 'Er-Rahim', 'anlam': 'Ahirette, müminlere sonsuz merhamet eden'},
    {'arapca': 'الْمَلِكُ', 'turkce': 'El-Melik', 'anlam': 'Mülkün gerçek sahibi, bütün kâinatın hükümdarı'},
    {'arapca': 'الْقُدُّوسُ', 'turkce': 'El-Kuddüs', 'anlam': 'Her türlü eksiklik ve ayıptan münezzeh olan'},
    {'arapca': 'السَّلامُ', 'turkce': 'Es-Selam', 'anlam': 'Her türlü tehlikelerden selamete çıkaran'},
    {'arapca': 'الْمُؤْمِنُ', 'turkce': 'El-Mümin', 'anlam': 'Güven veren, emin kılan, koruyan'},
    {'arapca': 'الْمُهَيْمِنُ', 'turkce': 'El-Müheymin', 'anlam': 'Koruyup gözeten, her şeye şahit olan'},
    {'arapca': 'الْعَزِيزُ', 'turkce': 'El-Aziz', 'anlam': 'Sonsuz izzet sahibi, mağlup edilemeyen'},
    {'arapca': 'الْجَبَّارُ', 'turkce': 'El-Cebbar', 'anlam': 'İstediğini zorla yaptıran, ulaşılmaz'},
    {'arapca': 'الْمُتَكَبِّرُ', 'turkce': 'El-Mütekebbir', 'anlam': 'Büyüklükte eşi benzeri olmayan'},
    {'arapca': 'الْخَالِقُ', 'turkce': 'El-Hâlık', 'anlam': 'Yaratan, yoktan var eden'},
    {'arapca': 'الْبَارِئُ', 'turkce': 'El-Bâri', 'anlam': 'Her şeyi kusursuzca yaratan'},
    {'arapca': 'الْمُصَوِّرُ', 'turkce': 'El-Musavvir', 'anlam': 'Şekil veren, tasvir eden'},
    {'arapca': 'الْغَفَّارُ', 'turkce': 'El-Gaffar', 'anlam': 'Günahları çok bağışlayan'},
    {'arapca': 'الْقَهَّارُ', 'turkce': 'El-Kahhar', 'anlam': 'Her şeye galip gelen'},
    {'arapca': 'الْوَهَّابُ', 'turkce': 'El-Vehhab', 'anlam': 'Karşılıksız çok hediye eden'},
    {'arapca': 'الرَّزَّاقُ', 'turkce': 'Er-Rezzak', 'anlam': 'Bütün canlıların rızkını veren'},
    {'arapca': 'الْفَتَّاحُ', 'turkce': 'El-Fettah', 'anlam': 'Her türlü güçlüğü açan, kolaylaştıran'},
    {'arapca': 'الْعَلِيمُ', 'turkce': 'El-Alîm', 'anlam': 'Her şeyi en ince ayrıntısına kadar bilen'},
    {'arapca': 'الْقَابِضُ', 'turkce': 'El-Kâbıd', 'anlam': 'Rızkı tutan, daraltan'},
    {'arapca': 'الْبَاسِطُ', 'turkce': 'El-Bâsıt', 'anlam': 'Rızkı açan, genişleten'},
    {'arapca': 'الْخَافِضُ', 'turkce': 'El-Hâfıd', 'anlam': 'Dereceleri alçaltan'},
    {'arapca': 'الرَّافِعُ', 'turkce': 'Er-Râfi', 'anlam': 'Dereceleri yükselten'},
    {'arapca': 'الْمُعِزُّ', 'turkce': 'El-Muizz', 'anlam': 'İzzet ve şeref veren'},
    {'arapca': 'الْمُذِلُّ', 'turkce': 'El-Müzill', 'anlam': 'Alçaltan, zelil kılan'},
    {'arapca': 'السَّمِيعُ', 'turkce': 'Es-Semi', 'anlam': 'Her şeyi işiten'},
    {'arapca': 'الْبَصِيرُ', 'turkce': 'El-Basîr', 'anlam': 'Her şeyi gören'},
    {'arapca': 'الْحَكَمُ', 'turkce': 'El-Hakem', 'anlam': 'Hüküm veren, hâkimlerin hâkimi'},
    {'arapca': 'الْعَدْلُ', 'turkce': 'El-Adl', 'anlam': 'Mutlak adalet sahibi'},
    {'arapca': 'اللَّطِيفُ', 'turkce': 'El-Latîf', 'anlam': 'Lütuf sahibi, nazik davranan'},
    {'arapca': 'الْخَبِيرُ', 'turkce': 'El-Habîr', 'anlam': 'Her şeyden haberdar olan'},
    {'arapca': 'الْحَلِيمُ', 'turkce': 'El-Halîm', 'anlam': 'Çok yumuşak davranan, hilim sahibi'},
    {'arapca': 'الْعَظِيمُ', 'turkce': 'El-Azîm', 'anlam': 'Büyüklükte sonsuz olan'},
    {'arapca': 'الْغَفُورُ', 'turkce': 'El-Gafûr', 'anlam': 'Çok bağışlayan'},
    {'arapca': 'الشَّكُورُ', 'turkce': 'Eş-Şekûr', 'anlam': 'Az iyiliğe çok mükâfat veren'},
    {'arapca': 'الْعَلِيُّ', 'turkce': 'El-Aliyy', 'anlam': 'Yüceliğin sahibi'},
    {'arapca': 'الْكَبِيرُ', 'turkce': 'El-Kebîr', 'anlam': 'Büyüklükte sınırsız olan'},
    {'arapca': 'الْحَفِيظُ', 'turkce': 'El-Hafîz', 'anlam': 'Her şeyi koruyup gözeten'},
    {'arapca': 'الْمُقِيتُ', 'turkce': 'El-Mukît', 'anlam': 'Bedenlerin ve ruhların gıdasını veren'},
    {'arapca': 'الْحَسِيبُ', 'turkce': 'El-Hasîb', 'anlam': 'Hesap soran, hesaba çeken'},
    {'arapca': 'الْجَلِيلُ', 'turkce': 'El-Celîl', 'anlam': 'Celâlet ve azamet sahibi'},
    {'arapca': 'الْكَرِيمُ', 'turkce': 'El-Kerîm', 'anlam': 'Sonsuz kerem sahibi'},
    {'arapca': 'الرَّقِيبُ', 'turkce': 'Er-Rakîb', 'anlam': 'Her şeyi gözetleyen'},
    {'arapca': 'الْمُجِيبُ', 'turkce': 'El-Mücîb', 'anlam': 'Duaları kabul eden'},
    {'arapca': 'الْوَاسِعُ', 'turkce': 'El-Vâsi', 'anlam': 'İlmi ve merhameti sınırsız olan'},
    {'arapca': 'الْحَكِيمُ', 'turkce': 'El-Hakîm', 'anlam': 'Her işi hikmetli olan'},
    {'arapca': 'الْوَدُودُ', 'turkce': 'El-Vedûd', 'anlam': 'Çok seven, çok sevilen'},
    {'arapca': 'الْمَجِيدُ', 'turkce': 'El-Mecîd', 'anlam': 'Şanı çok yüce olan'},
    {'arapca': 'الْبَاعِثُ', 'turkce': 'El-Bâis', 'anlam': 'Ölüleri dirilten'},
    {'arapca': 'الشَّهِيدُ', 'turkce': 'Eş-Şehîd', 'anlam': 'Her yerde hazır ve nazır olan'},
    {'arapca': 'الْحَقُّ', 'turkce': 'El-Hakk', 'anlam': 'Varlığı gerçek olan'},
    {'arapca': 'الْوَكِيلُ', 'turkce': 'El-Vekîl', 'anlam': 'Güvenilip dayanılan'},
    {'arapca': 'الْقَوِيُّ', 'turkce': 'El-Kaviyy', 'anlam': 'Sonsuz güç sahibi'},
    {'arapca': 'الْمَتِينُ', 'turkce': 'El-Metîn', 'anlam': 'Çok sağlam, pek güçlü'},
    {'arapca': 'الْوَلِيُّ', 'turkce': 'El-Veliyy', 'anlam': 'Müminlerin dostu'},
    {'arapca': 'الْحَمِيدُ', 'turkce': 'El-Hamîd', 'anlam': 'Övgüye lâyık olan'},
    {'arapca': 'الْمُحْصِي', 'turkce': 'El-Muhsî', 'anlam': 'Her şeyi sayan'},
    {'arapca': 'الْمُبْدِئُ', 'turkce': 'El-Mübdi', 'anlam': 'İlk yaratan'},
    {'arapca': 'الْمُعِيدُ', 'turkce': 'El-Muîd', 'anlam': 'Tekrar yaratan'},
    {'arapca': 'الْمُحْيِي', 'turkce': 'El-Muhyî', 'anlam': 'Hayat veren'},
    {'arapca': 'الْمُمِيتُ', 'turkce': 'El-Mümît', 'anlam': 'Ölümü yaratan'},
    {'arapca': 'الْحَيُّ', 'turkce': 'El-Hayy', 'anlam': 'Diri, her şeyi bilen ve her şeye gücü yeten'},
    {'arapca': 'الْقَيُّومُ', 'turkce': 'El-Kayyûm', 'anlam': 'Her şeyi ayakta tutan'},
    {'arapca': 'الْوَاجِدُ', 'turkce': 'El-Vâcid', 'anlam': 'İstediğini, istediği anda bulan'},
    {'arapca': 'الْمَاجِدُ', 'turkce': 'El-Mâcid', 'anlam': 'Şerefi ve keremi sonsuz olan'},
    {'arapca': 'الْوَاحِدُ', 'turkce': 'El-Vâhid', 'anlam': 'Tek olan, ortağı olmayan'},
    {'arapca': 'الصَّمَدُ', 'turkce': 'Es-Samed', 'anlam': 'Hiçbir şeye muhtaç olmayan'},
    {'arapca': 'الْقَادِرُ', 'turkce': 'El-Kâdir', 'anlam': 'Her şeye gücü yeten'},
    {'arapca': 'الْمُقْتَدِرُ', 'turkce': 'El-Muktedir', 'anlam': 'Kudret sahibi'},
    {'arapca': 'الْمُقَدِّمُ', 'turkce': 'El-Mukaddim', 'anlam': 'Öne alan'},
    {'arapca': 'الْمُؤَخِّرُ', 'turkce': 'El-Muahhir', 'anlam': 'Geriye bırakan'},
    {'arapca': 'الأَوَّلُ', 'turkce': 'El-Evvel', 'anlam': 'Varlığının başlangıcı olmayan'},
    {'arapca': 'الآخِرُ', 'turkce': 'El-Âhir', 'anlam': 'Varlığının sonu olmayan'},
    {'arapca': 'الظَّاهِرُ', 'turkce': 'Ez-Zâhir', 'anlam': 'Varlığı açık olan'},
    {'arapca': 'الْبَاطِنُ', 'turkce': 'El-Bâtın', 'anlam': 'Gizli olan'},
    {'arapca': 'الْوَالِي', 'turkce': 'El-Vâlî', 'anlam': 'Her şeyi yöneten'},
    {'arapca': 'الْمُتَعَالِي', 'turkce': 'El-Müteâlî', 'anlam': 'Yüce olan'},
    {'arapca': 'الْبَرُّ', 'turkce': 'El-Berr', 'anlam': 'İyilik ve ihsan sahibi'},
    {'arapca': 'التَّوَّابُ', 'turkce': 'Et-Tevvâb', 'anlam': 'Tövbeleri çok kabul eden'},
    {'arapca': 'الْمُنْتَقِمُ', 'turkce': 'El-Müntakim', 'anlam': 'Suçlulardan intikam alan'},
    {'arapca': 'الْعَفُوُّ', 'turkce': 'El-Afüvv', 'anlam': 'Affı çok olan'},
    {'arapca': 'الرَّؤُوفُ', 'turkce': 'Er-Raûf', 'anlam': 'Çok şefkatli olan'},
    {'arapca': 'مَالِكُ الْمُلْكِ', 'turkce': 'Mâlikü\'l-Mülk', 'anlam': 'Mülkün sahibi'},
    {'arapca': 'ذُو الْجَلالِ وَالإِكْرَامِ', 'turkce': 'Zü\'l-Celâli ve\'l-İkram', 'anlam': 'Celâl ve ikram sahibi'},
    {'arapca': 'الْمُقْسِطُ', 'turkce': 'El-Muksit', 'anlam': 'Adaletle hükmeden'},
    {'arapca': 'الْجَامِعُ', 'turkce': 'El-Câmi', 'anlam': 'Toplayan, bir araya getiren'},
    {'arapca': 'الْغَنِيُّ', 'turkce': 'El-Ganiyy', 'anlam': 'Çok zengin olan'},
    {'arapca': 'الْمُغْنِي', 'turkce': 'El-Muğnî', 'anlam': 'Zenginlik veren'},
    {'arapca': 'الْمَانِعُ', 'turkce': 'El-Mâni', 'anlam': 'Engelleyen, koruyan'},
    {'arapca': 'الضَّارُّ', 'turkce': 'Ed-Dârr', 'anlam': 'Zarar vermeye gücü yeten'},
    {'arapca': 'النَّافِعُ', 'turkce': 'En-Nâfi', 'anlam': 'Fayda vermeye gücü yeten'},
    {'arapca': 'النُّورُ', 'turkce': 'En-Nûr', 'anlam': 'Nur olan, nurlandıran'},
    {'arapca': 'الْهَادِي', 'turkce': 'El-Hâdî', 'anlam': 'Hidayet eden'},
    {'arapca': 'الْبَدِيعُ', 'turkce': 'El-Bedî', 'anlam': 'Eşsiz yaratan'},
    {'arapca': 'الْبَاقِي', 'turkce': 'El-Bâkî', 'anlam': 'Varlığının sonu olmayan'},
    {'arapca': 'الْوَارِثُ', 'turkce': 'El-Vâris', 'anlam': 'Her şeyin gerçek sahibi'},
    {'arapca': 'الرَّشِيدُ', 'turkce': 'Er-Reşîd', 'anlam': 'Doğru yolu gösteren'},
    {'arapca': 'الصَّبُورُ', 'turkce': 'Es-Sabûr', 'anlam': 'Çok sabırlı olan'},
  ];

  late Map<String, String> _gununIsmi;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _gununIsmi = _getGununIsmi();
    _lastDate = DateTime.now();
    _scheduleMidnightRefresh();
    _temaService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _controller.dispose();
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _gununIsmi = _getGununIsmi();
        _lastDate = DateTime.now();
      });
      _scheduleMidnightRefresh();
    });
  }

  Map<String, String> _getGununIsmi() {
    final now = DateTime.now();
    // Yılın gününe göre isim seç (her gün farklı)
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % _esmaulHusna.length;
    return _esmaulHusna[index];
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final now = DateTime.now();
    if (_lastDate == null ||
        now.year != _lastDate!.year ||
        now.month != _lastDate!.month ||
        now.day != _lastDate!.day) {
      _gununIsmi = _getGununIsmi();
      _lastDate = now;
    }
    
    return GestureDetector(
      onTap: _toggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
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
            color: renkler.vurgu.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: renkler.vurgu.withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Ana içerik
            Row(
              children: [
                // Sol - Arapça isim
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        renkler.vurgu.withValues(alpha: 0.2),
                        renkler.vurgu.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: renkler.vurgu.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _gununIsmi['arapca'] ?? '',
                      style: TextStyle(
                        color: renkler.vurgu,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Arial',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Sağ - Türkçe isim ve başlık
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GÜNÜN ESMÂSI',
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _gununIsmi['turkce'] ?? '',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: renkler.vurgu,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpanded ? 'Gizle' : 'Anlamını gör',
                            style: TextStyle(
                              color: renkler.vurgu,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Genişleyen anlam bölümü
            SizeTransition(
              sizeFactor: _animation,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: renkler.vurgu.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: renkler.vurgu.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: renkler.vurgu,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ANLAMI',
                              style: TextStyle(
                                color: renkler.vurgu,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _gununIsmi['anlam'] ?? '',
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
