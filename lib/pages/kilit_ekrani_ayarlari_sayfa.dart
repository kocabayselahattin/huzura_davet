import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/home_widget_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class KilitEkraniAyarlariSayfa extends StatefulWidget {
  const KilitEkraniAyarlariSayfa({super.key});

  @override
  State<KilitEkraniAyarlariSayfa> createState() => _KilitEkraniAyarlariSayfaState();
}

class _KilitEkraniAyarlariSayfaState extends State<KilitEkraniAyarlariSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  bool _kilitEkraniBildirimiAktif = false;
  bool _ecirBariGoster = true;
  int _secilenStilIndex = 0;
  bool _yukleniyor = true;
  
  // Stil seçenekleri
  final List<Map<String, dynamic>> _stilSecenekleri = [
    {
      'isim': 'Kompakt',
      'key': 'compact',
      'aciklama': 'Sonraki vakit ve geri sayım',
      'icon': Icons.view_compact,
    },
    {
      'isim': 'Detaylı',
      'key': 'detailed',
      'aciklama': 'Tüm vakitler ve tarih',
      'icon': Icons.view_list,
    },
    {
      'isim': 'Minimal',
      'key': 'minimal',
      'aciklama': 'Sadece sonraki vakit',
      'icon': Icons.minimize,
    },
    {
      'isim': 'Tam Vakit',
      'key': 'full',
      'aciklama': '6 vakit saati ile',
      'icon': Icons.calendar_view_day,
    },
  ];

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onChanged);
    _languageService.addListener(_onChanged);
    _ayarlariYukle();
  }

  @override
  void dispose() {
    _temaService.removeListener(_onChanged);
    _languageService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _kilitEkraniBildirimiAktif = prefs.getBool('kilit_ekrani_bildirimi_aktif') ?? false;
      _ecirBariGoster = prefs.getBool('kilit_ekrani_ecir_bari') ?? true;
      final stilKey = prefs.getString('kilit_ekrani_stili') ?? 'compact';
      _secilenStilIndex = _stilSecenekleri.indexWhere((s) => s['key'] == stilKey);
      if (_secilenStilIndex < 0) _secilenStilIndex = 0;
      _yukleniyor = false;
    });
    
    // Aktifse bildirimi güncelle
    if (_kilitEkraniBildirimiAktif) {
      _bildirimiGuncelle();
    }
  }

  Future<void> _ayarlariKayDet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kilit_ekrani_bildirimi_aktif', _kilitEkraniBildirimiAktif);
    await prefs.setBool('kilit_ekrani_ecir_bari', _ecirBariGoster);
    await prefs.setString('kilit_ekrani_stili', _stilSecenekleri[_secilenStilIndex]['key']);
    
    if (_kilitEkraniBildirimiAktif) {
      await _bildirimiGuncelle();
    } else {
      await _bildirimiKapat();
    }
  }

  Future<void> _bildirimiGuncelle() async {
    try {
      // Konum ve vakit bilgilerini al
      final ilceId = await KonumService.getIlceId();
      final il = await KonumService.getIl();
      final ilce = await KonumService.getIlce();
      
      if (ilceId == null) {
        _uyariGoster(_languageService['location_not_found'] ?? 'Konum bilgisi bulunamadı');
        return;
      }
      
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (vakitler == null) {
        _uyariGoster(_languageService['prayer_times_not_found'] ?? 'Vakit bilgisi alınamadı');
        return;
      }
      
      // Bildirim içeriğini oluştur
      final stilKey = _stilSecenekleri[_secilenStilIndex]['key'];
      final baslik = _olustrBaslik(stilKey, il, ilce);
      final icerik = _olusturIcerik(stilKey, vakitler);
      
      // Ongoing notification kanalı oluştur
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        const channel = AndroidNotificationChannel(
          'kilit_ekrani_channel',
          'Kilit Ekranı Bildirimi',
          description: 'Kilit ekranında namaz vakitlerini gösterir',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );
        await androidImplementation.createNotificationChannel(channel);
      }
      
      // Bildirimi göster
      final androidDetails = AndroidNotificationDetails(
        'kilit_ekrani_channel',
        'Kilit Ekranı Bildirimi',
        channelDescription: 'Kilit ekranında namaz vakitlerini gösterir',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true, // Sürekli bildirim
        autoCancel: false,
        showWhen: false,
        visibility: NotificationVisibility.public, // Kilit ekranında görünür
        category: AndroidNotificationCategory.service,
        styleInformation: _ecirBariGoster 
            ? BigTextStyleInformation(
                icerik,
                contentTitle: baslik,
                summaryText: _languageService['lock_screen_widget'] ?? 'Kilit Ekranı Widget',
              )
            : null,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );
      
      await _notificationsPlugin.show(
        9999, // Sabit ID
        baslik,
        _ecirBariGoster ? null : icerik,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Kilit ekranı bildirimi hatası: $e');
    }
  }

  Future<void> _bildirimiKapat() async {
    await _notificationsPlugin.cancel(9999);
  }

  String _olustrBaslik(String stilKey, String? il, String? ilce) {
    final konum = il != null && ilce != null ? '$il / $ilce' : (il ?? 'Konum');
    switch (stilKey) {
      case 'minimal':
        return _languageService['next_prayer'] ?? 'Sonraki Vakit';
      case 'detailed':
      case 'full':
        return '📍 $konum';
      default:
        return '🕌 ${_languageService['app_name'] ?? 'Huzur Vakti'}';
    }
  }

  String _olusturIcerik(String stilKey, Map<String, dynamic> vakitler) {
    final imsak = vakitler['Imsak'] ?? '-';
    final gunes = vakitler['Gunes'] ?? '-';
    final ogle = vakitler['Ogle'] ?? '-';
    final ikindi = vakitler['Ikindi'] ?? '-';
    final aksam = vakitler['Aksam'] ?? '-';
    final yatsi = vakitler['Yatsi'] ?? '-';
    
    // Sonraki vakti hesapla
    final now = DateTime.now();
    final vakitMap = {
      _languageService['imsak'] ?? 'İmsak': imsak,
      _languageService['gunes'] ?? 'Güneş': gunes,
      _languageService['ogle'] ?? 'Öğle': ogle,
      _languageService['ikindi'] ?? 'İkindi': ikindi,
      _languageService['aksam'] ?? 'Akşam': aksam,
      _languageService['yatsi'] ?? 'Yatsı': yatsi,
    };
    
    String sonrakiVakit = '';
    String sonrakiSaat = '';
    
    for (final entry in vakitMap.entries) {
      final parts = entry.value.split(':');
      if (parts.length == 2) {
        final saat = int.tryParse(parts[0]) ?? 0;
        final dakika = int.tryParse(parts[1]) ?? 0;
        final vakitZamani = DateTime(now.year, now.month, now.day, saat, dakika);
        if (vakitZamani.isAfter(now)) {
          sonrakiVakit = entry.key;
          sonrakiSaat = entry.value;
          break;
        }
      }
    }
    
    if (sonrakiVakit.isEmpty) {
      sonrakiVakit = _languageService['imsak'] ?? 'İmsak';
      sonrakiSaat = imsak;
    }
    
    final kalanSure = _hesaplaKalanSure(sonrakiSaat);
    
    switch (stilKey) {
      case 'minimal':
        return '$sonrakiVakit: $sonrakiSaat ($kalanSure ${_languageService['remaining'] ?? 'kaldı'})';
      case 'compact':
        return '⏰ $sonrakiVakit $sonrakiSaat\n⏳ $kalanSure ${_languageService['remaining'] ?? 'kaldı'}';
      case 'detailed':
        return '⏰ $sonrakiVakit: $sonrakiSaat ($kalanSure)\n'
               '🌅 ${_languageService['imsak'] ?? 'İmsak'}: $imsak  ☀️ ${_languageService['gunes'] ?? 'Güneş'}: $gunes\n'
               '🌤️ ${_languageService['ogle'] ?? 'Öğle'}: $ogle  🌇 ${_languageService['ikindi'] ?? 'İkindi'}: $ikindi\n'
               '🌆 ${_languageService['aksam'] ?? 'Akşam'}: $aksam  🌙 ${_languageService['yatsi'] ?? 'Yatsı'}: $yatsi';
      case 'full':
        return '⏰ Sonraki: $sonrakiVakit $sonrakiSaat ($kalanSure)\n'
               '${_languageService['imsak'] ?? 'İmsak'}: $imsak | ${_languageService['gunes'] ?? 'Güneş'}: $gunes | ${_languageService['ogle'] ?? 'Öğle'}: $ogle\n'
               '${_languageService['ikindi'] ?? 'İkindi'}: $ikindi | ${_languageService['aksam'] ?? 'Akşam'}: $aksam | ${_languageService['yatsi'] ?? 'Yatsı'}: $yatsi';
      default:
        return '$sonrakiVakit: $sonrakiSaat ($kalanSure)';
    }
  }

  String _hesaplaKalanSure(String hedefSaat) {
    final parts = hedefSaat.split(':');
    if (parts.length != 2) return '-';
    
    final now = DateTime.now();
    final hedef = DateTime(
      now.year, now.month, now.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
    
    var fark = hedef.difference(now);
    if (fark.isNegative) {
      // Yarına
      fark = hedef.add(const Duration(days: 1)).difference(now);
    }
    
    final saat = fark.inHours;
    final dakika = fark.inMinutes % 60;
    
    if (saat > 0) {
      return '$saat ${_languageService['hour_short'] ?? 'sa'} $dakika ${_languageService['minute_short'] ?? 'dk'}';
    }
    return '$dakika ${_languageService['minute_short'] ?? 'dk'}';
  }

  void _uyariGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    
    if (_yukleniyor) {
      return Scaffold(
        backgroundColor: renkler.arkaPlan,
        appBar: AppBar(
          title: Text(
            _languageService['lock_screen_widget'] ?? 'Kilit Ekranı Widget',
            style: TextStyle(color: renkler.yaziPrimary),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: renkler.yaziPrimary),
        ),
        body: Center(child: CircularProgressIndicator(color: renkler.vurgu)),
      );
    }
    
    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _languageService['lock_screen_widget'] ?? 'Kilit Ekranı Widget',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Açıklama kartı
          _bilgiKarti(renkler),
          const SizedBox(height: 20),
          
          // Ana anahtar
          _anaAyarKarti(renkler),
          const SizedBox(height: 20),
          
          // Önizleme (hemen ana ayarın altında)
          if (_kilitEkraniBildirimiAktif) ...[
            _onizlemeKarti(renkler),
            const SizedBox(height: 20),
            
            // Stil seçimi
            _stilSecimKarti(renkler),
            const SizedBox(height: 20),
            
            // Ecir barı
            _ecirBariKarti(renkler),
          ],
        ],
      ),
    );
  }

  Widget _bilgiKarti(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.vurgu.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renkler.vurgu.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: renkler.vurgu, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _languageService['lock_screen_widget_info'] ?? 
              'Kilit ekranında sürekli olarak namaz vakitlerini gösteren bir bildirim oluşturur. Telefonunuzu açmadan vakitleri görebilirsiniz.',
              style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anaAyarKarti(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kilitEkraniBildirimiAktif 
                  ? renkler.vurgu.withValues(alpha: 0.15) 
                  : renkler.arkaPlan,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.lock_clock,
              color: _kilitEkraniBildirimiAktif ? renkler.vurgu : renkler.yaziSecondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _languageService['lock_screen_notification'] ?? 'Kilit Ekranı Bildirimi',
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _kilitEkraniBildirimiAktif 
                      ? (_languageService['active'] ?? 'Aktif')
                      : (_languageService['inactive'] ?? 'Kapalı'),
                  style: TextStyle(
                    color: _kilitEkraniBildirimiAktif ? renkler.vurgu : renkler.yaziSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _kilitEkraniBildirimiAktif,
            onChanged: (value) {
              setState(() {
                _kilitEkraniBildirimiAktif = value;
              });
              _ayarlariKayDet();
            },
            activeColor: renkler.vurgu,
          ),
        ],
      ),
    );
  }

  Widget _stilSecimKarti(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService['notification_style'] ?? 'Bildirim Stili',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_stilSecenekleri.length, (index) {
            final stil = _stilSecenekleri[index];
            final secili = index == _secilenStilIndex;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _secilenStilIndex = index;
                });
                _ayarlariKayDet();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secili ? renkler.vurgu.withValues(alpha: 0.15) : renkler.arkaPlan,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: secili ? renkler.vurgu : renkler.ayirac.withValues(alpha: 0.3),
                    width: secili ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      stil['icon'] as IconData,
                      color: secili ? renkler.vurgu : renkler.yaziSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stil['isim'] as String,
                            style: TextStyle(
                              color: renkler.yaziPrimary,
                              fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            stil['aciklama'] as String,
                            style: TextStyle(
                              color: renkler.yaziSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (secili)
                      Icon(Icons.check_circle, color: renkler.vurgu),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _ecirBariKarti(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: renkler.vurgu),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _languageService['reward_bar'] ?? 'Ecir Barı',
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _languageService['reward_bar_desc'] ?? 'Detaylı bildirim içeriği göster',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _ecirBariGoster,
            onChanged: (value) {
              setState(() {
                _ecirBariGoster = value;
              });
              _ayarlariKayDet();
            },
            activeColor: renkler.vurgu,
          ),
        ],
      ),
    );
  }

  Widget _buildEcirBar(double progress, TemaRenkleri renkler) {
    Color calculateColor(double progress) {
      if (progress > 0.5) {
        return Color.lerp(Colors.green, Colors.yellow, 1 - progress)!;
      } else {
        return Color.lerp(Colors.yellow, Colors.red, 1 - progress)!;
      }
    }

    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          colors: [
            calculateColor(progress),
            calculateColor(progress * 0.8),
          ],
        ),
      ),
    );
  }

  Widget _onizlemeKarti(TemaRenkleri renkler) {
    final stilKey = _stilSecenekleri[_secilenStilIndex]['key'] as String;
    final now = DateTime.now();
    final nextPrayerTime = _getNextPrayerTime();
    final totalDuration = nextPrayerTime.difference(now).inSeconds;
    final progress = totalDuration > 0 ? 1 - (totalDuration / (24 * 60 * 60)) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService['preview'] ?? 'Önizleme',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Bildirim önizlemesi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: renkler.vurgu,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mosque, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getOnizlemeBaslik(stilKey),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildEcirBar(progress.toDouble(), renkler),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getOnizlemeIcerik(stilKey),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
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
    );
  }

  String _getOnizlemeBaslik(String stilKey) {
    switch (stilKey) {
      case 'minimal':
        return _languageService['next_prayer'] ?? 'Sonraki Vakit';
      case 'detailed':
      case 'full':
        return '📍 İstanbul / Kadıköy';
      default:
        return '🕌 ${_languageService['app_name'] ?? 'Huzur Vakti'}';
    }
  }

  String _getOnizlemeIcerik(String stilKey) {
    final kalanSure = '2 sa 15 dk';
    switch (stilKey) {
      case 'minimal':
        return '${_languageService['ogle'] ?? 'Öğle'}: 12:30 ($kalanSure ${_languageService['remaining'] ?? 'kaldı'})';
      case 'compact':
        return '⏰ ${_languageService['ogle'] ?? 'Öğle'} 12:30\n⏳ $kalanSure ${_languageService['remaining'] ?? 'kaldı'}';
      case 'detailed':
        return '⏰ ${_languageService['ogle'] ?? 'Öğle'}: 12:30 ($kalanSure)\n'
               '🌅 İmsak: 05:30  ☀️ Güneş: 07:00\n'
               '🌤️ Öğle: 12:30  🌇 İkindi: 15:30\n'
               '🌆 Akşam: 18:00  🌙 Yatsı: 19:30';
      case 'full':
        return '⏰ Sonraki: ${_languageService['ogle'] ?? 'Öğle'} 12:30 ($kalanSure)\n'
               'İmsak: 05:30 | Güneş: 07:00 | Öğle: 12:30\n'
               'İkindi: 15:30 | Akşam: 18:00 | Yatsı: 19:30';
      default:
        return '${_languageService['ogle'] ?? 'Öğle'}: 12:30 ($kalanSure)';
    }
  }

  DateTime _getNextPrayerTime() {
    // Logic to calculate the next prayer time dynamically
    final now = DateTime.now();
    final prayerTimes = [
      DateTime(now.year, now.month, now.day, 5, 30), // Example times
      DateTime(now.year, now.month, now.day, 12, 30),
      DateTime(now.year, now.month, now.day, 15, 30),
      DateTime(now.year, now.month, now.day, 18, 0),
      DateTime(now.year, now.month, now.day, 19, 30),
    ];

    for (final time in prayerTimes) {
      if (time.isAfter(now)) {
        return time;
      }
    }

    // If no future prayer times, return the first prayer time of the next day
    return prayerTimes.first.add(const Duration(days: 1));
  }
}
