import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:app_settings/app_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static AudioPlayer? _audioPlayer;
  static bool _initialized = false;

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

    // Özel eşlemeler
    if (name == 'best_2015') name = 'best';

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
      debugPrint('🔊 Ses kaynağı: $soundResourceName (orijinal: $soundAsset)');

      // Android notification channel'ı ses ile oluştur
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // Her ses için ayrı kanal oluştur (Android kısıtlaması)
        final channelId = 'vakit_channel_$soundResourceName';
        final channel = AndroidNotificationChannel(
          channelId,
          'Vakit Bildirimleri',
          description: 'Namaz vakitleri için bildirimler',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundResourceName),
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);

        // Bildirim göster (Android native ses ile)
        final androidPlatformChannelSpecifics = AndroidNotificationDetails(
          channelId,
          'Vakit Bildirimleri',
          channelDescription: 'Namaz vakitleri için bildirimler',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundResourceName),
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          enableVibration: true,
          enableLights: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          autoCancel: false,
          ongoing: true,
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
      }
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
