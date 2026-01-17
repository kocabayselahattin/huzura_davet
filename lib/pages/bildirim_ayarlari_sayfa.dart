import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dnd_service.dart';

class BildirimAyarlariSayfa extends StatefulWidget {
  const BildirimAyarlariSayfa({super.key});

  @override
  State<BildirimAyarlariSayfa> createState() => _BildirimAyarlariSayfaState();
}

class _BildirimAyarlariSayfaState extends State<BildirimAyarlariSayfa> {
  // Bildirim açık/kapalı durumları
  Map<String, bool> _bildirimAcik = {
    'imsak': true,
    'gunes': false,
    'ogle': true,
    'ikindi': true,
    'aksam': true,
    'yatsi': true,
  };

  // Vakitlerde sessize al seçeneği
  bool _sessizeAl = false;

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
    'imsak': 'ding_dong.mp3',
    'gunes': 'arriving.mp3',
    'ogle': 'echo.mp3',
    'ikindi': 'sweet_favour.mp3',
    'aksam': 'violet.mp3',
    'yatsi': 'woodpecker.mp3',
  };

  final List<int> _erkenSureler = [0, 5, 10, 15, 20, 30, 45, 60];
  final List<Map<String, String>> _sesSecenekleri = [
    {'ad': 'Best 2015', 'dosya': 'best_2015.mp3'},
    {'ad': 'Arriving', 'dosya': 'arriving.mp3'},
    {'ad': 'Corner', 'dosya': 'corner.mp3'},
    {'ad': 'Ding Dong', 'dosya': 'ding_dong.mp3'},
    {'ad': 'Echo', 'dosya': 'echo.mp3'},
    {'ad': 'iPhone SMS', 'dosya': 'iphone_sms_original.mp3'},
    {'ad': 'Snaps', 'dosya': 'snaps.mp3'},
    {'ad': 'Sweet Favour', 'dosya': 'sweet_favour.mp3'},
    {'ad': 'Violet', 'dosya': 'violet.mp3'},
    {'ad': 'Woodpecker', 'dosya': 'woodpecker.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (final vakit in _bildirimAcik.keys) {
        _bildirimAcik[vakit] = prefs.getBool('bildirim_$vakit') ?? _bildirimAcik[vakit]!;
        _erkenBildirim[vakit] = prefs.getInt('erken_$vakit') ?? _erkenBildirim[vakit]!;
        _bildirimSesi[vakit] = prefs.getString('bildirim_sesi_$vakit') ?? _bildirimSesi[vakit]!;
      }
      _sessizeAl = prefs.getBool('sessize_al') ?? false;
    });
  }

  Future<void> _ayarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();

    for (final vakit in _bildirimAcik.keys) {
      await prefs.setBool('bildirim_$vakit', _bildirimAcik[vakit]!);
      await prefs.setInt('erken_$vakit', _erkenBildirim[vakit]!);
      await prefs.setString('bildirim_sesi_$vakit', _bildirimSesi[vakit]!);
    }
    await prefs.setBool('sessize_al', _sessizeAl);

    if (_sessizeAl) {
      await DndService.schedulePrayerDnd();
    } else {
      await DndService.cancelPrayerDnd();
    }

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

  Future<bool?> _showDndPermissionDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B3151),
          title: const Text('Sessize Alma İzni', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Vakitlerde sessize almak için sistem izni gerekiyor. İzin vermek ister misiniz?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              child: const Text('İzin Ver', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Switch(
                      value: _sessizeAl,
                      onChanged: (value) async {
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

          // Tümünü aç/kapat
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      for (final key in _bildirimAcik.keys) {
                        _bildirimAcik[key] = true;
                      }
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
        ],
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
                });
              },
              activeColor: Colors.cyanAccent,
            ),
          ),

          // Alt kısım - Erken bildirim ve ses seçimi
          if (acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        color: Colors.white54,
                        size: 18,
                      ),
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
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Colors.cyanAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              style: const TextStyle(color: Colors.white),
                              items: _erkenSureler.map((dakika) {
                                String label;
                                if (dakika == 0) {
                                  label = 'Zamanında';
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
                              value: _sesSecenekleri.any((s) => s['dosya'] == seciliSes) 
                                  ? seciliSes 
                                  : _sesSecenekleri.first['dosya'],
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2B3151),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Colors.cyanAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              style: const TextStyle(color: Colors.white),
                              items: _sesSecenekleri.map((ses) {
                                return DropdownMenuItem(
                                  value: ses['dosya'],
                                  child: Text(ses['ad']!),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _bildirimSesi[key] = value;
                                  });
                                }
                              },
                            ),
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
    );
  }
}
