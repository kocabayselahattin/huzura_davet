import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Cihazda yerel olarak gömülü tam Kur'an-ı Kerim verisini (Elmalılı Hamdi
/// Yazır meali) yönetir. İnternet gerektirmeden Kur'an sayfasını ve günün
/// ayeti içeriğini besler.
class KuranVeriService {
  static Map<String, dynamic>? _veri;
  static List<_FlatAyet>? _tumAyetlerSirali;

  /// Besmele-i şerif. Ayet gösterilen her yerde (günün ayeti kartı, paylaşım
  /// görseli, düz metin paylaşımı) metnin başına konur.
  static const String besmele = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  // Sure no (1-114) -> Türkçe sure adı.
  static const List<String> sureAdlari = [
    'Fatiha',
    'Bakara',
    'Âl-i İmrân',
    'Nisâ',
    'Mâide',
    "En'âm",
    "A'râf",
    'Enfâl',
    'Tevbe',
    'Yûnus',
    'Hûd',
    'Yûsuf',
    "Ra'd",
    'İbrâhîm',
    'Hicr',
    'Nahl',
    'İsrâ',
    'Kehf',
    'Meryem',
    'Tâhâ',
    'Enbiyâ',
    'Hac',
    "Mü'minûn",
    'Nûr',
    'Furkân',
    'Şuarâ',
    'Neml',
    'Kasas',
    'Ankebût',
    'Rûm',
    'Lokmân',
    'Secde',
    'Ahzâb',
    "Sebe'",
    'Fâtır',
    'Yâsîn',
    'Sâffât',
    'Sâd',
    'Zümer',
    "Mü'min",
    'Fussilet',
    'Şûrâ',
    'Zuhruf',
    'Duhân',
    'Câsiye',
    'Ahkâf',
    'Muhammed',
    'Fetih',
    'Hucurât',
    'Kâf',
    'Zâriyât',
    'Tûr',
    'Necm',
    'Kamer',
    'Rahmân',
    'Vâkıa',
    'Hadîd',
    'Mücâdele',
    'Haşr',
    'Mümtehine',
    'Saf',
    'Cuma',
    'Münâfikûn',
    'Teğâbün',
    'Talâk',
    'Tahrîm',
    'Mülk',
    'Kalem',
    'Hâkka',
    'Meâric',
    'Nûh',
    'Cin',
    'Müzzemmil',
    'Müddessir',
    'Kıyâme',
    'İnsân',
    'Mürselât',
    "Nebe'",
    'Nâziât',
    'Abese',
    'Tekvîr',
    'İnfitâr',
    'Mutaffifîn',
    'İnşikâk',
    'Bürûc',
    'Târık',
    "A'lâ",
    'Gâşiye',
    'Fecr',
    'Beled',
    'Şems',
    'Leyl',
    'Duhâ',
    'İnşirâh',
    'Tîn',
    'Alak',
    'Kadir',
    'Beyyine',
    'Zilzâl',
    'Âdiyât',
    'Kâria',
    'Tekâsür',
    'Asr',
    'Hümeze',
    'Fîl',
    'Kureyş',
    'Mâûn',
    'Kevser',
    'Kâfirûn',
    'Nasr',
    'Tebbet',
    'İhlâs',
    'Felak',
    'Nâs',
  ];

  static Future<void>? _yuklemeFuture;

  static bool get yuklendiMi => _veri != null;

  // Sure no (1-114) -> ayet sayısı. Sayfa/hatim planı gibi ayet-sayımına
  // dayalı hesaplamalar için; sureAdlari ile aynı sırada.
  static const List<int> ayetSayilari = [
    7,
    286,
    200,
    176,
    120,
    165,
    206,
    75,
    129,
    109,
    123,
    111,
    43,
    52,
    99,
    128,
    111,
    110,
    98,
    135,
    112,
    78,
    118,
    64,
    77,
    227,
    93,
    88,
    69,
    60,
    34,
    30,
    73,
    54,
    45,
    83,
    182,
    88,
    75,
    85,
    54,
    53,
    89,
    59,
    37,
    35,
    38,
    29,
    18,
    45,
    60,
    49,
    62,
    55,
    78,
    96,
    29,
    22,
    24,
    13,
    14,
    11,
    11,
    18,
    12,
    12,
    30,
    52,
    52,
    44,
    28,
    28,
    20,
    56,
    40,
    31,
    50,
    40,
    46,
    42,
    29,
    19,
    36,
    25,
    22,
    17,
    19,
    26,
    30,
    20,
    15,
    21,
    11,
    8,
    8,
    19,
    5,
    8,
    8,
    11,
    11,
    8,
    3,
    9,
    5,
    4,
    7,
    3,
    6,
    3,
    5,
    4,
    5,
    6,
  ];

  /// Kur'an'ın tamamındaki ayet sayısı.
  static const int toplamAyetSayisi = 6236;

  /// Standart 604 sayfalık Mushaf baskısındaki toplam sayfa sayısı.
  static const int toplamSayfaSayisi = 604;

  static List<int>? _sureAyetOfsetleri;

  /// offset[s] = s. sureden önceki toplam ayet sayısı (s: 1-114).
  static List<int> get _ofsetler {
    final mevcut = _sureAyetOfsetleri;
    if (mevcut != null) return mevcut;
    final offs = List<int>.filled(116, 0);
    for (int s = 1; s <= 114; s++) {
      offs[s + 1] = offs[s] + ayetSayilari[s - 1];
    }
    _sureAyetOfsetleri = offs;
    return offs;
  }

  /// Bir ayetin Kur'an'ın başından itibaren kaçıncı ayet olduğunu (1-6236)
  /// döndürür. Hatim planında ilerleme yüzdesi bununla hesaplanır.
  static int globalAyetNo(int sureNo, int ayetNo) => _ofsetler[sureNo] + ayetNo;

  // 604 sayfalık standart Mushaf baskısının her sayfasının başladığı
  // [sureNo, ayetNo] çifti. Kaynak: quran-center/quran-meta (MIT), Hafs
  // rivayeti, King Fahd Kompleksi standart sayfalaması.
  static List<List<int>>? _sayfaBaslangiclari;

  static bool get sayfaVerisiHazirMi => _sayfaBaslangiclari != null;

  /// Yerel Kur'an verisini bir kez yükler ve bellekte tutar.
  ///
  /// ~3 MB'lık JSON'un ayrıştırılması ayrı bir isolate'te (compute) yapılır;
  /// aksi halde açılışta arayüz donar ve uygulama beyaz ekranda bekler.
  /// Eşzamanlı çağrılar aynı yüklemeyi paylaşır, veri iki kez ayrıştırılmaz.
  static Future<void> yukle() {
    if (_veri != null) return Future.value();
    return _yuklemeFuture ??= _yukleVeAyristir();
  }

  static Future<void> _yukleVeAyristir() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/kuran_meal.json',
      );
      _veri = await compute(_jsonAyristir, jsonStr);

      final sayfaJsonStr = await rootBundle.loadString(
        'assets/data/mushaf_sayfalari.json',
      );
      _sayfaBaslangiclari = (json.decode(sayfaJsonStr) as List)
          .map<List<int>>(
            (e) => (e as List).map((x) => x as int).toList(growable: false),
          )
          .toList(growable: false);
    } catch (_) {
      // Yükleme başarısızsa çağıranlar yerel yedek içeriğe düşer.
      _yuklemeFuture = null;
    }
  }

  /// Verilen sayfa numarasının (1-604) başladığı [sureNo, ayetNo].
  static List<int> sayfaBaslangici(int sayfaNo) {
    final liste = _sayfaBaslangiclari;
    if (liste == null || liste.isEmpty) return const [1, 1];
    final index = sayfaNo.clamp(1, liste.length) - 1;
    return liste[index];
  }

  /// Verilen ayetin içinde bulunduğu Mushaf sayfa numarasını (1-604) döndürür.
  /// Sayfa verisi henüz yüklenmemişse 1 döner.
  static int sayfaNoForSureAyet(int sureNo, int ayetNo) {
    final liste = _sayfaBaslangiclari;
    if (liste == null || liste.isEmpty) return 1;

    final hedef = globalAyetNo(sureNo, ayetNo);
    // Binary search: başlangıcı hedefe eşit ya da öncesinde olan son sayfa.
    int lo = 0, hi = liste.length - 1, sonucIndex = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final baslangic = globalAyetNo(liste[mid][0], liste[mid][1]);
      if (baslangic <= hedef) {
        sonucIndex = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return sonucIndex + 1;
  }

  /// Verilen sayfa numarasının (1-604) bittiği [sureNo, ayetNo] (bir
  /// sonraki sayfanın başlangıcından bir önceki ayet). Son sayfa için
  /// Kur'an'ın son ayeti (Nâs, 6) döner.
  static List<int> sayfaBitisi(int sayfaNo) {
    if (sayfaNo >= toplamSayfaSayisi) return const [114, 6];
    final sonrakiBaslangic = sayfaBaslangici(sayfaNo + 1);
    return oncekiAyet(sonrakiBaslangic[0], sonrakiBaslangic[1]);
  }

  /// Verilen ayetten bir önceki ayet; sure başıysa bir önceki surenin son
  /// ayeti. Fatiha'nın ilk ayetinden öncesi olmadığından kendisi döner.
  static List<int> oncekiAyet(int sureNo, int ayetNo) {
    if (ayetNo > 1) return [sureNo, ayetNo - 1];
    if (sureNo > 1) return [sureNo - 1, ayetSayilari[sureNo - 2]];
    return const [1, 1];
  }

  /// compute() ile ayrı isolate'te çalışır; üst düzey/static olmak zorundadır.
  static Map<String, dynamic> _jsonAyristir(String jsonStr) =>
      json.decode(jsonStr) as Map<String, dynamic>;

  /// Belirtilen sureye ait ayetleri döndürür.
  /// Her öğe: {'no': int, 'arapca': String, 'okunus': String, 'meal': String}
  static List<Map<String, dynamic>> sureAyetleri(int sureNo) {
    final veri = _veri;
    if (veri == null) return [];
    final liste = veri[sureNo.toString()];
    if (liste is! List) return [];
    return liste.cast<Map<String, dynamic>>();
  }

  /// Günün ayeti havuzunu oluşturur. Tek başına gösterildiğinde anlamlı
  /// olmayacak kadar kısa mealler (ör. huruf-u mukattaa: "Elif, lâm, mîm.")
  /// havuza hiç alınmaz — böylece her gün farklı ve anlamlı bir ayet gelir.
  static void _siraliListeyiOlustur() {
    if (_tumAyetlerSirali != null) return;
    final veri = _veri;
    if (veri == null) {
      _tumAyetlerSirali = [];
      return;
    }
    final sonuc = <_FlatAyet>[];
    for (int sureNo = 1; sureNo <= 114; sureNo++) {
      final ayetler = veri[sureNo.toString()];
      if (ayetler is! List) continue;
      for (final a in ayetler) {
        if (a is Map) {
          final meal = a['meal']?.toString() ?? '';
          if (!_tekBasinaAnlamliMi(meal)) continue;
          sonuc.add(
            _FlatAyet(
              sureNo: sureNo,
              ayetNo: a['no'] is int
                  ? a['no'] as int
                  : int.tryParse(a['no']?.toString() ?? '') ?? 0,
              meal: meal,
              arapca: a['arapca']?.toString() ?? '',
            ),
          );
        }
      }
    }
    _tumAyetlerSirali = sonuc;
  }

  /// Tek başına gösterildiğinde anlamlı olmayacak kadar kısa mealler
  /// (ör. huruf-u mukattaa: "Elif, lâm, mîm.") için alt sınır.
  static const int _minMealUzunlugu = 60;

  /// Cümlenin bittiğini gösteren noktalama. Tırnak/parantez kapanışları
  /// noktadan sonra gelebildiği için onlara da izin verilir.
  static final RegExp _cumleSonuNoktalamasi = RegExp(r'''[.!?]["”»’')\s]*$''');

  /// Ayetin günün ayeti havuzuna girip giremeyeceğini belirler.
  ///
  /// Kur'an'daki bazı ayetler bir sonrakine bağlanır; tek başına
  /// gösterildiklerinde anlam bütünlüğü olmaz (ör. Bürûc 85:6 "Hani o ateşin
  /// başına oturmuşlar,"). Bunlar üç ölçütle elenir:
  ///
  /// 1. Çok kısa olanlar (huruf-u mukattaa gibi) havuza alınmaz.
  /// 2. Cümle sonu noktalaması olmadan biten mealler (virgül, iki nokta)
  ///    sonraki ayete bağlanır.
  /// 3. Küçük harfle başlayanlar önceki ayetin devamıdır.
  static bool _tekBasinaAnlamliMi(String meal) {
    final temiz = meal.trim();
    if (temiz.length < _minMealUzunlugu) return false;
    if (!_cumleSonuNoktalamasi.hasMatch(temiz)) return false;

    final ilkHarf = temiz[0];
    final kucugu = ilkHarf.toLowerCase();
    if (ilkHarf == kucugu && ilkHarf.toUpperCase() != ilkHarf) return false;

    return true;
  }

  /// Günün ayeti sayacının başlangıcı. Sıranın nereden başladığını belirleyen
  /// keyfi bir sabittir; değiştirilirse sıra tümüyle kayar.
  static final DateTime _ayetReferansTarihi = DateTime(2024, 1, 1);

  /// Günün ayetini, Kur'an'ın tamamına yayılmış tekrarsız bir sırayla döndürür.
  ///
  /// Ayetler mushaf sırasıyla değil karışık gelir; böylece her gün farklı bir
  /// sureden ayet çıkar. Buna rağmen sıra rastgele değildir: seçim yalnızca
  /// tarihe bağlıdır, dolayısıyla kart, bildirim ve ana ekran widget'ı hep aynı
  /// ayeti gösterir ve aynı gün her cihazda aynı ayet görünür.
  ///
  /// Çok kısa mealler (huruf-u mukattaa gibi) havuza hiç alınmaz.
  static Map<String, String> gununAyeti(DateTime tarih) {
    _siraliListeyiOlustur();
    final liste = _tumAyetlerSirali;
    if (liste == null || liste.isEmpty) return {'text': '', 'source': ''};

    final bugun = DateTime(tarih.year, tarih.month, tarih.day);
    final gunSayisi = bugun.difference(_ayetReferansTarihi).inDays;
    final index = _karisikIndex(gunSayisi, liste.length);
    final secilen = liste[index];

    final sureAdi = secilen.sureNo >= 1 && secilen.sureNo <= sureAdlari.length
        ? sureAdlari[secilen.sureNo - 1]
        : '';

    return {
      'text': secilen.meal,
      'source': '$sureAdi, ${secilen.ayetNo}',
      // Paylaşım kartı Arapça metni de basabilsin diye taşınır; metin
      // gösteren tüketiciler yalnızca 'text' ve 'source' okur.
      'arabic': secilen.arapca,
    };
  }

  /// Gün sayısını, havuzun tamamını tekrarsız dolaşan karışık bir sıraya çevirir.
  ///
  /// Her gün [_adim] kadar ileri atlanır. Adım, havuz uzunluğuyla aralarında
  /// asal seçildiği için bu atlayış tüm havuzu ziyaret etmeden başa dönmez:
  /// ayetler karışık gelir ama havuz bitmeden hiçbiri ikinci kez çıkmaz.
  static int _karisikIndex(int gunSayisi, int uzunluk) {
    if (uzunluk <= 1) return 0;

    var adim = 7919; // Havuz uzunluğuna göre ayarlanan büyük asal.
    while (_obeb(adim, uzunluk) != 1) {
      adim++;
    }

    // Referans tarihten önceki günlerde çarpım negatif olabilir.
    final ham = (gunSayisi * adim) % uzunluk;
    return (ham + uzunluk) % uzunluk;
  }

  /// En büyük ortak bölen (Öklid).
  static int _obeb(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final kalan = x % y;
      x = y;
      y = kalan;
    }
    return x;
  }
}

class _FlatAyet {
  final int sureNo;
  final int ayetNo;
  final String meal;
  final String arapca;

  _FlatAyet({
    required this.sureNo,
    required this.ayetNo,
    required this.meal,
    required this.arapca,
  });
}
