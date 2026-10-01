/// Zekât nisap ölçütü: hesaplama altın veya gümüş fiyatı üzerinden yapılır.
enum NisapOlcusu { altin, gumus }

/// Zekât hesabının sonucu.
class ZekatSonucu {
  final double toplamVarlik;
  final double nisapDegeri;
  final bool nisabaUlasti;
  final double odenecekZekat;

  const ZekatSonucu({
    required this.toplamVarlik,
    required this.nisapDegeri,
    required this.nisabaUlasti,
    required this.odenecekZekat,
  });
}

/// Zekât ve fitre için saf hesaplama mantığı (UI'dan bağımsız).
///
/// Altın/gümüş güncel piyasa fiyatı ve yıllık fitre miktarı uygulama
/// içinde sabitlenmez — bu değerler zamanla değiştiği için kullanıcı
/// kendi girer (bkz. [ZekatHesaplayiciSayfa]).
class ZekatHesaplamaService {
  ZekatHesaplamaService._();

  static const double altinNisapGram = 85.0;
  static const double gumusNisapGram = 595.0;
  static const double zekatOrani = 0.025;

  static ZekatSonucu hesaplaZekat({
    required double altinGram,
    required double altinFiyatGram,
    required double gumusGram,
    required double gumusFiyatGram,
    required double nakit,
    required NisapOlcusu olcut,
  }) {
    final toplamVarlik =
        (altinGram * altinFiyatGram) + (gumusGram * gumusFiyatGram) + nakit;

    final nisapDegeri = olcut == NisapOlcusu.altin
        ? altinNisapGram * altinFiyatGram
        : gumusNisapGram * gumusFiyatGram;

    final nisabaUlasti = nisapDegeri > 0 && toplamVarlik >= nisapDegeri;
    final odenecekZekat = nisabaUlasti ? toplamVarlik * zekatOrani : 0.0;

    return ZekatSonucu(
      toplamVarlik: toplamVarlik,
      nisapDegeri: nisapDegeri,
      nisabaUlasti: nisabaUlasti,
      odenecekZekat: odenecekZekat,
    );
  }

  static double hesaplaFitre({
    required double kisiBasi,
    required int kisiSayisi,
  }) {
    if (kisiSayisi <= 0) return 0.0;
    return kisiBasi * kisiSayisi;
  }
}
