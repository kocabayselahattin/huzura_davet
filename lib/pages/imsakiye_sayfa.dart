import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/konum_service.dart';
import '../services/diyanet_api_service.dart';
import 'il_ilce_sec_sayfa.dart';

class ImsakiyeSayfa extends StatefulWidget {
  const ImsakiyeSayfa({super.key});

  @override
  State<ImsakiyeSayfa> createState() => _ImsakiyeSayfaState();
}

class _ImsakiyeSayfaState extends State<ImsakiyeSayfa> {
  String? secilenIl;
  String? secilenIlce;
  String? secilenIlceId;

  final PageController _pageController = PageController(initialPage: 500);
  int _currentPage = 500; // Ortadan başla (geriye ve ileriye scroll için)
  DateTime _currentMonth = DateTime.now();

  final Map<String, List<dynamic>> _vakitCache = {}; // Ay bazında cache
  final Set<String> _yukleniyorAylar = {}; // Şu anda yüklenen aylar
  bool yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _konumBilgileriniYukle();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    // Konum yüklenince ön yüklemeyi başlat
    if (ilceId != null) {
      _preloadMonths(_currentPage);
    }
  }

  String _getAyKey(DateTime tarih) {
    return '${tarih.year}-${tarih.month}';
  }

  // Önceki ve sonraki ayları arka planda yükle
  Future<void> _preloadMonths(int currentIndex) async {
    if (secilenIlceId == null) return;

    // Mevcut ay + önceki 2 ay + sonraki 4 ay yükle (toplam 7 ay)
    for (int offset = -2; offset <= 4; offset++) {
      final ay = DateTime(
        DateTime.now().year,
        DateTime.now().month + (currentIndex - 500) + offset,
      );
      final key = _getAyKey(ay);
      
      // Zaten cache'de veya yükleniyor ise atla
      if (_vakitCache.containsKey(key) || _yukleniyorAylar.contains(key)) {
        continue;
      }
      
      // Arka planda yükle (await yok, paralel çalışır)
      _loadMonthData(ay);
    }
  }

  Future<void> _loadMonthData(DateTime ay) async {
    if (secilenIlceId == null) return;
    
    final key = _getAyKey(ay);
    if (_vakitCache.containsKey(key) || _yukleniyorAylar.contains(key)) {
      return;
    }

    _yukleniyorAylar.add(key);

    try {
      // Yeni aylık API metodunu kullan
      final ayVakitleri = await DiyanetApiService.getAylikVakitler(
        secilenIlceId!,
        ay.year,
        ay.month,
      );

      if (mounted && ayVakitleri.isNotEmpty) {
        setState(() {
          _vakitCache[key] = ayVakitleri;
        });
      }
    } catch (e) {
      print('Ön yükleme hatası ($key): $e');
    } finally {
      _yukleniyorAylar.remove(key);
    }
  }

  Future<List<dynamic>> _getVakitlerForMonth(DateTime ay) async {
    if (secilenIlceId == null) return [];

    final key = _getAyKey(ay);

    // Cache'de varsa kullan
    if (_vakitCache.containsKey(key)) {
      return _vakitCache[key]!;
    }

    try {
      // Yeni aylık API metodunu kullan
      final ayVakitleri = await DiyanetApiService.getAylikVakitler(
        secilenIlceId!,
        ay.year,
        ay.month,
      );

      if (ayVakitleri.isNotEmpty) {
        _vakitCache[key] = ayVakitleri;
        return ayVakitleri;
      }
    } catch (e) {
      print('Vakitler alınırken hata: $e');
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      appBar: AppBar(
        title: const Text('İmsakiye'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IlIlceSecSayfa()),
              );
              if (result == true) {
                _konumBilgileriniYukle();
                setState(() {
                  _vakitCache.clear(); // Cache'i temizle
                });
              }
            },
          ),
        ],
      ),
      body: secilenIl == null || secilenIlce == null
          ? _konumSeciliDegil()
          : Column(
              children: [
                // Konum bilgisi
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B3151),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.cyanAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$secilenIl / $secilenIlce',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ay göstergesi ve navigasyon
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.cyanAccent,
                        ),
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'tr_TR').format(_currentMonth),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.cyanAccent,
                        ),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Aylık imsakiye - PageView ile
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                        final ayFark = index - 500;
                        _currentMonth = DateTime(
                          DateTime.now().year,
                          DateTime.now().month + ayFark,
                        );
                      });
                      // Sayfa değiştiğinde sonraki ayları ön yükle
                      _preloadMonths(index);
                    },
                    itemBuilder: (context, index) {
                      final ayFark = index - 500;
                      final ay = DateTime(
                        DateTime.now().year,
                        DateTime.now().month + ayFark,
                      );
                      return _buildMonthView(ay);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthView(DateTime ay) {
    return FutureBuilder<List<dynamic>>(
      future: _getVakitlerForMonth(ay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
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
                  '${DateFormat('MMMM yyyy', 'tr_TR').format(ay)}\niçin veri bulunamadı',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final vakitler = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: vakitler.length,
          itemBuilder: (context, index) {
            final vakit = vakitler[index];
            return _imsakiyeSatiri(vakit);
          },
        );
      },
    );
  }

  Widget _konumSeciliDegil() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 80, color: Colors.white38),
          const SizedBox(height: 20),
          const Text(
            'Konum Seçilmedi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vakitleri görmek için önce\nil ve ilçe seçmeniz gerekiyor',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
            label: const Text('İl/İlçe Seç'),
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
        ? DateFormat('EEEE', 'tr_TR').format(tarihObj)
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
                _vakitRow('İmsak', widget.imsak, Icons.nightlight_round),
                _vakitRow('Güneş', widget.gunes, Icons.wb_sunny),
                _vakitRow('Öğle', widget.ogle, Icons.light_mode),
                _vakitRow('İkindi', widget.ikindi, Icons.brightness_6),
                _vakitRow('Akşam', widget.aksam, Icons.wb_twilight),
                _vakitRow('Yatsı', widget.yatsi, Icons.nights_stay),
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
