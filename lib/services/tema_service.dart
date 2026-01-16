import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTema {
  gece,         // Varsayılan koyu mavi
  seher,        // Mor-pembe tonları (sahur vakti)
  tan,          // Turuncu-sarı tonları (güneş doğuşu)
  ogle,         // Açık mavi tonları (gündüz)
  aksam,        // Kırmızı-turuncu tonları (gün batımı)
  yildizli,     // Derin siyah + yıldız efekti
  zumrut,       // Yeşil tonları (huzur)
  okyanus,      // Derin mavi-yeşil
  lavanta,      // Yumuşak mor tonları
  altin,        // Altın sarısı lüks tema
  karbon,       // Siyah-gri minimalist
  sakura,       // Pembe-beyaz (bahar)
  ozel,         // Kullanıcının özel teması
}

class TemaRenkleri {
  final Color arkaPlan;
  final Color kartArkaPlan;
  final Color vurgu;
  final Color vurguSecondary;
  final Color yaziPrimary;
  final Color yaziSecondary;
  final Color ayirac;
  final Gradient? arkaPlanGradient;
  final String isim;
  final String aciklama;
  final IconData ikon;
  final List<Color>? dekoratifRenkler;

  const TemaRenkleri({
    required this.arkaPlan,
    required this.kartArkaPlan,
    required this.vurgu,
    required this.vurguSecondary,
    required this.yaziPrimary,
    required this.yaziSecondary,
    required this.ayirac,
    this.arkaPlanGradient,
    required this.isim,
    required this.aciklama,
    required this.ikon,
    this.dekoratifRenkler,
  });

  TemaRenkleri copyWith({
    Color? arkaPlan,
    Color? kartArkaPlan,
    Color? vurgu,
    Color? vurguSecondary,
    Color? yaziPrimary,
    Color? yaziSecondary,
    Color? ayirac,
    Gradient? arkaPlanGradient,
    String? isim,
    String? aciklama,
    IconData? ikon,
    List<Color>? dekoratifRenkler,
  }) {
    return TemaRenkleri(
      arkaPlan: arkaPlan ?? this.arkaPlan,
      kartArkaPlan: kartArkaPlan ?? this.kartArkaPlan,
      vurgu: vurgu ?? this.vurgu,
      vurguSecondary: vurguSecondary ?? this.vurguSecondary,
      yaziPrimary: yaziPrimary ?? this.yaziPrimary,
      yaziSecondary: yaziSecondary ?? this.yaziSecondary,
      ayirac: ayirac ?? this.ayirac,
      arkaPlanGradient: arkaPlanGradient ?? this.arkaPlanGradient,
      isim: isim ?? this.isim,
      aciklama: aciklama ?? this.aciklama,
      ikon: ikon ?? this.ikon,
      dekoratifRenkler: dekoratifRenkler ?? this.dekoratifRenkler,
    );
  }
}

class TemaService extends ChangeNotifier {
  static final TemaService _instance = TemaService._internal();
  factory TemaService() => _instance;
  TemaService._internal();

  AppTema _mevcutTema = AppTema.gece;
  TemaRenkleri? _ozelTema;
  
  AppTema get mevcutTema => _mevcutTema;

  static const Map<AppTema, TemaRenkleri> temalar = {
    // 1. Gece - Varsayılan
    AppTema.gece: TemaRenkleri(
      arkaPlan: Color(0xFF1B2741),
      kartArkaPlan: Color(0xFF2B3151),
      vurgu: Color(0xFF00BCD4),
      vurguSecondary: Color(0xFF26C6DA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF3D4466),
      isim: 'Gece',
      aciklama: 'Huzurlu gece mavisi',
      ikon: Icons.nights_stay,
      dekoratifRenkler: [Color(0xFF00838F), Color(0xFF006064), Color(0xFF004D40)],
    ),
    
    // 2. Seher - Sahur vakti
    AppTema.seher: TemaRenkleri(
      arkaPlan: Color(0xFF2D1B4E),
      kartArkaPlan: Color(0xFF3D2B5E),
      vurgu: Color(0xFFE040FB),
      vurguSecondary: Color(0xFFFF80AB),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFCE93D8),
      ayirac: Color(0xFF4A3A6A),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2D1B4E), Color(0xFF1A0F2E)],
      ),
      isim: 'Seher',
      aciklama: 'Sahur vakti huzuru',
      ikon: Icons.brightness_3,
      dekoratifRenkler: [Color(0xFF9C27B0), Color(0xFF7B1FA2), Color(0xFF4A148C)],
    ),
    
    // 3. Tan - Güneş doğuşu
    AppTema.tan: TemaRenkleri(
      arkaPlan: Color(0xFF3E2723),
      kartArkaPlan: Color(0xFF4E3A31),
      vurgu: Color(0xFFFFAB40),
      vurguSecondary: Color(0xFFFFD54F),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFFFCC80),
      ayirac: Color(0xFF5D4037),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
      ),
      isim: 'Tan',
      aciklama: 'Güneş doğuşu sıcaklığı',
      ikon: Icons.wb_sunny,
      dekoratifRenkler: [Color(0xFFFF6F00), Color(0xFFE65100), Color(0xFFBF360C)],
    ),
    
    // 4. Öğle - Gündüz
    AppTema.ogle: TemaRenkleri(
      arkaPlan: Color(0xFF1565C0),
      kartArkaPlan: Color(0xFF1976D2),
      vurgu: Color(0xFF64FFDA),
      vurguSecondary: Color(0xFF80DEEA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB3E5FC),
      ayirac: Color(0xFF1E88E5),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
      ),
      isim: 'Öğle',
      aciklama: 'Berrak gökyüzü',
      ikon: Icons.light_mode,
      dekoratifRenkler: [Color(0xFF0097A7), Color(0xFF00838F), Color(0xFF006064)],
    ),
    
    // 5. Akşam - Gün batımı
    AppTema.aksam: TemaRenkleri(
      arkaPlan: Color(0xFF4A1C1C),
      kartArkaPlan: Color(0xFF5A2C2C),
      vurgu: Color(0xFFFF7043),
      vurguSecondary: Color(0xFFFFAB91),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFFFCCBC),
      ayirac: Color(0xFF6D3030),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6D3030), Color(0xFF4A1C1C), Color(0xFF2C1010)],
      ),
      isim: 'Akşam',
      aciklama: 'Gün batımı kızıllığı',
      ikon: Icons.wb_twilight,
      dekoratifRenkler: [Color(0xFFD84315), Color(0xFFBF360C), Color(0xFF8D1717)],
    ),
    
    // 6. Yıldızlı - Gece gökyüzü
    AppTema.yildizli: TemaRenkleri(
      arkaPlan: Color(0xFF0D0D1A),
      kartArkaPlan: Color(0xFF1A1A2E),
      vurgu: Color(0xFFB388FF),
      vurguSecondary: Color(0xFFEA80FC),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFF9E9E9E),
      ayirac: Color(0xFF252540),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16162D), Color(0xFF0D0D1A)],
      ),
      isim: 'Yıldızlı',
      aciklama: 'Derin gece gökyüzü',
      ikon: Icons.star,
      dekoratifRenkler: [Color(0xFF7C4DFF), Color(0xFF651FFF), Color(0xFF6200EA)],
    ),
    
    // 7. Zümrüt - Huzur ve doğa
    AppTema.zumrut: TemaRenkleri(
      arkaPlan: Color(0xFF1B3D2F),
      kartArkaPlan: Color(0xFF264D3B),
      vurgu: Color(0xFF69F0AE),
      vurguSecondary: Color(0xFFA5D6A7),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFC8E6C9),
      ayirac: Color(0xFF2E7D32),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B5E20), Color(0xFF1B3D2F)],
      ),
      isim: 'Zümrüt',
      aciklama: 'Cennet bahçesi huzuru',
      ikon: Icons.eco,
      dekoratifRenkler: [Color(0xFF00E676), Color(0xFF00C853), Color(0xFF1B5E20)],
    ),
    
    // 8. Okyanus - Derin deniz
    AppTema.okyanus: TemaRenkleri(
      arkaPlan: Color(0xFF0D2137),
      kartArkaPlan: Color(0xFF163354),
      vurgu: Color(0xFF4DD0E1),
      vurguSecondary: Color(0xFF80DEEA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB2EBF2),
      ayirac: Color(0xFF1A5276),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A5276), Color(0xFF0D2137), Color(0xFF051420)],
      ),
      isim: 'Okyanus',
      aciklama: 'Derin deniz mavisi',
      ikon: Icons.water,
      dekoratifRenkler: [Color(0xFF00ACC1), Color(0xFF0097A7), Color(0xFF00838F)],
    ),
    
    // 9. Lavanta - Yumuşak mor
    AppTema.lavanta: TemaRenkleri(
      arkaPlan: Color(0xFF2E2240),
      kartArkaPlan: Color(0xFF3D3055),
      vurgu: Color(0xFFCE93D8),
      vurguSecondary: Color(0xFFE1BEE7),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFD1C4E9),
      ayirac: Color(0xFF4A3F6B),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF4A3F6B), Color(0xFF2E2240)],
      ),
      isim: 'Lavanta',
      aciklama: 'Sakinleştirici lavanta',
      ikon: Icons.local_florist,
      dekoratifRenkler: [Color(0xFFAB47BC), Color(0xFF8E24AA), Color(0xFF6A1B9A)],
    ),
    
    // 10. Altın - Lüks görünüm
    AppTema.altin: TemaRenkleri(
      arkaPlan: Color(0xFF1A1A1A),
      kartArkaPlan: Color(0xFF2D2D2D),
      vurgu: Color(0xFFFFD700),
      vurguSecondary: Color(0xFFFFC107),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFE0E0E0),
      ayirac: Color(0xFF424242),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
      ),
      isim: 'Altın',
      aciklama: 'Zarif altın parıltısı',
      ikon: Icons.diamond,
      dekoratifRenkler: [Color(0xFFFFB300), Color(0xFFFFA000), Color(0xFFFF8F00)],
    ),
    
    // 11. Karbon - Minimalist siyah
    AppTema.karbon: TemaRenkleri(
      arkaPlan: Color(0xFF121212),
      kartArkaPlan: Color(0xFF1E1E1E),
      vurgu: Color(0xFF03DAC6),
      vurguSecondary: Color(0xFF018786),
      yaziPrimary: Color(0xFFE0E0E0),
      yaziSecondary: Color(0xFF9E9E9E),
      ayirac: Color(0xFF2C2C2C),
      isim: 'Karbon',
      aciklama: 'Modern minimalist',
      ikon: Icons.dark_mode,
      dekoratifRenkler: [Color(0xFF00BFA5), Color(0xFF00897B), Color(0xFF004D40)],
    ),
    
    // 12. Sakura - Bahar çiçeği
    AppTema.sakura: TemaRenkleri(
      arkaPlan: Color(0xFF2D2133),
      kartArkaPlan: Color(0xFF3D3143),
      vurgu: Color(0xFFFFB7C5),
      vurguSecondary: Color(0xFFF8BBD9),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFF8BBD9),
      ayirac: Color(0xFF4D4153),
      arkaPlanGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3D3143), Color(0xFF2D2133)],
      ),
      isim: 'Sakura',
      aciklama: 'Bahar çiçeği pembesi',
      ikon: Icons.spa,
      dekoratifRenkler: [Color(0xFFF48FB1), Color(0xFFEC407A), Color(0xFFD81B60)],
    ),
    
    // 13. Özel - Kullanıcı tanımlı
    AppTema.ozel: TemaRenkleri(
      arkaPlan: Color(0xFF1B2741),
      kartArkaPlan: Color(0xFF2B3151),
      vurgu: Color(0xFF00BCD4),
      vurguSecondary: Color(0xFF26C6DA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF3D4466),
      isim: 'Özel Tema',
      aciklama: 'Kendi renkleriniz',
      ikon: Icons.palette,
      dekoratifRenkler: [Color(0xFF00838F), Color(0xFF006064), Color(0xFF004D40)],
    ),
  };

  TemaRenkleri get renkler {
    if (_mevcutTema == AppTema.ozel && _ozelTema != null) {
      return _ozelTema!;
    }
    return temalar[_mevcutTema]!;
  }

  Future<void> temayiYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final temaIndex = prefs.getInt('tema_index') ?? 0;
    if (temaIndex < AppTema.values.length) {
      _mevcutTema = AppTema.values[temaIndex];
    }
    await _ozelTemayiYukle();
    notifyListeners();
  }

  Future<void> _ozelTemayiYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final arkaPlan = prefs.getInt('ozel_tema_arkaPlan');
    final kartArkaPlan = prefs.getInt('ozel_tema_kartArkaPlan');
    final vurgu = prefs.getInt('ozel_tema_vurgu');
    final vurguSecondary = prefs.getInt('ozel_tema_vurguSecondary');
    
    if (arkaPlan != null && vurgu != null) {
      _ozelTema = TemaRenkleri(
        arkaPlan: Color(arkaPlan),
        kartArkaPlan: Color(kartArkaPlan ?? arkaPlan),
        vurgu: Color(vurgu),
        vurguSecondary: Color(vurguSecondary ?? vurgu),
        yaziPrimary: Colors.white,
        yaziSecondary: const Color(0xFFB0BEC5),
        ayirac: Color(kartArkaPlan ?? arkaPlan).withOpacity(0.5),
        isim: 'Özel Tema',
        aciklama: 'Sizin seçtiğiniz renkler',
        ikon: Icons.palette,
      );
    }
  }

  Future<void> temayiDegistir(AppTema yeniTema) async {
    _mevcutTema = yeniTema;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tema_index', yeniTema.index);
    notifyListeners();
  }

  Future<void> ozelTemayiKaydet({
    required Color arkaPlan,
    required Color kartArkaPlan,
    required Color vurgu,
    required Color vurguSecondary,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ozel_tema_arkaPlan', arkaPlan.value);
    await prefs.setInt('ozel_tema_kartArkaPlan', kartArkaPlan.value);
    await prefs.setInt('ozel_tema_vurgu', vurgu.value);
    await prefs.setInt('ozel_tema_vurguSecondary', vurguSecondary.value);
    
    _ozelTema = TemaRenkleri(
      arkaPlan: arkaPlan,
      kartArkaPlan: kartArkaPlan,
      vurgu: vurgu,
      vurguSecondary: vurguSecondary,
      yaziPrimary: Colors.white,
      yaziSecondary: const Color(0xFFB0BEC5),
      ayirac: kartArkaPlan.withOpacity(0.5),
      isim: 'Özel Tema',
      aciklama: 'Sizin seçtiğiniz renkler',
      ikon: Icons.palette,
    );
    
    _mevcutTema = AppTema.ozel;
    await prefs.setInt('tema_index', AppTema.ozel.index);
    notifyListeners();
  }

  // Hazır renk paletleri
  static const List<Map<String, dynamic>> hazirPaletler = [
    {'isim': 'Gece Mavisi', 'arkaPlan': Color(0xFF1B2741), 'vurgu': Color(0xFF00BCD4)},
    {'isim': 'Orman Yeşili', 'arkaPlan': Color(0xFF1B3D2F), 'vurgu': Color(0xFF4CAF50)},
    {'isim': 'Bordo', 'arkaPlan': Color(0xFF3E1A1A), 'vurgu': Color(0xFFE53935)},
    {'isim': 'Mor Rüya', 'arkaPlan': Color(0xFF2E1F47), 'vurgu': Color(0xFF9C27B0)},
    {'isim': 'Turkuaz', 'arkaPlan': Color(0xFF0D3B3E), 'vurgu': Color(0xFF00BCD4)},
    {'isim': 'Karamel', 'arkaPlan': Color(0xFF3E2723), 'vurgu': Color(0xFFFF9800)},
    {'isim': 'Gül Kurusu', 'arkaPlan': Color(0xFF3D2429), 'vurgu': Color(0xFFE91E63)},
    {'isim': 'Zeytin', 'arkaPlan': Color(0xFF2E3D1B), 'vurgu': Color(0xFF8BC34A)},
  ];

  ThemeData buildThemeData() {
    final r = renkler;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: r.arkaPlan,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: r.yaziPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: r.yaziPrimary),
      ),
      colorScheme: ColorScheme.dark(
        primary: r.vurgu,
        secondary: r.vurguSecondary,
        surface: r.kartArkaPlan,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: r.yaziPrimary),
        bodyMedium: TextStyle(color: r.yaziPrimary),
        bodySmall: TextStyle(color: r.yaziSecondary),
      ),
      iconTheme: IconThemeData(color: r.vurgu),
      dividerColor: r.ayirac,
      cardColor: r.kartArkaPlan,
    );
  }
}
