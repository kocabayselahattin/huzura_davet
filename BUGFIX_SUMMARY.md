# Hata Düzeltmeleri - Yedek Çözümler

## 🔧 Yapılan Düzeltmeler

### 1. Zikirmatik Titreşim Sorunu

#### Çözüm A (Şu an aktif):
- `VibrationService` sınıfı oluşturuldu
- Native Android titreşim API'si kullanılıyor
- `VibrationHandler.kt` ile doğrudan sistem titreşimi
- Hata yönetimi ve fallback mekanizması

#### Test Etmek İçin:
```bash
# Uygulamayı çalıştır
flutter run

# Ayarlar > Titreşim Test sayfasını aç (eklenecek)
# Veya Zikirmatik sayfasını aç ve tıkla
```

#### Eğer Hala Çalışmazsa:
1. **Cihaz Ayarları Kontrolü:**
   - Ayarlar > Ses ve Titreşim > Titreşim açık mı?
   - Telefon sessize alınmış mı?
   - Pil tasarrufu modu titreşimi engelliyor mu?

2. **Manuel Test:**
   ```dart
   // lib/pages/vibration_test_page.dart açılmış
   // Her butonu test edin
   ```

3. **Alternative (Basit vibrate):**
   ```dart
   import 'package:vibration/vibration.dart';
   
   // pubspec.yaml'a ekle:
   // vibration: ^1.8.4
   
   // Kullanım:
   await Vibration.vibrate(duration: 100);
   ```

### 2. Widget Geri Sayım Sorunu

#### Çözüm A (Chronometer - Şu an aktif):
- Android Chronometer widget'ı kullanılıyor
- `SystemClock.elapsedRealtime()` ile dinamik geri sayım
- Her 5 saniyede widget verisi güncelleniyor
- Chronometer kendi kendine geri sayıyor

#### Çözüm B (Yedek - TextView):
- Eğer Chronometer başarısız olursa otomatik TextView'e geçiyor
- Log'larda görebilirsiniz: "Chronometer hatası, TextView'e geçiliyor"

#### Test Etmek İçin:
```bash
# Widget'ı ekrana ekle
# Geri sayımın azaldığını gözle

# Log'ları kontrol et:
flutter run
# veya
adb logcat | grep WidgetUtils
```

#### Eğer Hala Çalışmazsa:

**Seçenek 1: TextView ile manuel güncelleme**
```kotlin
// WidgetUtils.kt içinde applyCountdown fonksiyonunu şununla değiştir:
fun applyCountdown(views: RemoteViews, viewId: Int, remaining: String) {
    views.setTextViewText(viewId, remaining)
}

// HomeWidgetService.dart'ta güncelleme sıklığını artır:
Timer.periodic(const Duration(seconds: 1), (_) {
    updateAllWidgets();
});
```

**Seçenek 2: WorkManager ile arka plan güncelleme**
```yaml
# pubspec.yaml
workmanager: ^0.5.2

# Dart kodunda:
await Workmanager().registerPeriodicTask(
  "widget-update",
  "updateWidgets",
  frequency: Duration(seconds: 15),
);
```

## 📱 Debug Komutları

### Log'ları İzle:
```bash
# Tüm log'lar
adb logcat

# Sadece uygulama log'ları
adb logcat | grep "huzur_vakti"

# Widget log'ları
adb logcat | grep "WidgetUtils"

# Vibration log'ları
adb logcat | grep "Vibration"
```

### Widget'ı Manuel Güncelle:
```bash
# Android Studio'da Debug Console'da:
HomeWidget.updateWidget(...)

# veya Native kodu tetikle:
adb shell am broadcast -a com.example.huzur_vakti.UPDATE_WIDGETS
```

## 🔍 Sorun Tespit Rehberi

### Titreşim Çalışmıyor:
1. ✅ VIBRATE izni AndroidManifest.xml'de var mı?
2. ✅ Cihaz ayarlarında titreşim açık mı?
3. ✅ Pil tasarrufu modu kapalı mı?
4. ❓ Cihaz donanımı titreşimi destekliyor mu?
5. ❓ Başka uygulamalarda titreşim çalışıyor mu?

### Widget Geri Sayım Çalışmıyor:
1. ✅ Widget ekranda gösteriliyor mu?
2. ✅ HomeWidgetService başlatılmış mı?
3. ❓ Log'larda "Chronometer başarıyla ayarlandı" yazıyor mu?
4. ❓ Widget XML'de Chronometer view var mı?
5. ❓ Widget her 5 saniyede güncelleniyor mu?

## 📝 Dosya Yapısı

```
lib/
├── services/
│   ├── vibration_service.dart       # Titreşim servisi (yeni)
│   └── home_widget_service.dart     # Widget güncelleme
├── pages/
│   ├── zikir_matik_sayfa.dart       # VibrationService kullanan
│   └── vibration_test_page.dart     # Test sayfası (yeni)

android/
└── app/src/main/kotlin/.../
    ├── MainActivity.kt               # VibrationHandler eklendi
    ├── VibrationHandler.kt           # Native titreşim (yeni)
    └── widgets/
        └── WidgetUtils.kt            # Chronometer + TextView
```

## 🚀 Yapılacaklar (İsteğe Bağlı)

1. Vibration Test sayfasını ayarlara ekle
2. Widget debug sayfası ekle (geri sayım durumunu göster)
3. Alternatif vibration paketi dene (vibration: ^1.8.4)
4. Widget'ları WorkManager ile güncelle
5. Cihaz özellik kontrolü ekle (hasVibrator, supportsChronometer)
