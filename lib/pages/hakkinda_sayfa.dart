import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class HakkindaSayfa extends StatefulWidget {
  const HakkindaSayfa({super.key});

  @override
  State<HakkindaSayfa> createState() => _HakkindaSayfaState();
}

class _HakkindaSayfaState extends State<HakkindaSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  @override
  void dispose() {
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: renkler.vurgu,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _languageService['about'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      renkler.vurgu,
                      renkler.vurgu.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mosque,
                    size: 80,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),

          // İçerik
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Uygulama Logosu ve Adı
                  _uygulamaBilgisi(renkler),
                  const SizedBox(height: 24),

                  // Açıklama
                  _baslikVeMetin(
                    _languageService['what_is_huzur_vakti'],
                    _languageService['about_desc'],
                    renkler,
                  ),
                  const SizedBox(height: 24),

                  // Özellikler
                  _ozelliklerBolumu(renkler),
                  const SizedBox(height: 24),

                  // Önemli Bilgiler
                  _onemliNotlar(renkler),
                  const SizedBox(height: 24),

                  // İletişim
                  _iletisimBolumu(renkler),
                  const SizedBox(height: 24),

                  // Versiyon ve Telif
                  _altBilgi(renkler),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uygulamaBilgisi(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            renkler.vurgu.withValues(alpha: 0.2),
            renkler.vurgu.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: renkler.vurgu.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: renkler.vurgu,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mosque,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _languageService['app_name'] ?? 'Huzur Vakti',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _languageService['prayer_times_assistant'] ?? 'Namaz Vakitleri ve İbadet Asistanı',
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_languageService['version'] ?? 'Versiyon'} 2.3.0',
            style: TextStyle(
              color: renkler.yaziSecondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _baslikVeMetin(String baslik, String metin, TemaRenkleri renkler) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          metin,
          style: TextStyle(
            color: renkler.yaziSecondary,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _ozelliklerBolumu(TemaRenkleri renkler) {
    final ozellikler = [
      {
        'ikon': Icons.location_city,
        'renk': Colors.blue,
        'baslik': '🆕 Çoklu Konum',
        'aciklama': 'Birden fazla konum ekleyin ve aralarında kolayca geçiş yapın',
      },
      {
        'ikon': Icons.public,
        'renk': Colors.green,
        'baslik': '🆕 Ülke Desteği',
        'aciklama': 'Türkiye dışındaki ülkeler için hazırlıklar devam ediyor',
      },
      {
        'ikon': Icons.notifications_active,
        'renk': Colors.red,
        'baslik': 'Akıllı Bildirimler',
        'aciklama': 'Her vakit için özelleştirilebilir bildirimler, erken hatırlatma ve vaktinde bildirim seçenekleri',
      },
      {
        'ikon': Icons.lock_open,
        'renk': Colors.purple,
        'baslik': '🆕 Otomatik Widget Güncelleme',
        'aciklama': 'Ekran kilidi açıldığında widget otomatik güncellenir',
      },
      {
        'ikon': Icons.location_on,
        'renk': Colors.teal,
        'baslik': 'Konum Tabanlı',
        'aciklama': 'GPS ile konumunuzu otomatik tespit eder ve en doğru vakit bilgilerini sunar',
      },
      {
        'ikon': Icons.menu_book,
        'renk': Colors.deepOrange,
        'baslik': '🆕 Namazda Okunan Dualar',
        'aciklama': 'Sübhaneke, Fatiha, Tahiyyat, Salavat ve tüm namaz duaları Arapça ve okunuşlarıyla',
      },
      {
        'ikon': Icons.checklist,
        'renk': Colors.indigo,
        'baslik': '🆕 32 ve 54 Farz',
        'aciklama': 'İslam\'ın tüm farzları detaylı açıklamalarıyla',
      },
      {
        'ikon': Icons.brightness_3,
        'renk': Colors.indigo,
        'baslik': 'Özel Gün ve Geceler',
        'aciklama': 'Kandil geceleri, bayramlar ve önemli günler hakkında detaylı bilgi ve hatırlatmalar',
      },
      {
        'ikon': Icons.book,
        'renk': Colors.orange,
        'baslik': 'Kur\'an-ı Kerim',
        'aciklama': 'Günün ayeti, sureler ve meal ile Kur\'an-ı Kerim\'e kolay erişim',
      },
      {
        'ikon': Icons.library_books,
        'renk': Colors.brown,
        'baslik': '40 Hadis-i Şerif',
        'aciklama': 'Peygamber Efendimiz (S.A.V)\'in hadislerinden seçilmiş 40 hadis koleksiyonu',
      },
      {
        'ikon': Icons.library_books,
        'renk': Colors.brown,
        'baslik': '📿 Özel Zikir Ekleme',
        'aciklama': 'Kendi zikirlerinizi ekleyin, düzenleyin ve silin',
      },
      {
        'ikon': Icons.blur_circular,
        'renk': Colors.cyan,
        'baslik': 'Zikir Matik',
        'aciklama': 'Dijital tesbih, sayaç ve titreşim özelliği ile zikirlerinizi takip edin',
      },
      {
        'ikon': Icons.star,
        'renk': Colors.amber,
        'baslik': 'Esmaül Hüsna',
        'aciklama': 'Allah\'ın 99 güzel ismi ve anlamları, günün esması özelliği',
      },
      {
        'ikon': Icons.qr_code,
        'renk': Colors.deepPurple,
        'baslik': 'Kıble Yönü',
        'aciklama': 'Pusula ile Kıble yönünü kolayca bulun',
      },
      {
        'ikon': Icons.mosque,
        'renk': Colors.lightGreen,
        'baslik': '🆕 Yakındaki Camiler',
        'aciklama': 'OpenStreetMap ile 2km yarıçapta camileri görüntüleyin',
      },
      {
        'ikon': Icons.widgets,
        'renk': Colors.pink,
        'baslik': 'Widget Desteği',
        'aciklama': 'Ana ekranınızda vakit bilgilerini görüntüleyin',
      },
      {
        'ikon': Icons.dark_mode,
        'renk': Colors.blueGrey,
        'baslik': 'Tema Seçenekleri',
        'aciklama': 'Premium, Galaksi, Neon, Okyanus ve Dijital tema seçenekleri',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageService['features'],
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...ozellikler.map((ozellik) => _ozellikKarti(
          renkler,
          ozellik['ikon'] as IconData,
          ozellik['renk'] as Color,
          ozellik['baslik'] as String,
          ozellik['aciklama'] as String,
        )),
      ],
    );
  }

  Widget _ozellikKarti(
    TemaRenkleri renkler,
    IconData ikon,
    Color renk,
    String baslik,
    String aciklama,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: renkler.ayirac.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, color: renk, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aciklama,
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onemliNotlar(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[700], size: 24),
              const SizedBox(width: 12),
              Text(
                _languageService['important_info'] ?? 'Önemli Bilgiler',
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _notSatiri(
            '• ${_languageService['diyanet_data_note'] ?? 'Vakit hesaplamaları Diyanet İşleri Başkanlığı verilerine göre yapılmaktadır.'}',
            renkler,
          ),
          _notSatiri(
            '• ${_languageService['battery_optimization_note'] ?? 'Bildirimlerin düzgün çalışması için pil optimizasyonu izinlerini ayarlamanız önerilir.'}',
            renkler,
          ),
          _notSatiri(
            '• ${_languageService['location_permission_note'] ?? 'Konum izni verilmediğinde manuel şehir seçimi yapmanız gerekmektedir.'}',
            renkler,
          ),
          _notSatiri(
            '• ${_languageService['internet_note'] ?? 'İnternet bağlantısı sadece ilk kurulumda ve konum güncellemelerinde gereklidir.'}',
            renkler,
          ),
        ],
      ),
    );
  }

  Widget _notSatiri(String metin, TemaRenkleri renkler) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        metin,
        style: TextStyle(
          color: renkler.yaziSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _iletisimBolumu(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageService['contact_support'] ?? 'İletişim ve Destek',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _iletisimSatiri(Icons.email, _languageService['email'] ?? 'E-posta', ' ', renkler),
          _iletisimSatiri(Icons.web, _languageService['web'] ?? 'Web', ' ', renkler),
          _iletisimSatiri(Icons.bug_report, _languageService['bug_report'] ?? 'Hata Bildirimi', ' ', renkler),
        ],
      ),
    );
  }

  Widget _iletisimSatiri(IconData ikon, String baslik, String deger, TemaRenkleri renkler) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(ikon, color: renkler.vurgu, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  deger,
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _altBilgi(TemaRenkleri renkler) {
    return Column(
      children: [
        Divider(color: renkler.ayirac),
        const SizedBox(height: 16),
        
        // Play Store düğmesi
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () {
              // Play Store linki (şimdilik devre dışı)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_languageService['coming_soon_playstore'] ?? 'Yakında Play Store\'da!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.shop, size: 20),
            label: Text(_languageService['rate_on_playstore'] ?? 'Play Store\'da Değerlendir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        Text(
          '© 2026 ${_languageService['app_name'] ?? 'Huzur Vakti'}',
          style: TextStyle(
            color: renkler.yaziSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _languageService['all_rights_reserved'] ?? 'Tüm hakları saklıdır.',
          style: TextStyle(
            color: renkler.yaziSecondary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _languageService['for_allah'] ?? 'Allah\'ın (C.C) rızası için hazırlanmıştır.',
          style: TextStyle(
            color: renkler.vurgu,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _languageService['developer_name'] ?? 'Geliştirici: Selahattin Kocabay',
          style: TextStyle(
            color: renkler.yaziSecondary.withValues(alpha: 0.6),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
