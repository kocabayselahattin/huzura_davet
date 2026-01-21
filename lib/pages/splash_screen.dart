import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ana_sayfa.dart';
import 'il_ilce_sec_sayfa.dart';
import 'dil_secim_sayfa.dart';
import 'onboarding_permissions_page.dart';
import '../services/konum_service.dart';
import '../services/permission_service.dart';
import '../services/language_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _durum = 'Başlatılıyor...';

  @override
  void initState() {
    super.initState();
    _kontrolVeYonlendir();
  }

  Future<void> _kontrolVeYonlendir() async {
    if (!mounted) return;

    // 1 saniye splash screen göster
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // SharedPreferences'ı tek seferde al
    final prefs = await SharedPreferences.getInstance();
    final dilSecildi = prefs.containsKey('language');
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    // İlk açılış kontrolü
    if (!dilSecildi) {
      // 1. Dil seçimi
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DilSecimSayfa()),
      );

      if (result != true || !mounted) return;
    }

    // 2. İzin onboarding (sadece ilk kurulumda)
    if (!onboardingCompleted) {
      setState(() => _durum = 'İzinler ayarlanıyor...');

      final permissionResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OnboardingPermissionsPage(),
        ),
      );

      if (!mounted) return;

      // Onboarding tamamlandı olarak işaretle
      await prefs.setBool('onboarding_completed', true);
    }

    // Önce kaydedilmiş konum var mı kontrol et
    setState(() => _durum = 'Konum kontrol ediliyor...');

    // SharedPreferences'tan direkt oku
    final ilceId = prefs.getString('selected_ilce_id');
    final ilId = prefs.getString('selected_il_id');

    // Hızlı validasyon (API çağrısı yapmadan)
    bool isValid = _hizliValidasyon(ilceId);

    // Eğer geçerli konum varsa, direkt ana sayfaya git
    if (isValid &&
        ilceId != null &&
        ilceId.isNotEmpty &&
        ilId != null &&
        ilId.isNotEmpty) {
      print('✅ Kayıtlı konum bulundu, ana sayfaya yönlendiriliyor...');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AnaSayfa(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
      return;
    }

    // Konum kaydedilmemişse (ilk açılış) konum iznini kontrol et
    setState(() => _durum = 'Konum izni kontrol ediliyor...');

    // Konum iznini kontrol et
    final konumIzniVar = await PermissionService.checkLocationPermission();

    if (!mounted) return;

    // İlk açılış: İl/İlçe seçim sayfasına yönlendir
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            IlIlceSecOnboarding(konumIzniVar: konumIzniVar),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  // Hızlı ilçe ID validasyonu (async olmadan)
  bool _hizliValidasyon(String? ilceId) {
    if (ilceId == null || ilceId.isEmpty) return false;

    // Bilinen geçersiz ID'ler
    const invalidIds = [
      '1219',
      '1823',
      '1020',
      '1003',
      '1421',
      '1200',
      '1201',
      '1202',
      '1203',
      '1204',
      '1205',
    ];
    if (invalidIds.contains(ilceId)) return false;

    // Geçerli ID'ler genelde 9000-18000 aralığında
    try {
      final idNum = int.parse(ilceId);
      return idNum >= 9000 && idNum <= 20000;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Arka plan: İkon ile uyumlu koyu mavi gradient
      backgroundColor: const Color(0xFF1B2741),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          // İkon renkleri ile uyumlu gradient (#1B2741 -> #2B3151)
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B2741), // İkonun arka plan rengi
              Color(0xFF2B3151), // Hafif açık ton
              Color(0xFF1B2741), // Tekrar koyu ton
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Uygulama İkonu (PNG)
            Container(
              width: 150,
              height: 150,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BCD4).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Eğer icon yüklenemezse fallback olarak cami ikonu göster
                    return const Icon(
                      Icons.mosque_outlined,
                      size: 90,
                      color: Color(0xFF00BCD4),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Uygulama İsmi
            const Text(
              "HUZUR VAKTİ",
              style: TextStyle(
                color: Color(0xFFFFFFFF), // Beyaz
                fontSize: 34,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
                shadows: [
                  Shadow(
                    color: Color(0xFF00BCD4),
                    blurRadius: 20,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Alt yazı
            Text(
              "Vaktin huzuruna erişin",
              style: TextStyle(
                color: const Color(0xFF00BCD4).withOpacity(0.7),
                fontSize: 15,
                fontStyle: FontStyle.italic,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            // Durum göstergesi
            Text(
              _durum,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(
                  const Color(0xFF00BCD4).withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// İlk kullanım için Onboarding Sayfası
class IlIlceSecOnboarding extends StatelessWidget {
  final bool konumIzniVar;

  const IlIlceSecOnboarding({super.key, this.konumIzniVar = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hoşgeldin İkonu
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 80,
                  color: Colors.cyanAccent,
                ),
              ),
              const SizedBox(height: 40),

              // Hoşgeldin Başlık
              Text(
                LanguageService().translate('welcome_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Açıklama
              Text(
                konumIzniVar
                    ? LanguageService().translate('welcome_desc_location')
                    : LanguageService().translate('welcome_desc_manual'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Devam Et Butonu
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IlIlceSecSayfa(
                        ilkKurulum: true,
                        otomatikKonumTespit: konumIzniVar,
                      ),
                    ),
                  );

                  if (result == true && context.mounted) {
                    // Seçim başarılı, ana sayfaya git
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const AnaSayfa()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      konumIzniVar
                          ? LanguageService().translate('auto_detect')
                          : LanguageService().translate('manual_select'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, size: 24),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // İpucu
              Text(
                LanguageService().translate('settings_tip'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
