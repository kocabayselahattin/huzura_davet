import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:app_settings/app_settings.dart';
import 'language_service.dart';
import 'ses_onizleme_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final Set<String> _createdChannels = {};

  static const String _onTimeChannelId = 'vakit_on_time_channel';
  static const String _earlyChannelId = 'vakit_early_channel';

  static const List<String> _legacySoundNames = [
    'aksam_ezani',
    'aksam_ezani_segah',
    'ayasofya_ezan_sesi',
    'best',
    'corner',
    'ding_dong',
    'esselatu_hayrun_minen_nevm1',
    'esselatu_hayrun_minen_nevm2',
    'ikindi_ezani_hicaz',
    'melodi',
    'mescid_i_nebi_sabah_ezani',
    'ney_uyan',
    'ogle_ezani_rast',
    'sabah_ezani_saba',
    'snaps',
    'sweet_favour',
    'violet',
    'yatsi_ezani_ussak',
  ];

  // Convert sound file name to Android raw resource name
  static String _getSoundResourceName(String? soundAsset) {
    if (soundAsset == null || soundAsset.isEmpty) return 'best';

    // Get file name and remove extension
    String name = soundAsset.toLowerCase();
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.endsWith('.mp3')) {
      name = name.substring(0, name.length - 4);
    }

    // Remove invalid characters for Android resource name
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    return name;
  }

  static Future<void> initialize([dynamic context]) async {
    if (_initialized) return;

    final languageService = LanguageService();
    await languageService.load();
    final onTimeChannelName =
      languageService['on_time_channel_name'] ?? 'On-time notifications';
    final onTimeChannelDesc =
      languageService['on_time_channel_desc'] ??
      'Notifications shown at prayer times';
    final earlyChannelName =
      languageService['early_channel_name'] ?? 'Early notifications';
    final earlyChannelDesc =
      languageService['early_channel_desc'] ??
      'Notifications shown before prayer times';

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
        // Check notification permission and log
      final hasPermission =
          await androidImplementation.areNotificationsEnabled() ?? false;
        debugPrint('📱 Notification permission status: $hasPermission');

      if (!hasPermission) {
        debugPrint(
          '⚠️ Notification permission missing. Requesting permission...',
        );
        final granted =
            await androidImplementation.requestNotificationsPermission() ??
            false;
        debugPrint('📱 Notification permission result: $granted');
        if (!granted) {
          debugPrint(
            '⚠️ Notification permission denied, opening settings...',
          );
          AppSettings.openAppSettings(type: AppSettingsType.notification);
        }
      }
      for (final sound in _legacySoundNames) {
        try {
          await androidImplementation.deleteNotificationChannel(
            channelId: 'vakit_channel_$sound',
          );
        } catch (_) {
          // Ignore missing channels.
        }
      }

      if (!_createdChannels.contains(_onTimeChannelId)) {
        final channel = AndroidNotificationChannel(
          _onTimeChannelId,
          onTimeChannelName,
          description: onTimeChannelDesc,
          importance: Importance.max,
          playSound: false,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);
        _createdChannels.add(_onTimeChannelId);
      }

      if (!_createdChannels.contains(_earlyChannelId)) {
        final channel = AndroidNotificationChannel(
          _earlyChannelId,
          earlyChannelName,
          description: earlyChannelDesc,
          importance: Importance.max,
          playSound: false,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);
        _createdChannels.add(_earlyChannelId);
      }
    }

    _initialized = true;
  }

  static Future<void> showVakitNotification({
    required String title,
    required String body,
    String? soundAsset,
  }) async {
    try {
        // Get sound resource name
      final soundResourceName = _getSoundResourceName(soundAsset);
        debugPrint('🔊 Notification sound resource: $soundResourceName');

        final languageService = LanguageService();
        await languageService.load();
        final prayerChannelName =
          languageService['prayer_notification_channel_name'] ??
          'Prayer notifications';
        final prayerChannelDesc =
          languageService['prayer_notification_channel_desc'] ??
          'Notifications for prayer times';
        final prayerChannelTicker =
          languageService['prayer_notification_channel_ticker'] ??
          'Prayer notification';

      final channelId = _onTimeChannelId;
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        channelId,
        prayerChannelName,
        channelDescription: prayerChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: false,
        sound: null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        autoCancel: false,
        ongoing: false,
        ticker: prayerChannelTicker,
      );

      final notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
        100000,
      );

      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
      debugPrint(
        '✅ Notification sent: $title - $body (ID: $notificationId, sound: $soundResourceName)',
      );
    } catch (e) {
      debugPrint('❌ Notification send failed: $e');
    }
  }

  /// Test sound (while app is open)
  ///
  /// Ses, bildirimlerin kullandığı res/raw kopyasından çalınır; "sounds/"
  /// öneki ve ".mp3" uzantısı verilse de kabul edilir.
  static Future<void> testSound(String soundAsset) async {
    final sesId = soundAsset
        .replaceFirst('sounds/', '')
        .replaceAll('.mp3', '')
        .toLowerCase();
    final calindi = await SesOnizlemeService.cal(sesId);
    debugPrint(
      calindi ? '🔊 Test sound played: $sesId' : '⚠️ Test sound failed: $sesId',
    );
  }

  /// Stop sound
  static Future<void> stopSound() => SesOnizlemeService.durdur();
}
