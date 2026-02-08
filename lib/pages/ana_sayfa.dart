import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
import '../widgets/gun_donumu_sayac_widget.dart';
import '../widgets/esmaul_husna_widget.dart';
import '../widgets/ramazan_banner_widget.dart';
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
  int _currentSayacIndex = 22;
  bool _sayacYuklendi = false;

  // Multi-location system
  List<KonumModel> _konumlar = [];
  int _aktifKonumIndex = 0;
  PageController? _konumPageController;

  // Key for widget refresh
  Key _vakitListesiKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadSayacIndex(); // Load the selected counter index
    _konumYukle();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
    // Special day popup check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOzelGun();
      // Schedule notifications
      _scheduleNotifications();
      // Auto location update check
      _checkLocationChange();
    });
  }

  Future<void> _scheduleNotifications() async {
    try {
      await ScheduledNotificationService.scheduleAllPrayerNotifications();
    } catch (e) {
      debugPrint('⚠️ Notification scheduling error: $e');
    }
  }

  /// Check location changes and notify if city changed.
  Future<void> _checkLocationChange() async {
    try {
      // Get current saved location
      final aktifKonum = await KonumService.getAktifKonum();
      if (aktifKonum == null) {
        debugPrint('📍 No saved location, skipping check');
        return;
      }

      // GPS permission check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 GPS disabled, skipping location check');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permission missing, skipping check');
        return;
      }

      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy:
              LocationAccuracy.low, // Low accuracy for faster result
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('📍 Location fetch failed: $e');
        return;
      }

      // Reverse geocode to get city info
      final locationInfo = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (locationInfo == null) {
        debugPrint('📍 City info not available');
        return;
      }

      final currentCity = locationInfo['city']?.toString().toUpperCase() ?? '';
      final currentDistrict = locationInfo['district']?.toString() ?? '';
      final savedCity = aktifKonum.ilAdi.toUpperCase();

      // Normalize locale-specific characters
      final normalizedCurrentCity = _normalizeString(currentCity);
      final normalizedSavedCity = _normalizeString(savedCity);

      debugPrint('📍 Current city: $currentCity ($normalizedCurrentCity)');
      debugPrint('📍 Saved city: $savedCity ($normalizedSavedCity)');

      // Check if city changed
      if (normalizedCurrentCity.isNotEmpty &&
          normalizedSavedCity.isNotEmpty &&
          !normalizedCurrentCity.contains(normalizedSavedCity) &&
          !normalizedSavedCity.contains(normalizedCurrentCity)) {
        debugPrint('🔄 City change detected!');

        // Ask the user
        if (mounted) {
          _showLocationChangeDialog(currentCity, currentDistrict, savedCity);
        }
      }
    } catch (e) {
      debugPrint('📍 Location check error: $e');
    }
  }

  /// Reverse geocode coordinates to city/district.
  Future<Map<String, String>?> _reverseGeocode(double lat, double lon) async {
    try {
      final languageCode = _languageService.currentLanguage;
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1&accept-language=$languageCode';

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'HuzurVakti/2.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          return {
            'city':
                address['province'] ??
                address['state'] ??
                address['city'] ??
                '',
            'district':
                address['town'] ??
                address['county'] ??
                address['district'] ??
                '',
            'country_code':
                address['country_code']?.toString().toUpperCase() ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('⚠️ Reverse geocoding error: $e');
    }
    return null;
  }

  /// Normalize locale-specific characters
  String _normalizeString(String input) {
    return input
        .replaceAll('İ', 'I')
        .replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G')
        .replaceAll('Ü', 'U')
        .replaceAll('Ö', 'O')
        .replaceAll('Ç', 'C')
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(' PROVINCE', '')
        .replaceAll(' İLİ', '')
        .trim();
  }

  /// Show location change dialog
  void _showLocationChangeDialog(
    String newCity,
    String newDistrict,
    String savedCity,
  ) {
    final renkler = _temaService.renkler;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.location_on, color: renkler.vurgu),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _languageService['location_changed'] ?? '',
                style: TextStyle(color: renkler.yaziPrimary, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                _languageService['location_change_detected'] ?? '',
              style: TextStyle(color: renkler.yaziSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: renkler.arkaPlan,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location, color: renkler.vurgu, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_languageService['current_location'] ?? ''}: $newCity${newDistrict.isNotEmpty ? ' / $newDistrict' : ''}',
                          style: TextStyle(
                            color: renkler.yaziPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_city,
                        color: renkler.yaziSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_languageService['saved_location'] ?? ''}: $savedCity',
                          style: TextStyle(
                            color: renkler.yaziSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
                _languageService['update_location_question'] ?? '',
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _languageService['no_keep_current'] ?? '',
              style: TextStyle(color: renkler.yaziSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: renkler.vurgu,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to location selection
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IlIlceSecSayfa()),
              ).then((_) {
                // Reload location on return
                _konumYukle();
              });
            },
            child: Text(_languageService['yes_update'] ?? ''),
          ),
        ],
      ),
    );
  }

  Future<void> _checkOzelGun() async {
    if (mounted) {
      await checkAndShowOzelGunPopup(context);
    }
  }

  Future<void> _loadSayacIndex() async {
    // Get counter index from TemaService
    final index = _temaService.aktifSayacIndex;
    if (mounted) {
      setState(() {
        _currentSayacIndex = index == 0 ? 22 : index;
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
        // Update when counter changes
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
              (_languageService['location_not_selected'] ?? '').toUpperCase();
        } else {
          final aktifKonum = konumlar[_aktifKonumIndex];
          konumBasligi = "${aktifKonum.ilAdi} / ${aktifKonum.ilceAdi}";
        }

        _konumPageController = PageController(initialPage: _aktifKonumIndex);
      });
    }
  }

  // Change location
  Future<void> _konumDegistir(int yeniIndex) async {
    if (yeniIndex >= 0 && yeniIndex < _konumlar.length) {
      await KonumService.setAktifKonumIndex(yeniIndex);
      setState(() {
        _aktifKonumIndex = yeniIndex;
        final aktifKonum = _konumlar[yeniIndex];
        konumBasligi = "${aktifKonum.ilAdi} / ${aktifKonum.ilceAdi}";
      });

      // Update widgets
      await HomeWidgetService.updateAllWidgets();
      debugPrint('✅ Active location changed: ${_konumlar[yeniIndex].tamAd}');

      // Refresh prayer list and widgets
      if (mounted) {
        setState(() {
          _vakitListesiKey =
              UniqueKey(); // Force rebuild prayer list
        });
      }
    }
  }

  // App info popup
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
              _languageService['app_name'] ?? '',
              style: TextStyle(
                color: renkler.yaziPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_languageService['version'] ?? ''}: 1.0.0+1',
              style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
                _languageService['prayer_times_assistant'] ?? '',
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
                    _languageService['about'] ?? '',
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
                    _languageService['close'] ?? '',
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

  // Location selection popup dialog
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
              _languageService['saved_locations_title'] ?? '',
              style: TextStyle(color: renkler.yaziPrimary, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _konumlar.isEmpty
              ? Text(
                    _languageService['no_saved_locations'] ?? '',
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
                                _languageService['active_location'] ?? '',
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
                                          '',
                                        style: TextStyle(
                                          color: renkler.yaziPrimary,
                                        ),
                                      ),
                                      content: Text(
                                        '${konum.tamAd} ${_languageService['delete_location_confirm'] ?? ''}',
                                        style: TextStyle(
                                          color: renkler.yaziSecondary,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(
                                            _languageService['cancel'] ?? '',
                                            style: TextStyle(
                                              color: renkler.yaziSecondary,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            _languageService['delete'] ?? '',
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
              _languageService['close'] ?? '',
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
          // Qibla compass icon
          IconButton(
            icon: Icon(Icons.explore, color: renkler.vurgu, size: 26),
            tooltip: _languageService['qibla'] ?? '',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KibleSayfa()),
              );
            },
          ),
          // Add location icon
          IconButton(
            icon: Icon(Icons.add_location_alt, color: renkler.vurgu, size: 26),
            tooltip: _languageService['add_location'] ?? '',
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
              // --- LOCATION WARNING (when location not selected) ---
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
                                  '',
                              style: TextStyle(
                                color: renkler.yaziPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                                _languageService['select_location_prompt'] ??
                                  '',
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

              // --- COUNTER SECTION ---
              SizedBox(
                height: 240,
                width: double.infinity,
                child: _sayacYuklendi
                    ? _buildSelectedCounter()
                    : const Center(child: CircularProgressIndicator()),
              ),

              const SizedBox(height: 10),

              // --- RAMAZAN BANNER ---
              const RamazanBannerWidget(),

              const SizedBox(height: 10),

              // --- ESMAUL HUSNA ---
              const EsmaulHusnaWidget(),

              const SizedBox(height: 10),

              // --- SPECIAL DAY BANNER ---
              const OzelGunBannerWidget(),

              const SizedBox(height: 10),

              // --- PRAYER TIMES LIST ---
              VakitListesiWidget(key: _vakitListesiKey),

              const SizedBox(height: 20),

              // --- TODAY'S CONTENT ---
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
    switch (_currentSayacIndex) {
      case 0:
        return const IslamiSayacWidget();
      case 1:
        return const KalemSayacWidget();
      case 2:
        return const NurSayacWidget();
      case 3:
        return const HilalSayacWidget();
      case 4:
        return const MihrapSayacWidget();
      case 5:
        return const DijitalSayacWidget();
      case 6:
        return const PremiumSayacWidget();
      case 7:
        return const GalaksiSayacWidget();
      case 8:
        return const NeonSayacWidget();
      case 9:
        return const OkyanusSayacWidget();
      case 10:
        return const MinimalSayacWidget();
      case 11:
        return const RetroSayacWidget();
      case 12:
        return const AuroraSayacWidget();
      case 13:
        return const KristalSayacWidget();
      case 14:
        return const VolkanikSayacWidget();
      case 15:
        return const ZenSayacWidget();
      case 16:
        return const SiberSayacWidget();
      case 17:
        return const GeceSayacWidget();
      case 18:
        return const MatrixSayacWidget();
      case 19:
        return const NefesSayacWidget();
      case 20:
        return const GeometrikSayacWidget();
      case 21:
        return const TeslaSayacWidget();
      case 22:
        return const GunDonumuSayacWidget();
      default:
        return const IslamiSayacWidget();
    }
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.apps,
                    color: Colors.white.withOpacity(0.8),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _languageService['menu_title'] ?? '',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                    _buildMenuCard(
                      icon: Icons.schedule,
                      title: _languageService['calendar'] ?? '',
                      color: Colors.blue,
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
                    _buildMenuCard(
                      icon: Icons.auto_awesome,
                      title: _languageService['dhikr'] ?? '',
                      color: Colors.purple,
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
                    _buildMenuCard(
                      icon: Icons.mosque,
                      title: _languageService['worship'] ?? '',
                      color: Colors.green,
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
                    _buildMenuCard(
                      icon: Icons.explore,
                      title: _languageService['qibla'] ?? '',
                      color: Colors.orange,
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
                    _buildMenuCard(
                      icon: Icons.place,
                        title: _languageService['nearby_mosques'] ?? '',
                      color: Colors.red,
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
                    _buildMenuCard(
                      icon: Icons.celebration,
                      title: _languageService['special_days'] ?? '',
                      color: Colors.pink,
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
                    _buildMenuCard(
                      icon: Icons.menu_book,
                      title: _languageService['hadith'] ?? '',
                      color: Colors.teal,
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
                    _buildMenuCard(
                      icon: Icons.auto_stories,
                      title: _languageService['quran'] ?? '',
                      color: Colors.indigo,
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
                    _buildMenuCard(
                      icon: Icons.settings,
                      title: _languageService['settings'] ?? '',
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AyarlarSayfa(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      icon: Icons.info,
                      title: _languageService['about'] ?? '',
                      color: Colors.amber,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HakkindaSayfa(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
