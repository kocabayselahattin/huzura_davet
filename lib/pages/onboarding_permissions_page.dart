import 'package:flutter/material.dart';
import 'dart:io';
import '../services/permission_service.dart';

/// Uygulama ilk açılışta gerekli tüm izinleri sırayla ister
class OnboardingPermissionsPage extends StatefulWidget {
  const OnboardingPermissionsPage({super.key});

  @override
  State<OnboardingPermissionsPage> createState() =>
      _OnboardingPermissionsPageState();
}

class _OnboardingPermissionsPageState extends State<OnboardingPermissionsPage> {
  int _currentStep = 0;
  bool _isProcessing = false;

  // İzin durumları
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _overlayGranted = false;
  bool _batteryOptDisabled = false;
  bool _exactAlarmGranted = false;

  final List<_PermissionStep> _steps = [
    _PermissionStep(
      icon: Icons.location_on,
      title: 'Konum İzni',
      description:
          'Bulunduğunuz konuma göre doğru namaz vakitlerini gösterebilmek için konum izni gereklidir.',
      color: Colors.blue,
    ),
    _PermissionStep(
      icon: Icons.notifications_active,
      title: 'Bildirim İzni',
      description:
          'Namaz vakitlerinde sizi bilgilendirmek için bildirim izni gereklidir.',
      color: Colors.orange,
    ),
    _PermissionStep(
      icon: Icons.alarm,
      title: 'Tam Zamanlı Alarm İzni',
      description:
          'Bildirimlerin tam vakitinde çalması için alarm izni gereklidir.',
      color: Colors.purple,
    ),
    _PermissionStep(
      icon: Icons.layers,
      title: 'Üstünde Göster İzni',
      description:
          'Vakit girdiğinde ekranda bildirim gösterebilmek için bu izin gereklidir.',
      color: Colors.teal,
    ),
    _PermissionStep(
      icon: Icons.battery_charging_full,
      title: 'Pil Optimizasyonu Muafiyeti',
      description:
          'Arka planda bildirimlerin düzgün çalışması için pil optimizasyonunun kapatılması gerekir.',
      color: Colors.green,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    if (!Platform.isAndroid) return;

    final locationStatus = await PermissionService.checkLocationPermission();
    final notificationStatus =
        await PermissionService.checkNotificationPermission();
    final exactAlarmStatus = await PermissionService.hasExactAlarmPermission();
    final overlayStatus = await PermissionService.hasOverlayPermission();
    final batteryStatus =
        await PermissionService.isBatteryOptimizationDisabled();

    if (mounted) {
      setState(() {
        _locationGranted = locationStatus;
        _notificationGranted = notificationStatus;
        _exactAlarmGranted = exactAlarmStatus;
        _overlayGranted = overlayStatus;
        _batteryOptDisabled = batteryStatus;
      });
    }
  }

  Future<void> _requestCurrentPermission() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      bool granted = false;

      switch (_currentStep) {
        case 0: // Konum
          granted = await PermissionService.requestLocationPermission();
          _locationGranted = granted;
          break;
        case 1: // Bildirim
          granted = await PermissionService.requestNotificationPermission();
          _notificationGranted = granted;
          break;
        case 2: // Exact Alarm
          granted = await PermissionService.requestExactAlarmPermission();
          _exactAlarmGranted = granted;
          break;
        case 3: // Overlay
          await PermissionService.openOverlaySettings();
          // Ayarlardan döndükten sonra kontrol et
          await Future.delayed(const Duration(milliseconds: 500));
          _overlayGranted = await PermissionService.hasOverlayPermission();
          granted = _overlayGranted;
          break;
        case 4: // Pil
          await PermissionService.requestBatteryOptimizationExemption();
          await Future.delayed(const Duration(milliseconds: 500));
          _batteryOptDisabled =
              await PermissionService.isBatteryOptimizationDisabled();
          granted = _batteryOptDisabled;
          break;
      }

      if (mounted) {
        setState(() {});

        if (granted || _currentStep >= _steps.length - 1) {
          _nextStep();
        } else {
          // İzin verilmedi uyarısı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_steps[_currentStep].title} verilmedi. Yine de devam edebilirsiniz.',
              ),
              action: SnackBarAction(label: 'Devam', onPressed: _nextStep),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    Navigator.pop(context, true);
  }

  void _skipAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2B3151),
        title: const Text(
          'İzinleri Atla?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Bazı özellikler (bildirimler, konum tabanlı vakitler) düzgün çalışmayabilir.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeOnboarding();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Atla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  bool _isStepGranted(int step) {
    switch (step) {
      case 0:
        return _locationGranted;
      case 1:
        return _notificationGranted;
      case 2:
        return _exactAlarmGranted;
      case 3:
        return _overlayGranted;
      case 4:
        return _batteryOptDisabled;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isGranted = _isStepGranted(_currentStep);

    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Üst kısım - Progress
              Row(
                children: [
                  for (int i = 0; i < _steps.length; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _currentStep
                              ? _steps[i].color
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Adım sayacı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Adım ${_currentStep + 1} / ${_steps.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: _skipAll,
                    child: const Text(
                      'Tümünü Atla',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Ana içerik
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_currentStep),
                  children: [
                    // İkon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: step.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(step.icon, size: 60, color: step.color),
                          if (isGranted)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Başlık
                    Text(
                      step.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Açıklama
                    Text(
                      step.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (isGranted) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'İzin Verildi',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Butonlar
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Geri',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : (isGranted ? _nextStep : _requestCurrentPermission),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isGranted ? Colors.green : step.color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isGranted
                                  ? (_currentStep < _steps.length - 1
                                        ? 'Devam'
                                        : 'Tamamla')
                                  : 'İzin Ver',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Alt bilgi
              Text(
                _currentStep < _steps.length - 1
                    ? 'Bu izni vermezseniz bazı özellikler çalışmayabilir'
                    : 'Tüm izinler alındı, uygulamayı kullanmaya başlayabilirsiniz',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStep {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _PermissionStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
