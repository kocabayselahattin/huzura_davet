import 'package:flutter/material.dart';
import 'dart:io';
import '../services/permission_service.dart';
import '../services/language_service.dart';

/// Uygulama ilk açılışta gerekli tüm izinleri sırayla ister
class OnboardingPermissionsPage extends StatefulWidget {
  const OnboardingPermissionsPage({super.key});

  @override
  State<OnboardingPermissionsPage> createState() =>
      _OnboardingPermissionsPageState();
}

class _OnboardingPermissionsPageState extends State<OnboardingPermissionsPage>
    with WidgetsBindingObserver {
  final LanguageService _languageService = LanguageService();
  int _currentStep = 0;
  bool _isProcessing = false;

  // İzin durumları
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _overlayGranted = false;
  bool _batteryOptDisabled = false;
  bool _exactAlarmGranted = false;
  bool _dndGranted = false;

  late List<_PermissionStep> _steps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('🔐 OnboardingPermissions: initState başladı');
    _initSteps();
    _checkCurrentPermissions();
    print('🔐 OnboardingPermissions: initState bitti');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckSpecialPermissions();
    }
  }

  void _initSteps() {
    _steps = [
      _PermissionStep(
        icon: Icons.location_on,
        title: _languageService['location_permission'] ?? '',
        description:
            _languageService['location_permission_desc'] ?? '',
        color: Colors.blue,
      ),
      _PermissionStep(
        icon: Icons.notifications_active,
        title: _languageService['notification_permission'] ?? '',
        description:
            _languageService['notification_permission_desc'] ?? '',
        color: Colors.orange,
      ),
      _PermissionStep(
        icon: Icons.alarm,
        title:
            _languageService['exact_alarm_permission'] ?? '',
        description:
            _languageService['exact_alarm_permission_desc'] ?? '',
        color: Colors.purple,
      ),
      _PermissionStep(
        icon: Icons.layers,
        title: _languageService['overlay_permission'] ?? '',
        description:
            _languageService['overlay_permission_desc'] ?? '',
        color: Colors.teal,
      ),
      _PermissionStep(
        icon: Icons.battery_charging_full,
        title:
            _languageService['battery_permission'] ?? '',
        description:
            _languageService['battery_permission_desc'] ?? '',
        color: Colors.green,
      ),
      _PermissionStep(
        icon: Icons.do_not_disturb,
        title: _languageService['dnd_permission'] ?? '',
        description:
            _languageService['dnd_permission_desc'] ?? '',
        color: Colors.red,
      ),
    ];
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
    final dndStatus = await PermissionService.hasDndPolicyAccess();

    if (mounted) {
      setState(() {
        _locationGranted = locationStatus;
        _notificationGranted = notificationStatus;
        _exactAlarmGranted = exactAlarmStatus;
        _overlayGranted = overlayStatus;
        _batteryOptDisabled = batteryStatus;
        _dndGranted = dndStatus;
      });
    }
  }

  Future<void> _recheckSpecialPermissions() async {
    if (!Platform.isAndroid) return;
    final overlayStatus = await PermissionService.hasOverlayPermission();
    final batteryStatus =
        await PermissionService.isBatteryOptimizationDisabled();
    final dndStatus = await PermissionService.hasDndPolicyAccess();
    if (mounted) {
      setState(() {
        _overlayGranted = overlayStatus;
        _batteryOptDisabled = batteryStatus;
        _dndGranted = dndStatus;
      });
    }
  }

  Future<bool> _checkOverlayWithRetry() async {
    for (int i = 0; i < 4; i++) {
      final granted = await PermissionService.hasOverlayPermission();
      if (granted) return true;
      await Future.delayed(const Duration(milliseconds: 700));
    }
    return await PermissionService.hasOverlayPermission();
  }

  Future<bool> _checkBatteryWithRetry() async {
    for (int i = 0; i < 4; i++) {
      final granted = await PermissionService.isBatteryOptimizationDisabled();
      if (granted) return true;
      await Future.delayed(const Duration(milliseconds: 700));
    }
    return await PermissionService.isBatteryOptimizationDisabled();
  }

  Future<void> _requestCurrentPermission() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      bool granted = false;

      switch (_currentStep) {
        case 0: // Konum
          granted = await PermissionService.requestLocationPermission();
          if (mounted) {
            _locationGranted =
                await PermissionService.checkLocationPermission();
            granted = _locationGranted;
          }
          break;
        case 1: // Bildirim
          granted = await PermissionService.requestNotificationPermission();
          if (mounted) {
            _notificationGranted =
                await PermissionService.checkNotificationPermission();
            granted = _notificationGranted;
          }
          break;
        case 2: // Exact Alarm
          granted = await PermissionService.requestExactAlarmPermission();
          if (mounted) {
            _exactAlarmGranted =
                await PermissionService.hasExactAlarmPermission();
            granted = _exactAlarmGranted;
          }
          break;
        case 3: // Overlay
          await PermissionService.openOverlaySettings();
          if (mounted) {
            _overlayGranted = await _checkOverlayWithRetry();
            granted = _overlayGranted;
          }
          break;
        case 4: // Pil
          await PermissionService.requestBatteryOptimizationExemption();
          if (mounted) {
            _batteryOptDisabled = await _checkBatteryWithRetry();
            granted = _batteryOptDisabled;
          }
          break;
        case 5: // DND
          await PermissionService.openDndPolicySettings();
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 500));
            _dndGranted = await PermissionService.hasDndPolicyAccess();
            granted = _dndGranted;
          }
          break;
      }

      if (mounted) {
        setState(() {});

        // İzin verildi veya son adımsa devam et
        if (granted) {
          _nextStep();
        } else {
          // İzin verilmedi - kullanıcıya açık bilgi ver
          if (!mounted) return;

          String message = '';
          switch (_currentStep) {
            case 0: // Konum
              message =
                _languageService['permission_location_denied_info'] ?? '';
              break;
            case 1: // Bildirim
              message =
                _languageService['permission_notification_denied_info'] ?? '';
              break;
            case 2: // Exact Alarm
              message =
                _languageService['permission_exact_alarm_denied_info'] ?? '';
              break;
            case 3: // Overlay
              message =
                _languageService['permission_overlay_denied_info'] ?? '';
              break;
            case 4: // Pil
              message =
                _languageService['permission_battery_denied_info'] ?? '';
              break;
            case 5: // DND
              message =
                _languageService['permission_dnd_denied_info'] ?? '';
              break;
          }

          final shouldContinue = await showDialog<bool>(
            context: context,
            barrierDismissible: false, // Dialog dışına tıklayarak kapatılamaz
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2B3151),
              title: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _languageService['permission_info'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    _languageService['try_again'] ?? '',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _languageService['continue'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );

          if (shouldContinue == true && mounted) {
            _nextStep();
          }
          // false ise aynı adımda kal, kullanıcı tekrar deneyebilir
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
        title: Text(
          _languageService['skip_permissions'] ?? '',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _languageService['skip_permissions_warning'] ?? '',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _languageService['cancel'] ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeOnboarding();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(
              _languageService['skip'] ?? '',
              style: const TextStyle(color: Colors.white),
            ),
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
      case 5:
        return _dndGranted;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔐 OnboardingPermissions: build çağrıldı, step=$_currentStep');
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
                    '${_languageService['step'] ?? ''} ${_currentStep + 1} / ${_steps.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: _skipAll,
                    child: Text(
                      _languageService['skip_all'] ?? '',
                      style: const TextStyle(color: Colors.white54),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        step.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.left,
                      ),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _languageService['permission_granted'] ?? '',
                              style: const TextStyle(
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
                        child: Text(
                          _languageService['back'] ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
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
                                        ? (_languageService['continue'] ?? '')
                                        : (_languageService['onboarding_complete'] ??
                                          ''))
                                : (_languageService['grant_permission'] ??
                                  ''),
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
                    ? (_languageService['permission_warning'] ?? '')
                    : (_languageService['all_permissions_granted'] ?? ''),
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
