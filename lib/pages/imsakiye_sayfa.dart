import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import '../services/language_service.dart';
import 'il_ilce_sec_sayfa.dart';

class ImsakiyeSayfa extends StatefulWidget {
  const ImsakiyeSayfa({super.key});

  @override
  State<ImsakiyeSayfa> createState() => _ImsakiyeSayfaState();
}

class _ImsakiyeSayfaState extends State<ImsakiyeSayfa> {
  final LanguageService _languageService = LanguageService();
  
  String? secilenIl;
  String? secilenIlce;
  String? secilenIlceId;

  List<dynamic> vakitler = [];
  bool yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _konumBilgileriniYukle();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getLocale() {
    final lang = _languageService.currentLanguage;
    switch (lang) {
      case 'tr':
        return 'tr_TR';
      case 'en':
        return 'en_US';
      case 'de':
        return 'de_DE';
      case 'fr':
        return 'fr_FR';
      default:
        return 'tr_TR';
    }
  }

  Future<void> _konumBilgileriniYukle() async {
    final il = await KonumService.getIl();
    final ilce = await KonumService.getIlce();
    final ilceId = await KonumService.getIlceId();
    
    setState(() {
      secilenIl = il;
      secilenIlce = ilce;
      secilenIlceId = ilceId;
    });
    
    // Konum yüklenince vakitleri çek
    if (ilceId != null) {
      _vakitleriYukle();
    }
  }

  Future<void> _vakitleriYukle() async {
    if (secilenIlceId == null) return;
    
    setState(() {
      yukleniyor = true;
    });

    try {
      final data = await DiyanetApiService.getVakitler(secilenIlceId!);
      if (data != null && data.containsKey('vakitler')) {
        setState(() {
          vakitler = data['vakitler'] as List;
          yukleniyor = false;
        });
      } else {
        setState(() {
          yukleniyor = false;
        });
      }
    } catch (e) {
      print('Vakitler yüklenemedi: $e');
      setState(() {
        yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      appBar: AppBar(
        title: Text(_languageService['imsakiye_title'] ?? 'İmsakiye'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: secilenIl == null || secilenIlce == null
          ? _konumSeciliDegil()
          : yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : vakitler.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 60,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Veri bulunamadı',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: vakitler.length,
                      itemBuilder: (context, index) {
                        final vakit = vakitler[index];
                        return _imsakiyeSatiri(vakit);
                      },
                    ),
    );
  }

  Widget _konumSeciliDegil() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 80, color: Colors.white38),
          const SizedBox(height: 20),
          Text(
            _languageService['location_not_selected'] ?? 'Konum Seçilmedi',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _languageService['select_city_first'] ?? 'Vakitleri görmek için önce\nil ve ilçe seçmeniz gerekiyor',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IlIlceSecSayfa()),
              );
              if (result == true) {
                _konumBilgileriniYukle();
              }
            },
            icon: const Icon(Icons.location_city),
            label: Text(_languageService['select_city_district'] ?? 'İl/İlçe Seç'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imsakiyeSatiri(dynamic vakit) {
    final tarih = vakit['MiladiTarihKisa'] ?? '';
    final hicriTarih = vakit['HicriTarihUzun'] ?? '';
    
    // Debug: İlk ve son satırda tarih yazdır
    if (tarih.isNotEmpty) {
      // İlk günü debug için yazdır (sadece 1. gün)
      final parts = tarih.split('.');
      if (parts.length == 3 && parts[0] == '01') {
        print('🗓️ İmsakiye satırı: $tarih');
      }
    }

    DateTime? tarihObj;
    bool bugun = false;
    try {
      if (tarih.isNotEmpty) {
        final parts = tarih.split('.');
        if (parts.length == 3) {
          final yilParca = parts[2].trim();
          final ayParca = parts[1].trim();
          final gunParca = parts[0].trim();
          final yil = yilParca.length == 2
              ? 2000 + int.parse(yilParca)
              : int.parse(yilParca);
          tarihObj = DateTime(
            yil, // Yıl
            int.parse(ayParca), // Ay
            int.parse(gunParca), // Gün
          );
          final simdi = DateTime.now();
          bugun =
              tarihObj.year == simdi.year &&
              tarihObj.month == simdi.month &&
              tarihObj.day == simdi.day;
        }
      }
    } catch (e) {
      // Tarih parse hatası
    }

    final gunAdi = tarihObj != null
        ? DateFormat('EEEE', _getLocale()).format(tarihObj)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bugun
            ? Colors.cyanAccent.withOpacity(0.15)
            : const Color(0xFF2B3151),
        borderRadius: BorderRadius.circular(12),
        border: bugun ? Border.all(color: Colors.cyanAccent, width: 2) : null,
      ),
      child: ExpansibleTile(
        tarih: tarih,
        gunAdi: gunAdi,
        hicriTarih: hicriTarih,
        bugun: bugun,
        imsak: vakit['Imsak'] ?? '-',
        gunes: vakit['Gunes'] ?? '-',
        ogle: vakit['Ogle'] ?? '-',
        ikindi: vakit['Ikindi'] ?? '-',
        aksam: vakit['Aksam'] ?? '-',
        yatsi: vakit['Yatsi'] ?? '-',
      ),
    );
  }
}

class ExpansibleTile extends StatefulWidget {
  final String tarih;
  final String gunAdi;
  final String hicriTarih;
  final bool bugun;
  final String imsak;
  final String gunes;
  final String ogle;
  final String ikindi;
  final String aksam;
  final String yatsi;

  const ExpansibleTile({
    super.key,
    required this.tarih,
    required this.gunAdi,
    required this.hicriTarih,
    required this.bugun,
    required this.imsak,
    required this.gunes,
    required this.ogle,
    required this.ikindi,
    required this.aksam,
    required this.yatsi,
  });

  @override
  State<ExpansibleTile> createState() => _ExpansibleTileState();
}

class _ExpansibleTileState extends State<ExpansibleTile> {
  bool expanded = false;
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    expanded = widget.bugun;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: () => setState(() => expanded = !expanded),
          leading: Icon(
            widget.bugun ? Icons.today : Icons.calendar_today,
            color: widget.bugun ? Colors.cyanAccent : Colors.white70,
          ),
          title: Text(
            '${widget.tarih} - ${widget.gunAdi}',
            style: TextStyle(
              color: widget.bugun ? Colors.cyanAccent : Colors.white,
              fontWeight: widget.bugun ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            widget.hicriTarih,
            style: TextStyle(
              color: widget.bugun
                  ? Colors.cyanAccent.withOpacity(0.7)
                  : Colors.white54,
              fontSize: 11,
            ),
          ),
          trailing: Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: widget.bugun ? Colors.cyanAccent : Colors.white70,
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                _vakitRow(_languageService['imsak'] ?? 'İmsak', widget.imsak, Icons.nightlight_round),
                _vakitRow(_languageService['gunes'] ?? 'Güneş', widget.gunes, Icons.wb_sunny),
                _vakitRow(_languageService['ogle'] ?? 'Öğle', widget.ogle, Icons.light_mode),
                _vakitRow(_languageService['ikindi'] ?? 'İkindi', widget.ikindi, Icons.brightness_6),
                _vakitRow(_languageService['aksam'] ?? 'Akşam', widget.aksam, Icons.wb_twilight),
                _vakitRow(_languageService['yatsi'] ?? 'Yatsı', widget.yatsi, Icons.nights_stay),
              ],
            ),
          ),
      ],
    );
  }

  Widget _vakitRow(String ad, String saat, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.cyanAccent.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ad,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            saat,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
