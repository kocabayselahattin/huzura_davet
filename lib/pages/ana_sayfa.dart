import 'package:flutter/material.dart';
import '../widgets/premium_sayac_widget.dart';
import '../widgets/vakit_listesi_widget.dart';
import '../widgets/gunun_icerigi_widget.dart';
import '../widgets/yarim_daire_sayac_widget.dart';
import '../widgets/dijital_sayac_widget.dart';
import '../widgets/esmaul_husna_widget.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import 'imsakiye_sayfa.dart';
import 'ayarlar_sayfa.dart';
import 'zikir_matik_sayfa.dart';
import 'kirk_hadis_sayfa.dart';
import 'kuran_sayfa.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  String konumBasligi = "KONUM SEÇİLMEDİ";
  final TemaService _temaService = TemaService();

  @override
  void initState() {
    super.initState();
    _konumYukle();
    _temaService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _konumYukle() async {
    final il = await KonumService.getIl();
    final ilce = await KonumService.getIlce();

    if (il != null && ilce != null) {
      setState(() {
        konumBasligi = "$il / $ilce";
      });
    } else if (il != null) {
      setState(() {
        konumBasligi = il;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          konumBasligi.toUpperCase(),
          style: TextStyle(
            letterSpacing: 2, 
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- SAYAÇ SLIDER BÖLÜMÜ ---
              SizedBox(
                height: 240,
                child: PageView(
                  controller: PageController(viewportFraction: 0.95),
                  children: const [
                    DijitalSayacWidget(),
                    PremiumSayacWidget(),
                    YarimDaireSayacWidget(),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // --- ESMAUL HUSNA ---
              const EsmaulHusnaWidget(),

              const SizedBox(height: 10),

              // --- VAKİT LİSTESİ ---
              const VakitListesiWidget(),

              const SizedBox(height: 20),

              // --- GÜNÜN İÇERİĞİ ---
              const GununIcerigiWidget(),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showMenu(context);
        },
        backgroundColor: renkler.kartArkaPlan,
        child: Icon(Icons.menu, color: renkler.yaziPrimary),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showMenu(BuildContext context) {
    final renkler = _temaService.renkler;

    showModalBottomSheet(
      context: context,
      backgroundColor: renkler.arkaPlan,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.schedule, color: renkler.vurgu),
                title: Text(
                  'İmsakiye',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImsakiyeSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome, color: renkler.vurgu),
                title: Text(
                  'Zikir Matik',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ZikirMatikSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.menu_book, color: renkler.vurgu),
                title: Text(
                  '40 Hadis',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KirkHadisSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_stories, color: renkler.vurgu),
                title: Text(
                  'Kur\'an-ı Kerim',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KuranSayfa(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.settings, color: renkler.vurgu),
                title: Text(
                  'Ayarlar',
                  style: TextStyle(color: renkler.yaziPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AyarlarSayfa(),
                    ),
                  );
                  _konumYukle();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
