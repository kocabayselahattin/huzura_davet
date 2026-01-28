import 'package:flutter/material.dart';
import '../widgets/premium_sayac_widget.dart';
import '../widgets/vakit_listesi_widget.dart';
import '../widgets/gunun_icerigi_widget.dart';
import '../widgets/galaksi_sayac_widget.dart';
import '../widgets/neon_sayac_widget.dart';
import '../widgets/okyanus_sayac_widget.dart';
import '../widgets/dijital_sayac_widget.dart';
import '../widgets/minimal_sayac_widget.dart';
import '../widgets/retro_sayac_widget.dart';
import '../widgets/aurora_sayac_widget.dart';
import '../widgets/kristal_sayac_widget.dart';
import '../widgets/volkanik_sayac_widget.dart';
import '../widgets/zen_sayac_widget.dart';
import '../widgets/siber_sayac_widget.dart';
import '../widgets/gece_sayac_widget.dart';
import '../widgets/matrix_sayac_widget.dart';
import '../widgets/nefes_sayac_widget.dart';
import '../widgets/geometrik_sayac_widget.dart';
import '../widgets/tesla_sayac_widget.dart';
import '../widgets/islami_sayac_widget.dart';
import '../widgets/kalem_sayac_widget.dart';
import '../widgets/nur_sayac_widget.dart';
import '../widgets/hilal_sayac_widget.dart';
import '../widgets/mihrap_sayac_widget.dart';
import '../widgets/esmaul_husna_widget.dart';
import '../widgets/ozel_gun_popup.dart';
import '../widgets/ozel_gun_banner_widget.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/home_widget_service.dart';
import '../services/scheduled_notification_service.dart';
import '../models/konum_model.dart';
import 'imsakiye_sayfa.dart';
import 'ayarlar_sayfa.dart';
import 'zikir_matik_sayfa.dart';
import 'kirk_hadis_sayfa.dart';
import 'kuran_sayfa.dart';
import 'ibadet_sayfa.dart';
import 'ozel_gunler_sayfa.dart';
import 'kible_sayfa.dart';
import 'yakin_camiler_sayfa.dart';
import 'hakkinda_sayfa.dart';
import 'il_ilce_sec_sayfa.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  String konumBasligi = "";
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  int _currentSayacIndex = 0;
  bool _sayacYuklendi = false;

  // Çoklu konum sistemi
  List<KonumModel> _konumlar = [];
  int _aktifKonumIndex = 0;
  PageController? _konumPageController;

  // Widget yenileme için key
  Key _vakitListesiKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadSayacIndex();
    _konumYukle();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
    // Özel gün popup kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOzelGun();
      // Zamanlanmış bildirimleri ayarla
      _scheduleNotifications();
    });
  }

  Future<void> _scheduleNotifications() async {
    try {
      await ScheduledNotificationService.scheduleAllPrayerNotifications();
    } catch (e) {
      print('⚠️ Bildirim zamanlama hatası: $e');
    }
  }

  Future<void> _checkOzelGun() async {
    if (mounted) {
      await checkAndShowOzelGunPopup(context);
    }
  }

  Future<void> _loadSayacIndex() async {
    // TemaService'den sayaç index'ini al
    final index = _temaService.aktifSayacIndex;
    if (mounted) {
      setState(() {
        _currentSayacIndex = index;
        _sayacYuklendi = true;
      });
    }
  }

  @override
  void dispose() {
    _konumPageController?.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) {
      setState(() {
        // Sayaç değiştiğinde güncelle
        _currentSayacIndex = _temaService.aktifSayacIndex;
      });
    }
  }

  Future<void> _konumYukle() async {
    final konumlar = await KonumService.getKonumlar();
    final aktifIndex = await KonumService.getAktifKonumIndex();

    if (mounted) {
      setState(() {
        _konumlar = konumlar;
        _aktifKonumIndex = aktifIndex < konumlar.length ? aktifIndex : 0;

        if (konumlar.isEmpty) {
          konumBasligi =
              _languageService['location_not_selected_upper'] ??
              "KONUM SEÇİLMEDİ";
        } else {
          final aktifKonum = konumlar[_aktifKonumIndex];
          konumBasligi = "${aktifKonum.ilAdi} / ${aktifKonum.ilceAdi}";
        }

        _konumPageController = PageController(initialPage: _aktifKonumIndex);
      });
    }
  }

  // Konum değiştirme fonksiyonu
  Future<void> _konumDegistir(int yeniIndex) async {
    if (yeniIndex >= 0 && yeniIndex < _konumlar.length) {
      await KonumService.setAktifKonumIndex(yeniIndex);
      setState(() {
        _aktifKonumIndex = yeniIndex;
        final aktifKonum = _konumlar[yeniIndex];
        konumBasligi = "${aktifKonum.ilAdi} / ${aktifKonum.ilceAdi}";
      });

      // Widget'ları güncelle
      await HomeWidgetService.updateAllWidgets();
      print('✅ Aktif konum değiştirildi: ${_konumlar[yeniIndex].tamAd}');

      // Vakit listesini ve tüm widgetları yenile
      if (mounted) {
        setState(() {
          _vakitListesiKey =
              UniqueKey(); // Vakit listesini zorla yeniden oluştur
        });
      }
    }
  }

  // Uygulama bilgi popup'ı
  void _showAppInfoDialog() {
    final renkler = _temaService.renkler;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: renkler.vurgu,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: renkler.vurgu.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _languageService['app_name'] ?? 'Huzur Vakti',
              style: TextStyle(
                color: renkler.yaziPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_languageService['version'] ?? 'Versiyon'}: 2.3.0',
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _languageService['prayer_times_assistant'] ??
                  'Namaz Vakitleri ve İbadet Asistanı',
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HakkindaSayfa(),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.info_outline,
                    color: renkler.vurgu,
                    size: 18,
                  ),
                  label: Text(
                    _languageService['about'] ?? 'Hakkında',
                    style: TextStyle(color: renkler.vurgu),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: renkler.yaziSecondary,
                    size: 18,
                  ),
                  label: Text(
                    _languageService['close'] ?? 'Kapat',
                    style: TextStyle(color: renkler.yaziSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Konum seçim popup dialogu
  void _showKonumSecimDialog() {
    final renkler = _temaService.renkler;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.location_on, color: renkler.vurgu),
            const SizedBox(width: 12),
            Text(
              _languageService['saved_locations_title'] ?? 'Kayıtlı Konumlar',
              style: TextStyle(color: renkler.yaziPrimary, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _konumlar.isEmpty
              ? Text(
                  _languageService['no_saved_locations'] ??
                      'Henüz kayıtlı konum yok',
                  style: TextStyle(color: renkler.yaziSecondary),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _konumlar.length,
                  itemBuilder: (context, index) {
                    final konum = _konumlar[index];
                    final isAktif = index == _aktifKonumIndex;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isAktif
                            ? renkler.vurgu.withValues(alpha: 0.15)
                            : renkler.arkaPlan,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAktif
                              ? renkler.vurgu
                              : renkler.ayirac.withValues(alpha: 0.3),
                          width: isAktif ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAktif
                                ? renkler.vurgu.withValues(alpha: 0.2)
                                : renkler.kartArkaPlan,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isAktif ? Icons.location_on : Icons.location_city,
                            color: isAktif
                                ? renkler.vurgu
                                : renkler.yaziSecondary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          konum.tamAd,
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontWeight: isAktif
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: isAktif
                            ? Text(
                                _languageService['active_location'] ??
                                    'Aktif Konum',
                                style: TextStyle(
                                  color: renkler.vurgu,
                                  fontSize: 11,
                                ),
                              )
                            : null,
                        trailing: _konumlar.length > 1 && !isAktif
                            ? IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[400],
                                  size: 20,
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final onay = await showDialog<bool>(
                                    context: this.context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: renkler.kartArkaPlan,
                                      title: Text(
                                        _languageService['delete_location'] ??
                                            'Konumu Sil',
                                        style: TextStyle(
                                          color: renkler.yaziPrimary,
                                        ),
                                      ),
                                      content: Text(
                                        '${konum.tamAd} ${_languageService['delete_location_confirm'] ?? 'konumunu silmek istediğinize emin misiniz?'}',
                                        style: TextStyle(
                                          color: renkler.yaziSecondary,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(
                                            _languageService['cancel'] ??
                                                'İptal',
                                            style: TextStyle(
                                              color: renkler.yaziSecondary,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            _languageService['delete'] ?? 'Sil',
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (onay == true) {
                                    await KonumService.removeKonum(index);
                                    _konumYukle();
                                  }
                                },
                              )
                            : isAktif
                            ? Icon(
                                Icons.check_circle,
                                color: renkler.vurgu,
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          if (!isAktif) {
                            _konumDegistir(index);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _languageService['close'] ?? 'Kapat',
              style: TextStyle(color: renkler.vurgu),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 56,
        leading: GestureDetector(
          onTap: _showAppInfoDialog,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: renkler.vurgu.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        title: GestureDetector(
          onTap: () {
            if (_konumlar.isNotEmpty) {
              _showKonumSecimDialog();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_konumlar.length > 1)
                Icon(
                  Icons.unfold_more,
                  color: renkler.yaziSecondary.withOpacity(0.5),
                  size: 18,
                ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  konumBasligi.toUpperCase(),
                  style: TextStyle(
                    letterSpacing: 1.5,
                    fontSize: 13,
                    color: renkler.yaziPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (_konumlar.length > 1) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more,
                  color: renkler.yaziSecondary.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // Kıble Pusulası ikonu
          IconButton(
            icon: Icon(Icons.explore, color: renkler.vurgu, size: 26),
            tooltip: _languageService['qibla'] ?? 'Kıble Yönü',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KibleSayfa()),
              );
            },
          ),
          // Konum ekle ikonu
          IconButton(
            icon: Icon(Icons.add_location_alt, color: renkler.vurgu, size: 26),
            tooltip: _languageService['add_location'] ?? 'Konum Ekle',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IlIlceSecSayfa()),
              );
              if (result == true || result == null) {
                await _konumYukle();
                setState(() {
                  _vakitListesiKey = UniqueKey();
                });
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- KONUM UYARISI (Eğer konum seçilmemişse) ---
              if (_konumlar.isEmpty)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _languageService['location_not_selected'] ??
                                  'Konum Seçilmedi',
                              style: TextStyle(
                                color: renkler.yaziPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _languageService['select_location_hint'] ??
                                  'Namaz vakitlerini görmek için ayarlardan il/ilçe seçin',
                              style: TextStyle(
                                color: renkler.yaziSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.orange,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AyarlarSayfa(),
                            ),
                          ).then((_) => _konumYukle());
                        },
                      ),
                    ],
                  ),
                ),

              // --- SAYAÇ BÖLÜMÜ ---
              SizedBox(
                height: 240,
                child: _sayacYuklendi
                    ? _buildSelectedCounter()
                    : const Center(child: CircularProgressIndicator()),
              ),

              const SizedBox(height: 10),

              // --- ESMAUL HUSNA ---
              const EsmaulHusnaWidget(),

              const SizedBox(height: 10),

              // --- ÖZEL GÜN BANNER ---
              const OzelGunBannerWidget(),

              const SizedBox(height: 10),

              // --- VAKİT LİSTESİ ---
              VakitListesiWidget(key: _vakitListesiKey),

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
          _showMenuBottomSheet(context, renkler);
        },
        backgroundColor: renkler.kartArkaPlan,
        child: Icon(Icons.menu, color: renkler.yaziPrimary),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSelectedCounter() {
    // Ana ekranda seçili sayaç veri yükler (shouldLoadData: true)
    switch (_currentSayacIndex) {
      case 0:
        return const IslamiSayacWidget(shouldLoadData: true);
      case 1:
        return const KalemSayacWidget(shouldLoadData: true);
      case 2:
        return const NurSayacWidget(shouldLoadData: true);
      case 3:
        return const HilalSayacWidget(shouldLoadData: true);
      case 4:
        return const MihrapSayacWidget(shouldLoadData: true);
      case 5:
        return const DijitalSayacWidget(shouldLoadData: true);
      case 6:
        return const PremiumSayacWidget(shouldLoadData: true);
      case 7:
        return const GalaksiSayacWidget(shouldLoadData: true);
      case 8:
        return const NeonSayacWidget(shouldLoadData: true);
      case 9:
        return const OkyanusSayacWidget(shouldLoadData: true);
      case 10:
        return const MinimalSayacWidget(shouldLoadData: true);
      case 11:
        return const RetroSayacWidget(shouldLoadData: true);
      case 12:
        return const AuroraSayacWidget(shouldLoadData: true);
      case 13:
        return const KristalSayacWidget(shouldLoadData: true);
      case 14:
        return const VolkanikSayacWidget(shouldLoadData: true);
      case 15:
        return const ZenSayacWidget(shouldLoadData: true);
      case 16:
        return const SiberSayacWidget(shouldLoadData: true);
      case 17:
        return const GeceSayacWidget(shouldLoadData: true);
      case 18:
        return const MatrixSayacWidget(shouldLoadData: true);
      case 19:
        return const NefesSayacWidget(shouldLoadData: true);
      case 20:
        return const GeometrikSayacWidget(shouldLoadData: true);
      case 21:
        return const TeslaSayacWidget(shouldLoadData: true);
      default:
        return const IslamiSayacWidget(shouldLoadData: true);
    }
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
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.schedule, color: renkler.vurgu),
                  title: Text(
                    _languageService['calendar'] ?? 'İmsakiye',
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
                    _languageService['dhikr'] ?? 'Zikir Matik',
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
                  leading: Icon(Icons.mosque, color: renkler.vurgu),
                  title: Text(
                    _languageService['worship'] ?? 'İbadet',
                    style: TextStyle(color: renkler.yaziPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IbadetSayfa(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.explore, color: renkler.vurgu),
                  title: Text(
                    _languageService['qibla'] ?? 'Kıble Yönü',
                    style: TextStyle(color: renkler.yaziPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KibleSayfa(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.place, color: renkler.vurgu),
                  title: Text(
                    _languageService['nearby_mosques'] ?? 'Yakındaki Camiler',
                    style: TextStyle(color: renkler.yaziPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const YakinCamilerSayfa(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.celebration, color: renkler.vurgu),
                  title: Text(
                    _languageService['special_days'] ?? 'Özel Gün ve Geceler',
                    style: TextStyle(color: renkler.yaziPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OzelGunlerSayfa(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.menu_book, color: renkler.vurgu),
                  title: Text(
                    _languageService['hadith'] ?? '40 Hadis',
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
                    _languageService['quran'] ?? 'Kur\'an-ı Kerim',
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
                    _languageService['settings'] ?? 'Ayarlar',
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
                    await _konumYukle();
                    // Vakit listesini yenile
                    setState(() {
                      _vakitListesiKey = UniqueKey();
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMenuBottomSheet(BuildContext context, renkler) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: renkler.arkaPlan,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [renkler.vurgu, renkler.vurgu.withOpacity(0.7)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.apps, color: Colors.white.withOpacity(0.8), size: 28),
                  const SizedBox(width: 12),
                  const Text('MENÜ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildMenuCard(icon: Icons.schedule, title: _languageService['calendar'] ?? 'İmsakiye', color: Colors.blue, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ImsakiyeSayfa())); }),
                    _buildMenuCard(icon: Icons.auto_awesome, title: _languageService['dhikr'] ?? 'Zikir Matik', color: Colors.purple, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ZikirMatikSayfa())); }),
                    _buildMenuCard(icon: Icons.mosque, title: _languageService['worship'] ?? 'İbadet', color: Colors.green, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const IbadetSayfa())); }),
                    _buildMenuCard(icon: Icons.explore, title: _languageService['qibla'] ?? 'Kıble Yönü', color: Colors.orange, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const KibleSayfa())); }),
                    _buildMenuCard(icon: Icons.place, title: _languageService['nearby_mosques'] ?? 'Yakın Camiler', color: Colors.red, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const YakinCamilerSayfa())); }),
                    _buildMenuCard(icon: Icons.celebration, title: _languageService['special_days'] ?? 'Özel Günler', color: Colors.pink, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const OzelGunlerSayfa())); }),
                    _buildMenuCard(icon: Icons.menu_book, title: _languageService['hadith'] ?? '40 Hadis', color: Colors.teal, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const KirkHadisSayfa())); }),
                    _buildMenuCard(icon: Icons.auto_stories, title: _languageService['quran'] ?? 'Kur\'an-ı Kerim', color: Colors.indigo, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const KuranSayfa())); }),
                    _buildMenuCard(icon: Icons.settings, title: _languageService['settings'] ?? 'Ayarlar', color: Colors.blueGrey, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const AyarlarSayfa())); }),
                    _buildMenuCard(icon: Icons.info, title: _languageService['about'] ?? 'Hakkında', color: Colors.amber, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const HakkindaSayfa())); }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.8), color.withOpacity(0.6)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
