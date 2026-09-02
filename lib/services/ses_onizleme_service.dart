import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Uygulama içi ses ön dinlemesini yerel taraftan (Android res/raw) çalar.
///
/// Bildirim ve alarm sesleri zaten res/raw altında duruyor. Ön dinleme de
/// oradan beslendiği için assets/sounds altındaki ikinci kopya kaldırıldı;
/// paket ~47 MB küçüldü. Kullanıcının cihazdan seçtiği özel sesler bu
/// servisten geçmez, onlar dosya yolundan audioplayers ile çalınır.
class SesOnizlemeService {
  static const MethodChannel _kanal = MethodChannel(
    'huzur_vakti/ses_onizleme',
  );

  static final Set<VoidCallback> _bitisDinleyicileri = {};
  static bool _kuruldu = false;

  static void _kur() {
    if (_kuruldu) return;
    _kuruldu = true;
    _kanal.setMethodCallHandler((cagri) async {
      if (cagri.method == 'bitti') {
        // Dinleyici listesi geri çağrı sırasında değişebilir.
        for (final dinleyici in _bitisDinleyicileri.toList()) {
          dinleyici();
        }
      }
      return null;
    });
  }

  /// Ses kendiliğinden bittiğinde çağrılacak dinleyiciyi ekler.
  static void bitisiDinle(VoidCallback dinleyici) {
    _kur();
    _bitisDinleyicileri.add(dinleyici);
  }

  static void dinlemeyiBirak(VoidCallback dinleyici) =>
      _bitisDinleyicileri.remove(dinleyici);

  /// [sesId], res/raw altındaki dosya adıdır ("best", "ding_dong" ...).
  /// Ses bulunamazsa false döner.
  static Future<bool> cal(String sesId) async {
    _kur();
    try {
      final sonuc = await _kanal.invokeMethod<bool>('cal', {'sesId': sesId});
      return sonuc ?? false;
    } on PlatformException catch (e) {
      debugPrint('⚠️ Ses ön dinleme başlatılamadı: ${e.message}');
      return false;
    } on MissingPluginException {
      // Android dışı bir platformda sessizce yok sayılır.
      return false;
    }
  }

  static Future<void> durdur() async {
    try {
      await _kanal.invokeMethod('durdur');
    } catch (e) {
      debugPrint('⚠️ Ses ön dinleme durdurulamadı: $e');
    }
  }
}
