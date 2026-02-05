import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../services/dnd_service.dart';
import '../services/scheduled_notification_service.dart';
import '../services/daily_content_notification_service.dart';
import '../services/language_service.dart';

class BildirimAyarlariSayfa extends StatefulWidget {
  const BildirimAyarlariSayfa({super.key});

  @override
  State<BildirimAyarlariSayfa> createState() => _BildirimAyarlariSayfaState();
}

class _BildirimAyarlariSayfaState extends State<BildirimAyarlariSayfa> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final LanguageService _languageService = LanguageService();

  // Bildirim açık/kapalı durumları
  // Varsayılanlar main.dart'taki ile tutarlı olmalı
  final Map<String, bool> _bildirimAcik = {
    'imsak': true,
    'gunes': true,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Vaktinde bildirim (tam vakitte göster)
  // Varsayılan: öğle, ikindi, akşam, yatsı için açık
  final Map<String, bool> _vaktindeBildirim = {
    'imsak': false,
    'gunes': false,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Alarm açık/kapalı durumları (kilit ekranında alarm çalar)
  // Varsayılan: öğle, ikindi, akşam, yatsı için açık
  final Map<String, bool> _alarmAcik = {
    'imsak': false,
    'gunes': false,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Vakitlerde sessize al seçeneği
  bool _sessizeAl = false;

  // Kilit ekranı bildirimi
  bool _kilitEkraniBildirimi = false;

  // Günlük içerik bildirimleri
  bool _gunlukIcerikBildirimleri = true;

  // Günlük içerik alarm ayarları
  TimeOfDay _gunlukAyetSaati = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _gunlukHadisSaati = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _gunlukDuaSaati = const TimeOfDay(hour: 20, minute: 0);
  String _gunlukIcerikSesi = 'ding_dong.mp3';

  // Ses çalma durumu (play/pause toggle için)
  String? _sesCalanKey; // Hangi vakit için ses çalıyor

  // Kilit ekranı servisi için MethodChannel
  static const _lockScreenChannel = MethodChannel('huzur_vakti/lockscreen');

  // Değişiklik takibi
  bool _degisiklikYapildi = false;

  // Erken bildirim süreleri (dakika)
  // Varsayılan: 15 dakika önce (güneş 45 dakika)
  final Map<String, int> _erkenBildirim = {
    'imsak': 15,
    'gunes': 45,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
  };

  // Vaktinde bildirim sesi seçimi (her vakit için) - default: Best
  final Map<String, String> _bildirimSesi = {
    'imsak': 'best.mp3',
    'gunes': 'best.mp3',
    'ogle': 'best.mp3',
    'ikindi': 'best.mp3',
    'aksam': 'best.mp3',
    'yatsi': 'best.mp3',
  };

  // Erken bildirim sesi seçimi (her vakit için) - default: Best (vaktinde ile aynı)
  final Map<String, String> _erkenBildirimSesi = {
    'imsak': 'best.mp3',
    'gunes': 'best.mp3',
    'ogle': 'best.mp3',
    'ikindi': 'best.mp3',
    'aksam': 'best.mp3',
    'yatsi': 'best.mp3',
  };

  final List<int> _erkenSureler = [0, 5, 10, 15, 20, 30, 45, 60];

  // Ses seçenekleri - getter olarak tanımlanıyor çünkü languageService'e ihtiyaç var
  List<Map<String, String>> get _sesSecenekleri => [
    {
      'ad': _languageService['sound_aksam_ezani'] ?? 'Akşam Ezanı',
      'dosya': 'aksam_ezani.mp3',
    },
    {
      'ad': _languageService['sound_ayasofya_ezan'] ?? 'Ayasofya Ezan Sesi',
      'dosya': 'ayasofya_ezan_sesi.mp3',
    },
    {'ad': _languageService['sound_best'] ?? 'Best', 'dosya': 'best.mp3'},
    {'ad': _languageService['sound_corner'] ?? 'Corner', 'dosya': 'corner.mp3'},
    {
      'ad': _languageService['sound_ding_dong'] ?? 'Ding Dong',
      'dosya': 'ding_dong.mp3',
    },
    {
      'ad':
          _languageService['sound_esselatu_1'] ??
          'Es-Selatu Hayrun Minen Nevm 1',
      'dosya': 'esselatu_hayrun_minen_nevm1.mp3',
    },
    {
      'ad':
          _languageService['sound_esselatu_2'] ??
          'Es-Selatu Hayrun Minen Nevm 2',
      'dosya': 'esselatu_hayrun_minen_nevm2.mp3',
    },
    {'ad': _languageService['sound_melodi'] ?? 'Melodi', 'dosya': 'melodi.mp3'},
    {
      'ad':
          _languageService['sound_mescid_nebi_sabah'] ??
          'Mescid-i Nebi Sabah Ezanı',
      'dosya': 'mescid_i_nebi_sabah_ezani.mp3',
    },
    {'ad': _languageService['sound_snaps'] ?? 'Snaps', 'dosya': 'snaps.mp3'},
    {
      'ad': _languageService['sound_sweet_favour'] ?? 'Sweet Favour',
      'dosya': 'sweet_favour.mp3',
    },
    {'ad': _languageService['sound_violet'] ?? 'Violet', 'dosya': 'violet.mp3'},
    {
      'ad': _languageService['sound_sabah_ezani_saba'] ?? 'Sabah Ezanı (Saba)',
      'dosya': 'sabah_ezani_saba.mp3',
    },
    {
      'ad': _languageService['sound_ogle_ezani_rast'] ?? 'Öğle Ezanı (Rast)',
      'dosya': 'ogle_ezani_rast.mp3',
    },
    {
      'ad':
          _languageService['sound_ikindi_ezani_hicaz'] ??
          'İkindi Ezanı (Hicaz)',
      'dosya': 'ikindi_ezani_hicaz.mp3',
    },
    {
      'ad':
          _languageService['sound_aksam_ezani_segah'] ?? 'Akşam Ezanı (Segah)',
      'dosya': 'aksam_ezani_segah.mp3',
    },
    {
      'ad':
          _languageService['sound_yatsi_ezani_ussak'] ?? 'Yatsı Ezanı (Uşşak)',
      'dosya': 'yatsi_ezani_ussak.mp3',
    },
    {
      'ad': _languageService['sound_ney_uyan'] ?? 'Ney - Uyan',
      'dosya': 'ney_uyan.mp3',
    },
    {
      'ad': _languageService['custom_sound'] ?? 'Özel Ses Seç',
      'dosya': 'custom',
    },
  ];

  // Özel ses yolları
  final Map<String, String> _ozelSesDosyalari = {};

  List<Map<String, String>> get _gunlukIcerikSesSecenekleri =>
      _sesSecenekleri.where((s) => s['dosya'] != 'custom').toList();

  /// Dosya adını Android resource kurallarına uygun hale getirir
  /// - Küçük harfe çevirir
  /// - Türkçe karakterleri değiştirir
  /// - Rakamla başlıyorsa önüne "sound_" ekler
  /// - Geçersiz karakterleri alt çizgi ile değiştirir
  String _normalizeFileName(String fileName) {
    // Uzantıyı ayır
    final lastDot = fileName.lastIndexOf('.');
    String name = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    String ext = lastDot > 0 ? fileName.substring(lastDot) : '';

    // Küçük harfe çevir
    name = name.toLowerCase();
    ext = ext.toLowerCase();

    // Türkçe karakterleri değiştir
    final turkceKarakterler = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'Ç': 'c',
      'Ğ': 'g',
      'İ': 'i',
      'Ö': 'o',
      'Ş': 's',
      'Ü': 'u',
    };
    turkceKarakterler.forEach((key, value) {
      name = name.replaceAll(key, value);
    });

    // Sadece harf, rakam ve alt çizgi bırak
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    // Birden fazla alt çizgiyi teke indir
    name = name.replaceAll(RegExp(r'_+'), '_');

    // Baş ve sondaki alt çizgileri kaldır
    name = name.replaceAll(RegExp(r'^_+|_+$'), '');

    // Boşsa varsayılan isim ver
    if (name.isEmpty) {
      name = 'custom_sound';
    }

    // Rakamla başlıyorsa önüne "sound_" ekle
    if (RegExp(r'^[0-9]').hasMatch(name)) {
      name = 'sound_$name';
    }

    return '$name$ext';
  }

  /// Özel ses dosyasını uygulamanın dizinine güvenli isimle kopyalar
  Future<String?> _copyCustomSoundFile(
    String sourcePath,
    String vakitKey,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soundsDir = Directory('${appDir.path}/custom_sounds');

      // Dizin yoksa oluştur
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      // Orijinal dosya adını al ve normalize et
      final originalFileName = sourcePath.split('/').last.split('\\').last;
      final safeFileName = _normalizeFileName(originalFileName);

      // Benzersiz isim oluştur (vakit key + zaman damgası)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${vakitKey}_${timestamp}_$safeFileName';

      final destPath = '${soundsDir.path}/$uniqueFileName';

      // Dosyayı kopyala
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);

      return destPath;
    } catch (e) {
      debugPrint('Ses dosyası kopyalanamadı: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
    _baslangicAyarlari();
  }

  Future<void> _baslangicAyarlari() async {
    // Günlük içerik bildirimlerini başlat
    try {
      await DailyContentNotificationService.initialize();
      await DailyContentNotificationService.scheduleDailyContentNotifications();
      debugPrint('✅ Başlangıçta günlük içerik bildirimleri zamanlandı');
    } catch (e) {
      debugPrint('❌ Günlük içerik bildirimleri hatası: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (final vakit in _bildirimAcik.keys) {
        _bildirimAcik[vakit] =
            prefs.getBool('bildirim_$vakit') ?? _bildirimAcik[vakit]!;
        // Vaktinde bildirim varsayılanları: öğle, ikindi, akşam, yatsı için true
        final varsayilanVaktinde =
            (vakit == 'ogle' ||
            vakit == 'ikindi' ||
            vakit == 'aksam' ||
            vakit == 'yatsi');
        _vaktindeBildirim[vakit] =
            prefs.getBool('vaktinde_$vakit') ?? varsayilanVaktinde;
        _alarmAcik[vakit] = prefs.getBool('alarm_$vakit') ?? _alarmAcik[vakit]!;
        _erkenBildirim[vakit] =
            prefs.getInt('erken_$vakit') ?? _erkenBildirim[vakit]!;
        _bildirimSesi[vakit] =
            prefs.getString('bildirim_sesi_$vakit') ?? _bildirimSesi[vakit]!;
        // Erken bildirim sesi: kayıtlı değer yoksa vaktinde sesi kullan
        _erkenBildirimSesi[vakit] =
            prefs.getString('erken_bildirim_sesi_$vakit') ??
            _bildirimSesi[vakit]!;

        // Özel ses yollarını yükle
        final ozelSes = prefs.getString('ozel_ses_$vakit');
        if (ozelSes != null) {
          _ozelSesDosyalari[vakit] = ozelSes;
        }
        final ozelErkenSes = prefs.getString('ozel_erken_ses_$vakit');
        if (ozelErkenSes != null) {
          _ozelSesDosyalari['${vakit}_erken'] = ozelErkenSes;
        }
      }
      _gunlukIcerikBildirimleri =
          prefs.getBool('daily_content_notifications_enabled') ?? true;
      _gunlukAyetSaati = _parseTimeOfDay(
        prefs.getString('daily_content_verse_time'),
        const TimeOfDay(hour: 8, minute: 0),
      );
      _gunlukHadisSaati = _parseTimeOfDay(
        prefs.getString('daily_content_hadith_time'),
        const TimeOfDay(hour: 13, minute: 0),
      );
      _gunlukDuaSaati = _parseTimeOfDay(
        prefs.getString('daily_content_prayer_time'),
        const TimeOfDay(hour: 20, minute: 0),
      );
      _gunlukIcerikSesi =
          prefs.getString('daily_content_notification_sound') ??
          _gunlukIcerikSesi;
      _sessizeAl = prefs.getBool('sessize_al') ?? false;
      _kilitEkraniBildirimi =
          prefs.getBool('kilit_ekrani_bildirimi_aktif') ?? false;
    });
  }

  Future<void> _ayarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();

    // Bildirim izinlerini kontrol et
    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidImpl = notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      // Bildirim izni kontrolü
      final hasNotificationPermission =
          await androidImpl.areNotificationsEnabled() ?? false;
      if (!hasNotificationPermission) {
        if (mounted) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                _languageService['notification_permission_required'] ??
                    'Bildirim İzni Gerekli',
              ),
              content: Text(
                _languageService['notification_permission_message'] ??
                    'Vakit bildirimleri için bildirim izni vermeniz gerekiyor.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_languageService['give_up'] ?? 'Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_languageService['allow'] ?? 'İzin Ver'),
                ),
              ],
            ),
          );

          if (shouldRequest == true) {
            final granted = await androidImpl.requestNotificationsPermission();
            if (granted != true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _languageService['notification_permission_denied'] ??
                          'Bildirim izni verilmedi. Bildirimler çalışmayacak.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          } else {
            return;
          }
        }
      }

      // Exact alarm izni kontrolü
      final canScheduleExact =
          await androidImpl.canScheduleExactNotifications() ?? false;
      if (!canScheduleExact) {
        if (mounted) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                _languageService['exact_alarm_permission_required'] ??
                    'Tam Zamanlı Alarm İzni Gerekli',
              ),
              content: Text(
                _languageService['exact_alarm_permission_message'] ??
                    'Vakit bildirimlerinin tam zamanında çalması için alarm izni vermeniz gerekiyor.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_languageService['give_up'] ?? 'Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_languageService['allow'] ?? 'İzin Ver'),
                ),
              ],
            ),
          );

          if (shouldRequest == true) {
            await androidImpl.requestExactAlarmsPermission();
          }
        }
      }
    }

    for (final vakit in _bildirimAcik.keys) {
      await prefs.setBool('bildirim_$vakit', _bildirimAcik[vakit]!);
      await prefs.setBool('vaktinde_$vakit', _vaktindeBildirim[vakit]!);
      await prefs.setBool('alarm_$vakit', _alarmAcik[vakit]!);
      await prefs.setInt('erken_$vakit', _erkenBildirim[vakit]!);
      await prefs.setString('bildirim_sesi_$vakit', _bildirimSesi[vakit]!);
      await prefs.setString(
        'erken_bildirim_sesi_$vakit',
        _erkenBildirimSesi[vakit]!,
      );
      debugPrint(
        '💾 [$vakit] Kaydedildi: bildirim=${_bildirimAcik[vakit]}, vaktinde=${_vaktindeBildirim[vakit]}, alarm=${_alarmAcik[vakit]}, erken=${_erkenBildirim[vakit]}, ses=${_bildirimSesi[vakit]}, erkenSes=${_erkenBildirimSesi[vakit]}',
      );

      // Özel ses yollarını kaydet
      if (_ozelSesDosyalari.containsKey(vakit)) {
        await prefs.setString('ozel_ses_$vakit', _ozelSesDosyalari[vakit]!);
      }
      if (_ozelSesDosyalari.containsKey('${vakit}_erken')) {
        await prefs.setString(
          'ozel_erken_ses_$vakit',
          _ozelSesDosyalari['${vakit}_erken']!,
        );
      }
    }
    await prefs.setBool('sessize_al', _sessizeAl);
    await DailyContentNotificationService.setDailyContentNotificationSettings(
      enabled: _gunlukIcerikBildirimleri,
      soundFileName: _gunlukIcerikSesi,
      verseTime: _formatTimeOfDay(_gunlukAyetSaati),
      hadithTime: _formatTimeOfDay(_gunlukHadisSaati),
      prayerTime: _formatTimeOfDay(_gunlukDuaSaati),
    );

    // NOT: DndService artık kullanılmıyor - AlarmService "sessize_al" ayarını kontrol edip
    // telefonu sessize alıyor. Çakışma önlendi.
    // Eski DND zamanlayıcılarını temizle
    if (!_sessizeAl) {
      await DndService.cancelPrayerDnd();
    }

    // Zamanlanmış bildirimleri yeniden ayarla
    await ScheduledNotificationService.scheduleAllPrayerNotifications();
    // Günlük içerik alarmlari ayarlari yukarida guncellendi

    setState(() {
      _degisiklikYapildi = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService['notification_settings_saved'] ??
                'Bildirim ayarları kaydedildi',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleSessizeAl(bool value) async {
    // NOT: DndService artık kullanılmıyor - AlarmService "sessize_al" ayarını
    // kontrol edip telefonu sessize alıyor. Çakışma önlendi.
    // Kullanıcı "Kal/Çık" butonlarıyla sessiz modu yönetebilir.

    if (!value) {
      // Sessize al kapatıldığında eski DND zamanlayıcılarını temizle
      await DndService.cancelPrayerDnd();
    }

    if (mounted) {
      setState(() {
        _sessizeAl = value;
      });
    }
  }

  TimeOfDay _parseTimeOfDay(String? value, TimeOfDay fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickDailyContentTime({
    required TimeOfDay current,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked != null) {
      setState(() {
        onSelected(picked);
        _degisiklikYapildi = true;
      });
    }
  }

  /// Kilit ekranı bildirimi aç/kapat
  Future<void> _toggleKilitEkraniBildirimi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kilit_ekrani_bildirimi_aktif', value);

    try {
      if (value) {
        // Servisi başlat
        await _lockScreenChannel.invokeMethod('startLockScreenService');
        debugPrint('✅ Kilit ekranı bildirimi servisi başlatıldı');
      } else {
        // Servisi durdur
        await _lockScreenChannel.invokeMethod('stopLockScreenService');
        debugPrint('🛑 Kilit ekranı bildirimi servisi durduruldu');
      }
    } catch (e) {
      debugPrint('❌ Kilit ekranı bildirimi hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _languageService['lock_screen_error'] ??
                  'Kilit ekranı bildirimi ayarlanamadı',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _kilitEkraniBildirimi = !value; // Geri al
        });
      }
    }
  }

  Future<void> _sesCal(String key, String sesDosyasi) async {
    try {
      if (_sesCalanKey == key) {
        // Aynı tuşa basıldıysa durdur
        await _audioPlayer.stop();
        setState(() => _sesCalanKey = null);
      } else {
        // Farklı tuşa basıldıysa önce durdur sonra yenisini çal
        await _audioPlayer.stop();

        if (sesDosyasi == 'custom' && _ozelSesDosyalari.containsKey(key)) {
          // Özel ses çal
          await _audioPlayer.play(DeviceFileSource(_ozelSesDosyalari[key]!));
        } else if (sesDosyasi != 'custom') {
          // Asset ses çal - dosya adını düzgün kullan
          await _audioPlayer.play(AssetSource('sounds/$sesDosyasi'));
        }

        setState(() => _sesCalanKey = key);

        // Ses bitince otomatik toggle
        _audioPlayer.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            setState(() => _sesCalanKey = null);
          }
        });
      }
    } catch (e) {
      setState(() => _sesCalanKey = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_languageService['sound_error'] ?? 'Ses hatası'}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _ozelSesSec(String key) async {
    final isErken = key.endsWith('_erken');
    final baseKey = isErken ? key.replaceFirst('_erken', '') : key;
    // Önce kullanıcıyı bilgilendir
    final devam = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageService['custom_sound_title'] ?? 'Özel Ses Seçimi',
        ),
        content: Text(
          _languageService['custom_sound_info'] ??
              'Telefonunuzdan bir ses dosyası seçebilirsiniz.\n\n'
                  'Desteklenen formatlar:\n'
                  '• MP3\n'
                  '• WAV\n'
                  '• OGG\n'
                  '• M4A\n\n'
                  'Seçtiğiniz ses dosyası uygulama içine kopyalanacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService['cancel'] ?? 'İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_languageService['select_file'] ?? 'Dosya Seç'),
          ),
        ],
      ),
    );

    if (devam != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final secilenDosyaYolu = result.files.single.path!;

        // Dosyayı güvenli isimle uygulamanın dizinine kopyala
        final guvenliDosyaYolu = await _copyCustomSoundFile(
          secilenDosyaYolu,
          key,
        );

        if (guvenliDosyaYolu != null) {
          setState(() {
            _ozelSesDosyalari[key] = guvenliDosyaYolu;
            if (isErken) {
              _erkenBildirimSesi[baseKey] = 'custom';
            } else {
              _bildirimSesi[baseKey] = 'custom';
            }
            _degisiklikYapildi = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _languageService['custom_sound_selected'] ??
                      'Özel ses seçildi',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Seçilen sesi çal
          await _sesCal(key, 'custom');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _languageService['custom_sound_copy_error'] ??
                      'Ses dosyası kopyalanamadı',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Kullanıcı iptal etti, önceki seçimi koru
        if (mounted) {
          setState(() {
            // Eğer custom seçiliyse ve dosya yoksa, varsayılan sese dön
            if (isErken) {
              if (_erkenBildirimSesi[baseKey] == 'custom' &&
                  !_ozelSesDosyalari.containsKey(key)) {
                _erkenBildirimSesi[baseKey] = _sesSecenekleri.first['dosya']!;
              }
            } else {
              if (_bildirimSesi[baseKey] == 'custom' &&
                  !_ozelSesDosyalari.containsKey(key)) {
                _bildirimSesi[baseKey] = _sesSecenekleri.first['dosya']!;
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_languageService['sound_select_error'] ?? 'Ses seçilemedi'}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showDndPermissionDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B3151),
          title: Text(
            _languageService['dnd_permission_title'] ?? 'Sessize Alma İzni',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            _languageService['dnd_permission_message'] ??
                'Vakitlerde sessize almak için sistem izni gerekiyor. İzin vermek ister misiniz?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                _languageService['give_up'] ?? 'Vazgeç',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
              ),
              child: Text(
                _languageService['allow'] ?? 'İzin Ver',
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_degisiklikYapildi) {
          final kaydet = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2B3151),
              title: Text(
                _languageService['save_changes_title'] ??
                    'Değişiklikleri Kaydet?',
                style: const TextStyle(color: Colors.white),
              ),
              content: Text(
                _languageService['save_changes_message'] ??
                    'Yaptığınız değişiklikler kaydedilsin mi?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    _languageService['dont_save'] ?? 'Kaydetme',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                  ),
                  child: Text(
                    _languageService['save'] ?? 'Kaydet',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          );

          if (kaydet == true) {
            await _ayarlariKaydet();
          }
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1B2741),
        appBar: AppBar(
          title: Text(
            _languageService['notification_settings_title'] ??
                'Bildirim Ayarları',
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _ayarlariKaydet,
              tooltip: _languageService['save'] ?? 'Kaydet',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bilgilendirme kartı
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.cyanAccent),
                      const SizedBox(width: 12),
                      Text(
                        _languageService['notification_alarm_system'] ??
                            'Bildirim ve Alarm Sistemi',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _languageService['notification_info_text'] ??
                        '• Her vakit için bildirimi açıp kapatabilirsiniz\n'
                            '• "Vaktinde Hatırlat" ile sesli alarm kurabilirsiniz\n'
                            '• Erken hatırlatma ile vakitten önce uyarı alabilirsiniz\n'
                            '• Alarmlar 7 gün önceden otomatik zamanlanır\n'
                            '• Uygulama arka planda alarmları günceller',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Vakitlerde sessize al seçeneği
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_off, color: Colors.orangeAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _languageService['mute_during_prayer'] ??
                              'Vakitlerde sessize al',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _sessizeAl,
                        onChanged: (value) async {
                          setState(() {
                            _degisiklikYapildi = true;
                          });
                          await _toggleSessizeAl(value);
                        },
                        activeThumbColor: Colors.orangeAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 36,
                      right: 12,
                      bottom: 6,
                    ),
                    child: Text(
                      _languageService['mute_during_prayer_desc'] ??
                          'Cuma namazı 60 dk, diğer vakitler 30 dk. Çık/Kal butonlu bildirim gösterilir.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Günlük içerik alarmları
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.tealAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _languageService['daily_content_notifications'] ??
                              'Günlük İçerik Alarmları',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _gunlukIcerikBildirimleri,
                        onChanged: (value) async {
                          setState(() {
                            _gunlukIcerikBildirimleri = value;
                            _degisiklikYapildi = true;
                          });
                        },
                        activeThumbColor: Colors.tealAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 36,
                      right: 12,
                      bottom: 6,
                    ),
                    child: Text(
                      _languageService['daily_content_notifications_desc'] ??
                          'Her gun secilen saatlerde gunun ayeti, hadisi ve duasi alarm olarak calar.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Alarm zamanlari
                  Padding(
                    padding: const EdgeInsets.only(left: 36, right: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('📖', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_verse_label'] ??
                                  'Günün Ayeti:',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _pickDailyContentTime(
                                current: _gunlukAyetSaati,
                                onSelected: (value) {
                                  _gunlukAyetSaati = value;
                                },
                              ),
                              child: Text(
                                _formatTimeOfDay(_gunlukAyetSaati),
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('📿', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_hadith_label'] ??
                                  'Günün Hadisi:',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _pickDailyContentTime(
                                current: _gunlukHadisSaati,
                                onSelected: (value) {
                                  _gunlukHadisSaati = value;
                                },
                              ),
                              child: Text(
                                _formatTimeOfDay(_gunlukHadisSaati),
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('🤲', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_dua_label'] ??
                                  'Günün Duası:',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _pickDailyContentTime(
                                current: _gunlukDuaSaati,
                                onSelected: (value) {
                                  _gunlukDuaSaati = value;
                                },
                              ),
                              child: Text(
                                _formatTimeOfDay(_gunlukDuaSaati),
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.music_note,
                              color: Colors.tealAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['daily_content_alarm_sound'] ??
                                  'Alarm Sesi:',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 160,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _gunlukIcerikSesSecenekleri.any(
                                        (s) =>
                                            s['dosya'] == _gunlukIcerikSesi,
                                      )
                                      ? _gunlukIcerikSesi
                                      : _gunlukIcerikSesSecenekleri
                                          .first['dosya'],
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2B3151),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.tealAccent,
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  items:
                                      _gunlukIcerikSesSecenekleri.map((ses) {
                                    return DropdownMenuItem(
                                      value: ses['dosya'],
                                      child: Text(
                                        ses['ad']!,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _gunlukIcerikSesi = value;
                                      _degisiklikYapildi = true;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Kilit ekranı bildirimi seçeneği
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_clock, color: Colors.purpleAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _languageService['lock_screen_notification'] ??
                              'Kilit Ekranı Bildirimi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _kilitEkraniBildirimi,
                        onChanged: (value) async {
                          setState(() {
                            _kilitEkraniBildirimi = value;
                            _degisiklikYapildi = true;
                          });
                          await _toggleKilitEkraniBildirimi(value);
                        },
                        activeThumbColor: Colors.purpleAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 36,
                      right: 12,
                      bottom: 6,
                    ),
                    child: Text(
                      _languageService['lock_screen_notification_desc'] ??
                          'Kilit ekranında hangi vakitten hangi vakte geçildiği ve kalan süreyi gösterir. Uygulama kapalıyken de çalışır.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tümünü aç/kapat butonları
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final key in _bildirimAcik.keys) {
                          _bildirimAcik[key] = true;
                        }
                        _degisiklikYapildi = true;
                      });
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: Text(
                      _languageService['enable_all_notifications'] ??
                          'Tümünü Aç',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      side: const BorderSide(color: Colors.cyanAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final key in _bildirimAcik.keys) {
                          _bildirimAcik[key] = false;
                        }
                        _degisiklikYapildi = true;
                      });
                    },
                    icon: const Icon(Icons.notifications_off),
                    label: Text(
                      _languageService['disable_all_notifications'] ??
                          'Tümünü Kapat',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Vakit bildirimleri
            _vakitBildirimKarti(
              _languageService['imsak'] ?? 'İmsak',
              'imsak',
              Icons.nightlight_round,
              _languageService['imsak_desc'] ?? 'Sahur için uyanma vakti',
            ),
            _vakitBildirimKarti(
              _languageService['gunes'] ?? 'Güneş',
              'gunes',
              Icons.wb_sunny,
              _languageService['gunes_desc'] ?? 'Güneşin doğuş vakti',
            ),
            _vakitBildirimKarti(
              _languageService['ogle'] ?? 'Öğle',
              'ogle',
              Icons.light_mode,
              _languageService['ogle_desc'] ?? 'Öğle namazı vakti',
            ),
            _vakitBildirimKarti(
              _languageService['ikindi'] ?? 'İkindi',
              'ikindi',
              Icons.brightness_6,
              _languageService['ikindi_desc'] ?? 'İkindi namazı vakti',
            ),
            _vakitBildirimKarti(
              _languageService['aksam'] ?? 'Akşam',
              'aksam',
              Icons.wb_twilight,
              _languageService['aksam_desc'] ?? 'Akşam namazı ve iftar vakti',
            ),
            _vakitBildirimKarti(
              _languageService['yatsi'] ?? 'Yatsı',
              'yatsi',
              Icons.nights_stay,
              _languageService['yatsi_desc'] ?? 'Yatsı namazı vakti',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _vakitBildirimKarti(
    String baslik,
    String key,
    IconData icon,
    String aciklama,
  ) {
    final acik = _bildirimAcik[key]!;
    final vaktindeAcik = _vaktindeBildirim[key]!;
    final erkenDakika = _erkenBildirim[key]!;
    final seciliSes = _bildirimSesi[key]!;
    final erkenSeciliSes = _erkenBildirimSesi[key]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: acik
            ? Colors.cyanAccent.withOpacity(0.05)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: acik ? Colors.cyanAccent.withOpacity(0.3) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          // Üst kısım - Switch
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: acik
                    ? Colors.cyanAccent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: acik ? Colors.cyanAccent : Colors.white54,
              ),
            ),
            title: Text(
              baslik,
              style: TextStyle(
                color: acik ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              aciklama,
              style: TextStyle(
                color: acik ? Colors.white54 : Colors.white38,
                fontSize: 12,
              ),
            ),
            trailing: Switch(
              value: acik,
              onChanged: (value) {
                setState(() {
                  _bildirimAcik[key] = value;
                  _degisiklikYapildi = true;
                });
              },
              activeThumbColor: Colors.cyanAccent,
            ),
          ),

          // Alt kısım - Vaktinde bildirim, erken bildirim ve ses seçimi
          if (acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Vaktinde Hatırlat - Tam vakitte bildirim
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: vaktindeAcik
                          ? Colors.orangeAccent.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: vaktindeAcik
                            ? Colors.orangeAccent.withOpacity(0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: vaktindeAcik
                              ? Colors.orangeAccent
                              : Colors.white54,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _languageService['notify_at_prayer'] ??
                                'Vaktinde Hatırlat',
                            style: TextStyle(
                              color: vaktindeAcik
                                  ? Colors.orangeAccent
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: vaktindeAcik,
                          onChanged: (value) {
                            setState(() {
                              _vaktindeBildirim[key] = value;
                              _degisiklikYapildi = true;
                            });
                          },
                          activeThumbColor: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _languageService['early_reminder'] ??
                            'Erken hatırlatma:',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: erkenDakika,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2B3151),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.cyanAccent,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              style: const TextStyle(color: Colors.white),
                              items: _erkenSureler.map((dakika) {
                                String label;
                                if (dakika == 0) {
                                  label = _languageService['none'] ?? 'Yok';
                                } else if (dakika < 60) {
                                  label =
                                      '$dakika ${_languageService['minutes_before'] ?? 'dk önce'}';
                                } else {
                                  label =
                                      '${dakika ~/ 60} ${_languageService['hours_before'] ?? 'saat önce'}';
                                }
                                return DropdownMenuItem(
                                  value: dakika,
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _erkenBildirim[key] = value;
                                    _degisiklikYapildi = true;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // === VAKTİNDE ALARM SESİ ===
                  if (vaktindeAcik) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.alarm,
                                color: Colors.orangeAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _languageService['on_time_sound'] ??
                                    'Vaktinde Alarm Sesi:',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value:
                                          _sesSecenekleri.any(
                                            (s) => s['dosya'] == seciliSes,
                                          )
                                          ? seciliSes
                                          : _sesSecenekleri.first['dosya'],
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF2B3151),
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.orangeAccent,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      items: _sesSecenekleri.map((ses) {
                                        return DropdownMenuItem(
                                          value: ses['dosya'],
                                          child: Text(ses['ad']!),
                                        );
                                      }).toList(),
                                      onChanged: (value) async {
                                        if (value != null) {
                                          if (value == 'custom') {
                                            await _ozelSesSec(key);
                                          } else {
                                            setState(() {
                                              final eskiSes = _bildirimSesi[key]!;
                                              _bildirimSesi[key] = value;
                                              // Erken ses eski vaktinde ses ile aynıysa, yeni sese senkronla
                                              if (_erkenBildirimSesi[key] == eskiSes) {
                                                _erkenBildirimSesi[key] = value;
                                              }
                                              _degisiklikYapildi = true;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: _sesCalanKey == key
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  onPressed: () => _sesCal(key, seciliSes),
                                  icon: Icon(
                                    _sesCalanKey == key
                                        ? Icons.stop_circle
                                        : Icons.play_circle,
                                    color: _sesCalanKey == key
                                        ? Colors.red
                                        : Colors.green,
                                    size: 28,
                                  ),
                                  tooltip: _sesCalanKey == key
                                      ? (_languageService['stop'] ?? 'Durdur')
                                      : (_languageService['listen'] ?? 'Dinle'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (seciliSes == 'custom' &&
                              _ozelSesDosyalari.containsKey(key))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_languageService['custom'] ?? 'Özel'}: ${_ozelSesDosyalari[key]!.split('/').last.split('\\').last}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // === ERKEN BİLDİRİM SESİ ===
                  if (erkenDakika > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.timer,
                                color: Colors.cyanAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _languageService['early_sound'] ??
                                    'Erken Hatırlatma Sesi:',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value:
                                          _sesSecenekleri.any(
                                            (s) => s['dosya'] == erkenSeciliSes,
                                          )
                                          ? erkenSeciliSes
                                          : _sesSecenekleri.first['dosya'],
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF2B3151),
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.cyanAccent,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      items: _sesSecenekleri.map((ses) {
                                        return DropdownMenuItem(
                                          value: ses['dosya'],
                                          child: Text(ses['ad']!),
                                        );
                                      }).toList(),
                                      onChanged: (value) async {
                                        if (value != null) {
                                          if (value == 'custom') {
                                            await _ozelSesSec('${key}_erken');
                                          } else {
                                            setState(() {
                                              _erkenBildirimSesi[key] = value;
                                              _degisiklikYapildi = true;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: _sesCalanKey == '${key}_erken'
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  onPressed: () =>
                                      _sesCal('${key}_erken', erkenSeciliSes),
                                  icon: Icon(
                                    _sesCalanKey == '${key}_erken'
                                        ? Icons.stop_circle
                                        : Icons.play_circle,
                                    color: _sesCalanKey == '${key}_erken'
                                        ? Colors.red
                                        : Colors.green,
                                    size: 28,
                                  ),
                                  tooltip: _sesCalanKey == '${key}_erken'
                                      ? (_languageService['stop'] ?? 'Durdur')
                                      : (_languageService['listen'] ?? 'Dinle'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (erkenSeciliSes == 'custom' &&
                              _ozelSesDosyalari.containsKey('${key}_erken'))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_languageService['custom'] ?? 'Özel'}: ${_ozelSesDosyalari['${key}_erken']!.split('/').last.split('\\').last}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
