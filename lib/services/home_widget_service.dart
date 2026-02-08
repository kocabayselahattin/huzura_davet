import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diyanet_api_service.dart';
import 'konum_service.dart';
import 'ozel_gunler_service.dart';
import 'language_service.dart';

/// Service that updates Android home screen widgets.
class HomeWidgetService {
  static const String _appGroupId = 'group.com.kocabay.huzurvakti';

  static Timer? _updateTimer;
  static Map<String, String> _vakitSaatleri = {};
  static String? _lastGeriSayim; // Last sent countdown value
  static int _lastMinute = -1; // Last updated minute
  static String? _lastLanguage; // Son dil

  /// Start the service.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
    await _loadVakitler();
    await _loadWidgetColors();
    await updateAllWidgets();

    // Update widgets when the language changes.
    LanguageService().addListener(_onLanguageChanged);

    // Update every 30 seconds.
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      updateAllWidgets();
    });
  }

  /// Called when the language changes.
  static void _onLanguageChanged() {
    final currentLang = LanguageService().currentLanguage;
    if (_lastLanguage != currentLang) {
      _lastLanguage = currentLang;
      _lastGeriSayim = null; // Clear cache to force widget updates.
      updateAllWidgets();
    }
  }

  /// Stop the service.
  static void dispose() {
    _updateTimer?.cancel();
    _updateTimer = null;
    LanguageService().removeListener(_onLanguageChanged);
  }

  /// Load widget color settings.
  static Future<void> _loadWidgetColors() async {
    final prefs = await SharedPreferences.getInstance();
    final arkaPlanKey = prefs.getString('widget_arkaplan_key') ?? 'orange';
    final yaziRengiHex = prefs.getString('widget_yazi_rengi_hex') ?? 'FFFFFF';
    final seffaflik = prefs.getDouble('widget_seffaflik') ?? 1.0;

    await HomeWidget.saveWidgetData<String>('arkaplan_key', arkaPlanKey);
    await HomeWidget.saveWidgetData<String>('yazi_rengi_hex', yaziRengiHex);
    await HomeWidget.saveWidgetData<double>('seffaflik', seffaflik);
  }

  /// Update widget colors (legacy for all widgets).
  static Future<void> updateWidgetColors({
    required String arkaPlanKey,
    required String yaziRengiHex,
    required double seffaflik,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_arkaplan_key', arkaPlanKey);
    await prefs.setString('widget_yazi_rengi_hex', yaziRengiHex);
    await prefs.setDouble('widget_seffaflik', seffaflik);

    await HomeWidget.saveWidgetData<String>('arkaplan_key', arkaPlanKey);
    await HomeWidget.saveWidgetData<String>('yazi_rengi_hex', yaziRengiHex);
    await HomeWidget.saveWidgetData<double>('seffaflik', seffaflik);

    await updateAllWidgets();
  }

  /// Update colors for a specific widget.
  static Future<void> updateWidgetColorsForWidget({
    required String widgetId,
    required String arkaPlanKey,
    required String yaziRengiHex,
    required double seffaflik,
  }) async {
    // Save widget-specific colors.
    await HomeWidget.saveWidgetData<String>('${widgetId}_arkaplan_key', arkaPlanKey);
    await HomeWidget.saveWidgetData<String>('${widgetId}_yazi_rengi_hex', yaziRengiHex);
    await HomeWidget.saveWidgetData<double>('${widgetId}_seffaflik', seffaflik);

    await updateAllWidgets();
  }

  /// Load prayer times.
  static Future<void> _loadVakitler() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId != null) {
      final data = await DiyanetApiService.getBugunVakitler(ilceId);
      if (data != null) {
        _vakitSaatleri = {
          'Imsak': data['Imsak'] ?? '05:30',
          'Gunes': data['Gunes'] ?? '07:00',
          'Ogle': data['Ogle'] ?? '12:30',
          'Ikindi': data['Ikindi'] ?? '15:30',
          'Aksam': data['Aksam'] ?? '18:00',
          'Yatsi': data['Yatsi'] ?? '19:30',
        };
      }
    }
  }

  /// Update all widgets.
  static Future<void> updateAllWidgets() async {
    final now = DateTime.now();
    final lang = LanguageService();

    // Skip updates when the minute has not changed.
    if (_lastMinute == now.minute && _vakitSaatleri.isNotEmpty) {
      return;
    }
    _lastMinute = now.minute;

    if (_vakitSaatleri.isEmpty) {
      await _loadVakitler();
    }

    final vakitBilgisi = _hesaplaVakitBilgisi(now);

    // Skip updates when the countdown has not changed.
    final yeniGeriSayim = vakitBilgisi['geriSayim'] ?? '';
    if (_lastGeriSayim == yeniGeriSayim) {
      return; // No changes.
    }
    _lastGeriSayim = yeniGeriSayim;

    // Dates
    final locale = _getLocale();
    final miladiTarih = DateFormat('dd MMMM yyyy', locale).format(now);
    final miladiKisa = DateFormat('dd MMM yyyy', locale).format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih =
        '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';

    // Location
    final il = await KonumService.getIl();
    final ilce = await KonumService.getIlce();
    final konum = il != null && ilce != null
        ? '$il / $ilce'
        : il ?? (lang['location_not_selected'] ?? '');

    // Widget verilerini kaydet
    await HomeWidget.saveWidgetData<String>(
      'sonraki_vakit',
      vakitBilgisi['sonrakiVakit'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'sonraki_vakit_saati',
      vakitBilgisi['sonrakiSaat'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'mevcut_vakit',
      vakitBilgisi['mevcutVakit'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'mevcut_vakit_saati',
      vakitBilgisi['mevcutSaat'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'kalan_sure',
      vakitBilgisi['kalanSure'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'kalan_kisa',
      vakitBilgisi['kalanKisa'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>('geri_sayim', yeniGeriSayim);
    // Clamp progress value to 0-100.
    int ilerleme = int.tryParse(vakitBilgisi['ilerleme'] ?? '0') ?? 0;
    if (ilerleme < 0) ilerleme = 0;
    if (ilerleme > 100) ilerleme = 100;
    await HomeWidget.saveWidgetData<int>('ilerleme', ilerleme);

    await HomeWidget.saveWidgetData<String>('tarih', miladiTarih);
    await HomeWidget.saveWidgetData<String>('miladi_tarih', miladiKisa);
    await HomeWidget.saveWidgetData<String>('hicri_tarih', hicriTarih);
    await HomeWidget.saveWidgetData<String>('konum', konum);

    // Save prayer times.
    await HomeWidget.saveWidgetData<String>(
      'imsak_saati',
      _vakitSaatleri['Imsak'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'gunes_saati',
      _vakitSaatleri['Gunes'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'ogle_saati',
      _vakitSaatleri['Ogle'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'ikindi_saati',
      _vakitSaatleri['Ikindi'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'aksam_saati',
      _vakitSaatleri['Aksam'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'yatsi_saati',
      _vakitSaatleri['Yatsi'] ?? '',
    );

    // Daily hadith
    final hadis = await _getGununHadisi();
    await HomeWidget.saveWidgetData<String>('gunun_sozu', hadis['metin'] ?? '');
    await HomeWidget.saveWidgetData<String>(
      'soz_kaynak',
      hadis['kaynak'] ?? '',
    );

    // Daily hadith (legacy key)
    await HomeWidget.saveWidgetData<String>(
      'gunun_hadisi',
      hadis['metin'] ?? '',
    );

    // Daily Asma al-Husna
    final esma = _getGununEsmasi();
    await HomeWidget.saveWidgetData<String>(
      'esma_arapca',
      esma['arapca'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'esma_turkce',
      esma['turkce'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>('esma_anlam', esma['anlam'] ?? '');

    // Special day check
    final ozelGun = OzelGunlerService.bugunOzelGunMu();
    if (ozelGun != null) {
      await HomeWidget.saveWidgetData<String>('ozel_gun_adi', ozelGun.ad);
      await HomeWidget.saveWidgetData<String>(
        'ozel_gun_mesaj',
        ozelGun.tebrikMesaji,
      );
      await HomeWidget.saveWidgetData<bool>('ozel_gun_var', true);
    } else {
      await HomeWidget.saveWidgetData<String>('ozel_gun_adi', '');
      await HomeWidget.saveWidgetData<String>('ozel_gun_mesaj', '');
      await HomeWidget.saveWidgetData<bool>('ozel_gun_var', false);
    }

    // Qibla degree (sample value - requires real location)
    await HomeWidget.saveWidgetData<double>('kible_derece', 156.7);

    // Widget translations
    await HomeWidget.saveWidgetData<String>(
      'widget_time_remaining',
      lang['widget_time_remaining'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_time_to',
      lang['widget_time_to'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_current_time',
      lang['widget_current_time'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_now_at',
      lang['widget_now_at'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_now_in_time',
      lang['widget_now_in_time'] ?? '',
    );
    
    // Prayer name translations
    await HomeWidget.saveWidgetData<String>(
      'label_imsak',
      lang['imsak'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'label_gunes',
      lang['gunes'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'label_ogle',
      lang['ogle'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'label_ikindi',
      lang['ikindi'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'label_aksam',
      lang['aksam'] ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'label_yatsi',
      lang['yatsi'] ?? '',
    );

    // Trigger widget updates
    try {
      await HomeWidget.updateWidget(
        name: 'KlasikTuruncuWidget',
        androidName: 'KlasikTuruncuWidget',
        qualifiedAndroidName:
            'com.example.huzur_vakti.widgets.KlasikTuruncuWidget',
      );
      await HomeWidget.updateWidget(
        name: 'MiniSunsetWidget',
        androidName: 'MiniSunsetWidget',
        qualifiedAndroidName:
            'com.example.huzur_vakti.widgets.MiniSunsetWidget',
      );
      await HomeWidget.updateWidget(
        name: 'GlassmorphismWidget',
        androidName: 'GlassmorphismWidget',
        qualifiedAndroidName:
            'com.example.huzur_vakti.widgets.GlassmorphismWidget',
      );
      await HomeWidget.updateWidget(
        name: 'NeonGlowWidget',
        androidName: 'NeonGlowWidget',
        qualifiedAndroidName: 'com.example.huzur_vakti.widgets.NeonGlowWidget',
      );
      await HomeWidget.updateWidget(
        name: 'TimelineWidget',
        androidName: 'TimelineWidget',
        qualifiedAndroidName: 'com.example.huzur_vakti.widgets.TimelineWidget',
      );
      await HomeWidget.updateWidget(
        name: 'CosmicWidget',
        androidName: 'CosmicWidget',
        qualifiedAndroidName: 'com.example.huzur_vakti.widgets.CosmicWidget',
      );
      await HomeWidget.updateWidget(
        name: 'ZenWidget',
        androidName: 'ZenWidget',
        qualifiedAndroidName: 'com.example.huzur_vakti.widgets.ZenWidget',
      );
      await HomeWidget.updateWidget(
        name: 'OrigamiWidget',
        androidName: 'OrigamiWidget',
        qualifiedAndroidName: 'com.example.huzur_vakti.widgets.OrigamiWidget',
      );
    } catch (e) {
      // Keep going if widget update fails.
      print('Widget update error: $e');
    }
  }

  /// Calculate prayer time info.
  static Map<String, String> _hesaplaVakitBilgisi(DateTime now) {
    final languageService = LanguageService();
    final hourShort = languageService['hour_short'] ?? '';
    final minuteShort = languageService['minute_short'] ?? '';
    final timeLeftSuffix = languageService['time_left_suffix'] ?? '';
    
    // Prayer name translations
    String getVakitAdi(String key) {
      switch (key) {
        case 'Imsak': return languageService['imsak'] ?? '';
        case 'Gunes': return languageService['gunes'] ?? '';
        case 'Ogle': return languageService['ogle'] ?? '';
        case 'Ikindi': return languageService['ikindi'] ?? '';
        case 'Aksam': return languageService['aksam'] ?? '';
        case 'Yatsi': return languageService['yatsi'] ?? '';
        default: return key;
      }
    }
    
    if (_vakitSaatleri.isEmpty) {
      final shortRemaining = '2$hourShort 30$minuteShort';
      final remainingWithSuffix = timeLeftSuffix.isNotEmpty
          ? '$shortRemaining $timeLeftSuffix'
          : shortRemaining;
      return {
        'sonrakiVakit': getVakitAdi('Ogle'),
        'sonrakiSaat': '12:30',
        'mevcutVakit': getVakitAdi('Gunes'),
        'mevcutSaat': '07:00',
        'kalanSure': remainingWithSuffix,
        'kalanKisa': shortRemaining,
        'geriSayim': shortRemaining,
        'ilerleme': '50',
      };
    }

    final nowTotalSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    final vakitListesi = [
      {'key': 'Imsak'},
      {'key': 'Gunes'},
      {'key': 'Ogle'},
      {'key': 'Ikindi'},
      {'key': 'Aksam'},
      {'key': 'Yatsi'},
    ];

    // Calculate prayer time seconds.
    List<int> vakitSaniyeleri = [];
    for (final vakit in vakitListesi) {
      final saat = _vakitSaatleri[vakit['key']] ?? '00:00';
      final parts = saat.split(':');
      vakitSaniyeleri.add(
        int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60,
      );
    }

    String sonrakiVakit = getVakitAdi('Imsak');
    String sonrakiSaat = _vakitSaatleri['Imsak'] ?? '05:30';
    String mevcutVakit = getVakitAdi('Yatsi');
    String mevcutSaat = _vakitSaatleri['Yatsi'] ?? '19:30';
    int toplamSaniye = 1;
    int gecenSaniye = 0;
    int kalanToplamSaniye = 0;

    // Determine next prayer time.
    int sonrakiIndex = -1;
    for (int i = 0; i < vakitSaniyeleri.length; i++) {
      if (vakitSaniyeleri[i] > nowTotalSeconds) {
        sonrakiIndex = i;
        break;
      }
    }

    if (sonrakiIndex == -1) {
      // All prayer times passed; next is tomorrow's imsak.
      sonrakiVakit = getVakitAdi('Imsak');
      sonrakiSaat = _vakitSaatleri['Imsak'] ?? '05:30';
      mevcutVakit = getVakitAdi('Yatsi');
      mevcutSaat = _vakitSaatleri['Yatsi'] ?? '19:30';

      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;

      // Total duration from yatsi to next imsak.
      toplamSaniye = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      // Time elapsed since yatsi.
      gecenSaniye = nowTotalSeconds - yatsiSaniye;
      if (gecenSaniye < 0) gecenSaniye = 0;

      // Time remaining until next imsak.
      kalanToplamSaniye = (24 * 3600 - nowTotalSeconds) + imsakSaniye;
    } else if (sonrakiIndex == 0) {
      // After midnight, before imsak.
      sonrakiVakit = getVakitAdi('Imsak');
      sonrakiSaat = _vakitSaatleri['Imsak'] ?? '05:30';
      mevcutVakit = getVakitAdi('Yatsi');
      mevcutSaat = _vakitSaatleri['Yatsi'] ?? '19:30';

      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;

      // Total duration from last yatsi to today's imsak.
      toplamSaniye = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      // Elapsed time: after midnight + time from last yatsi to midnight.
      gecenSaniye = nowTotalSeconds + (24 * 3600 - yatsiSaniye);

      kalanToplamSaniye = imsakSaniye - nowTotalSeconds;
    } else {
      // Normal daytime period.
      sonrakiVakit = getVakitAdi(vakitListesi[sonrakiIndex]['key']!);
      sonrakiSaat =
          _vakitSaatleri[vakitListesi[sonrakiIndex]['key']] ?? '00:00';
      mevcutVakit = getVakitAdi(vakitListesi[sonrakiIndex - 1]['key']!);
      mevcutSaat =
          _vakitSaatleri[vakitListesi[sonrakiIndex - 1]['key']] ?? '00:00';

      toplamSaniye =
          vakitSaniyeleri[sonrakiIndex] - vakitSaniyeleri[sonrakiIndex - 1];
      gecenSaniye = nowTotalSeconds - vakitSaniyeleri[sonrakiIndex - 1];
      kalanToplamSaniye = vakitSaniyeleri[sonrakiIndex] - nowTotalSeconds;
    }

    if (kalanToplamSaniye < 0) {
      kalanToplamSaniye += 24 * 3600;
    }

    final kalanSaat = kalanToplamSaniye ~/ 3600;
    final kalanDk = (kalanToplamSaniye % 3600) ~/ 60;

    int ilerleme = toplamSaniye > 0
        ? ((gecenSaniye / toplamSaniye) * 100).round()
        : 0;
    ilerleme = ilerleme.clamp(0, 100);

    // Countdown format without seconds.
    final geriSayimStr = kalanSaat > 0
      ? '$kalanSaat$hourShort $kalanDk$minuteShort'
      : '$kalanDk$minuteShort';
    final kalanSureStr = timeLeftSuffix.isNotEmpty
      ? '$geriSayimStr $timeLeftSuffix'
      : geriSayimStr;

    return {
      'sonrakiVakit': sonrakiVakit,
      'sonrakiSaat': sonrakiSaat,
      'mevcutVakit': mevcutVakit,
      'mevcutSaat': mevcutSaat,
      'kalanSure': kalanSureStr,
      'kalanKisa': geriSayimStr,
      'geriSayim': geriSayimStr,
      'ilerleme': ilerleme.toString(),
    };
  }

  static String _getLocale() {
    switch (LanguageService().currentLanguage) {
      case 'tr':
        return 'tr_TR';
      case 'en':
        return 'en_US';
      case 'de':
        return 'de_DE';
      case 'fr':
        return 'fr_FR';
      case 'ar':
        return 'ar_SA';
      case 'fa':
        return 'fa_IR';
      default:
        return 'en_US';
    }
  }

  static String _getHicriAyAdi(int ay) {
    final languageService = LanguageService();
    if (ay >= 1 && ay <= 12) {
      return languageService['hijri_month_$ay'] ?? '';
    }
    return '';
  }

  static Future<Map<String, String>> _getGununHadisi() async {
    final languageService = LanguageService();
    final hadisler = languageService['hadiths'];
    if (hadisler is List && hadisler.isNotEmpty) {
      final dayOfYear = DateTime.now()
          .difference(DateTime(DateTime.now().year, 1, 1))
          .inDays;
      final index = dayOfYear % hadisler.length;
      final hadis = hadisler[index];
      if (hadis is Map) {
        return {
          'metin': hadis['text']?.toString() ?? '',
          'kaynak': hadis['source']?.toString() ?? '',
        };
      }
    }
    return {'metin': '', 'kaynak': ''};
  }

  static Map<String, String> _getGununEsmasi() {
    final languageService = LanguageService();
    final esmalar = languageService['daily_esmaul_husna'];
    if (esmalar is List && esmalar.isNotEmpty) {
      final dayOfYear = DateTime.now()
          .difference(DateTime(DateTime.now().year, 1, 1))
          .inDays;
      final index = dayOfYear % esmalar.length;
      final esma = esmalar[index];
      if (esma is Map) {
        return {
          'arapca': esma['arabic']?.toString() ?? '',
          'turkce': esma['name']?.toString() ?? '',
          'anlam': esma['meaning']?.toString() ?? '',
        };
      }
    }
    return {'arapca': '', 'turkce': '', 'anlam': ''};
  }
}
