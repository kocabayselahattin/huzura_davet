import 'package:flutter/material.dart';
import '../services/ozel_gunler_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Özel gün ve gece banner widget'ı
/// Esmaül Hüsna ile Vakit Listesi arasında gösterilir
class OzelGunBannerWidget extends StatefulWidget {
  const OzelGunBannerWidget({super.key});

  @override
  State<OzelGunBannerWidget> createState() => _OzelGunBannerWidgetState();
}

class _OzelGunBannerWidgetState extends State<OzelGunBannerWidget>
    with SingleTickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  OzelGun? _ozelGun;

  @override
  void initState() {
    super.initState();
    _ozelGun = OzelGunlerService.bugunOzelGunMu();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _temaService.addListener(_onUpdate);
    _languageService.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _temaService.removeListener(_onUpdate);
    _languageService.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {
        _ozelGun = OzelGunlerService.bugunOzelGunMu();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Özel gün yoksa boş widget döndür
    if (_ozelGun == null) {
      return const SizedBox.shrink();
    }

    final renkler = _temaService.renkler;
    final bannerRenkleri = _getBannerRenkleri(_ozelGun!.tur);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  bannerRenkleri.primary,
                  bannerRenkleri.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: bannerRenkleri.primary.withValues(alpha: _glowAnimation.value),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: bannerRenkleri.secondary.withValues(alpha: _glowAnimation.value * 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Dekoratif arka plan desenleri
                Positioned(
                  right: -20,
                  top: -20,
                  child: Icon(
                    _getDekoratifIkon(_ozelGun!.tur),
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  left: -15,
                  bottom: -15,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                // İçerik
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Sol taraf - Animasyonlu ikon
                      _buildAnimatedIcon(bannerRenkleri),
                      const SizedBox(width: 16),
                      // Sağ taraf - Metin içeriği
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Özel gün adı
                            Text(
                              _ozelGun!.ad,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Tebrik mesajı
                            Row(
                              children: [
                                _buildSparkle(),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _ozelGun!.tebrikMesaji,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                _buildSparkle(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedIcon(_BannerRenkleri renk) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2 + (_glowAnimation.value * 0.1)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: _glowAnimation.value * 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            _getIkon(_ozelGun!.tur),
            size: 32,
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildSparkle() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (_glowAnimation.value * 0.5),
          child: const Text(
            '✨',
            style: TextStyle(fontSize: 14),
          ),
        );
      },
    );
  }

  _BannerRenkleri _getBannerRenkleri(OzelGunTuru tur) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return _BannerRenkleri(
          primary: const Color(0xFFFFB300),
          secondary: const Color(0xFFFF8F00),
        );
      case OzelGunTuru.kandil:
        return _BannerRenkleri(
          primary: const Color(0xFF7B1FA2),
          secondary: const Color(0xFF4A148C),
        );
      case OzelGunTuru.mubarekGece:
        return _BannerRenkleri(
          primary: const Color(0xFF00695C),
          secondary: const Color(0xFF004D40),
        );
      case OzelGunTuru.onemliGun:
        return _BannerRenkleri(
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF0D47A1),
        );
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

  IconData _getDekoratifIkon(OzelGunTuru tur) {
    switch (tur) {
      case OzelGunTuru.bayram:
        return Icons.mosque;
      case OzelGunTuru.kandil:
        return Icons.auto_awesome;
      case OzelGunTuru.mubarekGece:
        return Icons.nightlight_round;
      case OzelGunTuru.onemliGun:
        return Icons.menu_book;
    }
  }
}

class _BannerRenkleri {
  final Color primary;
  final Color secondary;

  _BannerRenkleri({required this.primary, required this.secondary});
}
