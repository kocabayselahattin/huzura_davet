import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:app_settings/app_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static AudioPlayer? _audioPlayer;
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

  // Ses dosyası adını Android raw kaynağı adına dönüştür
  static String _getSoundResourceName(String? soundAsset) {
    if (soundAsset == null || soundAsset.isEmpty) return 'ding_dong';

    // Dosya adını al ve uzantıyı kaldır
    String name = soundAsset.toLowerCase();
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.endsWith('.mp3')) {
      name = name.substring(0, name.length - 4);
    }

    // Android resource adı için geçersiz karakterleri temizle
    name = name.replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    return name;
  }

  static Future<AudioPlayer> _getAudioPlayer() async {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      // AudioPlayer ayarları
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
    }
    return _audioPlayer!;
  }

  static Future<void> initialize([dynamic context]) async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Bildirime tıklandı: ${response.payload}');
      },
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      // Bildirim iznini kontrol et ve logla
      final hasPermission =
          await androidImplementation.areNotificationsEnabled() ?? false;
      debugPrint('📱 Bildirim izni durumu: $hasPermission');

      if (!hasPermission) {
        debugPrint(
          '⚠️ Bildirim izni verilmemiş! Kullanıcıdan izin isteniyor...',
        );
        final granted =
            await androidImplementation.requestNotificationsPermission() ??
            false;
        debugPrint('📱 Bildirim izni sonucu: $granted');
        if (!granted) {
          debugPrint(
            '⚠️ Kullanıcı bildirim izni vermedi, ayarlara yönlendiriliyor...',
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
          'Vaktinde Bildirimler',
          description: 'Vakitlerinde gosterilen bildirimler',
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
          'Erken Bildirimler',
          description: 'Vakitlerden once gosterilen bildirimler',
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
      // Ses kaynağı adını al
      final soundResourceName = _getSoundResourceName(soundAsset);
      debugPrint('🔊 Ses kaynağı (bildirim): $soundResourceName');

      final channelId = _onTimeChannelId;
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        channelId,
        'Vakit Bildirimleri',
        channelDescription: 'Namaz vakitleri için bildirimler',
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
        ticker: 'Vakit bildirimi',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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
        '✅ Bildirim gönderildi: $title - $body (ID: $notificationId, Ses: $soundResourceName)',
      );
    } catch (e) {
      debugPrint('❌ Bildirim gönderilemedi: $e');
    }
  }

  /// Sesi test et (uygulama açıkken)
  static Future<void> testSound(String soundAsset) async {
    try {
      final player = await _getAudioPlayer();
      await player.stop();

      String assetPath = soundAsset;
      if (!assetPath.startsWith('sounds/')) {
        assetPath = 'sounds/$soundAsset';
      }

      await player.setVolume(1.0);
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.play(AssetSource(assetPath));
      debugPrint('🔊 Test sesi çalındı: $assetPath');
    } catch (e) {
      debugPrint('⚠️ Test sesi çalınamadı: $e');
    }
  }

  /// Sesi durdur
  static Future<void> stopSound() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
    }
  }

  /// Kaynakları temizle
  static Future<void> dispose() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }
  }
}
