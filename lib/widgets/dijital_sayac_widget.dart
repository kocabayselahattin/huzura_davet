import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/tema_service.dart';

class DijitalSayacWidget extends StatefulWidget {
  const DijitalSayacWidget({super.key});

  @override
  State<DijitalSayacWidget> createState() => _DijitalSayacWidgetState();
}

class _DijitalSayacWidgetState extends State<DijitalSayacWidget> {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  String _sonrakiVakitSaati = '';
  Map<String, String> _vakitSaatleri = {};
  final TemaService _temaService = TemaService();

  @override
  void initState() {
    super.initState();
    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hesaplaKalanSure();
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
    if (ilceId == null) {
      _varsayilanVakitleriKullan();
      return;
    }

    try {
      final data = await DiyanetApiService.getVakitler(ilceId);
      if (data != null && data.containsKey('vakitler')) {
        final vakitler = data['vakitler'] as List;
        if (vakitler.isNotEmpty) {
          // Bugünün vakitlerini bul
          final bugun = DateTime.now();
          final bugunVakit = vakitler.firstWhere((v) {
            final tarih = v['MiladiTarihKisa'] ?? '';
            try {
              final parts = tarih.split('.');
              if (parts.length == 3) {
                final gun = int.parse(parts[0]);
                final ay = int.parse(parts[1]);
                final yil = int.parse(parts[2]);
                return gun == bugun.day && ay == bugun.month && yil == bugun.year;
              }
            } catch (e) {
              // Parse error
            }
            return false;
          }, orElse: () => vakitler.isNotEmpty ? Map<String, dynamic>.from(vakitler[0]) : <String, dynamic>{}) as Map<String, dynamic>;

          setState(() {
            _vakitSaatleri = {
              'Imsak': bugunVakit['Imsak'] ?? '06:12',
              'Gunes': bugunVakit['Gunes'] ?? '07:45',
              'Ogle': bugunVakit['Ogle'] ?? '13:22',
              'Ikindi': bugunVakit['Ikindi'] ?? '15:58',
              'Aksam': bugunVakit['Aksam'] ?? '18:25',
              'Yatsi': bugunVakit['Yatsi'] ?? '19:50',
            };
          });
          _hesaplaKalanSure();
        }
      } else {
        _varsayilanVakitleriKullan();
      }
    } catch (e) {
      _varsayilanVakitleriKullan();
    }
  }

  void _varsayilanVakitleriKullan() {
    setState(() {
      _vakitSaatleri = {
        'Imsak': '06:12',
        'Gunes': '07:45',
        'Ogle': '13:22',
        'Ikindi': '15:58',
        'Aksam': '18:25',
        'Yatsi': '19:50',
      };
    });
    _hesaplaKalanSure();
  }

  void _hesaplaKalanSure() {
    if (_vakitSaatleri.isEmpty) return;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final vakitSaatleri = [
      {'adi': 'İmsak', 'saat': _vakitSaatleri['Imsak']!},
      {'adi': 'Güneş', 'saat': _vakitSaatleri['Gunes']!},
      {'adi': 'Öğle', 'saat': _vakitSaatleri['Ogle']!},
      {'adi': 'İkindi', 'saat': _vakitSaatleri['Ikindi']!},
      {'adi': 'Akşam', 'saat': _vakitSaatleri['Aksam']!},
      {'adi': 'Yatsı', 'saat': _vakitSaatleri['Yatsi']!},
    ];

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';
    String vakitSaati = '';

    for (final vakit in vakitSaatleri) {
      final saat = vakit['saat'] as String;
      try {
        final parts = saat.split(':');
        final vakitMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

        if (vakitMinutes > nowMinutes) {
          sonrakiVakitZamani = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          sonrakiVakitAdi = vakit['adi'] as String;
          vakitSaati = saat;
          break;
        }
      } catch (e) {
        // Parse error
      }
    }

    if (sonrakiVakitZamani == null) {
      final yarin = now.add(const Duration(days: 1));
      final imsakSaat = _vakitSaatleri['Imsak']!.split(':');
      sonrakiVakitZamani = DateTime(
        yarin.year,
        yarin.month,
        yarin.day,
        int.parse(imsakSaat[0]),
        int.parse(imsakSaat[1]),
      );
      sonrakiVakitAdi = 'İmsak';
      vakitSaati = _vakitSaatleri['Imsak']!;
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
      _sonrakiVakitSaati = vakitSaati;
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes % 60;
    final seconds = _kalanSure.inSeconds % 60;

    final now = DateTime.now();
    final miladiTarih = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih =
        '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            renkler.kartArkaPlan,
            renkler.kartArkaPlan.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_sonrakiVakit Vaktine',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: renkler.vurgu,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: renkler.vurgu.withValues(alpha: 0.5),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 66,
              fontWeight: FontWeight.bold,
              color: renkler.yaziPrimary,
              fontFamily: 'Digital-7',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Miladi',
                      style: TextStyle(
                        color: renkler.yaziSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      miladiTarih,
                      style: TextStyle(
                        color: renkler.yaziSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Hicri',
                      style: TextStyle(
                        color: renkler.yaziSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hicriTarih,
                      style: TextStyle(
                        color: renkler.yaziSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getHicriAyAdi(int ay) {
    const aylar = [
      '',
      'Muharrem',
      'Safer',
      'Rebiülevvel',
      'Rebiülahir',
      'Cemaziyelevvel',
      'Cemaziyelahir',
      'Recep',
      'Şaban',
      'Ramazan',
      'Şevval',
      'Zilkade',
      'Zilhicce',
    ];
    return aylar[ay];
  }
}
