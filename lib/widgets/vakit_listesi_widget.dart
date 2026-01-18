import 'package:flutter/material.dart';
import 'dart:async';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VakitListesiWidget extends StatefulWidget {
  const VakitListesiWidget({super.key});

  @override
  State<VakitListesiWidget> createState() => _VakitListesiWidgetState();
}

class _VakitListesiWidgetState extends State<VakitListesiWidget> {
  final TemaService _temaService = TemaService();
  Map<String, String> vakitSaatleri = {
    'Imsak': '—:—',
    'Gunes': '—:—',
    'Ogle': '—:—',
    'Ikindi': '—:—',
    'Aksam': '—:—',
    'Yatsi': '—:—',
  };
  String? aktifVakit;
  String? sonrakiVakit;
  Timer? _timer;
  bool _iconVisible = true;

  @override
  void initState() {
    super.initState();
    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _aktifVaktiGuncelle();
    });
    // İkon yanıp sönme animasyonu için
    Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) {
        setState(() => _iconVisible = !_iconVisible);
      }
    });
    _temaService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId == null) return;

    try {
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (vakitler != null) {
        setState(() {
          vakitSaatleri = {
            'Imsak': vakitler['Imsak'] ?? '—:—',
            'Gunes': vakitler['Gunes'] ?? '—:—',
            'Ogle': vakitler['Ogle'] ?? '—:—',
            'Ikindi': vakitler['Ikindi'] ?? '—:—',
            'Aksam': vakitler['Aksam'] ?? '—:—',
            'Yatsi': vakitler['Yatsi'] ?? '—:—',
          };
        });
        _aktifVaktiGuncelle();
      }
    } catch (e) {
      // Hata durumunda varsayılan değerler kalacak
    }
  }

  Future<void> _aktifVaktiGuncelle() async {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final vakitListesi = [
      {'adi': 'Imsak', 'saat': vakitSaatleri['Imsak']!},
      {'adi': 'Gunes', 'saat': vakitSaatleri['Gunes']!},
      {'adi': 'Ogle', 'saat': vakitSaatleri['Ogle']!},
      {'adi': 'Ikindi', 'saat': vakitSaatleri['Ikindi']!},
      {'adi': 'Aksam', 'saat': vakitSaatleri['Aksam']!},
      {'adi': 'Yatsi', 'saat': vakitSaatleri['Yatsi']!},
    ];

    String? yeniAktif;
    String? yeniSonraki;

    for (int i = 0; i < vakitListesi.length; i++) {
      final vakit = vakitListesi[i];
      final saat = vakit['saat'] as String;
      if (saat == '—:—') continue;

      try {
        final parts = saat.split(':');
        final vakitMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

        if (nowMinutes < vakitMinutes) {
          yeniSonraki = vakit['adi'] as String;
          if (i > 0) {
            yeniAktif = vakitListesi[i - 1]['adi'] as String;
          } else {
            yeniAktif = vakitListesi.last['adi'] as String;
          }
          break;
        }
      } catch (e) {
        // Parse hatası
      }
    }

    if (yeniSonraki == null) {
      yeniAktif = vakitListesi.last['adi'] as String;
      yeniSonraki = vakitListesi.first['adi'] as String;
    }

    // Bildirim tetikleme: aktif vakit değiştiyse bildir
    if (yeniAktif != aktifVakit && yeniAktif != null) {
      // Kullanıcı ayarlarını oku
      final prefs = await SharedPreferences.getInstance();
      final key = yeniAktif.toLowerCase();
      final bildirimAcik = prefs.getBool('bildirim_$key') ?? true;
      final ses = prefs.getString('bildirim_sesi_$key');
      // Eğer dosya yoksa varsayılan olarak 'ding_dong.mp3' kullan
      final rawSes = [
        'arriving.mp3',
        'best.mp3',
        'Corner.mp3',
        'Ding_Dong.mp3',
        'Echo.mp3',
        'iphone_sms_original.mp3',
        'snaps.mp3',
        'Sweet_Favour.mp3',
        'Violet.mp3',
        'Woodpecker.mp3',
      ];
      final sesDosyasi = (ses != null && rawSes.contains(ses)) ? ses : 'Ding_Dong.mp3';
      if (bildirimAcik) {
        await NotificationService.showVakitNotification(
          title: 'Vakit Girdi',
          body: '$yeniAktif vakti başladı.',
          soundAsset: sesDosyasi,
        );
      }
    }

    if (yeniAktif != aktifVakit || yeniSonraki != sonrakiVakit) {
      setState(() {
        aktifVakit = yeniAktif;
        sonrakiVakit = yeniSonraki;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _vakitSatiri(
            "Imsak",
            vakitSaatleri['Imsak']!,
            Icons.nightlight_round,
            'Imsak',
            renkler,
          ),
          _vakitSatiri(
            "Güneş",
            vakitSaatleri['Gunes']!,
            Icons.wb_sunny,
            'Gunes',
            renkler,
          ),
          _vakitSatiri(
            "Öğle",
            vakitSaatleri['Ogle']!,
            Icons.light_mode,
            'Ogle',
            renkler,
          ),
          _vakitSatiri(
            "İkindi",
            vakitSaatleri['Ikindi']!,
            Icons.brightness_6,
            'Ikindi',
            renkler,
          ),
          _vakitSatiri(
            "Akşam",
            vakitSaatleri['Aksam']!,
            Icons.wb_twilight,
            'Aksam',
            renkler,
          ),
          _vakitSatiri(
            "Yatsı",
            vakitSaatleri['Yatsi']!,
            Icons.nights_stay,
            'Yatsi',
            renkler,
          ),
        ],
      ),
    );
  }

  Widget _vakitSatiri(String ad, String saat, IconData icon, String key, TemaRenkleri renkler) {
    final aktif = aktifVakit == key;
    final sonraki = sonrakiVakit == key;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: aktif ? renkler.vurgu.withValues(alpha: 0.15) : Colors.transparent,
        border: Border(bottom: BorderSide(color: renkler.yaziSecondary.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: sonraki && !_iconVisible ? 0.2 : 1.0,
            duration: const Duration(milliseconds: 400),
            child: Icon(
              icon,
              color: aktif
                  ? renkler.vurgu
                  : sonraki
                      ? Colors.orange
                      : renkler.yaziSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ad,
              style: TextStyle(
                color: aktif ? renkler.vurgu : renkler.yaziPrimary,
                fontSize: 16,
                fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            saat,
            style: TextStyle(
              color: aktif ? renkler.vurgu : renkler.yaziSecondary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
