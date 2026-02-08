import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppTema {
  gece, // Default deep blue
  seher, // Purple-pink (predawn)
  tan, // Orange-yellow (sunrise)
  ogle, // Light blue (daytime)
  aksam, // Red-orange (sunset)
  yildizli, // Deep black + star effect
  zumrut, // Green tones (calm)
  okyanus, // Deep blue-green
  lavanta, // Soft purple tones
  altin, // Luxury gold theme
  karbon, // Black-gray minimalist
  sakura, // Pink-white (spring)
  ozel, // User custom theme
}

/// Counter-based theme definitions
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
  bool _sayacTemasiKullan = true; // Use counter theme
  int _aktifSayacIndex = 22; // Default: solstice counter

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

  /// Counter theme colors (new order: Islamic themes first)
  static const Map<int, TemaRenkleri> sayacTemalari = {
    // 0: Islamic - green and gold
    0: TemaRenkleri(
      arkaPlan: Color(0xFF0D2818),
      kartArkaPlan: Color(0xFF1A3D28),
      vurgu: Color(0xFFD4AF37),
      vurguSecondary: Color(0xFF00BFA5),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFA5D6A7),
      ayirac: Color(0xFF2E5238),
      isim: 'counter_theme_islamic_name',
      aciklama: 'counter_theme_islamic_desc',
      ikon: Icons.mosque,
    ),
    // 1: Pen - dark green tones
    1: TemaRenkleri(
      arkaPlan: Color(0xFF1B4332),
      kartArkaPlan: Color(0xFF2D6A4F),
      vurgu: Color(0xFF40916C),
      vurguSecondary: Color(0xFF52B788),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB7E4C7),
      ayirac: Color(0xFF40916C),
      isim: 'counter_theme_kalem_name',
      aciklama: 'counter_theme_kalem_desc',
      ikon: Icons.edit,
    ),
    // 2: Nur - blue tones
    2: TemaRenkleri(
      arkaPlan: Color(0xFF1A237E),
      kartArkaPlan: Color(0xFF283593),
      vurgu: Color(0xFF3949AB),
      vurguSecondary: Color(0xFF5C6BC0),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFC5CAE9),
      ayirac: Color(0xFF3949AB),
      isim: 'counter_theme_nur_name',
      aciklama: 'counter_theme_nur_desc',
      ikon: Icons.wb_sunny,
    ),
    // 3: Crescent - night blue
    3: TemaRenkleri(
      arkaPlan: Color(0xFF0D1B2A),
      kartArkaPlan: Color(0xFF1B263B),
      vurgu: Color(0xFF415A77),
      vurguSecondary: Color(0xFF778DA9),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFE0E1DD),
      ayirac: Color(0xFF415A77),
      isim: 'counter_theme_hilal_name',
      aciklama: 'counter_theme_hilal_desc',
      ikon: Icons.nights_stay,
    ),
    // 4: Mihrab - brown tones
    4: TemaRenkleri(
      arkaPlan: Color(0xFF2C1810),
      kartArkaPlan: Color(0xFF5D4037),
      vurgu: Color(0xFF8D6E63),
      vurguSecondary: Color(0xFFA1887F),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFD7CCC8),
      ayirac: Color(0xFF6D4C41),
      isim: 'counter_theme_mihrap_name',
      aciklama: 'counter_theme_mihrap_desc',
      ikon: Icons.architecture,
    ),
    // 5: Digital - cyan tones
    5: TemaRenkleri(
      arkaPlan: Color(0xFF1B2741),
      kartArkaPlan: Color(0xFF2B3151),
      vurgu: Color(0xFF00BCD4),
      vurguSecondary: Color(0xFF26C6DA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF3D4466),
      isim: 'counter_theme_digital_name',
      aciklama: 'counter_theme_digital_desc',
      ikon: Icons.access_time,
    ),
    // 6: Premium - gold tones
    6: TemaRenkleri(
      arkaPlan: Color(0xFF1A1A1A),
      kartArkaPlan: Color(0xFF242424),
      vurgu: Color(0xFFFFD700),
      vurguSecondary: Color(0xFFDAA520),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFC0C0C0),
      ayirac: Color(0xFF3A3A3A),
      isim: 'counter_theme_premium_name',
      aciklama: 'counter_theme_premium_desc',
      ikon: Icons.star,
    ),
    // 7: Galaxy - purple tones
    7: TemaRenkleri(
      arkaPlan: Color(0xFF0F0326),
      kartArkaPlan: Color(0xFF1A0B2E),
      vurgu: Color(0xFF9D4EDD),
      vurguSecondary: Color(0xFF7B2CBF),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB8B8FF),
      ayirac: Color(0xFF2D1450),
      isim: 'counter_theme_galaxy_name',
      aciklama: 'counter_theme_galaxy_desc',
      ikon: Icons.blur_circular,
    ),
    // 8: Neon - electric pink
    8: TemaRenkleri(
      arkaPlan: Color(0xFF0D0D0D),
      kartArkaPlan: Color(0xFF1A1A1A),
      vurgu: Color(0xFFFF006E),
      vurguSecondary: Color(0xFFFF69B4),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFFFB3D9),
      ayirac: Color(0xFF2D0D1F),
      isim: 'counter_theme_neon_name',
      aciklama: 'counter_theme_neon_desc',
      ikon: Icons.flashlight_on,
    ),
    // 9: Ocean - blue depth
    9: TemaRenkleri(
      arkaPlan: Color(0xFF0B3954),
      kartArkaPlan: Color(0xFF154360),
      vurgu: Color(0xFF5DADE2),
      vurguSecondary: Color(0xFF3498DB),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFAED6F1),
      ayirac: Color(0xFF1A5276),
      isim: 'counter_theme_ocean_name',
      aciklama: 'counter_theme_ocean_desc',
      ikon: Icons.water,
    ),
    // 10: Minimal - white tones
    10: TemaRenkleri(
      arkaPlan: Color(0xFFF5F5F5),
      kartArkaPlan: Color(0xFFFFFFFF),
      vurgu: Color(0xFF424242),
      vurguSecondary: Color(0xFF757575),
      yaziPrimary: Color(0xFF212121),
      yaziSecondary: Color(0xFF757575),
      ayirac: Color(0xFFE0E0E0),
      isim: 'counter_theme_minimal_name',
      aciklama: 'counter_theme_minimal_desc',
      ikon: Icons.crop_square,
    ),
    // 11: Retro - LCD green
    11: TemaRenkleri(
      arkaPlan: Color(0xFF0D1F0D),
      kartArkaPlan: Color(0xFF142414),
      vurgu: Color(0xFF00FF41),
      vurguSecondary: Color(0xFF33FF66),
      yaziPrimary: Color(0xFF00FF41),
      yaziSecondary: Color(0xFF00CC33),
      ayirac: Color(0xFF1A2E1A),
      isim: 'counter_theme_retro_name',
      aciklama: 'counter_theme_retro_desc',
      ikon: Icons.tv,
    ),
    // 12: Aurora - northern lights
    12: TemaRenkleri(
      arkaPlan: Color(0xFF0A0A1A),
      kartArkaPlan: Color(0xFF0D1B2A),
      vurgu: Color(0xFF00D4AA),
      vurguSecondary: Color(0xFF8B5CF6),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFF9CA3AF),
      ayirac: Color(0xFF1B263B),
      isim: 'counter_theme_aurora_name',
      aciklama: 'counter_theme_aurora_desc',
      ikon: Icons.nights_stay,
    ),
    // 13: Crystal - glass effect
    13: TemaRenkleri(
      arkaPlan: Color(0xFFE8EDF2),
      kartArkaPlan: Color(0xFFF5F7FA),
      vurgu: Color(0xFF5C6BC0),
      vurguSecondary: Color(0xFF64B5F6),
      yaziPrimary: Color(0xFF3D4F6F),
      yaziSecondary: Color(0xFF6B7D9A),
      ayirac: Color(0xFFDAE2EB),
      isim: 'counter_theme_crystal_name',
      aciklama: 'counter_theme_crystal_desc',
      ikon: Icons.diamond_outlined,
    ),
    // 14: Volcanic - fire tones
    14: TemaRenkleri(
      arkaPlan: Color(0xFF1A0A00),
      kartArkaPlan: Color(0xFF2D1810),
      vurgu: Color(0xFFFF6B35),
      vurguSecondary: Color(0xFFFF0844),
      yaziPrimary: Color(0xFFFFAA00),
      yaziSecondary: Color(0xFFFF8C00),
      ayirac: Color(0xFF3D1F15),
      isim: 'counter_theme_volcanic_name',
      aciklama: 'counter_theme_volcanic_desc',
      ikon: Icons.local_fire_department,
    ),
    // 15: Zen - nature tones
    15: TemaRenkleri(
      arkaPlan: Color(0xFFE8E4D9),
      kartArkaPlan: Color(0xFFF5F5DC),
      vurgu: Color(0xFF4A6741),
      vurguSecondary: Color(0xFF6B8E5F),
      yaziPrimary: Color(0xFF2D3A29),
      yaziSecondary: Color(0xFF5C6B54),
      ayirac: Color(0xFFD4CFC4),
      isim: 'counter_theme_zen_name',
      aciklama: 'counter_theme_zen_desc',
      ikon: Icons.spa,
    ),
    // 16: Cyber - cyberpunk
    16: TemaRenkleri(
      arkaPlan: Color(0xFF0D0221),
      kartArkaPlan: Color(0xFF1A0533),
      vurgu: Color(0xFFFF00FF),
      vurguSecondary: Color(0xFF00FFFF),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB388FF),
      ayirac: Color(0xFF2D0845),
      isim: 'counter_theme_cyber_name',
      aciklama: 'counter_theme_cyber_desc',
      ikon: Icons.memory,
    ),
    // 17: Night - moonlight
    17: TemaRenkleri(
      arkaPlan: Color(0xFF0A1628),
      kartArkaPlan: Color(0xFF1E3A5F),
      vurgu: Color(0xFFFFF8DC),
      vurguSecondary: Color(0xFFFFE4B5),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF2D4A6F),
      isim: 'counter_theme_night_name',
      aciklama: 'counter_theme_night_desc',
      ikon: Icons.nightlight_round,
    ),
    // 18: Matrix - hacker green
    18: TemaRenkleri(
      arkaPlan: Color(0xFF000000),
      kartArkaPlan: Color(0xFF0A0A0A),
      vurgu: Color(0xFF00FF00),
      vurguSecondary: Color(0xFF00CC00),
      yaziPrimary: Color(0xFF00FF00),
      yaziSecondary: Color(0xFF009900),
      ayirac: Color(0xFF003300),
      isim: 'counter_theme_matrix_name',
      aciklama: 'counter_theme_matrix_desc',
      ikon: Icons.code,
    ),
    // 19: Breath - meditation blue
    19: TemaRenkleri(
      arkaPlan: Color(0xFF0A1628),
      kartArkaPlan: Color(0xFF142238),
      vurgu: Color(0xFF7EC8E3),
      vurguSecondary: Color(0xFF4A90B8),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0C4DE),
      ayirac: Color(0xFF1E3A5F),
      isim: 'counter_theme_breath_name',
      aciklama: 'counter_theme_breath_desc',
      ikon: Icons.air,
    ),
    // 20: Geometric - sacred geometry
    20: TemaRenkleri(
      arkaPlan: Color(0xFF1A0A2E),
      kartArkaPlan: Color(0xFF2D1B4E),
      vurgu: Color(0xFFD4AF37),
      vurguSecondary: Color(0xFFFFD700),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFDDA0DD),
      ayirac: Color(0xFF3D2B5E),
      isim: 'counter_theme_geometric_name',
      aciklama: 'counter_theme_geometric_desc',
      ikon: Icons.hexagon_outlined,
    ),
    // 21: Tesla - electric blue
    21: TemaRenkleri(
      arkaPlan: Color(0xFF030318),
      kartArkaPlan: Color(0xFF0A0A28),
      vurgu: Color(0xFF00BFFF),
      vurguSecondary: Color(0xFF00FFFF),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFF87CEEB),
      ayirac: Color(0xFF141438),
      isim: 'counter_theme_tesla_name',
      aciklama: 'counter_theme_tesla_desc',
      ikon: Icons.bolt,
    ),
    // 22: Solstice - night with gold accents
    22: TemaRenkleri(
      arkaPlan: Color(0xFF0B0F1E),
      kartArkaPlan: Color(0xFF141A2E),
      vurgu: Color(0xFFD9A441),
      vurguSecondary: Color(0xFF2BB4A5),
      yaziPrimary: Color(0xFFE9ECEF),
      yaziSecondary: Color(0xFFB6C2CC),
      ayirac: Color(0xFF1E2740),
      isim: 'counter_theme_solstice_name',
      aciklama: 'counter_theme_solstice_desc',
      ikon: Icons.change_circle_outlined,
    ),
  };

  static const Map<AppTema, TemaRenkleri> temalar = {
    // 1. Night - default
    AppTema.gece: TemaRenkleri(
      arkaPlan: Color(0xFF1B2741),
      kartArkaPlan: Color(0xFF2B3151),
      vurgu: Color(0xFF00BCD4),
      vurguSecondary: Color(0xFF26C6DA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF3D4466),
      isim: 'app_theme_night_name',
      aciklama: 'app_theme_night_desc',
      ikon: Icons.nights_stay,
      dekoratifRenkler: [
        Color(0xFF00838F),
        Color(0xFF006064),
        Color(0xFF004D40),
      ],
    ),

    // 2. Predawn - suhoor time
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
      isim: 'app_theme_predawn_name',
      aciklama: 'app_theme_predawn_desc',
      ikon: Icons.brightness_3,
      dekoratifRenkler: [
        Color(0xFF9C27B0),
        Color(0xFF7B1FA2),
        Color(0xFF4A148C),
      ],
    ),

    // 3. Dawn - sunrise
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
      isim: 'app_theme_dawn_name',
      aciklama: 'app_theme_dawn_desc',
      ikon: Icons.wb_sunny,
      dekoratifRenkler: [
        Color(0xFFFF6F00),
        Color(0xFFE65100),
        Color(0xFFBF360C),
      ],
    ),

    // 4. Noon - daytime
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
      isim: 'app_theme_noon_name',
      aciklama: 'app_theme_noon_desc',
      ikon: Icons.light_mode,
      dekoratifRenkler: [
        Color(0xFF0097A7),
        Color(0xFF00838F),
        Color(0xFF006064),
      ],
    ),

    // 5. Evening - sunset
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
      isim: 'app_theme_evening_name',
      aciklama: 'app_theme_evening_desc',
      ikon: Icons.wb_twilight,
      dekoratifRenkler: [
        Color(0xFFD84315),
        Color(0xFFBF360C),
        Color(0xFF8D1717),
      ],
    ),

    // 6. Starry - night sky
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
      isim: 'app_theme_starry_name',
      aciklama: 'app_theme_starry_desc',
      ikon: Icons.star,
      dekoratifRenkler: [
        Color(0xFF7C4DFF),
        Color(0xFF651FFF),
        Color(0xFF6200EA),
      ],
    ),

    // 7. Emerald - calm and nature
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
      isim: 'app_theme_emerald_name',
      aciklama: 'app_theme_emerald_desc',
      ikon: Icons.eco,
      dekoratifRenkler: [
        Color(0xFF00E676),
        Color(0xFF00C853),
        Color(0xFF1B5E20),
      ],
    ),

    // 8. Ocean - deep sea
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
      isim: 'app_theme_ocean_name',
      aciklama: 'app_theme_ocean_desc',
      ikon: Icons.water,
      dekoratifRenkler: [
        Color(0xFF00ACC1),
        Color(0xFF0097A7),
        Color(0xFF00838F),
      ],
    ),

    // 9. Lavender - soft purple
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
      isim: 'app_theme_lavender_name',
      aciklama: 'app_theme_lavender_desc',
      ikon: Icons.local_florist,
      dekoratifRenkler: [
        Color(0xFFAB47BC),
        Color(0xFF8E24AA),
        Color(0xFF6A1B9A),
      ],
    ),

    // 10. Gold - luxury look
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
      isim: 'app_theme_gold_name',
      aciklama: 'app_theme_gold_desc',
      ikon: Icons.diamond,
      dekoratifRenkler: [
        Color(0xFFFFB300),
        Color(0xFFFFA000),
        Color(0xFFFF8F00),
      ],
    ),

    // 11. Carbon - minimalist black
    AppTema.karbon: TemaRenkleri(
      arkaPlan: Color(0xFF121212),
      kartArkaPlan: Color(0xFF1E1E1E),
      vurgu: Color(0xFF03DAC6),
      vurguSecondary: Color(0xFF018786),
      yaziPrimary: Color(0xFFE0E0E0),
      yaziSecondary: Color(0xFF9E9E9E),
      ayirac: Color(0xFF2C2C2C),
      isim: 'app_theme_carbon_name',
      aciklama: 'app_theme_carbon_desc',
      ikon: Icons.dark_mode,
      dekoratifRenkler: [
        Color(0xFF00BFA5),
        Color(0xFF00897B),
        Color(0xFF004D40),
      ],
    ),

    // 12. Sakura - spring blossom
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
      isim: 'app_theme_sakura_name',
      aciklama: 'app_theme_sakura_desc',
      ikon: Icons.spa,
      dekoratifRenkler: [
        Color(0xFFF48FB1),
        Color(0xFFEC407A),
        Color(0xFFD81B60),
      ],
    ),

    // 13. Custom - user defined
    AppTema.ozel: TemaRenkleri(
      arkaPlan: Color(0xFF1B2741),
      kartArkaPlan: Color(0xFF2B3151),
      vurgu: Color(0xFF00BCD4),
      vurguSecondary: Color(0xFF26C6DA),
      yaziPrimary: Colors.white,
      yaziSecondary: Color(0xFFB0BEC5),
      ayirac: Color(0xFF3D4466),
      isim: 'app_theme_custom_name',
      aciklama: 'app_theme_custom_desc',
      ikon: Icons.palette,
      dekoratifRenkler: [
        Color(0xFF00838F),
        Color(0xFF006064),
        Color(0xFF004D40),
      ],
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
    _aktifSayacIndex = prefs.getInt('secili_sayac_index') ?? 22;
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
        isim: 'app_theme_custom_name',
        aciklama: 'app_theme_custom_desc',
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
    _sayacTemasiKullan = false; // Manual theme selected
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tema_index', yeniTema.index);
    await prefs.setBool('sayac_temasi_kullan', false);
    notifyListeners();
  }

  /// Update theme when counter changes
  Future<void> sayacTemasiGuncelle(int sayacIndex) async {
    _aktifSayacIndex = sayacIndex;
    _sayacTemasiKullan =
      true; // When counter changes, theme should follow the counter
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secili_sayac_index', sayacIndex);
    await prefs.setBool('sayac_temasi_kullan', true);
    notifyListeners();
  }

  /// Toggle counter theme mode
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
      isim: 'app_theme_custom_name',
      aciklama: 'app_theme_custom_desc',
      ikon: Icons.palette,
    );

    _mevcutTema = AppTema.ozel;
    await prefs.setInt('tema_index', AppTema.ozel.index);
    notifyListeners();
  }

  // Preset color palettes
  static const List<Map<String, dynamic>> hazirPaletler = [
    // Classic tones
    {
      'isim': 'palette_night_blue',
      'arkaPlan': Color(0xFF1B2741),
      'vurgu': Color(0xFF00BCD4),
    },
    {
      'isim': 'palette_forest_green',
      'arkaPlan': Color(0xFF1B3D2F),
      'vurgu': Color(0xFF4CAF50),
    },
    {
      'isim': 'palette_burgundy',
      'arkaPlan': Color(0xFF3E1A1A),
      'vurgu': Color(0xFFE53935),
    },
    {
      'isim': 'palette_purple_dream',
      'arkaPlan': Color(0xFF2E1F47),
      'vurgu': Color(0xFF9C27B0),
    },
    {
      'isim': 'palette_turquoise',
      'arkaPlan': Color(0xFF0D3B3E),
      'vurgu': Color(0xFF00BCD4),
    },
    {
      'isim': 'palette_caramel',
      'arkaPlan': Color(0xFF3E2723),
      'vurgu': Color(0xFFFF9800),
    },
    {
      'isim': 'palette_rosewood',
      'arkaPlan': Color(0xFF3D2429),
      'vurgu': Color(0xFFE91E63),
    },
    {
      'isim': 'palette_olive',
      'arkaPlan': Color(0xFF2E3D1B),
      'vurgu': Color(0xFF8BC34A),
    },

    // Luxury & elegant
    {
      'isim': 'palette_gold_black',
      'arkaPlan': Color(0xFF0D0D0D),
      'vurgu': Color(0xFFFFD700),
    },
    {
      'isim': 'palette_rose_gold',
      'arkaPlan': Color(0xFF1A1215),
      'vurgu': Color(0xFFB76E79),
    },
    {
      'isim': 'palette_platinum',
      'arkaPlan': Color(0xFF1C1C1E),
      'vurgu': Color(0xFFE5E4E2),
    },
    {
      'isim': 'palette_bronze',
      'arkaPlan': Color(0xFF1F1710),
      'vurgu': Color(0xFFCD7F32),
    },

    // Nature tones
    {
      'isim': 'palette_ocean',
      'arkaPlan': Color(0xFF0A192F),
      'vurgu': Color(0xFF64FFDA),
    },
    {
      'isim': 'palette_forest_night',
      'arkaPlan': Color(0xFF0D1F0D),
      'vurgu': Color(0xFF00E676),
    },
    {
      'isim': 'palette_desert_night',
      'arkaPlan': Color(0xFF2D1F14),
      'vurgu': Color(0xFFFFAB40),
    },
    {
      'isim': 'palette_sunset',
      'arkaPlan': Color(0xFF2D1B2D),
      'vurgu': Color(0xFFFF6B6B),
    },

    // Neon & cyberpunk
    {
      'isim': 'palette_neon_pink',
      'arkaPlan': Color(0xFF0F0A1A),
      'vurgu': Color(0xFFFF00FF),
    },
    {
      'isim': 'palette_neon_blue',
      'arkaPlan': Color(0xFF0A0A14),
      'vurgu': Color(0xFF00FFFF),
    },
    {
      'isim': 'palette_neon_green',
      'arkaPlan': Color(0xFF0A140A),
      'vurgu': Color(0xFF00FF41),
    },
    {
      'isim': 'palette_electric_purple',
      'arkaPlan': Color(0xFF14081F),
      'vurgu': Color(0xFF9D00FF),
    },

    // Pastel & soft
    {
      'isim': 'palette_lavender',
      'arkaPlan': Color(0xFF1E1A26),
      'vurgu': Color(0xFFB39DDB),
    },
    {
      'isim': 'palette_mint',
      'arkaPlan': Color(0xFF142021),
      'vurgu': Color(0xFF80CBC4),
    },
    {
      'isim': 'palette_peach',
      'arkaPlan': Color(0xFF211A17),
      'vurgu': Color(0xFFFFAB91),
    },
    {
      'isim': 'palette_ice_blue',
      'arkaPlan': Color(0xFF141B21),
      'vurgu': Color(0xFF81D4FA),
    },

    // Premium & special
    {
      'isim': 'palette_galaxy',
      'arkaPlan': Color(0xFF0B0B1A),
      'vurgu': Color(0xFF7C4DFF),
    },
    {
      'isim': 'palette_aurora',
      'arkaPlan': Color(0xFF0D1418),
      'vurgu': Color(0xFF00E5FF),
    },
    {
      'isim': 'palette_pomegranate_blossom',
      'arkaPlan': Color(0xFF1A0A0F),
      'vurgu': Color(0xFFFF4081),
    },
    {
      'isim': 'palette_sapphire',
      'arkaPlan': Color(0xFF0A1628),
      'vurgu': Color(0xFF448AFF),
    },
    {
      'isim': 'palette_amber',
      'arkaPlan': Color(0xFF1A1408),
      'vurgu': Color(0xFFFFB300),
    },
    {
      'isim': 'palette_ruby',
      'arkaPlan': Color(0xFF1A080A),
      'vurgu': Color(0xFFFF1744),
    },
    {
      'isim': 'palette_emerald',
      'arkaPlan': Color(0xFF081A12),
      'vurgu': Color(0xFF00E676),
    },
    {
      'isim': 'palette_amethyst',
      'arkaPlan': Color(0xFF150A1F),
      'vurgu': Color(0xFFAA00FF),
    },
  ];

  ThemeData buildThemeData() {
    final r = renkler;
    // Use try-catch while loading fonts - some fonts may fail to load
    TextTheme fontTextTheme;
    try {
      fontTextTheme = GoogleFonts.getTextTheme(_fontFamily);
    } catch (e) {
      print(
        '⚠️ Font failed to load ($_fontFamily), using default font: $e',
      );
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
