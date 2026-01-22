import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diyanet_api_service.dart';
import 'konum_service.dart';
import 'ozel_gunler_service.dart';
import 'language_service.dart';

/// Android Home Screen Widget'larını güncelleyen servis
class HomeWidgetService {
  static const String _appGroupId = 'group.com.example.huzur_vakti';

  static Timer? _updateTimer;
  static Map<String, String> _vakitSaatleri = {};
  static String? _lastGeriSayim; // Son gönderilen geri sayım değeri
  static int _lastMinute = -1; // Son güncellenen dakika
  static String? _lastLanguage; // Son dil

  /// Servisi başlat
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
    await _loadVakitler();
    await _loadWidgetColors();
    await updateAllWidgets();

    // Dil değişikliğinde widget'ları güncelle
    LanguageService().addListener(_onLanguageChanged);

    // Her 30 saniyede bir güncelle (performans için artırıldı)
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      updateAllWidgets();
    });
  }

  /// Dil değişikliğinde çağrılır
  static void _onLanguageChanged() {
    final currentLang = LanguageService().currentLanguage;
    if (_lastLanguage != currentLang) {
      _lastLanguage = currentLang;
      _lastGeriSayim = null; // Cache'i temizle, widget güncellenmesi zorla
      updateAllWidgets();
    }
  }

  /// Servisi durdur
  static void dispose() {
    _updateTimer?.cancel();
    _updateTimer = null;
    LanguageService().removeListener(_onLanguageChanged);
  }

  /// Widget renk ayarlarını yükle
  static Future<void> _loadWidgetColors() async {
    final prefs = await SharedPreferences.getInstance();
    final arkaPlanKey = prefs.getString('widget_arkaplan_key') ?? 'orange';
    final yaziRengiHex = prefs.getString('widget_yazi_rengi_hex') ?? 'FFFFFF';
    final seffaflik = prefs.getDouble('widget_seffaflik') ?? 1.0;
    final fontKey = prefs.getString('widget_font_key') ?? 'condensed';

    await HomeWidget.saveWidgetData<String>('arkaplan_key', arkaPlanKey);
    await HomeWidget.saveWidgetData<String>('yazi_rengi_hex', yaziRengiHex);
    await HomeWidget.saveWidgetData<double>('seffaflik', seffaflik);
    await HomeWidget.saveWidgetData<String>('widget_font_key', fontKey);
  }

  /// Widget renklerini güncelle
  static Future<void> updateWidgetColors({
    required String arkaPlanKey,
    required String yaziRengiHex,
    required double seffaflik,
    required String fontKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_arkaplan_key', arkaPlanKey);
    await prefs.setString('widget_yazi_rengi_hex', yaziRengiHex);
    await prefs.setDouble('widget_seffaflik', seffaflik);
    await prefs.setString('widget_font_key', fontKey);

    await HomeWidget.saveWidgetData<String>('arkaplan_key', arkaPlanKey);
    await HomeWidget.saveWidgetData<String>('yazi_rengi_hex', yaziRengiHex);
    await HomeWidget.saveWidgetData<double>('seffaflik', seffaflik);
    await HomeWidget.saveWidgetData<String>('widget_font_key', fontKey);

    await updateAllWidgets();
  }

  /// Vakitleri yükle
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

  /// Tüm widget'ları güncelle
  static Future<void> updateAllWidgets() async {
    final now = DateTime.now();

    // Dakika değişmediyse güncelleme yapma (performans için)
    if (_lastMinute == now.minute && _vakitSaatleri.isNotEmpty) {
      return;
    }
    _lastMinute = now.minute;

    if (_vakitSaatleri.isEmpty) {
      await _loadVakitler();
    }

    final vakitBilgisi = _hesaplaVakitBilgisi(now);

    // Geri sayım değişmediyse widget'ları güncelleme (gereksiz güncellemeyi önle)
    final yeniGeriSayim = vakitBilgisi['geriSayim'] ?? '';
    if (_lastGeriSayim == yeniGeriSayim) {
      return; // Değişiklik yok, güncelleme yapma
    }
    _lastGeriSayim = yeniGeriSayim;

    // Tarih bilgileri
    final miladiTarih = DateFormat('dd MMMM yyyy', 'tr_TR').format(now);
    final miladiKisa = DateFormat('dd MMM yyyy', 'tr_TR').format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih =
        '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';

    // Konum bilgisi
    final il = await KonumService.getIl();
    final ilce = await KonumService.getIlce();
    final konum = il != null && ilce != null
        ? '$il / $ilce'
        : il ?? 'Konum seçilmedi';

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
    // İlerleme değeri 0-100 arası clamp
    int ilerleme = int.tryParse(vakitBilgisi['ilerleme'] ?? '0') ?? 0;
    if (ilerleme < 0) ilerleme = 0;
    if (ilerleme > 100) ilerleme = 100;
    await HomeWidget.saveWidgetData<int>('ilerleme', ilerleme);

    await HomeWidget.saveWidgetData<String>('tarih', miladiTarih);
    await HomeWidget.saveWidgetData<String>('miladi_tarih', miladiKisa);
    await HomeWidget.saveWidgetData<String>('hicri_tarih', hicriTarih);
    await HomeWidget.saveWidgetData<String>('konum', konum);

    // Vakit saatlerini kaydet
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

    // Günün sözü
    final hadis = await _getGununHadisi();
    await HomeWidget.saveWidgetData<String>('gunun_sozu', hadis['metin'] ?? '');
    await HomeWidget.saveWidgetData<String>(
      'soz_kaynak',
      hadis['kaynak'] ?? '',
    );

    // Günün hadisi
    await HomeWidget.saveWidgetData<String>(
      'gunun_hadisi',
      hadis['metin'] ?? '',
    );

    // Esmaül Hüsna
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

    // Özel gün kontrolü
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

    // Kıble derecesi (örnek değer - gerçek hesaplama için konum gerekli)
    await HomeWidget.saveWidgetData<double>('kible_derece', 156.7);

    // Widget'ları güncelle
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
      // Widget güncellenemezse devam et
      print('Widget güncelleme hatası: $e');
    }
  }

  /// Vakit bilgisini hesapla
  static Map<String, String> _hesaplaVakitBilgisi(DateTime now) {
    final languageService = LanguageService();
    
    // Vakit isimlerinin çevirileri
    String getVakitAdi(String key) {
      switch (key) {
        case 'Imsak': return languageService['fajr'] ?? 'İmsak';
        case 'Gunes': return languageService['sunrise'] ?? 'Güneş';
        case 'Ogle': return languageService['dhuhr'] ?? 'Öğle';
        case 'Ikindi': return languageService['asr'] ?? 'İkindi';
        case 'Aksam': return languageService['maghrib'] ?? 'Akşam';
        case 'Yatsi': return languageService['isha'] ?? 'Yatsı';
        default: return key;
      }
    }
    
    if (_vakitSaatleri.isEmpty) {
      return {
        'sonrakiVakit': getVakitAdi('Ogle'),
        'sonrakiSaat': '12:30',
        'mevcutVakit': getVakitAdi('Gunes'),
        'mevcutSaat': '07:00',
        'kalanSure': '2s 30dk kaldı',
        'kalanKisa': '2s 30dk',
        'geriSayim': '2s 30dk',
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

    // Vakit saniyelerini hesapla
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

    // Sonraki vakti bul
    int sonrakiIndex = -1;
    for (int i = 0; i < vakitSaniyeleri.length; i++) {
      if (vakitSaniyeleri[i] > nowTotalSeconds) {
        sonrakiIndex = i;
        break;
      }
    }

    if (sonrakiIndex == -1) {
      // Tüm vakitler geçmiş, yarın imsak
      sonrakiVakit = getVakitAdi('Imsak');
      sonrakiSaat = _vakitSaatleri['Imsak'] ?? '05:30';
      mevcutVakit = getVakitAdi('Yatsi');
      mevcutSaat = _vakitSaatleri['Yatsi'] ?? '19:30';

      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;

      // Yatsıdan yarın imsaka kadar toplam süre
      toplamSaniye = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      // Yatsıdan şimdiye kadar geçen süre
      gecenSaniye = nowTotalSeconds - yatsiSaniye;
      if (gecenSaniye < 0) gecenSaniye = 0;

      // Yarın imsaka kalan süre
      kalanToplamSaniye = (24 * 3600 - nowTotalSeconds) + imsakSaniye;
    } else if (sonrakiIndex == 0) {
      // İmsak henüz olmadı (gece yarısından sonra, imsak öncesi)
      sonrakiVakit = getVakitAdi('Imsak');
      sonrakiSaat = _vakitSaatleri['Imsak'] ?? '05:30';
      mevcutVakit = getVakitAdi('Yatsi');
      mevcutSaat = _vakitSaatleri['Yatsi'] ?? '19:30';

      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;

      // Dün yatsıdan bugün imsaka kadar toplam süre
      toplamSaniye = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      // Gece yarısından şimdiye + dün yatsıdan gece yarısına = geçen süre
      gecenSaniye = nowTotalSeconds + (24 * 3600 - yatsiSaniye);

      kalanToplamSaniye = imsakSaniye - nowTotalSeconds;
    } else {
      // Normal durum: gündüz vakitleri
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

    // Geri sayım formatı: saniye YOK (widget'lar her 30sn güncellenir)
    final geriSayimStr = kalanSaat > 0 
        ? '${kalanSaat}s ${kalanDk}dk' 
        : '${kalanDk} dk';

    return {
      'sonrakiVakit': sonrakiVakit,
      'sonrakiSaat': sonrakiSaat,
      'mevcutVakit': mevcutVakit,
      'mevcutSaat': mevcutSaat,
      'kalanSure': kalanSaat > 0 
          ? '${kalanSaat}s ${kalanDk}dk kaldı'
          : '${kalanDk} dk kaldı',
      'kalanKisa': geriSayimStr,
      'geriSayim': geriSayimStr,
      'ilerleme': ilerleme.toString(),
    };
  }

  static String _getHicriAyAdi(int ay) {
    final languageService = LanguageService();
    if (ay >= 1 && ay <= 12) {
      return languageService['hijri_month_$ay'] ?? '';
    }
    return '';
  }

  static Future<Map<String, String>> _getGununHadisi() async {
    final hadisler = [
      {'metin': 'Ameller niyetlere göredir.', 'kaynak': 'Buhârî'},
      {
        'metin':
            'Müslüman, elinden ve dilinden Müslümanların güvende olduğu kimsedir.',
        'kaynak': 'Buhârî',
      },
      {'metin': 'Kolaylaştırınız, zorlaştırmayınız.', 'kaynak': 'Buhârî'},
      {
        'metin': 'Sizin en hayırlınız ahlakça en güzel olanınızdır.',
        'kaynak': 'Buhârî',
      },
      {'metin': 'Güzel söz sadakadır.', 'kaynak': 'Buhârî'},
      {
        'metin': 'Cennette yetim himaye edenle beraber olacağız.',
        'kaynak': 'Buhârî',
      },
      {'metin': 'Allah temizdir, temizi sever.', 'kaynak': 'Tirmizî'},
    ];

    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    final index = dayOfYear % hadisler.length;
    return hadisler[index];
  }

  static Map<String, String> _getGununEsmasi() {
    final esmalar = [
      {'arapca': 'الرحمن', 'turkce': 'ER-RAHMÂN', 'anlam': 'Çok merhametli'},
      {'arapca': 'الرحيم', 'turkce': 'ER-RAHÎM', 'anlam': 'Çok bağışlayan'},
      {'arapca': 'الملك', 'turkce': 'EL-MELİK', 'anlam': 'Mülkün sahibi'},
      {'arapca': 'القدوس', 'turkce': 'EL-KUDDÛS', 'anlam': 'Çok kutsal'},
      {'arapca': 'السلام', 'turkce': 'ES-SELÂM', 'anlam': 'Selamet veren'},
      {'arapca': 'المؤمن', 'turkce': "EL-MÜ'MİN", 'anlam': 'Güven veren'},
      {
        'arapca': 'المهيمن',
        'turkce': 'EL-MÜHEYMİN',
        'anlam': 'Koruyup gözeten',
      },
    ];

    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    final index = dayOfYear % esmalar.length;
    return esmalar[index];
  }
}
