import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/dnd_service.dart';
import '../services/scheduled_notification_service.dart';
import '../services/permission_service.dart';

class BildirimAyarlariSayfa extends StatefulWidget {
  const BildirimAyarlariSayfa({super.key});

  @override
  State<BildirimAyarlariSayfa> createState() => _BildirimAyarlariSayfaState();
}

class _BildirimAyarlariSayfaState extends State<BildirimAyarlariSayfa> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Bildirim açık/kapalı durumları
  Map<String, bool> _bildirimAcik = {
    'imsak': true,
    'gunes': false,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Vaktinde bildirim (tam vakitte göster)
  Map<String, bool> _vaktindeBildirim = {
    'imsak': false,
    'gunes': false,
    'ogle': false,
    'ikindi': false,
    'aksam': false,
    'yatsi': false,
  };

  // Vakitlerde sessize al seçeneği
  bool _sessizeAl = false;

  // Değişiklik takibi
  bool _degisiklikYapildi = false;

  // Erken bildirim süreleri (dakika)
  Map<String, int> _erkenBildirim = {
    'imsak': 30,
    'gunes': 0,
    'ogle': 15,
    'ikindi': 15,
    'aksam': 15,
    'yatsi': 15,
  };

  // Bildirim sesi seçimi (her vakit için)
  Map<String, String> _bildirimSesi = {
    'imsak': 'Ding_Dong.mp3',
    'gunes': 'arriving.mp3',
    'ogle': 'Echo.mp3',
    'ikindi': 'Sweet_Favour.mp3',
    'aksam': 'Violet.mp3',
    'yatsi': 'Woodpecker.mp3',
  };

  final List<int> _erkenSureler = [0, 5, 10, 15, 20, 30, 45, 60];
  final List<Map<String, String>> _sesSecenekleri = [
    {'ad': 'Best', 'dosya': '2015_best.mp3'},
    {'ad': 'Arriving', 'dosya': 'arriving.mp3'},
    {'ad': 'Corner', 'dosya': 'Corner.mp3'},
    {'ad': 'Ding Dong', 'dosya': 'Ding_Dong.mp3'},
    {'ad': 'Echo', 'dosya': 'Echo.mp3'},
    {'ad': 'iPhone SMS', 'dosya': 'iphone_sms_original.mp3'},
    {'ad': 'Snaps', 'dosya': 'snaps.mp3'},
    {'ad': 'Sweet Favour', 'dosya': 'Sweet_Favour.mp3'},
    {'ad': 'Violet', 'dosya': 'Violet.mp3'},
    {'ad': 'Woodpecker', 'dosya': 'Woodpecker.mp3'},
    {'ad': 'Özel Ses Seç', 'dosya': 'custom'},
  ];

  // Özel ses yolları
  Map<String, String> _ozelSesDosyalari = {};

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
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
        _vaktindeBildirim[vakit] = prefs.getBool('vaktinde_$vakit') ?? false;
        _erkenBildirim[vakit] =
            prefs.getInt('erken_$vakit') ?? _erkenBildirim[vakit]!;
        _bildirimSesi[vakit] =
            prefs.getString('bildirim_sesi_$vakit') ?? _bildirimSesi[vakit]!;

        // Özel ses yollarını yükle
        final ozelSes = prefs.getString('ozel_ses_$vakit');
        if (ozelSes != null) {
          _ozelSesDosyalari[vakit] = ozelSes;
        }
      }
      _sessizeAl = prefs.getBool('sessize_al') ?? false;
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
              title: const Text('Bildirim İzni Gerekli'),
              content: const Text(
                'Vakit bildirimleri için bildirim izni vermeniz gerekiyor.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('İzin Ver'),
                ),
              ],
            ),
          );

          if (shouldRequest == true) {
            final granted = await androidImpl.requestNotificationsPermission();
            if (granted != true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
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
              title: const Text('Tam Zamanlı Alarm İzni Gerekli'),
              content: const Text(
                'Vakit bildirimlerinin tam zamanında çalması için alarm izni vermeniz gerekiyor.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('İzin Ver'),
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
      await prefs.setInt('erken_$vakit', _erkenBildirim[vakit]!);
      await prefs.setString('bildirim_sesi_$vakit', _bildirimSesi[vakit]!);

      // Özel ses yollarını kaydet
      if (_ozelSesDosyalari.containsKey(vakit)) {
        await prefs.setString('ozel_ses_$vakit', _ozelSesDosyalari[vakit]!);
      }
    }
    await prefs.setBool('sessize_al', _sessizeAl);

    if (_sessizeAl) {
      await DndService.schedulePrayerDnd();
    } else {
      await DndService.cancelPrayerDnd();
    }

    // Zamanlanmış bildirimleri yeniden ayarla
    await ScheduledNotificationService.scheduleAllPrayerNotifications();

    setState(() {
      _degisiklikYapildi = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirim ayarları kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleSessizeAl(bool value) async {
    if (value) {
      final hasAccess = await DndService.hasPolicyAccess();
      if (!hasAccess) {
        final openSettings = await _showDndPermissionDialog();
        if (openSettings == true) {
          await DndService.openPolicySettings();
        }
        if (mounted) {
          setState(() {
            _sessizeAl = false;
          });
        }
        return;
      }

      final scheduled = await DndService.schedulePrayerDnd();
      if (!scheduled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessize alma planlanamadı. Konum seçimi gerekli.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _sessizeAl = false;
        });
        return;
      }
    } else {
      await DndService.cancelPrayerDnd();
    }

    if (mounted) {
      setState(() {
        _sessizeAl = value;
      });
    }
  }

  Future<void> _sesCal(String key, String sesDosyasi) async {
    try {
      await _audioPlayer.stop();

      if (sesDosyasi == 'custom' && _ozelSesDosyalari.containsKey(key)) {
        // Özel ses çal
        await _audioPlayer.play(DeviceFileSource(_ozelSesDosyalari[key]!));
      } else if (sesDosyasi != 'custom') {
        // Asset ses çal - dosya adını düzgün kullan
        await _audioPlayer.play(AssetSource('sounds/$sesDosyasi'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ses çalınamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _ozelSesSec(String key) async {
    // Önce kullanıcıyı bilgilendir
    final devam = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özel Ses Seçimi'),
        content: const Text(
          'Önemli: Ses dosyanızın adı rakamla başlamamalıdır.\n\n'
          'Android sisteminde ses dosyası isimleri harfle başlamalıdır.\n\n'
          'Örnek:\n'
          '✓ vakit_sesi.mp3\n'
          '✓ namaz_ezani.mp3\n'
          '✗ 2024_ses.mp3\n'
          '✗ 1_ezan.mp3',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anladım, Devam Et'),
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
        final dosyaYolu = result.files.single.path!;

        setState(() {
          _ozelSesDosyalari[key] = dosyaYolu;
          _bildirimSesi[key] = 'custom';
          _degisiklikYapildi = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Özel ses seçildi'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Seçilen sesi çal
        await _sesCal(key, 'custom');
      } else {
        // Kullanıcı iptal etti, önceki seçimi koru
        if (mounted) {
          setState(() {
            // Eğer custom seçiliyse ve dosya yoksa, varsayılan sese dön
            if (_bildirimSesi[key] == 'custom' &&
                !_ozelSesDosyalari.containsKey(key)) {
              _bildirimSesi[key] = _sesSecenekleri.first['dosya']!;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ses seçilemedi: $e'),
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
          title: const Text(
            'Sessize Alma İzni',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Vakitlerde sessize almak için sistem izni gerekiyor. İzin vermek ister misiniz?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Vazgeç',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
              ),
              child: const Text(
                'İzin Ver',
                style: TextStyle(color: Colors.black),
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
              title: const Text(
                'Değişiklikleri Kaydet?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Yaptığınız değişiklikler kaydedilsin mi?',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Kaydetme',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                  ),
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(color: Colors.black),
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
          title: const Text('Bildirim Ayarları'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _ayarlariKaydet,
              tooltip: 'Kaydet',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bilgilendirme kartı
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.cyanAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Her vakit için bildirimi açıp kapatabilir ve erken hatırlatma süresi belirleyebilirsiniz.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Vakitlerde sessize al seçeneği
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                      const Expanded(
                        child: Text(
                          'Vakitlerde sessize al',
                          style: TextStyle(
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
                        activeColor: Colors.orangeAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 36, right: 12, bottom: 6),
                    child: Text(
                      'Öğle, ikindi, akşam ve yatsı vakitlerinde 30 dk sessize alınır. Cuma günü 60 dk uygulanır.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
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
                    label: const Text('Tümünü Aç'),
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
                    label: const Text('Tümünü Kapat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Vakit bildirimleri
            _vakitBildirimKarti(
              'İmsak',
              'imsak',
              Icons.nightlight_round,
              'Sahur için uyanma vakti',
            ),
            _vakitBildirimKarti(
              'Güneş',
              'gunes',
              Icons.wb_sunny,
              'Güneşin doğuş vakti',
            ),
            _vakitBildirimKarti(
              'Öğle',
              'ogle',
              Icons.light_mode,
              'Öğle namazı vakti',
            ),
            _vakitBildirimKarti(
              'İkindi',
              'ikindi',
              Icons.brightness_6,
              'İkindi namazı vakti',
            ),
            _vakitBildirimKarti(
              'Akşam',
              'aksam',
              Icons.wb_twilight,
              'Akşam namazı ve iftar vakti',
            ),
            _vakitBildirimKarti(
              'Yatsı',
              'yatsi',
              Icons.nights_stay,
              'Yatsı namazı vakti',
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
    final vaktinde = _vaktindeBildirim[key]!;
    final erkenDakika = _erkenBildirim[key]!;
    final seciliSes = _bildirimSesi[key]!;

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
              activeColor: Colors.cyanAccent,
            ),
          ),

          // Alt kısım - Vaktinde, erken bildirim ve ses seçimi
          if (acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Vaktinde checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: vaktinde,
                        onChanged: (value) {
                          setState(() {
                            _vaktindeBildirim[key] = value ?? false;
                            _degisiklikYapildi = true;
                          });
                        },
                        activeColor: Colors.cyanAccent,
                      ),
                      const Text(
                        'Vaktinde bildirim gönder',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Erken hatırlatma:',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
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
                                  label = 'Yok';
                                } else if (dakika < 60) {
                                  label = '$dakika dk önce';
                                } else {
                                  label = '${dakika ~/ 60} saat önce';
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.music_note,
                        color: Colors.white54,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Bildirim sesi:',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
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
                                color: Colors.cyanAccent,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              style: const TextStyle(color: Colors.white),
                              items: _sesSecenekleri.map((ses) {
                                return DropdownMenuItem(
                                  value: ses['dosya'],
                                  child: Text(ses['ad']!),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                if (value != null) {
                                  if (value == 'custom') {
                                    // Özel ses seç
                                    await _ozelSesSec(key);
                                  } else {
                                    setState(() {
                                      _bildirimSesi[key] = value;
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
                      // Ses önizleme butonu
                      IconButton(
                        onPressed: () => _sesCal(key, seciliSes),
                        icon: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.cyanAccent,
                          size: 28,
                        ),
                        tooltip: 'Sesi dinle',
                      ),
                    ],
                  ),
                  // Özel ses seçildiyse dosya adını göster
                  if (seciliSes == 'custom' &&
                      _ozelSesDosyalari.containsKey(key))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 34),
                          Expanded(
                            child: Text(
                              'Özel: ${_ozelSesDosyalari[key]!.split('/').last.split('\\').last}',
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
              ),
            ),
        ],
      ),
    );
  }
}
