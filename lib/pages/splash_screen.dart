import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ana_sayfa.dart';
import 'il_ilce_sec_sayfa.dart';
import 'dil_secim_sayfa.dart';
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
    // İlk önce temel izinleri kontrol et
    if (!mounted) return;
    
    setState(() => _durum = 'İzinler kontrol ediliyor...');
    
    // Bildirim izinlerini iste (konum izninden önce) - timeout ile
    try {
      await PermissionService.requestAllPermissions()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('⚠️ İzin isteği zaman aşımına uğradı');
      });
    } catch (e) {
      print('⚠️ İzin isteği hatası: $e');
    }
    
    // 1 saniye splash screen göster (hız için kısaltıldı)
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // SharedPreferences'ı tek seferde al (performans için)
    final prefs = await SharedPreferences.getInstance();
    final dilSecildi = prefs.containsKey('language');
    
    if (!dilSecildi) {
      // İlk açılış - dil seçim ekranını göster
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DilSecimSayfa(),
        ),
      );
      
      if (result != true || !mounted) return;
    }

    // Önce kaydedilmiş konum var mı kontrol et
    setState(() => _durum = 'Konum kontrol ediliyor...');
    
    // SharedPreferences'tan direkt oku (ayrı await'ler yerine)
    final ilceId = prefs.getString('selected_ilce_id');
    final ilId = prefs.getString('selected_il_id');
    
    // Hızlı validasyon (API çağrısı yapmadan)
    bool isValid = _hizliValidasyon(ilceId);
    
    // Eğer geçerli konum varsa, direkt ana sayfaya git
    if (isValid && ilceId != null && ilceId.isNotEmpty && ilId != null && ilId.isNotEmpty) {
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

    // Konum iznini kontrol et (ancak zorla isteme)
    final konumIzniVar = await _konumIzniKontrolEt();

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

  Future<bool> _konumIzniKontrolEt() async {
    try {
      // Konum servisi açık mı kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Konum servisi kapalı');
        return false;
      }

      // İzin durumunu kontrol et
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // İzin iste
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Konum izni reddedildi');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Konum izni kalıcı olarak reddedildi');
        return false;
      }

      print('✅ Konum izni verildi');
      return true;
    } catch (e) {
      print('⚠️ Konum izni kontrolü hatası: $e');
      return false;
    }
  }

  // Hızlı ilçe ID validasyonu (async olmadan)
  bool _hizliValidasyon(String? ilceId) {
    if (ilceId == null || ilceId.isEmpty) return false;
    
    // Bilinen geçersiz ID'ler
    const invalidIds = ['1219', '1823', '1020', '1003', '1421', '1200', '1201', '1202', '1203', '1204', '1205'];
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
      // Arka plan: Derin petrol mavisi (Huzur veren koyu ton)
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          // Hafif bir gradyan ekleyerek derinlik kazandırıyoruz
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFF1B4332), // Merkeze yakın hafif yeşil dokunuş
              Color(0xFF081C15), // Kenarlara doğru derinleşen koyu ton
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern Cami İkonu (Neon Efektli)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D6A4F).withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mosque_outlined,
                size: 120,
                color: Color(0xFF74C69D), // Tatlı nane yeşili neon
              ),
            ),
            const SizedBox(height: 30),
            // Uygulama İsmi
            const Text(
              "HUZUR VAKTİ",
              style: TextStyle(
                color: Color(0xFFD8F3DC), // Çok açık yeşil, beyaza yakın
                fontSize: 32,
                fontWeight: FontWeight.w300, // Modern ve ince yazı tipi
                letterSpacing: 8, // Harf arası boşlukla ferahlık hissi
                shadows: [Shadow(color: Color(0xFF40916C), blurRadius: 15)],
              ),
            ),
            const SizedBox(height: 10),
            // Küçük bir alt yazı (Opsiyonel)
            Text(
              "Vaktin huzuruna erişin",
              style: TextStyle(
                color: const Color(0xFF95D5B2).withOpacity(0.6),
                fontSize: 14,
                fontStyle: FontStyle.italic,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 30),
            // Durum göstergesi
            Text(
              _durum,
              style: TextStyle(
                color: const Color(0xFF95D5B2).withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  const Color(0xFF74C69D).withOpacity(0.5),
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
                      builder: (context) =>
                          IlIlceSecSayfa(ilkKurulum: true, otomatikKonumTespit: konumIzniVar),
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
