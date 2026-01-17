import 'package:flutter/material.dart';
import '../services/ozel_gunler_service.dart';

class OzelGunPopup extends StatelessWidget {
  final OzelGun ozelGun;
  final VoidCallback onKapat;

  const OzelGunPopup({
    super.key,
    required this.ozelGun,
    required this.onKapat,
  });

  @override
  Widget build(BuildContext context) {
    final renk = _getRenk(ozelGun.tur);
    final ikon = _getIkon(ozelGun.tur);
    
    return Material(
      color: Colors.black54,
      child: InkWell(
        onTap: onKapat,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  renk.withValues(alpha: 0.9),
                  renk.withValues(alpha: 0.7),
                  _getRenkSecondary(ozelGun.tur).withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: renk.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dekoratif ikon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    ikon,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Tebrik mesajı
                Text(
                  ozelGun.tebrikMesaji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Özel gün adı
                Text(
                  ozelGun.ad,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Açıklama
                Text(
                  ozelGun.aciklama,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Kapatma ipucu
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kapatmak için dokunun',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRenk(OzelGunTuru tur) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return const Color(0xFFFFB300); // Altın sarısı
      case OzelGunTuru.kandil:
        return const Color(0xFF7B1FA2); // Mor
      case OzelGunTuru.mubarekGece:
        return const Color(0xFF00695C); // Koyu yeşil
      case OzelGunTuru.onemliGun:
        return const Color(0xFF1565C0); // Mavi
    }
  }

  Color _getRenkSecondary(OzelGunTuru tur) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return const Color(0xFFFF8F00);
      case OzelGunTuru.kandil:
        return const Color(0xFF4A148C);
      case OzelGunTuru.mubarekGece:
        return const Color(0xFF004D40);
      case OzelGunTuru.onemliGun:
        return const Color(0xFF0D47A1);
    }
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
}

/// Özel gün popup'ını göster
Future<void> showOzelGunPopup(BuildContext context, OzelGun ozelGun) async {
  await OzelGunlerService.popupGosterildiIsaretle();
  
  if (!context.mounted) return;
  
  await showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) => OzelGunPopup(
      ozelGun: ozelGun,
      onKapat: () => Navigator.of(context).pop(),
    ),
  );
}

/// Otomatik olarak özel gün kontrolü yap ve gerekirse popup göster
Future<void> checkAndShowOzelGunPopup(BuildContext context) async {
  // Popup gösterilmeli mi kontrol et
  final gosterilmeliMi = await OzelGunlerService.popupGosterilmeliMi();
  if (!gosterilmeliMi) return;
  
  // Bugün özel gün var mı kontrol et
  final ozelGun = OzelGunlerService.bugunOzelGunMu();
  if (ozelGun == null) return;
  
  if (!context.mounted) return;
  
  // Kısa bir gecikme ile göster (sayfa yüklendikten sonra)
  await Future.delayed(const Duration(milliseconds: 500));
  
  if (!context.mounted) return;
  
  await showOzelGunPopup(context, ozelGun);
}
