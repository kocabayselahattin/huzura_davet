import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ozel_gunler_service.dart';
import '../services/tema_service.dart';

class OzelGunlerSayfa extends StatefulWidget {
  const OzelGunlerSayfa({super.key});

  @override
  State<OzelGunlerSayfa> createState() => _OzelGunlerSayfaState();
}

class _OzelGunlerSayfaState extends State<OzelGunlerSayfa> {
  final TemaService _temaService = TemaService();
  List<Map<String, dynamic>> _yaklasanGunler = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _gunleriYukle();
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  void _gunleriYukle() {
    setState(() {
      _yukleniyor = true;
    });
    
    final gunler = OzelGunlerService.yaklasanOzelGunler();
    
    setState(() {
      _yaklasanGunler = gunler;
      _yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    
    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          'Özel Gün ve Geceler',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _yaklasanGunler.isEmpty
              ? _bosListe(renkler)
              : _gunlerListesi(renkler),
    );
  }

  Widget _bosListe(TemaRenkleri renkler) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: renkler.yaziSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Yaklaşan özel gün bulunamadı',
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gunlerListesi(TemaRenkleri renkler) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _yaklasanGunler.length,
      itemBuilder: (context, index) {
        final gun = _yaklasanGunler[index];
        final ozelGun = gun['ozelGun'] as OzelGun;
        final tarih = gun['tarih'] as DateTime;
        final kalanGun = gun['kalanGun'] as int;
        final hicriTarih = gun['hicriTarih'] as String;
        
        return _gunKarti(ozelGun, tarih, kalanGun, hicriTarih, renkler);
      },
    );
  }

  Widget _gunKarti(
    OzelGun ozelGun,
    DateTime tarih,
    int kalanGun,
    String hicriTarih,
    TemaRenkleri renkler,
  ) {
    final miladiTarih = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(tarih);
    final ikon = _getIkon(ozelGun.tur);
    final renk = _getRenk(ozelGun.tur, renkler);
    final bugunMu = kalanGun == 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bugunMu 
            ? renk.withValues(alpha: 0.2)
            : renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        border: bugunMu 
            ? Border.all(color: renk, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // İkon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ikon,
                color: renk,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            
            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ozelGun.ad,
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ozelGun.aciklama,
                    style: TextStyle(
                      color: renkler.yaziSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: renkler.yaziSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          miladiTarih,
                          style: TextStyle(
                            color: renkler.yaziSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_3,
                        size: 14,
                        color: renkler.yaziSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hicriTarih,
                        style: TextStyle(
                          color: renkler.yaziSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Kalan gün
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bugunMu 
                    ? renk 
                    : renk.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    bugunMu ? 'BUGÜN' : '$kalanGun',
                    style: TextStyle(
                      color: bugunMu ? Colors.white : renk,
                      fontSize: bugunMu ? 12 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!bugunMu)
                    Text(
                      'gün',
                      style: TextStyle(
                        color: renk,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIkon(OzelGunTuru tur) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return Icons.celebration;
      case OzelGunTuru.kandil:
        return Icons.brightness_7;
      case OzelGunTuru.mubarekGece:
        return Icons.nights_stay;
      case OzelGunTuru.onemliGun:
        return Icons.star;
    }
  }

  Color _getRenk(OzelGunTuru tur, TemaRenkleri renkler) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return Colors.amber;
      case OzelGunTuru.kandil:
        return Colors.purpleAccent;
      case OzelGunTuru.mubarekGece:
        return Colors.tealAccent;
      case OzelGunTuru.onemliGun:
        return renkler.vurgu;
    }
  }
}
