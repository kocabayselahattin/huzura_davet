import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static AudioPlayer? _audioPlayer;
  static bool _initialized = false;

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
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Bildirime tıklandı: ${response.payload}');
      },
    );
    
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // Varsayılan kanal oluştur
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'vakit_channel',
        'Vakit Bildirimleri',
        description: 'Namaz vakitleri için bildirimler',
        importance: Importance.max,
        playSound: false, // Sesi kendimiz çalacağız
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );
      await androidImplementation.createNotificationChannel(channel);
      
      // Bildirim iznini kontrol et ve logla
      final hasPermission = await androidImplementation.areNotificationsEnabled() ?? false;
      debugPrint('📱 Bildirim izni durumu: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('⚠️ Bildirim izni verilmemiş! Kullanıcıdan izin isteniyor...');
        final granted = await androidImplementation.requestNotificationsPermission() ?? false;
        debugPrint('📱 Bildirim izni sonucu: $granted');
      }
    }
    
    // AudioPlayer'ı önceden başlat
    await _getAudioPlayer();
    
    _initialized = true;
  }

  static Future<void> showVakitNotification({
    required String title,
    required String body,
    String? soundAsset,
  }) async {
    try {
      // Önce sesi çal (asset'ten)
      if (soundAsset != null && soundAsset.isNotEmpty) {
        try {
          final player = await _getAudioPlayer();
          await player.stop();
          
          // Asset dosya adını düzelt
          String assetPath = soundAsset;
          if (!assetPath.startsWith('sounds/')) {
            assetPath = 'sounds/$soundAsset';
          }
          
          // Ses ayarlarını yap
          await player.setVolume(1.0);
          await player.setPlayerMode(PlayerMode.mediaPlayer);
          
          // Sesi çal
          await player.play(AssetSource(assetPath));
          debugPrint('🔊 Ses çalınıyor: $assetPath');
          
          // Sesin çalması için kısa bir bekleme
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('⚠️ Ses çalınamadı: $e');
        }
      }
      
      // Bildirim göster (ses olmadan)
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'vakit_channel',
        'Vakit Bildirimleri',
        channelDescription: 'Namaz vakitleri için bildirimler',
        importance: Importance.max,
        priority: Priority.high,
        playSound: false, // Sesi kendimiz çalıyoruz
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: false,
        ticker: 'Vakit bildirimi',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );
      const notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );
      debugPrint('✅ Bildirim gönderildi: $title - $body (ID: $notificationId)');
    } catch (e) {
      debugPrint('❌ Bildirim gönderilemedi: $e');
      rethrow;
    }
  }
  
  /// Sesi test et
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
