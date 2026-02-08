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
  final ScrollController _scrollController = ScrollController();
  
  String? secilenIl;
  String? secilenIlce;
  String? secilenIlceId;

  List<dynamic> vakitler = [];
  bool yukleniyor = false;
  int _bugunIndex = -1;

  @override
  void initState() {
    super.initState();
    _konumBilgileriniYukle();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    
    // Fetch times after location loads.
    if (ilceId != null) {
      _vakitleriYukle();
    }
  }

  Future<void> _vakitleriYukle({bool forceRefresh = false}) async {
    if (secilenIlceId == null) return;
    
    setState(() {
      yukleniyor = true;
    });

    try {
      // Clear cache when forced refresh is requested.
      if (forceRefresh) {
        DiyanetApiService.clearCache();
      }
      
      final data = await DiyanetApiService.getVakitler(secilenIlceId!);
      if (data != null && data.containsKey('vakitler')) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yeniVakitler = (data['vakitler'] as List)
            .where((v) {
              final tarihStr = v['MiladiTarihKisa'] as String?;
              final dt = _parseMiladi(tarihStr);
              if (dt == null) return true;
              return !dt.isBefore(today);
            })
            .toList();

        int bugunIdx = -1;
        for (int i = 0; i < yeniVakitler.length; i++) {
          final tarih = yeniVakitler[i]['MiladiTarihKisa'] ?? '';
          final dt = _parseMiladi(tarih);
          if (dt != null && !dt.isBefore(today) && dt.difference(today).inDays == 0) {
            bugunIdx = i;
            break;
          }
        }

        setState(() {
          vakitler = yeniVakitler;
          _bugunIndex = bugunIdx;
          yukleniyor = false;
        });
        
        // Scroll to today (after the frame).
        if (bugunIdx >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBugun();
          });
        }
      } else {
        setState(() {
          yukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load prayer times: $e');
      setState(() {
        yukleniyor = false;
      });
    }
  }

  DateTime? _parseMiladi(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateFormat('dd.MM.yyyy', _getLocale()).parse(value);
    } catch (_) {
      try {
        return DateFormat('dd.MM.yyyy').parse(value);
      } catch (_) {
        return null;
      }
    }
  }
  
  void _scrollToBugun() {
    if (_bugunIndex < 0 || !_scrollController.hasClients) return;
    
    // Each row is about 80px tall (including margin).
    const itemHeight = 88.0;
    final targetOffset = _bugunIndex * itemHeight;
    
    // Center the target row on screen.
    final screenHeight = MediaQuery.of(context).size.height;
    final centeredOffset = targetOffset - (screenHeight / 2) + (itemHeight / 2);
    
    _scrollController.animateTo(
      centeredOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
  
  /// Refresh the calendar by clearing cache and fetching fresh data.
  Future<void> _yenile() async {
    // Notify the user.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_languageService['refreshing'] ?? 'Refreshing...'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Fetch fresh data after cache clear.
    await _vakitleriYukle(forceRefresh: true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService['refresh_success'] ?? 'Calendar updated!',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      appBar: AppBar(
        title: Text(
          _languageService['imsakiye_title'] ?? 'Prayer Calendar',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Refresh button.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: _languageService['refresh'] ?? 'Refresh',
            onPressed: yukleniyor ? null : _yenile,
          ),
        ],
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
                          Text(
                            _languageService['no_data_found'] ??
                                'No data found',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
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
            _languageService['location_not_selected'] ??
              'Location Not Selected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _languageService['select_city_first'] ??
              'Select a city/district to view prayer times',
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
            label: Text(
              _languageService['select_city_district'] ??
                  'Select City/District',
            ),
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
    
    // Debug: log the first day for verification.
    if (tarih.isNotEmpty) {
      // Log the first day for debug (day 1 only).
      final parts = tarih.split('.');
      if (parts.length == 3 && parts[0] == '01') {
        debugPrint('Imsakiye row: $tarih');
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
            yil, // Year
            int.parse(ayParca), // Month
            int.parse(gunParca), // Day
          );
          final simdi = DateTime.now();
          bugun =
              tarihObj.year == simdi.year &&
              tarihObj.month == simdi.month &&
              tarihObj.day == simdi.day;
        }
      }
    } catch (e) {
      // Date parse error.
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
                _vakitRow(
                  _languageService['imsak'] ?? 'Fajr',
                  widget.imsak,
                  Icons.nightlight_round,
                ),
                _vakitRow(
                  _languageService['gunes'] ?? 'Sunrise',
                  widget.gunes,
                  Icons.wb_sunny,
                ),
                _vakitRow(
                  _languageService['ogle'] ?? 'Dhuhr',
                  widget.ogle,
                  Icons.light_mode,
                ),
                _vakitRow(
                  _languageService['ikindi'] ?? 'Asr',
                  widget.ikindi,
                  Icons.brightness_6,
                ),
                _vakitRow(
                  _languageService['aksam'] ?? 'Maghrib',
                  widget.aksam,
                  Icons.wb_twilight,
                ),
                _vakitRow(
                  _languageService['yatsi'] ?? 'Isha',
                  widget.yatsi,
                  Icons.nights_stay,
                ),
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
