import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/kuran_veri_service.dart';
import '../services/tema_service.dart';

/// Paylaşım kartında gösterilebilecek içerik türleri.
enum PaylasimIcerikTuru { ayet, hadis, dua, esma }

/// Kartın yerleşim tasarımı. Renk şeması [PaylasimKartiStili] ile ayrı seçilir,
/// böylece her tasarım her renkle birleşebilir.
enum PaylasimKartiDuzeni {
  /// Köşelerde sekiz köşeli yıldız motifleri, ortalanmış içerik.
  klasik('card_layout_classic', 'Klasik'),

  /// Süssüz; büyük tırnak işareti ve sola yaslı metin.
  zarif('card_layout_elegant', 'Zarif'),

  /// Çift çerçeve ve üstte kemer motifiyle tezhip görünümü.
  tezhip('card_layout_ornate', 'Tezhip'),

  /// Gece göğü: hilal, yıldızlar ve altta minare silueti.
  hilal('card_layout_crescent', 'Hilal'),

  /// Kartı boydan boya saran mihrap kemeri.
  mihrap('card_layout_mihrab', 'Mihrap'),

  /// Tepeden sarkan kandil ve etrafına yayılan ışık halesi.
  kandil('card_layout_lantern', 'Kandil');

  const PaylasimKartiDuzeni(this.isimAnahtari, this.yedekIsim);

  /// Düzen adının dil dosyasındaki anahtarı.
  final String isimAnahtari;
  final String yedekIsim;

  /// Seçicide düzeni temsil eden ikon.
  IconData get ikon {
    switch (this) {
      case PaylasimKartiDuzeni.klasik:
        return Icons.auto_awesome_mosaic_rounded;
      case PaylasimKartiDuzeni.zarif:
        return Icons.format_quote_rounded;
      case PaylasimKartiDuzeni.tezhip:
        return Icons.filter_frames_rounded;
      case PaylasimKartiDuzeni.hilal:
        return Icons.nightlight_round;
      case PaylasimKartiDuzeni.mihrap:
        return Icons.mosque_rounded;
      case PaylasimKartiDuzeni.kandil:
        return Icons.light_rounded;
    }
  }
}

/// Üretilecek görselin en–boy oranı.
///
/// Android paylaşım penceresi hangi uygulamanın seçildiğini önceden bildirmediği
/// için hedef uygulamaya göre otomatik ayar yapılamaz; oranı kullanıcı seçer.
enum PaylasimKartiOrani {
  /// İçerik ne kadarsa o kadar; sohbette paylaşmak için uygun.
  serbest('card_ratio_free', 'Serbest', 0),

  /// 1:1 kare — gönderi paylaşımları için.
  kare('card_ratio_square', 'Kare', 1),

  /// 4:5 dikey — akışta en geniş yer kaplayan oran.
  dikey('card_ratio_portrait', 'Dikey', 5 / 4),

  /// 9:16 tam ekran — WhatsApp/Instagram durumu için.
  durum('card_ratio_status', 'Durum', 16 / 9);

  const PaylasimKartiOrani(this.isimAnahtari, this.yedekIsim, this.enBoy);

  final String isimAnahtari;
  final String yedekIsim;

  /// Yüksekliğin genişliğe oranı. 0 ise sabit bir orana zorlanmaz.
  final double enBoy;

  IconData get ikon {
    switch (this) {
      case PaylasimKartiOrani.serbest:
        return Icons.crop_free_rounded;
      case PaylasimKartiOrani.kare:
        return Icons.crop_square_rounded;
      case PaylasimKartiOrani.dikey:
        return Icons.crop_portrait_rounded;
      case PaylasimKartiOrani.durum:
        return Icons.stay_current_portrait_rounded;
    }
  }
}

/// Karta basılacak içerik. Arapça metin yoksa o bölüm hiç çizilmez.
class PaylasimIcerigi {
  final PaylasimIcerikTuru tur;

  /// Kartın üst şeridindeki etiket (örn. "GÜNÜN AYETİ").
  final String baslik;
  final String? arapca;
  final String metin;
  final String kaynak;

  /// Besmele yalnızca çok sayfalı paylaşımlarda ilk kartta gösterilsin diye
  /// eklendi; tek kartlık içerikte her zaman true kalır.
  final bool besmeleGoster;

  const PaylasimIcerigi({
    required this.tur,
    required this.baslik,
    required this.metin,
    required this.kaynak,
    this.arapca,
    this.besmeleGoster = true,
  });

  IconData get ikon {
    switch (tur) {
      case PaylasimIcerikTuru.ayet:
        return Icons.menu_book_rounded;
      case PaylasimIcerikTuru.hadis:
        return Icons.star_rounded;
      case PaylasimIcerikTuru.dua:
        return Icons.favorite_rounded;
      case PaylasimIcerikTuru.esma:
        return Icons.auto_awesome_rounded;
    }
  }

  /// Ayet paylaşımları besmele ile başlar.
  bool get besmeleliMi => tur == PaylasimIcerikTuru.ayet && besmeleGoster;

  /// Metni, her parçası en fazla [sinir] karakter olacak biçimde kelime
  /// sınırından böler. Tek kartta okunamayacak kadar uzun ayet/hadis/dua
  /// metinleri bu şekilde birden çok karta bölünür; hiçbir bölüm kırpılıp
  /// yarıda bırakılmaz (bkz. paylasim_onizleme_sayfa.dart).
  static List<String> metniBol(String metin, {int sinir = 700}) {
    final temiz = metin.trim();
    if (temiz.length <= sinir) return [temiz];

    final parcalar = <String>[];
    var kalan = temiz;
    while (kalan.length > sinir) {
      var kesimNoktasi = kalan.lastIndexOf(' ', sinir);
      if (kesimNoktasi <= 0) kesimNoktasi = sinir;
      parcalar.add(kalan.substring(0, kesimNoktasi).trim());
      kalan = kalan.substring(kesimNoktasi).trim();
    }
    if (kalan.isNotEmpty) parcalar.add(kalan);
    return parcalar;
  }

  /// Uygulamanın Play Store adresi. Görseldeki imza tıklanamadığı için düz
  /// metin paylaşımlarına bu bağlantı eklenir.
  static const String magazaBaglantisi =
      'https://play.google.com/store/apps/details?id=com.huzura.davet';

  /// Görsel paylaşılamazsa / metin olarak paylaşılırsa kullanılacak düz metin.
  String duzMetin(String imza) {
    final tampon = StringBuffer()
      ..writeln(baslik)
      ..writeln();
    if (besmeleliMi) {
      tampon
        ..writeln(KuranVeriService.besmele)
        ..writeln();
    }
    if ((arapca ?? '').trim().isNotEmpty) {
      tampon
        ..writeln(arapca!.trim())
        ..writeln();
    }
    tampon.writeln('"${metin.trim()}"');
    if (kaynak.trim().isNotEmpty) {
      tampon
        ..writeln()
        ..writeln('— ${kaynak.trim()}');
    }
    if (imza.trim().isNotEmpty) {
      tampon
        ..writeln()
        ..writeln(imza.trim());
    }
    tampon.writeln(magazaBaglantisi);
    return tampon.toString().trim();
  }
}

/// Kartın renk şeması. `temadan` ile üretilen stil, kullanıcının o anki
/// uygulama temasından türetilir; diğerleri sabit paletlerdir.
class PaylasimKartiStili {
  /// Stil adının dil dosyasındaki anahtarı.
  final String isimAnahtari;
  final String yedekIsim;
  final List<Color> arkaPlan;
  final Color vurgu;
  final Color yaziPrimary;
  final Color yaziSecondary;
  final bool acikZemin;

  const PaylasimKartiStili({
    required this.isimAnahtari,
    required this.yedekIsim,
    required this.arkaPlan,
    required this.vurgu,
    required this.yaziPrimary,
    required this.yaziSecondary,
    this.acikZemin = false,
  });

  /// Önizlemedeki stil noktasında gösterilen renk.
  Color get onizlemeRengi => arkaPlan.first;

  /// Renk bandı gibi dolu alanların üzerine yazılacak metin rengi.
  Color get vurguUstuYazi =>
      vurgu.computeLuminance() > 0.55 ? const Color(0xFF1A1D23) : Colors.white;

  /// Aktif uygulama temasından bir stil üretir; kart uygulamayla aynı
  /// görünsün isteyen kullanıcı için ilk seçenek budur.
  factory PaylasimKartiStili.temadan(TemaRenkleri renkler) {
    return PaylasimKartiStili(
      isimAnahtari: 'card_style_theme',
      yedekIsim: 'Tema',
      arkaPlan: [
        renkler.kartArkaPlan,
        Color.alphaBlend(
          renkler.arkaPlan.withValues(alpha: 0.85),
          renkler.kartArkaPlan,
        ),
      ],
      vurgu: renkler.vurgu,
      yaziPrimary: renkler.yaziPrimary,
      yaziSecondary: renkler.yaziSecondary,
      acikZemin: renkler.kartArkaPlan.computeLuminance() > 0.5,
    );
  }

  /// Tema stili hariç sabit paletler.
  static const List<PaylasimKartiStili> sabitStiller = [
    PaylasimKartiStili(
      isimAnahtari: 'card_style_night',
      yedekIsim: 'Gece',
      arkaPlan: [Color(0xFF13203A), Color(0xFF0A1122)],
      vurgu: Color(0xFFD9B45B),
      yaziPrimary: Color(0xFFF3F1EA),
      yaziSecondary: Color(0xFFA7B0C4),
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_emerald',
      yedekIsim: 'Zümrüt',
      arkaPlan: [Color(0xFF0E3B32), Color(0xFF07211D)],
      vurgu: Color(0xFF74C69D),
      yaziPrimary: Color(0xFFF0F7F3),
      yaziSecondary: Color(0xFF9FC7B6),
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_sepia',
      yedekIsim: 'Sepya',
      arkaPlan: [Color(0xFFF7EEDD), Color(0xFFE8D9BE)],
      vurgu: Color(0xFF9A6B2F),
      yaziPrimary: Color(0xFF3B2C18),
      yaziSecondary: Color(0xFF7A6547),
      acikZemin: true,
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_plain',
      yedekIsim: 'Sade',
      arkaPlan: [Color(0xFFFFFFFF), Color(0xFFF1F2F4)],
      vurgu: Color(0xFF2E5E8C),
      yaziPrimary: Color(0xFF1A1D23),
      yaziSecondary: Color(0xFF6B7280),
      acikZemin: true,
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_rose',
      yedekIsim: 'Gül',
      arkaPlan: [Color(0xFF3B1220), Color(0xFF1D0910)],
      vurgu: Color(0xFFE0A3B4),
      yaziPrimary: Color(0xFFF8EEF1),
      yaziSecondary: Color(0xFFC79AA6),
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_sapphire',
      yedekIsim: 'Safir',
      arkaPlan: [Color(0xFF102A4C), Color(0xFF071628)],
      vurgu: Color(0xFF7EB6E8),
      yaziPrimary: Color(0xFFEDF3FA),
      yaziSecondary: Color(0xFF9FB4CC),
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_amber',
      yedekIsim: 'Kehribar',
      arkaPlan: [Color(0xFF2A1D0E), Color(0xFF150E06)],
      vurgu: Color(0xFFE0A458),
      yaziPrimary: Color(0xFFF7EFE3),
      yaziSecondary: Color(0xFFC0A98C),
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_olive',
      yedekIsim: 'Zeytin',
      arkaPlan: [Color(0xFF2A2E1C), Color(0xFF14170D)],
      vurgu: Color(0xFFBFCB7E),
      yaziPrimary: Color(0xFFF2F4E8),
      yaziSecondary: Color(0xFFB2B89C),
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_ink',
      yedekIsim: 'Mürekkep',
      arkaPlan: [Color(0xFF14161A), Color(0xFF06070A)],
      vurgu: Color(0xFFB9C2CF),
      yaziPrimary: Color(0xFFF5F6F8),
      yaziSecondary: Color(0xFF8C93A0),
    ),
    PaylasimKartiStili(
      isimAnahtari: 'card_style_pearl',
      yedekIsim: 'Sedef',
      arkaPlan: [Color(0xFFEDF2F7), Color(0xFFD9E2EC)],
      vurgu: Color(0xFF34608F),
      yaziPrimary: Color(0xFF1B2733),
      yaziSecondary: Color(0xFF5D6D7E),
      acikZemin: true,
    ),
  ];
}

/// Paylaşılmak üzere PNG'ye çevrilen kart.
///
/// Genişliği sabittir; [PaylasimKartiService.pngUret] bu widget'ı 3x piksel
/// oranıyla yakaladığı için çıktı 1080 piksel genişliğinde olur.
class PaylasimKarti extends StatelessWidget {
  /// Kartın mantıksal genişliği. 3x yakalamada 1080 px eder.
  static const double genislik = 360;

  final PaylasimIcerigi icerik;
  final PaylasimKartiStili stil;
  final PaylasimKartiDuzeni duzen;
  final PaylasimKartiOrani oran;

  /// Arapça metin varsa gösterilsin mi (kullanıcı kapatabilir).
  final bool arapcaGoster;

  /// Kartın altındaki uygulama adı.
  final String imza;

  /// İmzanın altındaki tanıtım satırı (örn. "Namaz Vakti Uygulaması").
  final String tanitim;

  /// Metin birden çok karta bölündüğünde bu kartın sırası (1 tabanlı).
  /// Null veya [sayfaToplam] 1 ise rozet çizilmez.
  final int? sayfaNo;

  /// Toplam kart sayısı; birden fazlaysa köşede "sayfaNo/sayfaToplam"
  /// rozeti gösterilir ki kullanıcı içeriğin birkaç karta bölündüğünü görsün.
  final int? sayfaToplam;

  const PaylasimKarti({
    super.key,
    required this.icerik,
    required this.stil,
    required this.imza,
    this.tanitim = '',
    this.duzen = PaylasimKartiDuzeni.klasik,
    this.oran = PaylasimKartiOrani.serbest,
    this.arapcaGoster = true,
    this.sayfaNo,
    this.sayfaToplam,
  });

  /// Uzun metinlerde kartın taşmaması için yazı boyutunu kademeli küçültür.
  double _metinBoyutu(String metin) {
    final uzunluk = metin.characters.length;
    if (uzunluk < 120) return 20;
    if (uzunluk < 260) return 18;
    if (uzunluk < 450) return 16;
    if (uzunluk < 800) return 14;
    return 12.5;
  }

  double _arapcaBoyutu(String metin) {
    final uzunluk = metin.characters.length;
    if (uzunluk < 90) return 26;
    if (uzunluk < 200) return 22;
    if (uzunluk < 400) return 19;
    return 16;
  }

  /// Kart okunabilir kalsın diye çok uzun metinleri kırpar.
  String _kirp(String metin, int sinir) {
    final temiz = metin.trim();
    if (temiz.characters.length <= sinir) return temiz;
    return '${temiz.characters.take(sinir).toString().trimRight()}…';
  }

  String get _metin => _kirp(icerik.metin, 900);
  String get _arapca => (icerik.arapca ?? '').trim();
  bool get _arapcaVar => arapcaGoster && _arapca.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Seçilen oranın gerektirdiği en az yükseklik. İçerik daha uzunsa kart
    // uzar; kısaysa boşluk kartın zeminiyle dolar ve oran korunur.
    final enAzYukseklik = oran.enBoy > 0 ? genislik * oran.enBoy : 460.0;

    final govde = Container(
      width: genislik,
      constraints: BoxConstraints(minHeight: enAzYukseklik),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: stil.arkaPlan,
        ),
      ),
      // IntrinsicHeight, kartın gerçek yüksekliğini düzenin içine taşır: böylece
      // süslemeler kartın tamamını sarar, içerik de ortalanarak boşluğu doldurur.
      // İçerik seçilen orandan uzunsa kart uzar, kısaysa oran korunur.
      child: IntrinsicHeight(
        child: SizedBox(
          width: genislik,
          child: switch (duzen) {
            PaylasimKartiDuzeni.klasik => _klasikDuzen(),
            PaylasimKartiDuzeni.zarif => _zarifDuzen(),
            PaylasimKartiDuzeni.tezhip => _tezhipDuzen(),
            PaylasimKartiDuzeni.hilal => _hilalDuzen(),
            PaylasimKartiDuzeni.mihrap => _mihrapDuzen(),
            PaylasimKartiDuzeni.kandil => _kandilDuzen(),
          },
        ),
      ),
    );

    if (sayfaNo == null || (sayfaToplam ?? 1) <= 1) return govde;

    // İçerik birden çok karta bölündüğünde köşede "1/2" gibi bir rozet
    // gösterilir; kullanıcı bunun bir dizinin parçası olduğunu görsün.
    return Stack(
      children: [
        govde,
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: stil.vurgu.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stil.vurgu.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$sayfaNo/$sayfaToplam',
              style: TextStyle(
                color: stil.vurgu,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Düzenler -------------------------------------------------------------

  /// Köşe motifleri ve ince çerçeveyle klasik yerleşim.
  Widget _klasikDuzen() {
    return CustomPaint(
      painter: _KoseMotifiPainter(
        renk: stil.vurgu,
        acikZemin: stil.acikZemin,
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 34, 30, 26),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _baslikSatiri(ortala: true),
              const SizedBox(height: 22),
              if (icerik.besmeleliMi) ...[
                _besmele(18),
                const SizedBox(height: 18),
              ],
              if (_arapcaVar) ...[
                _arapcaMetni(),
                const SizedBox(height: 20),
                _elmasAyirac(),
                const SizedBox(height: 20),
              ],
              _anaMetin(TextAlign.center),
              const SizedBox(height: 22),
              if (icerik.kaynak.trim().isNotEmpty) _kaynakRozeti(),
              const SizedBox(height: 26),
              _altImza(),
            ],
          ),
        ),
    );
  }

  /// Süssüz, tipografiye dayanan yerleşim: büyük tırnak ve sola yaslı metin.
  Widget _zarifDuzen() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 38, 34, 30),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 2,
                color: stil.vurgu.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  icerik.baslik.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: stil.vurgu,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Icon(
            Icons.format_quote_rounded,
            size: 42,
            color: stil.vurgu.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 4),
          if (icerik.besmeleliMi) ...[
            _besmele(17, hizala: TextAlign.left),
            const SizedBox(height: 16),
          ],
          if (_arapcaVar) ...[
            _arapcaMetni(),
            const SizedBox(height: 18),
          ],
          _anaMetin(TextAlign.left),
          const SizedBox(height: 24),
          if (icerik.kaynak.trim().isNotEmpty)
            Text(
              '— ${icerik.kaynak.trim()}',
              style: TextStyle(
                color: stil.vurgu,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          // Zarif düzende imza da sola yaslı durur.
          const SizedBox(height: 24),
          Container(height: 1, color: stil.vurgu.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          _imzaSatirlari(ortala: false),
        ],
      ),
    );
  }

  /// Çift çerçeve ve üstte kemer motifiyle tezhip görünümü.
  Widget _tezhipDuzen() {
    return CustomPaint(
      painter: _TezhipPainter(
        renk: stil.vurgu,
        acikZemin: stil.acikZemin,
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(38, 30, 38, 32),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kemer motifine yer bırakan üst boşluk; başlık kemerin altında
              // kalmalı, üstüne binmemeli.
              const SizedBox(height: 66),
              Text(
                icerik.baslik.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: stil.vurgu,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 18),
              if (icerik.besmeleliMi) ...[
                _besmele(19),
                const SizedBox(height: 16),
              ],
              if (_arapcaVar) ...[
                _arapcaMetni(),
                const SizedBox(height: 18),
              ],
              _elmasAyirac(),
              const SizedBox(height: 18),
              _anaMetin(TextAlign.center),
              const SizedBox(height: 20),
              if (icerik.kaynak.trim().isNotEmpty)
                Text(
                  '— ${icerik.kaynak.trim()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: stil.vurgu,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 22),
              _altImza(),
            ],
          ),
        ),
    );
  }

  /// Gece göğü: tepede hilal ve yıldızlar, altta minare silueti.
  Widget _hilalDuzen() {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HilalPainter(
              renk: stil.vurgu,
              acikZemin: stil.acikZemin,
            ),
          ),
        ),
        Padding(
          // Üstte hilale, altta siluete yer bırakılır.
          padding: const EdgeInsets.fromLTRB(32, 92, 32, 74),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                icerik.baslik.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: stil.vurgu,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 20),
              if (icerik.besmeleliMi) ...[
                _besmele(18),
                const SizedBox(height: 16),
              ],
              if (_arapcaVar) ...[
                _arapcaMetni(),
                const SizedBox(height: 18),
                _elmasAyirac(),
                const SizedBox(height: 18),
              ],
              _anaMetin(TextAlign.center),
              const SizedBox(height: 20),
              if (icerik.kaynak.trim().isNotEmpty)
                Text(
                  '— ${icerik.kaynak.trim()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: stil.vurgu,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              // Hilal düzeninde imza, silueti bölmemesi için ayraçsız durur.
              const SizedBox(height: 18),
              _imzaSatirlari(ortala: true),
            ],
          ),
        ),
      ],
    );
  }

  /// İçeriği boydan boya saran mihrap kemeri.
  Widget _mihrapDuzen() {
    return CustomPaint(
      painter: _MihrapPainter(
        renk: stil.vurgu,
        acikZemin: stil.acikZemin,
      ),
      child: Padding(
          // Kemerin tepesi içeriğin üstünde kalmalı.
          padding: const EdgeInsets.fromLTRB(44, 96, 44, 90),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                icerik.baslik.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: stil.vurgu,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.8,
                ),
              ),
              const SizedBox(height: 18),
              if (icerik.besmeleliMi) ...[
                _besmele(18),
                const SizedBox(height: 16),
              ],
              if (_arapcaVar) ...[
                _arapcaMetni(),
                const SizedBox(height: 16),
              ],
              _elmasAyirac(),
              const SizedBox(height: 16),
              _anaMetin(TextAlign.center),
              const SizedBox(height: 20),
              if (icerik.kaynak.trim().isNotEmpty) _kaynakRozeti(),
              const SizedBox(height: 22),
              _altImza(),
            ],
          ),
        ),
    );
  }

  /// Tepeden sarkan kandil ve ışığının aydınlattığı metin alanı.
  Widget _kandilDuzen() {
    return CustomPaint(
      painter: _KandilPainter(
        renk: stil.vurgu,
        acikZemin: stil.acikZemin,
      ),
      child: Padding(
          // Üstte kandile yer bırakılır.
          padding: const EdgeInsets.fromLTRB(34, 132, 34, 110),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                icerik.baslik.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: stil.vurgu,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 20),
              if (icerik.besmeleliMi) ...[
                _besmele(18),
                const SizedBox(height: 16),
              ],
              if (_arapcaVar) ...[
                _arapcaMetni(),
                const SizedBox(height: 18),
                _elmasAyirac(),
                const SizedBox(height: 18),
              ],
              _anaMetin(TextAlign.center),
              const SizedBox(height: 20),
              if (icerik.kaynak.trim().isNotEmpty) _kaynakRozeti(),
              const SizedBox(height: 24),
              _altImza(),
            ],
          ),
        ),
    );
  }

  // --- Ortak parçalar -------------------------------------------------------

  Widget _baslikSatiri({required bool ortala}) {
    return Row(
      mainAxisAlignment:
          ortala ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: stil.vurgu.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icerik.ikon, color: stil.vurgu, size: 15),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            icerik.baslik.toUpperCase(),
            textAlign: ortala ? TextAlign.center : TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: stil.vurgu,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _besmele(double boyut, {TextAlign hizala = TextAlign.center}) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        KuranVeriService.besmele,
        textAlign: hizala,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: stil.vurgu,
          fontFamily: 'Amiri',
          fontSize: boyut,
          height: 1.7,
        ),
      ),
    );
  }

  Widget _arapcaMetni() {
    return Text(
      _kirp(_arapca, 500),
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: stil.yaziPrimary,
        fontFamily: 'Amiri',
        fontSize: _arapcaBoyutu(_arapca),
        height: 1.9,
      ),
    );
  }

  Widget _anaMetin(TextAlign hizala) {
    return Text(
      _metin,
      textAlign: hizala,
      style: TextStyle(
        color: stil.yaziPrimary,
        fontSize: _metinBoyutu(_metin),
        height: 1.75,
        letterSpacing: 0.1,
      ),
    );
  }

  /// Arapça ile meal arasındaki elmas motifli ince ayraç.
  Widget _elmasAyirac() {
    Widget cizgi(List<Color> renkler) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: renkler),
        ),
      ),
    );

    final saydam = stil.vurgu.withValues(alpha: 0);
    final dolgu = stil.vurgu.withValues(alpha: 0.45);

    return Row(
      children: [
        cizgi([saydam, dolgu]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: stil.vurgu.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
        cizgi([dolgu, saydam]),
      ],
    );
  }

  Widget _kaynakRozeti() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: stil.vurgu.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: stil.vurgu.withValues(alpha: 0.3)),
        ),
        child: Text(
          '— ${icerik.kaynak.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: stil.acikZemin ? stil.vurgu : stil.yaziSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _altImza() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: stil.vurgu.withValues(alpha: 0.18)),
        const SizedBox(height: 14),
        _imzaSatirlari(ortala: true),
      ],
    );
  }

  /// İki satırlı imza: üstte uygulama adı, altında ne işe yaradığını söyleyen
  /// tanıtım satırı. Kartı gören biri uygulamayı tanımasa da anlasın diye.
  Widget _imzaSatirlari({required bool ortala}) {
    final hizala = ortala ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: hizala,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              ortala ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.nightlight_round,
              size: 12,
              color: stil.vurgu.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                imza,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: stil.vurgu,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        if (tanitim.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            tanitim,
            textAlign: ortala ? TextAlign.center : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: stil.yaziSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ],
    );
  }
}

/// Klasik düzenin köşe yıldızlarını ve ince iç çerçevesini çizer.
/// Metnin okunmasını engellememesi için opaklık düşük tutulur.
class _KoseMotifiPainter extends CustomPainter {
  final Color renk;
  final bool acikZemin;

  const _KoseMotifiPainter({required this.renk, required this.acikZemin});

  @override
  void paint(Canvas canvas, Size size) {
    final cerceve = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = renk.withValues(alpha: acikZemin ? 0.30 : 0.22);

    canvas.drawRect(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      cerceve,
    );

    final motif = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = renk.withValues(alpha: acikZemin ? 0.22 : 0.16);

    const kenar = 46.0;
    final koseler = [
      const Offset(kenar, kenar),
      Offset(size.width - kenar, kenar),
      Offset(kenar, size.height - kenar),
      Offset(size.width - kenar, size.height - kenar),
    ];
    for (final kose in koseler) {
      yildizCiz(canvas, kose, 20, motif);
      canvas.drawCircle(kose, 27, motif..strokeWidth = 0.8);
      motif.strokeWidth = 1.2;
    }
  }

  /// İki kareyi 45° farkla üst üste çizerek sekiz köşeli yıldız oluşturur.
  static void yildizCiz(
    Canvas canvas,
    Offset merkez,
    double yaricap,
    Paint boya,
  ) {
    for (final baslangic in [0.0, math.pi / 4]) {
      final yol = Path();
      for (var i = 0; i < 4; i++) {
        final aci = baslangic + (math.pi / 2) * i;
        final nokta = Offset(
          merkez.dx + yaricap * math.cos(aci),
          merkez.dy + yaricap * math.sin(aci),
        );
        if (i == 0) {
          yol.moveTo(nokta.dx, nokta.dy);
        } else {
          yol.lineTo(nokta.dx, nokta.dy);
        }
      }
      yol.close();
      canvas.drawPath(yol, boya);
    }
  }

  @override
  bool shouldRepaint(_KoseMotifiPainter oldDelegate) =>
      oldDelegate.renk != renk || oldDelegate.acikZemin != acikZemin;
}

/// Hilal düzeninin gece göğünü çizer: tepede hilal, serpiştirilmiş yıldızlar
/// ve kartın altında minare–kubbe silueti.
class _HilalPainter extends CustomPainter {
  final Color renk;
  final bool acikZemin;

  const _HilalPainter({required this.renk, required this.acikZemin});

  @override
  void paint(Canvas canvas, Size size) {
    _hilalCiz(canvas, size);
    _yildizlariCiz(canvas, size);
    _siluetCiz(canvas, size);
  }

  /// İki çemberin farkını alarak hilal oluşturur.
  void _hilalCiz(Canvas canvas, Size size) {
    final merkez = Offset(size.width - 74, 62);
    const yaricap = 30.0;

    final dis = Path()
      ..addOval(Rect.fromCircle(center: merkez, radius: yaricap));
    final ic = Path()
      ..addOval(
        Rect.fromCircle(
          center: merkez.translate(yaricap * 0.42, -yaricap * 0.2),
          radius: yaricap * 0.88,
        ),
      );

    canvas.drawPath(
      Path.combine(PathOperation.difference, dis, ic),
      Paint()..color = renk.withValues(alpha: acikZemin ? 0.55 : 0.5),
    );
  }

  /// Sabit bir tohumla üretilen yıldızlar; kart her çizimde aynı görünür.
  void _yildizlariCiz(Canvas canvas, Size size) {
    final rastgele = math.Random(7);
    final boya = Paint()
      ..color = renk.withValues(alpha: acikZemin ? 0.35 : 0.4);

    // Yıldız sayısı kart yüksekliğiyle birlikte artar; 9:16 gibi uzun
    // oranlarda gökyüzü üstte sıkışıp geri kalanı boş kalmasın.
    final adet = (size.height / 22).round().clamp(20, 60);
    for (var i = 0; i < adet; i++) {
      final x = rastgele.nextDouble() * size.width;
      // Siluetin bulunduğu alt şerit boş bırakılır.
      final y = rastgele.nextDouble() * size.height * 0.82;
      final r = 0.7 + rastgele.nextDouble() * 1.3;
      canvas.drawCircle(Offset(x, y), r, boya);
    }

    // Birkaç ışıltılı dört uçlu yıldız.
    final isilti = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = renk.withValues(alpha: acikZemin ? 0.4 : 0.45);
    for (final nokta in [
      Offset(size.width * 0.18, size.height * 0.09),
      Offset(size.width * 0.36, size.height * 0.19),
      Offset(size.width * 0.72, size.height * 0.27),
      Offset(size.width * 0.24, size.height * 0.55),
    ]) {
      canvas.drawLine(nokta.translate(-5, 0), nokta.translate(5, 0), isilti);
      canvas.drawLine(nokta.translate(0, -5), nokta.translate(0, 5), isilti);
    }
  }

  /// Kartın alt kenarına oturan minare ve kubbe silueti.
  void _siluetCiz(Canvas canvas, Size size) {
    final taban = size.height;
    final boya = Paint()
      ..color = renk.withValues(alpha: acikZemin ? 0.30 : 0.24);

    final yol = Path()..moveTo(0, taban);

    // Sol minare.
    final solMinare = size.width * 0.16;
    yol
      ..lineTo(solMinare - 5, taban)
      ..lineTo(solMinare - 5, taban - 62)
      ..lineTo(solMinare, taban - 76)
      ..lineTo(solMinare + 5, taban - 62)
      ..lineTo(solMinare + 5, taban);

    // Ortadaki kubbe ve yanındaki gövde.
    final kubbeMerkez = size.width * 0.5;
    const kubbeYaricap = 34.0;
    yol
      ..lineTo(kubbeMerkez - kubbeYaricap - 16, taban)
      ..lineTo(kubbeMerkez - kubbeYaricap - 16, taban - 26)
      ..lineTo(kubbeMerkez - kubbeYaricap, taban - 26)
      ..arcToPoint(
        Offset(kubbeMerkez + kubbeYaricap, taban - 26),
        radius: const Radius.circular(kubbeYaricap),
      )
      ..lineTo(kubbeMerkez + kubbeYaricap + 16, taban - 26)
      ..lineTo(kubbeMerkez + kubbeYaricap + 16, taban);

    // Sağ minare.
    final sagMinare = size.width * 0.84;
    yol
      ..lineTo(sagMinare - 5, taban)
      ..lineTo(sagMinare - 5, taban - 54)
      ..lineTo(sagMinare, taban - 68)
      ..lineTo(sagMinare + 5, taban - 54)
      ..lineTo(sagMinare + 5, taban)
      ..lineTo(size.width, taban)
      ..close();

    canvas.drawPath(yol, boya);
  }

  @override
  bool shouldRepaint(_HilalPainter oldDelegate) =>
      oldDelegate.renk != renk || oldDelegate.acikZemin != acikZemin;
}

/// Mihrap düzeninde içeriği saran kemer çerçevesini çizer.
class _MihrapPainter extends CustomPainter {
  final Color renk;
  final bool acikZemin;

  const _MihrapPainter({required this.renk, required this.acikZemin});

  /// Verilen kenar boşluğuyla mihrap kemeri yolunu üretir.
  Path _kemerYolu(Size size, double bosluk, double kemerYuksekligi) {
    final sol = bosluk;
    final sag = size.width - bosluk;
    final alt = size.height - bosluk;
    final omuz = bosluk + kemerYuksekligi;
    final orta = size.width / 2;

    return Path()
      ..moveTo(sol, alt)
      ..lineTo(sol, omuz)
      // Sivri kemer: iki yay tepede birleşir.
      ..quadraticBezierTo(sol, bosluk, orta, bosluk)
      ..quadraticBezierTo(sag, bosluk, sag, omuz)
      ..lineTo(sag, alt)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = renk.withValues(alpha: acikZemin ? 0.5 : 0.4);
    final ic = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = renk.withValues(alpha: acikZemin ? 0.35 : 0.26);

    canvas.drawPath(_kemerYolu(size, 16, 96), dis);
    canvas.drawPath(_kemerYolu(size, 25, 92), ic);

    // Kemerin tepesindeki küçük alem motifi.
    final motif = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = renk.withValues(alpha: acikZemin ? 0.5 : 0.42);
    _KoseMotifiPainter.yildizCiz(canvas, Offset(size.width / 2, 62), 10, motif);

    // Tabanda ince zemin şeridi.
    final serit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = renk.withValues(alpha: acikZemin ? 0.3 : 0.22);
    canvas.drawLine(
      Offset(34, size.height - 28),
      Offset(size.width - 34, size.height - 28),
      serit,
    );
  }

  @override
  bool shouldRepaint(_MihrapPainter oldDelegate) =>
      oldDelegate.renk != renk || oldDelegate.acikZemin != acikZemin;
}

/// Kandil düzeninde tepeden sarkan kandili ve yaydığı ışık halesini çizer.
class _KandilPainter extends CustomPainter {
  final Color renk;
  final bool acikZemin;

  const _KandilPainter({required this.renk, required this.acikZemin});

  @override
  void paint(Canvas canvas, Size size) {
    final merkezX = size.width / 2;
    const zincirBas = 0.0;
    const zincirSon = 34.0;
    const govdeUst = 46.0;
    const govdeAlt = 104.0;

    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = renk.withValues(alpha: acikZemin ? 0.6 : 0.5);

    // Işık halesi önce çizilir ki kandil onun üstünde kalsın.
    final haleMerkezi = Offset(merkezX, govdeAlt - 12);
    final haleYaricap = size.width * 0.55;
    canvas.drawCircle(
      haleMerkezi,
      haleYaricap,
      Paint()
        ..shader = RadialGradient(
          colors: [
            renk.withValues(alpha: acikZemin ? 0.20 : 0.16),
            renk.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: haleMerkezi, radius: haleYaricap),
        ),
    );

    // Zincir ve askı halkası.
    canvas.drawLine(
      Offset(merkezX, zincirBas),
      Offset(merkezX, zincirSon),
      cizgi,
    );
    canvas.drawCircle(
      Offset(merkezX, zincirSon + 6),
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = renk.withValues(alpha: acikZemin ? 0.55 : 0.45),
    );

    // Kandil gövdesi: dar boyundan genişleyen kase ve altında sivri uç.
    const boyunYarim = 9.0;
    const kaseYarim = 30.0;
    final govde = Path()
      ..moveTo(merkezX - boyunYarim, govdeUst)
      ..lineTo(merkezX + boyunYarim, govdeUst)
      ..cubicTo(
        merkezX + kaseYarim,
        govdeUst + 16,
        merkezX + kaseYarim,
        govdeAlt - 16,
        merkezX,
        govdeAlt,
      )
      ..cubicTo(
        merkezX - kaseYarim,
        govdeAlt - 16,
        merkezX - kaseYarim,
        govdeUst + 16,
        merkezX - boyunYarim,
        govdeUst,
      )
      ..close();

    canvas.drawPath(
      govde,
      Paint()..color = renk.withValues(alpha: acikZemin ? 0.16 : 0.13),
    );
    canvas.drawPath(govde, cizgi);

    // Gövdenin ortasındaki alev.
    canvas.drawCircle(
      Offset(merkezX, govdeUst + 34),
      7,
      Paint()..color = renk.withValues(alpha: acikZemin ? 0.75 : 0.85),
    );

    // Kandilin iki yanına küçük ışıltılar.
    final isilti = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = renk.withValues(alpha: acikZemin ? 0.4 : 0.35);
    for (final nokta in [
      Offset(merkezX - 78, 70),
      Offset(merkezX + 78, 92),
      Offset(merkezX - 58, 128),
      Offset(merkezX + 62, 44),
    ]) {
      canvas.drawLine(nokta.translate(-4, 0), nokta.translate(4, 0), isilti);
      canvas.drawLine(nokta.translate(0, -4), nokta.translate(0, 4), isilti);
    }

    // Not: tabana ayrıca şerit çizilmez; imzanın kendi ayracıyla çakışıyordu.
  }

  @override
  bool shouldRepaint(_KandilPainter oldDelegate) =>
      oldDelegate.renk != renk || oldDelegate.acikZemin != acikZemin;
}

/// Tezhip düzeninin çift çerçevesini ve üstteki kemer motifini çizer.
class _TezhipPainter extends CustomPainter {
  final Color renk;
  final bool acikZemin;

  const _TezhipPainter({required this.renk, required this.acikZemin});

  @override
  void paint(Canvas canvas, Size size) {
    final disCerceve = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = renk.withValues(alpha: acikZemin ? 0.45 : 0.35);
    final icCerceve = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = renk.withValues(alpha: acikZemin ? 0.35 : 0.25);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 14, size.width - 28, size.height - 28),
        const Radius.circular(4),
      ),
      disCerceve,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(22, 22, size.width - 44, size.height - 44),
        const Radius.circular(2),
      ),
      icCerceve,
    );

    // Üstte ortalanmış kemer (mihrap) motifi ve içinde yıldız.
    final motif = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = renk.withValues(alpha: acikZemin ? 0.55 : 0.45);

    final merkezX = size.width / 2;
    const tepe = 44.0;
    const genislik = 34.0;
    const yukseklik = 40.0;

    final kemer = Path()
      ..moveTo(merkezX - genislik / 2, tepe + yukseklik)
      ..lineTo(merkezX - genislik / 2, tepe + yukseklik / 2)
      ..quadraticBezierTo(
        merkezX - genislik / 2,
        tepe,
        merkezX,
        tepe,
      )
      ..quadraticBezierTo(
        merkezX + genislik / 2,
        tepe,
        merkezX + genislik / 2,
        tepe + yukseklik / 2,
      )
      ..lineTo(merkezX + genislik / 2, tepe + yukseklik);
    canvas.drawPath(kemer, motif);

    _KoseMotifiPainter.yildizCiz(
      canvas,
      Offset(merkezX, tepe + yukseklik / 2 + 2),
      9,
      motif,
    );

    // Alt köşelerde küçük yıldızlar.
    final kucuk = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = renk.withValues(alpha: acikZemin ? 0.28 : 0.2);
    _KoseMotifiPainter.yildizCiz(
      canvas,
      Offset(42, size.height - 44),
      11,
      kucuk,
    );
    _KoseMotifiPainter.yildizCiz(
      canvas,
      Offset(size.width - 42, size.height - 44),
      11,
      kucuk,
    );
  }

  @override
  bool shouldRepaint(_TezhipPainter oldDelegate) =>
      oldDelegate.renk != renk || oldDelegate.acikZemin != acikZemin;
}
