import 'package:flutter/material.dart';
import 'ana_sayfa.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3 saniye sonra Ana Sayfaya yumuşak bir geçiş yap
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AnaSayfa(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
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
                shadows: [
                  Shadow(
                    color: Color(0xFF40916C),
                    blurRadius: 15,
                  ),
                ],
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
          ],
        ),
      ),
    );
  }
}