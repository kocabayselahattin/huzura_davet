import 'package:package_info_plus/package_info_plus.dart';

/// Uygulama versiyon bilgisi.
///
/// pubspec.yaml'daki `version` alanından derleme sırasında otomatik alınır;
/// [appVersionYukle] main()'de runApp'tan önce çağrılarak doldurulur. Elle
/// senkronize edilecek ikinci bir yer yoktur.
String appVersion = '';

/// Kullanıcıya gösterilecek sürüm (build numarasız).
String displayAppVersion = '';

/// pubspec.yaml'daki sürümü [PackageInfo] üzerinden okuyup yukarıdaki
/// değişkenleri doldurur.
Future<void> appVersionYukle() async {
  final bilgi = await PackageInfo.fromPlatform();
  displayAppVersion = bilgi.version;
  appVersion = bilgi.buildNumber.isEmpty
      ? bilgi.version
      : '${bilgi.version}+${bilgi.buildNumber}';
}
