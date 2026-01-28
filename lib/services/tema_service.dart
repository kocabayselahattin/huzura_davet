import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Sayaç bazlı tema tanımları
enum SayacTema {
  dijital,
  premium,
  galaksi,
  neon,
  okyanus,
  minimal,
  retro,
  aurora,
  kristal,
  volkanik,
  zen,
  siber,
  gece,
  matrix,
  nefes,
  geometrik,
  tesla,
  islami,
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
  String _fontFamily = 'Poppins';
  bool _sayacTemasiKullan = true; // Sayaç temasını kullan
  int _aktifSayacIndex = 0;

  static const List<String> fontFamilies = [
    'Poppins',
    'Inter',
    'Lato',
    'Nunito',
    'Roboto',
    'Montserrat',
    'Rubik',
    'Manrope',
    'Ubuntu',
    'Oswald',
    'Merriweather',
    'Playfair Display',
    'Open Sans',
    'Raleway',
    'Quicksand',
    'Work Sans',
  ];
  
  AppTema get mevcutTema => _mevcutTema;
  String get fontFamily => _fontFamily;
  bool get sayacTemasiKullan => _sayacTemasiKullan;
  int get aktifSayacIndex => _aktifSayacIndex;

  /// Sayaç bazlı tema renkleri (Yeni sıra: İslami temalar önce)
  static const Map<int, TemaRenkleri> sayacTemalari = {
    // 0: İslami - Yeşil ve Altın
    0: TemaRenkleri(
      arkaPlan: Color(0xFF0D2818),
      kartArkaPlan: Color(0xFF1A3D28),
      vurgu: Color(0xFFD4AF37),
      vurguSecondary: Color(0xFF00BFA5),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFA5D6A7),
      ayirac: Color(0xFF2E5238),
      isim: 'İslami',
      aciklama: 'İslami yeşil ve altın',
      ikon: Icons.mosque,
    ),
    // 1: Kalem - Koyu Yeşil tonları
    1: TemaRenkleri(
      arkaPlan: Color(0xFF1B4332),
      kartArkaPlan: Color(0xFF2D6A4F),
      vurgu: Color(0xFF40916C),
      vurguSecondary: Color(0xFF52B788),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB7E4C7),
      ayirac: Color(0xFF40916C),
      isim: 'Kalem',
      aciklama: 'İlim ve bereket yeşili',
      ikon: Icons.edit,
    ),
    // 2: Nur - Mavi tonları
    2: TemaRenkleri(
      arkaPlan: Color(0xFF1A237E),
      kartArkaPlan: Color(0xFF283593),
      vurgu: Color(0xFF3949AB),
      vurguSecondary: Color(0xFF5C6BC0),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFC5CAE9),
      ayirac: Color(0xFF3949AB),
      isim: 'Nur',
      aciklama: 'Işık temalı mavi',
      ikon: Icons.wb_sunny,
    ),
    // 3: Hilal - Gece mavisi
    3: TemaRenkleri(
      arkaPlan: Color(0xFF0D1B2A),
      kartArkaPlan: Color(0xFF1B263B),
      vurgu: Color(0xFF415A77),
      vurguSecondary: Color(0xFF778DA9),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFE0E1DD),
      ayirac: Color(0xFF415A77),
      isim: 'Hilal',
      aciklama: 'Yıldızlı gece',
      ikon: Icons.nights_stay,
    ),
    // 4: Mihrap - Kahverengi tonları
    4: TemaRenkleri(
      arkaPlan: Color(0xFF2C1810),
      kartArkaPlan: Color(0xFF5D4037),
      vurgu: Color(0xFF8D6E63),
      vurguSecondary: Color(0xFFA1887F),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFD7CCC8),
      ayirac: Color(0xFF6D4C41),
      isim: 'Mihrap',
      aciklama: 'Ahşap ve cami mimarisi',
      ikon: Icons.architecture,
    ),
    // 5: Dijital - Cyan tonları
    5: TemaRenkleri(
      arkaPlan: Color(0xFF1B2741),
      kartArkaPlan: Color(0xFF2B3151),
      vurgu: Color(0xFF00BCD4),
      vurguSecondary: Color(0xFF26C6DA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF3D4466),
      isim: 'Dijital',
      aciklama: 'Cyan dijital tonları',
      ikon: Icons.access_time,
    ),
    // 6: Premium - Altın tonları
    6: TemaRenkleri(
      arkaPlan: Color(0xFF1A1A1A),
      kartArkaPlan: Color(0xFF242424),
      vurgu: Color(0xFFFFD700),
      vurguSecondary: Color(0xFFDAA520),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFC0C0C0),
      ayirac: Color(0xFF3A3A3A),
      isim: 'Premium',
      aciklama: 'Lüks altın tonları',
      ikon: Icons.star,
    ),
    // 7: Galaksi - Mor tonları
    7: TemaRenkleri(
      arkaPlan: Color(0xFF0F0326),
      kartArkaPlan: Color(0xFF1A0B2E),
      vurgu: Color(0xFF9D4EDD),
      vurguSecondary: Color(0xFF7B2CBF),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB8B8FF),
      ayirac: Color(0xFF2D1450),
      isim: 'Galaksi',
      aciklama: 'Uzay mor tonları',
      ikon: Icons.blur_circular,
    ),
    // 8: Neon - Elektrik pembe
    8: TemaRenkleri(
      arkaPlan: Color(0xFF0D0D0D),
      kartArkaPlan: Color(0xFF1A1A1A),
      vurgu: Color(0xFFFF006E),
      vurguSecondary: Color(0xFFFF69B4),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFFFB3D9),
      ayirac: Color(0xFF2D0D1F),
      isim: 'Neon',
      aciklama: 'Canlı neon tonları',
      ikon: Icons.flashlight_on,
    ),
    // 9: Okyanus - Mavi derinlik
    9: TemaRenkleri(
      arkaPlan: Color(0xFF0B3954),
      kartArkaPlan: Color(0xFF154360),
      vurgu: Color(0xFF5DADE2),
      vurguSecondary: Color(0xFF3498DB),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFAED6F1),
      ayirac: Color(0xFF1A5276),
      isim: 'Okyanus',
      aciklama: 'Derin mavi tonları',
      ikon: Icons.water,
    ),
    // 10: Minimal - Beyaz tonları
    10: TemaRenkleri(
      arkaPlan: Color(0xFFF5F5F5),
      kartArkaPlan: Color(0xFFFFFFFF),
      vurgu: Color(0xFF424242),
      vurguSecondary: Color(0xFF757575),
      yaziPrimary: Color(0xFF212121),
      yaziSecondary: Color(0xFF757575),
      ayirac: Color(0xFFE0E0E0),
      isim: 'Minimal',
      aciklama: 'Sade beyaz tonları',
      ikon: Icons.crop_square,
    ),
    // 11: Retro - LCD yeşil
    11: TemaRenkleri(
      arkaPlan: Color(0xFF0D1F0D),
      kartArkaPlan: Color(0xFF142414),
      vurgu: Color(0xFF00FF41),
      vurguSecondary: Color(0xFF33FF66),
      yaziPrimary: Color(0xFF00FF41),
      yaziSecondary: Color(0xFF00CC33),
      ayirac: Color(0xFF1A2E1A),
      isim: 'Retro',
      aciklama: 'Nostaljik LCD yeşili',
      ikon: Icons.tv,
    ),
    // 12: Aurora - Kuzey ışıkları
    12: TemaRenkleri(
      arkaPlan: Color(0xFF0A0A1A),
      kartArkaPlan: Color(0xFF0D1B2A),
      vurgu: Color(0xFF00D4AA),
      vurguSecondary: Color(0xFF8B5CF6),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFF9CA3AF),
      ayirac: Color(0xFF1B263B),
      isim: 'Aurora',
      aciklama: 'Kuzey ışıkları tonları',
      ikon: Icons.nights_stay,
    ),
    // 13: Kristal - Cam efekti
    13: TemaRenkleri(
      arkaPlan: Color(0xFFE8EDF2),
      kartArkaPlan: Color(0xFFF5F7FA),
      vurgu: Color(0xFF5C6BC0),
      vurguSecondary: Color(0xFF64B5F6),
      yaziPrimary: Color(0xFF3D4F6F),
      yaziSecondary: Color(0xFF6B7D9A),
      ayirac: Color(0xFFDAE2EB),
      isim: 'Kristal',
      aciklama: 'Cam kristal tonları',
      ikon: Icons.diamond_outlined,
    ),
    // 14: Volkanik - Ateş tonları
    14: TemaRenkleri(
      arkaPlan: Color(0xFF1A0A00),
      kartArkaPlan: Color(0xFF2D1810),
      vurgu: Color(0xFFFF6B35),
      vurguSecondary: Color(0xFFFF0844),
      yaziPrimary: Color(0xFFFFAA00),
      yaziSecondary: Color(0xFFFF8C00),
      ayirac: Color(0xFF3D1F15),
      isim: 'Volkanik',
      aciklama: 'Ateş ve lav tonları',
      ikon: Icons.local_fire_department,
    ),
    // 15: Zen - Doğa tonları
    15: TemaRenkleri(
      arkaPlan: Color(0xFFE8E4D9),
      kartArkaPlan: Color(0xFFF5F5DC),
      vurgu: Color(0xFF4A6741),
      vurguSecondary: Color(0xFF6B8E5F),
      yaziPrimary: Color(0xFF2D3A29),
      yaziSecondary: Color(0xFF5C6B54),
      ayirac: Color(0xFFD4CFC4),
      isim: 'Zen',
      aciklama: 'Huzurlu doğa tonları',
      ikon: Icons.spa,
    ),
    // 16: Siber - Cyberpunk
    16: TemaRenkleri(
      arkaPlan: Color(0xFF0D0221),
      kartArkaPlan: Color(0xFF1A0533),
      vurgu: Color(0xFFFF00FF),
      vurguSecondary: Color(0xFF00FFFF),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB388FF),
      ayirac: Color(0xFF2D0845),
      isim: 'Siber',
      aciklama: 'Cyberpunk neon tonları',
      ikon: Icons.memory,
    ),
    // 17: Gece - Ay ışığı
    17: TemaRenkleri(
      arkaPlan: Color(0xFF0A1628),
      kartArkaPlan: Color(0xFF1E3A5F),
      vurgu: Color(0xFFFFF8DC),
      vurguSecondary: Color(0xFFFFE4B5),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF2D4A6F),
      isim: 'Gece',
      aciklama: 'Ay ışığı tonları',
      ikon: Icons.nightlight_round,
    ),
    // 18: Matrix - Hacker yeşil
    18: TemaRenkleri(
      arkaPlan: Color(0xFF000000),
      kartArkaPlan: Color(0xFF0A0A0A),
      vurgu: Color(0xFF00FF00),
      vurguSecondary: Color(0xFF00CC00),
      yaziPrimary: Color(0xFF00FF00),
      yaziSecondary: Color(0xFF009900),
      ayirac: Color(0xFF003300),
      isim: 'Matrix',
      aciklama: 'Hacker yeşil tonları',
      ikon: Icons.code,
    ),
    // 19: Nefes - Meditasyon mavisi
    19: TemaRenkleri(
      arkaPlan: Color(0xFF0A1628),
      kartArkaPlan: Color(0xFF142238),
      vurgu: Color(0xFF7EC8E3),
      vurguSecondary: Color(0xFF4A90B8),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0C4DE),
      ayirac: Color(0xFF1E3A5F),
      isim: 'Nefes',
      aciklama: 'Huzurlu meditasyon tonları',
      ikon: Icons.air,
    ),
    // 20: Geometrik - Sacred Geometry
    20: TemaRenkleri(
      arkaPlan: Color(0xFF1A0A2E),
      kartArkaPlan: Color(0xFF2D1B4E),
      vurgu: Color(0xFFD4AF37),
      vurguSecondary: Color(0xFFFFD700),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFDDA0DD),
      ayirac: Color(0xFF3D2B5E),
      isim: 'Geometrik',
      aciklama: 'Kutsal geometri tonları',
      ikon: Icons.hexagon_outlined,
    ),
    // 21: Tesla - Elektrik mavisi
    21: TemaRenkleri(
      arkaPlan: Color(0xFF030318),
      kartArkaPlan: Color(0xFF0A0A28),
      vurgu: Color(0xFF00BFFF),
      vurguSecondary: Color(0xFF00FFFF),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFF87CEEB),
      ayirac: Color(0xFF141438),
      isim: 'Tesla',
      aciklama: 'Elektrik enerji tonları',
      ikon: Icons.bolt,
    ),
  };

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
    // Sayaç teması kullanılıyorsa
    if (_sayacTemasiKullan && sayacTemalari.containsKey(_aktifSayacIndex)) {
      return sayacTemalari[_aktifSayacIndex]!;
    }
    // Manuel tema seçimi
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
    _fontFamily = prefs.getString('font_family') ?? _fontFamily;
    _sayacTemasiKullan = prefs.getBool('sayac_temasi_kullan') ?? true;
    _aktifSayacIndex = prefs.getInt('secili_sayac_index') ?? 0;
    await _ozelTemayiYukle();
    notifyListeners();
  }

  Future<void> _ozelTemayiYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final arkaPlan = prefs.getInt('ozel_tema_arkaPlan');
    final kartArkaPlan = prefs.getInt('ozel_tema_kartArkaPlan');
    final vurgu = prefs.getInt('ozel_tema_vurgu');
    final vurguSecondary = prefs.getInt('ozel_tema_vurguSecondary');
    final yaziPrimary = prefs.getInt('ozel_tema_yaziPrimary');
    final yaziSecondary = prefs.getInt('ozel_tema_yaziSecondary');
    
    if (arkaPlan != null && vurgu != null) {
      _ozelTema = TemaRenkleri(
        arkaPlan: Color(arkaPlan),
        kartArkaPlan: Color(kartArkaPlan ?? arkaPlan),
        vurgu: Color(vurgu),
        vurguSecondary: Color(vurguSecondary ?? vurgu),
        yaziPrimary: Color(yaziPrimary ?? Colors.white.value),
        yaziSecondary: Color(yaziSecondary ?? const Color(0xFFB0BEC5).value),
        ayirac: Color(kartArkaPlan ?? arkaPlan).withOpacity(0.5),
        isim: 'Özel Tema',
        aciklama: 'Sizin seçtiğiniz renkler',
        ikon: Icons.palette,
      );
    }
  }

  Future<void> fontuDegistir(String yeniFont) async {
    _fontFamily = yeniFont;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family', yeniFont);
    notifyListeners();
  }

  Future<void> temayiDegistir(AppTema yeniTema) async {
    _mevcutTema = yeniTema;
    _sayacTemasiKullan = false; // Manuel tema seçildi
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tema_index', yeniTema.index);
    await prefs.setBool('sayac_temasi_kullan', false);
    notifyListeners();
  }

  /// Sayaç değiştiğinde temayı güncelle
  Future<void> sayacTemasiGuncelle(int sayacIndex) async {
    _aktifSayacIndex = sayacIndex;
    _sayacTemasiKullan = true; // Sayaç değiştirildiğinde tema sayaca göre güncellenmeli
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secili_sayac_index', sayacIndex);
    await prefs.setBool('sayac_temasi_kullan', true);
    notifyListeners();
  }

  /// Sayaç teması modunu aç/kapat
  Future<void> sayacTemasiKullanAyarla(bool kullan) async {
    _sayacTemasiKullan = kullan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sayac_temasi_kullan', kullan);
    notifyListeners();
  }

  Future<void> ozelTemayiKaydet({
    required Color arkaPlan,
    required Color kartArkaPlan,
    required Color vurgu,
    required Color vurguSecondary,
    required Color yaziPrimary,
    required Color yaziSecondary,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ozel_tema_arkaPlan', arkaPlan.value);
    await prefs.setInt('ozel_tema_kartArkaPlan', kartArkaPlan.value);
    await prefs.setInt('ozel_tema_vurgu', vurgu.value);
    await prefs.setInt('ozel_tema_vurguSecondary', vurguSecondary.value);
    await prefs.setInt('ozel_tema_yaziPrimary', yaziPrimary.value);
    await prefs.setInt('ozel_tema_yaziSecondary', yaziSecondary.value);
    
    _ozelTema = TemaRenkleri(
      arkaPlan: arkaPlan,
      kartArkaPlan: kartArkaPlan,
      vurgu: vurgu,
      vurguSecondary: vurguSecondary,
      yaziPrimary: yaziPrimary,
      yaziSecondary: yaziSecondary,
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
    // Klasik Tonlar
    {'isim': 'Gece Mavisi', 'arkaPlan': Color(0xFF1B2741), 'vurgu': Color(0xFF00BCD4)},
    {'isim': 'Orman Yeşili', 'arkaPlan': Color(0xFF1B3D2F), 'vurgu': Color(0xFF4CAF50)},
    {'isim': 'Bordo', 'arkaPlan': Color(0xFF3E1A1A), 'vurgu': Color(0xFFE53935)},
    {'isim': 'Mor Rüya', 'arkaPlan': Color(0xFF2E1F47), 'vurgu': Color(0xFF9C27B0)},
    {'isim': 'Turkuaz', 'arkaPlan': Color(0xFF0D3B3E), 'vurgu': Color(0xFF00BCD4)},
    {'isim': 'Karamel', 'arkaPlan': Color(0xFF3E2723), 'vurgu': Color(0xFFFF9800)},
    {'isim': 'Gül Kurusu', 'arkaPlan': Color(0xFF3D2429), 'vurgu': Color(0xFFE91E63)},
    {'isim': 'Zeytin', 'arkaPlan': Color(0xFF2E3D1B), 'vurgu': Color(0xFF8BC34A)},
    
    // Lüks & Elegant
    {'isim': 'Altın Siyah', 'arkaPlan': Color(0xFF0D0D0D), 'vurgu': Color(0xFFFFD700)},
    {'isim': 'Rose Gold', 'arkaPlan': Color(0xFF1A1215), 'vurgu': Color(0xFFB76E79)},
    {'isim': 'Platin', 'arkaPlan': Color(0xFF1C1C1E), 'vurgu': Color(0xFFE5E4E2)},
    {'isim': 'Bronz', 'arkaPlan': Color(0xFF1F1710), 'vurgu': Color(0xFFCD7F32)},
    
    // Doğa Tonları
    {'isim': 'Okyanus', 'arkaPlan': Color(0xFF0A192F), 'vurgu': Color(0xFF64FFDA)},
    {'isim': 'Orman Gece', 'arkaPlan': Color(0xFF0D1F0D), 'vurgu': Color(0xFF00E676)},
    {'isim': 'Çöl Gece', 'arkaPlan': Color(0xFF2D1F14), 'vurgu': Color(0xFFFFAB40)},
    {'isim': 'Gün Batımı', 'arkaPlan': Color(0xFF2D1B2D), 'vurgu': Color(0xFFFF6B6B)},
    
    // Neon & Cyberpunk
    {'isim': 'Neon Pembe', 'arkaPlan': Color(0xFF0F0A1A), 'vurgu': Color(0xFFFF00FF)},
    {'isim': 'Neon Mavi', 'arkaPlan': Color(0xFF0A0A14), 'vurgu': Color(0xFF00FFFF)},
    {'isim': 'Neon Yeşil', 'arkaPlan': Color(0xFF0A140A), 'vurgu': Color(0xFF00FF41)},
    {'isim': 'Elektrik Mor', 'arkaPlan': Color(0xFF14081F), 'vurgu': Color(0xFF9D00FF)},
    
    // Pastel & Soft
    {'isim': 'Lavanta', 'arkaPlan': Color(0xFF1E1A26), 'vurgu': Color(0xFFB39DDB)},
    {'isim': 'Mint', 'arkaPlan': Color(0xFF142021), 'vurgu': Color(0xFF80CBC4)},
    {'isim': 'Şeftali', 'arkaPlan': Color(0xFF211A17), 'vurgu': Color(0xFFFFAB91)},
    {'isim': 'Buz Mavisi', 'arkaPlan': Color(0xFF141B21), 'vurgu': Color(0xFF81D4FA)},
    
    // Premium & Özel
    {'isim': 'Galaksi', 'arkaPlan': Color(0xFF0B0B1A), 'vurgu': Color(0xFF7C4DFF)},
    {'isim': 'Aurora', 'arkaPlan': Color(0xFF0D1418), 'vurgu': Color(0xFF00E5FF)},
    {'isim': 'Nar Çiçeği', 'arkaPlan': Color(0xFF1A0A0F), 'vurgu': Color(0xFFFF4081)},
    {'isim': 'Safir', 'arkaPlan': Color(0xFF0A1628), 'vurgu': Color(0xFF448AFF)},
    {'isim': 'Kehribar', 'arkaPlan': Color(0xFF1A1408), 'vurgu': Color(0xFFFFB300)},
    {'isim': 'Yakut', 'arkaPlan': Color(0xFF1A080A), 'vurgu': Color(0xFFFF1744)},
    {'isim': 'Zümrüt', 'arkaPlan': Color(0xFF081A12), 'vurgu': Color(0xFF00E676)},
    {'isim': 'Ametist', 'arkaPlan': Color(0xFF150A1F), 'vurgu': Color(0xFFAA00FF)},
  ];

  ThemeData buildThemeData() {
    final r = renkler;
    // Font yüklerken try-catch kullan - bazı fontlar yüklenemeyebilir
    TextTheme fontTextTheme;
    try {
      fontTextTheme = GoogleFonts.getTextTheme(_fontFamily);
    } catch (e) {
      print('⚠️ Font yüklenemedi ($_fontFamily), varsayılan font kullanılıyor: $e');
      fontTextTheme = GoogleFonts.poppinsTextTheme();
      _fontFamily = 'Poppins';
    }
    final textTheme = fontTextTheme.copyWith(
      bodyLarge: fontTextTheme.bodyLarge?.copyWith(color: r.yaziPrimary),
      bodyMedium: fontTextTheme.bodyMedium?.copyWith(color: r.yaziPrimary),
      bodySmall: fontTextTheme.bodySmall?.copyWith(color: r.yaziSecondary),
      titleLarge: fontTextTheme.titleLarge?.copyWith(color: r.yaziPrimary),
      titleMedium: fontTextTheme.titleMedium?.copyWith(color: r.yaziPrimary),
      titleSmall: fontTextTheme.titleSmall?.copyWith(color: r.yaziSecondary),
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: r.arkaPlan,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: r.yaziPrimary,
          fontSize: 20,
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
      textTheme: textTheme,
      iconTheme: IconThemeData(color: r.vurgu),
      dividerColor: r.ayirac,
      cardColor: r.kartArkaPlan,
    );
  }
}
