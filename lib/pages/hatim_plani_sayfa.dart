import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';
import '../services/hatim_plan_service.dart';
import '../services/kuran_veri_service.dart';
import '../widgets/ses_secici_sheet.dart';
import 'kuran_sayfa.dart';

/// Hatim planı hatırlatmasında seçilebilecek bildirim sesleri. "custom"
/// dışındakiler Bildirim Ayarları sayfasındaki genel listeyle aynı res/raw
/// kimlikleridir (bkz. bildirim_ayarlari_sayfa.dart); "system_default"
/// telefonun kendi varsayılan bildirim sesini, "custom" ise kullanıcının
/// cihazdan seçtiği bir dosyayı çalar (bkz. _sesSeciciGoster).
const List<List<String>> _hatirlaticiSesSecenekleri = [
  ['system_default', 'sound_system_default'],
  ['best', 'sound_best'],
  ['melodi', 'sound_melodi'],
  ['ding_dong', 'sound_ding_dong'],
  ['corner', 'sound_corner'],
  ['snaps', 'sound_snaps'],
  ['sweet_favour', 'sound_sweet_favour'],
  ['violet', 'sound_violet'],
  ['ney_uyan', 'sound_ney_uyan'],
  ['esselatu_hayrun_minen_nevm1', 'sound_esselatu_1'],
  ['esselatu_hayrun_minen_nevm2', 'sound_esselatu_2'],
  ['aksam_ezani', 'sound_aksam_ezani'],
  ['ayasofya_ezan_sesi', 'sound_ayasofya_ezan'],
  ['mescid_i_nebi_sabah_ezani', 'sound_mescid_nebi_sabah'],
  ['sabah_ezani_saba', 'sound_sabah_ezani_saba'],
  ['ogle_ezani_rast', 'sound_ogle_ezani_rast'],
  ['ikindi_ezani_hicaz', 'sound_ikindi_ezani_hicaz'],
  ['aksam_ezani_segah', 'sound_aksam_ezani_segah'],
  ['yatsi_ezani_ussak', 'sound_yatsi_ezani_ussak'],
  ['custom', 'custom_sound'],
];

/// Tek bir hatim/okuma planı: [planId] verilirse o planın ilerleme
/// görünümü, verilmezse yeni plan oluşturma formu gösterilir. Birden fazla
/// plan aynı anda var olabilir (ör. Ramazan'da hem serbest hem Ramazan
/// hatmine paralel devam etmek); her biri kendi adı, ilerlemesi ve
/// hatırlatma saatiyle bu sayfadan yönetilir.
class HatimPlaniSayfa extends StatefulWidget {
  final String? planId;

  const HatimPlaniSayfa({super.key, this.planId});

  @override
  State<HatimPlaniSayfa> createState() => _HatimPlaniSayfaState();
}

class _HatimPlaniSayfaState extends State<HatimPlaniSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  bool _yukleniyor = true;
  HatimPlani? _plan;
  bool _planBulunamadi = false;

  // Plan oluşturma formu durumu.
  final TextEditingController _adController = TextEditingController();
  bool _adKullaniciDegistirdi = false;
  HatimPlanTuru _seciliTur = HatimPlanTuru.serbest;
  // Süre seçimi: hazır seçeneklerden biri (15/30/60/90 gün) ya da elle
  // seçilen bir bitiş tarihi. Elle tarih seçimi, sayfa/gün hesabını
  // kendisi yapmak isteyen kullanıcılar için ikinci bir yoldur.
  static const List<int> _gunSecenekleri = [15, 30, 60, 90];
  int _seciliGunSayisi = 30;
  bool _ozelTarihModu = false;
  DateTime _baslangicTarihi = _saatsiz(DateTime.now());
  DateTime _bitisTarihi = _saatsiz(
    DateTime.now().add(const Duration(days: 30)),
  );

  // Hatırlatma ayarları.
  bool _hatirlaticiAcik = true;
  TimeOfDay _hatirlaticiSaati = const TimeOfDay(hour: 21, minute: 0);
  String _hatirlaticiSesi = 'best';
  String? _hatirlaticiOzelSesYolu;

  // Yalnızca hatırlatma ayrıntıları varsayılan olarak gizli tutulur.
  bool _gelismisAcik = false;

  // Ramazan'ın tahmini (Diyanet senkronize) başlangıcı; yalnızca kullanıcı
  // "Ramazan Planı" sekmesini seçtiğinde başlangıç tarihine önerilir.
  DateTime? _ramazanTahmini;

  static DateTime _saatsiz(DateTime t) => DateTime(t.year, t.month, t.day);

  String _sesAdi(String sesId, String? ozelYol) {
    if (sesId == 'custom') {
      if (ozelYol != null) {
        return ozelYol.split('/').last.split('\\').last;
      }
      return _languageService['custom_sound'] ?? 'Özel Ses Seç';
    }
    final girdi = _hatirlaticiSesSecenekleri.firstWhere(
      (s) => s[0] == sesId,
      orElse: () => _hatirlaticiSesSecenekleri.first,
    );
    return _languageService[girdi[1]] ?? girdi[0];
  }

  /// Kullanıcının cihazından bir ses dosyası seçtirir ve uygulamanın belge
  /// dizinine kopyalar (bkz. bildirim_ayarlari_sayfa.dart'taki aynı desen).
  /// Seçilmez/kopyalanamazsa null döner.
  Future<String?> _ozelSesSecVeKopyala() async {
    try {
      final sonuc = await FilePicker.platform.pickFiles(type: FileType.audio);
      final kaynakYol = sonuc?.files.single.path;
      if (kaynakYol == null) return null;

      final belgeDizini = await getApplicationDocumentsDirectory();
      final sesDizini = Directory('${belgeDizini.path}/custom_sounds');
      if (!await sesDizini.exists()) {
        await sesDizini.create(recursive: true);
      }

      final dosyaAdi = kaynakYol.split('/').last.split('\\').last;
      final benzersizAd =
          'hatim_${DateTime.now().millisecondsSinceEpoch}_$dosyaAdi';
      final hedefYol = '${sesDizini.path}/$benzersizAd';
      await File(kaynakYol).copy(hedefYol);
      return hedefYol;
    } catch (e) {
      return null;
    }
  }

  /// Hatırlatma sesi seçim panelini açar; her seçenek ön dinlenebilir.
  /// "Özel Ses Seç" için önce cihazdan dosya seçtirilir. Seçim yapılırsa
  /// sonuç kaydını döndürür, vazgeçilirse null.
  List<Map<String, String>> get _hatirlaticiSesSecenekleriResolved =>
      _hatirlaticiSesSecenekleri
          .map(
            (s) => <String, String>{
              'id': s[0],
              'ad': s[0] == 'custom'
                  ? (_languageService['custom_sound'] ?? 'Özel Ses Seç')
                  : (_languageService[s[1]] ?? s[0]),
            },
          )
          .toList();

  Future<({String id, String? ozelYol})?> _sesSeciciGoster(
    String seciliSesId,
  ) {
    return sesSeciciSheetAc(
      context: context,
      renkler: _temaService.renkler,
      baslik:
          _languageService['hatim_plan_reminder_sound'] ?? 'Hatırlatma Sesi',
      secenekler: _hatirlaticiSesSecenekleriResolved,
      seciliSesId: seciliSesId,
      ozelDosyaSec: _ozelSesSecVeKopyala,
    );
  }

  Widget _buildSesSatiri({
    required TemaRenkleri renkler,
    required String sesId,
    required String? ozelSesYolu,
    required void Function(String id, String? ozelYol) onSecildi,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SesSeciciSatiri(
        renkler: renkler,
        icon: Icons.music_note_rounded,
        etiket: _languageService['hatim_plan_reminder_sound'] ?? 'Hatırlatma Sesi',
        secilenAd: _sesAdi(sesId, ozelSesYolu),
        onTap: () async {
          final secilen = await _sesSeciciGoster(sesId);
          if (secilen != null) onSecildi(secilen.id, secilen.ozelYol);
        },
      ),
    );
  }

  String _getLocale() {
    switch (_languageService.currentLanguage) {
      case 'tr':
        return 'tr_TR';
      case 'en':
        return 'en_US';
      case 'de':
        return 'de_DE';
      case 'fr':
        return 'fr_FR';
      case 'ar':
        return 'ar_SA';
      case 'fa':
        return 'fa_IR';
      default:
        return 'tr_TR';
    }
  }

  String _varsayilanAd() => _seciliTur == HatimPlanTuru.ramazan
      ? (_languageService['hatim_plan_default_name_ramadan'] ??
            'Ramazan Hatmim')
      : (_languageService['hatim_plan_default_name_free'] ?? 'Hatmim');

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _adController.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    await KuranVeriService.yukle();

    if (widget.planId != null) {
      final plan = await HatimPlanService.planGetir(widget.planId!);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _planBulunamadi = plan == null;
        _yukleniyor = false;
      });
      return;
    }

    final ramazanTahmini = HatimPlanService.ramazanBaslangicTahmini();
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
      _ramazanTahmini = ramazanTahmini;
      if (!_adKullaniciDegistirdi) _adController.text = _varsayilanAd();
    });
  }

  /// Seçili moda göre planın toplam gün sayısı: elle tarih seçildiyse
  /// tarihler arasındaki fark, aksi halde hazır seçeneklerden biri.
  int get _serbestPlanGunSayisi {
    if (_ozelTarihModu) {
      final fark = _bitisTarihi.difference(_baslangicTarihi).inDays + 1;
      return fark < 1 ? 1 : fark;
    }
    return _seciliGunSayisi;
  }

  int get _serbestPlanGunlukSayfa =>
      (KuranVeriService.toplamSayfaSayisi / _serbestPlanGunSayisi).ceil();

  String get _hatirlaticiSaatiMetni =>
      '${_hatirlaticiSaati.hour.toString().padLeft(2, '0')}:${_hatirlaticiSaati.minute.toString().padLeft(2, '0')}';

  Future<void> _planOlustur() async {
    final ad = _adController.text.trim().isEmpty
        ? _varsayilanAd()
        : _adController.text.trim();

    late HatimPlani plan;
    if (_seciliTur == HatimPlanTuru.ramazan) {
      plan = await HatimPlanService.ramazanPlaniOlustur(
        ad: ad,
        baslangicTarihi: _baslangicTarihi,
        hatirlaticiAcik: _hatirlaticiAcik,
        hatirlaticiSaati: _hatirlaticiSaatiMetni,
        hatirlaticiSesi: _hatirlaticiSesi,
        hatirlaticiOzelSesYolu: _hatirlaticiOzelSesYolu,
      );
    } else if (_ozelTarihModu) {
      plan = await HatimPlanService.serbestPlanOlustur(
        ad: ad,
        baslangicTarihi: _baslangicTarihi,
        bitisTarihi: _bitisTarihi,
        hatirlaticiAcik: _hatirlaticiAcik,
        hatirlaticiSaati: _hatirlaticiSaatiMetni,
        hatirlaticiSesi: _hatirlaticiSesi,
        hatirlaticiOzelSesYolu: _hatirlaticiOzelSesYolu,
      );
    } else {
      plan = await HatimPlanService.serbestPlanOlustur(
        ad: ad,
        baslangicTarihi: _baslangicTarihi,
        bitisTarihi: _baslangicTarihi.add(Duration(days: _seciliGunSayisi - 1)),
        hatirlaticiAcik: _hatirlaticiAcik,
        hatirlaticiSaati: _hatirlaticiSaatiMetni,
        hatirlaticiSesi: _hatirlaticiSesi,
        hatirlaticiOzelSesYolu: _hatirlaticiOzelSesYolu,
      );
    }
    if (!mounted) return;
    setState(() => _plan = plan);
  }

  Future<void> _planiSilOnayla() async {
    final plan = _plan;
    if (plan == null) return;
    final renkler = _temaService.renkler;
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: renkler.kartArkaPlan,
        title: Text(
          _languageService['hatim_plan_delete'] ?? 'Planı Sil',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        content: Text(
          (_languageService['hatim_plan_delete_confirm'] ??
                  '"{ad}" planını silmek istediğine emin misin?')
              .replaceAll('{ad}', plan.ad),
          style: TextStyle(color: renkler.yaziSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_languageService['cancel'] ?? 'Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _languageService['hatim_plan_delete'] ?? 'Planı Sil',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (onay != true) return;

    await HatimPlanService.planiSil(plan.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Plan adı ve hatırlatma ayarlarını düzenlemek için alt panel açar.
  Future<void> _planAyarlariniAc(HatimPlani plan) async {
    final renkler = _temaService.renkler;
    final adCtrl = TextEditingController(text: plan.ad);
    bool acik = plan.hatirlaticiAcik;
    final saatParcalari = plan.hatirlaticiSaati.split(':');
    TimeOfDay saat = TimeOfDay(
      hour:
          int.tryParse(saatParcalari.isNotEmpty ? saatParcalari[0] : '') ?? 21,
      minute:
          int.tryParse(saatParcalari.length > 1 ? saatParcalari[1] : '') ?? 0,
    );
    String ses = plan.hatirlaticiSesi;
    String? ozelSesYolu = plan.hatirlaticiOzelSesYolu;

    // Kullanıcı "Kaydet"e basmadan (geri tuşu, sayfa dışına dokunma vb.)
    // panelden çıkarsa yaptığı değişiklikler sessizce kaybolmasın diye
    // önce değişiklik olup olmadığı kontrol edilir, varsa onay istenir.
    bool degisiklikVarMi() {
      final saatMetni =
          '${saat.hour.toString().padLeft(2, '0')}:${saat.minute.toString().padLeft(2, '0')}';
      return adCtrl.text.trim() != plan.ad ||
          acik != plan.hatirlaticiAcik ||
          (acik && saatMetni != plan.hatirlaticiSaati) ||
          (acik && ses != plan.hatirlaticiSesi) ||
          (acik && ozelSesYolu != plan.hatirlaticiOzelSesYolu);
    }

    Future<void> kapatmayaCalis(BuildContext sheetContext) async {
      if (!degisiklikVarMi()) {
        Navigator.pop(sheetContext, false);
        return;
      }
      final kaydet = await showDialog<bool>(
        context: sheetContext,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: renkler.kartArkaPlan,
          title: Text(
            _languageService['save_changes_title'] ?? '',
            style: TextStyle(color: renkler.yaziPrimary),
          ),
          content: Text(
            _languageService['save_changes_message'] ?? '',
            style: TextStyle(color: renkler.yaziSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                _languageService['dont_save'] ?? '',
                style: TextStyle(color: renkler.yaziSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: renkler.vurgu),
              child: Text(
                _languageService['save'] ?? '',
                style: TextStyle(color: renkler.arkaPlan),
              ),
            ),
          ],
        ),
      );
      if (!sheetContext.mounted || kaydet == null) return;
      Navigator.pop(sheetContext, kaydet);
    }

    final kaydedildi = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: renkler.kartArkaPlan,
      isScrollControlled: true,
      // Değişiklikler yanlışlıkla kaybolmasın diye dışarı dokunarak veya
      // aşağı kaydırarak kapatma kapalı; çıkış yalnızca X düğmesi, Kaydet
      // düğmesi ya da geri tuşu üzerinden olur (üçü de kapatmayaCalis'ten geçer).
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) kapatmayaCalis(sheetContext);
          },
          child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _languageService['hatim_plan_settings'] ??
                            'Plan Ayarları',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: renkler.yaziSecondary),
                      onPressed: () => kapatmayaCalis(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: adCtrl,
                  style: TextStyle(color: renkler.yaziPrimary),
                  decoration: InputDecoration(
                    labelText:
                        _languageService['hatim_plan_name'] ?? 'Plan Adı',
                    labelStyle: TextStyle(color: renkler.yaziSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: renkler.vurgu.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: renkler.vurgu),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _languageService['hatim_plan_reminder_title'] ??
                            'Hatırlatma',
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Switch(
                      value: acik,
                      activeColor: renkler.vurgu,
                      inactiveThumbColor: renkler.yaziSecondary,
                      inactiveTrackColor: renkler.yaziSecondary.withOpacity(
                        0.3,
                      ),
                      onChanged: (v) => setSheetState(() => acik = v),
                    ),
                  ],
                ),
                if (acik)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ZamanSeciciSatiri(
                      renkler: renkler,
                      leading: Icon(
                        Icons.schedule_rounded,
                        color: renkler.vurgu,
                        size: 18,
                      ),
                      etiket:
                          _languageService['hatim_plan_reminder_time'] ??
                          'Bildirim Saati',
                      saatMetni: saat.format(sheetContext),
                      onTap: () async {
                        final secilen = await showTimePicker(
                          context: sheetContext,
                          initialTime: saat,
                        );
                        if (secilen != null) {
                          setSheetState(() => saat = secilen);
                        }
                      },
                    ),
                  ),
                if (acik)
                  _buildSesSatiri(
                    renkler: renkler,
                    sesId: ses,
                    ozelSesYolu: ozelSesYolu,
                    onSecildi: (id, yol) => setSheetState(() {
                      ses = id;
                      ozelSesYolu = yol;
                    }),
                  ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [renkler.vurgu, renkler.vurguSecondary],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(sheetContext, true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _languageService['save'] ?? 'Kaydet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );

    if (kaydedildi != true) return;

    final yeniAd = adCtrl.text.trim().isEmpty ? plan.ad : adCtrl.text.trim();
    final saatMetni =
        '${saat.hour.toString().padLeft(2, '0')}:${saat.minute.toString().padLeft(2, '0')}';

    await HatimPlanService.planiGuncelle(plan.kopyala(ad: yeniAd));
    await HatimPlanService.planHatirlaticisiniAyarla(
      plan.id,
      acik: acik,
      saat: saatMetni,
      ses: ses,
      ozelSesYolu: ozelSesYolu,
    );

    if (!mounted) return;
    setState(() {
      _plan = plan.kopyala(
        ad: yeniAd,
        hatirlaticiAcik: acik,
        hatirlaticiSaati: saatMetni,
        hatirlaticiSesi: ses,
        hatirlaticiOzelSesYolu: ozelSesYolu,
      );
    });
  }

  void _kaldiginYerdenOku(HatimPlani plan) {
    final baslamamis = plan.mevcutAyetNo == 0;
    final sureNo = baslamamis ? 1 : plan.mevcutSureNo;
    final sure = sureListesi.firstWhere(
      (s) => s.no == sureNo,
      orElse: () => sureListesi.first,
    );
    final ayetNo = baslamamis
        ? 1
        : (plan.mevcutAyetNo + 1 > sure.ayetSayisi
              ? sure.ayetSayisi
              : plan.mevcutAyetNo + 1);

    // Günün hedefine henüz ulaşılmadıysa okuma alanı tam olarak o hedefe
    // kadar sınırlanır (kullanıcı o gün kaç sayfa/cüz okuması gerekiyorsa
    // yalnızca onu görür); kullanıcı zaten önden gidiyorsa (hedefi
    // geçtiyse) sınırlama yapılmaz, normal okumaya devam eder.
    final hedef = HatimPlanService.gunlukHedef(plan);
    final devamEdilecekYer = KuranVeriService.globalAyetNo(sureNo, ayetNo);
    final hedefKonumu = KuranVeriService.globalAyetNo(
      hedef.hedefSureNo,
      hedef.hedefAyetNo,
    );
    final hedefUlasilmadi = devamEdilecekYer <= hedefKonumu;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SureDetaySayfa(
          sure: sure,
          baslangicAyetNo: ayetNo,
          hatimPlanId: plan.id,
          hedefSureNo: hedefUlasilmadi ? hedef.hedefSureNo : null,
          hedefAyetNo: hedefUlasilmadi ? hedef.hedefAyetNo : null,
        ),
      ),
    ).then((_) => _yukle());
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final plan = _plan;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          plan?.ad ?? (_languageService['hatim_plan_title'] ?? 'Hatim Planı'),
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: renkler.yaziPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (plan != null) ...[
            IconButton(
              icon: Icon(Icons.tune_rounded, color: renkler.yaziSecondary),
              tooltip:
                  _languageService['hatim_plan_settings'] ?? 'Plan Ayarları',
              onPressed: () => _planAyarlariniAc(plan),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: renkler.yaziSecondary),
              tooltip: _languageService['hatim_plan_delete'] ?? 'Planı Sil',
              onPressed: _planiSilOnayla,
            ),
          ],
        ],
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: _yukleniyor
            ? Center(child: CircularProgressIndicator(color: renkler.vurgu))
            : _planBulunamadi
            ? _buildBulunamadiMesaji(renkler)
            : plan == null
            ? _buildOlusturmaFormu(renkler)
            : _buildPlanGorunumu(plan, renkler),
      ),
    );
  }

  Widget _buildBulunamadiMesaji(TemaRenkleri renkler) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _languageService['hatim_plan_not_found'] ??
              'Bu plan artık mevcut değil.',
          textAlign: TextAlign.center,
          style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
        ),
      ),
    );
  }

  // ---------------- Plan oluşturma formu ----------------

  Widget _buildOlusturmaFormu(TemaRenkleri renkler) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTurSecici(renkler),
        const SizedBox(height: 20),
        _buildTarihSatiri(
          baslik:
              _languageService['hatim_plan_start_date'] ?? 'Başlangıç Tarihi',
          tarih: _baslangicTarihi,
          renkler: renkler,
          onSecildi: (t) => setState(() => _baslangicTarihi = t),
        ),
        const SizedBox(height: 20),
        if (_seciliTur == HatimPlanTuru.serbest) ...[
          Text(
            _languageService['hatim_plan_duration_question'] ??
                'Hatmini kaç günde bitirmek istersin?',
            style: TextStyle(
              color: renkler.yaziPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (!_ozelTarihModu) _buildGunPresetleri(renkler),
          const SizedBox(height: 12),
          Center(
            child: Text(
              (_languageService['hatim_plan_estimated_summary'] ??
                      'Günde ≈{gunlukSayfa} sayfa okuyarak {gun} günde hatim tamamlanır.')
                  .replaceAll('{gunlukSayfa}', '$_serbestPlanGunlukSayfa')
                  .replaceAll('{gun}', '$_serbestPlanGunSayisi'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: renkler.vurgu.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _languageService['hatim_plan_ramadan_info'] ??
                  'Ramazan boyunca her gün 1 cüz okuyarak 30 günde hatim tamamlanır.',
              style: TextStyle(
                color: renkler.yaziSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _adController,
          onChanged: (_) => _adKullaniciDegistirdi = true,
          style: TextStyle(color: renkler.yaziPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: _languageService['hatim_plan_name'] ?? 'Plan Adı',
            labelStyle: TextStyle(color: renkler.yaziSecondary),
            prefixIcon: Icon(Icons.edit_note_rounded, color: renkler.vurgu),
            filled: true,
            fillColor: renkler.kartArkaPlan,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_seciliTur == HatimPlanTuru.serbest) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _ozelTarihModu = !_ozelTarihModu),
              child: Text(
                _ozelTarihModu
                    ? (_languageService['hatim_plan_use_presets'] ??
                          'Hazır sürelerden seçmek istiyorum')
                    : (_languageService['hatim_plan_custom_date'] ??
                          'Kendim bir bitiş tarihi seçmek istiyorum'),
                style: TextStyle(color: renkler.vurgu, fontSize: 13),
              ),
            ),
          ),
          if (_ozelTarihModu) ...[
            const SizedBox(height: 4),
            _buildTarihSatiri(
              baslik: _languageService['hatim_plan_end_date'] ?? 'Bitiş Tarihi',
              tarih: _bitisTarihi,
              ilkTarih: _baslangicTarihi.add(const Duration(days: 1)),
              renkler: renkler,
              onSecildi: (t) => setState(() => _bitisTarihi = t),
            ),
          ],
        ],
        const SizedBox(height: 20),
        _buildGelismisAyarlar(renkler),
        const SizedBox(height: 24),
        _buildBaslatButonu(renkler),
      ],
    );
  }

  /// Özel bitiş tarihi ve hatırlatma gibi ayrıntılar varsayılan olarak
  /// gizli tutulur; isteyen bu bölümü açıp ince ayar yapabilir.
  Widget _buildGelismisAyarlar(TemaRenkleri renkler) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _gelismisAcik = !_gelismisAcik),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _languageService['hatim_plan_advanced'] ??
                        'Gelişmiş ayarlar',
                    style: TextStyle(
                      color: renkler.yaziSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _gelismisAcik
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: renkler.yaziSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_gelismisAcik) ...[
          const SizedBox(height: 12),
          _buildHatirlaticiAyarlari(renkler),
        ],
      ],
    );
  }

  Widget _buildTurSecici(TemaRenkleri renkler) {
    return Row(
      children: [
        Expanded(
          child: _buildSecimKutusu(
            secili: _seciliTur == HatimPlanTuru.serbest,
            baslik: _languageService['hatim_plan_type_free'] ?? 'Serbest Plan',
            ikon: Icons.auto_stories_rounded,
            renkler: renkler,
            onTap: () => setState(() {
              _seciliTur = HatimPlanTuru.serbest;
              _baslangicTarihi = _saatsiz(DateTime.now());
              if (!_adKullaniciDegistirdi) {
                _adController.text = _varsayilanAd();
              }
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSecimKutusu(
            secili: _seciliTur == HatimPlanTuru.ramazan,
            baslik:
                _languageService['hatim_plan_type_ramadan'] ??
                'Ramazan Planı (30 Cüz)',
            ikon: Icons.nightlight_round,
            renkler: renkler,
            onTap: () => setState(() {
              _seciliTur = HatimPlanTuru.ramazan;
              if (_ramazanTahmini != null) {
                _baslangicTarihi = _saatsiz(_ramazanTahmini!);
              }
              if (!_adKullaniciDegistirdi) {
                _adController.text = _varsayilanAd();
              }
            }),
          ),
        ),
      ],
    );
  }

  /// Hazır süre seçenekleri: sayfa/gün hesabıyla uğraşmak istemeyen
  /// kullanıcılar (özellikle yaşlı kullanıcılar) için tek dokunuşluk seçim.
  Widget _buildGunPresetleri(TemaRenkleri renkler) {
    return SizedBox(
      height: 72,
      child: Row(
        children: _gunSecenekleri.map((gun) {
          final secili = !_ozelTarihModu && _seciliGunSayisi == gun;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildSecimKutusu(
                secili: secili,
                baslik: '$gun\n${_languageService['hatim_plan_days'] ?? 'gün'}',
                renkler: renkler,
                buyukMetin: true,
                onTap: () => setState(() {
                  _ozelTarihModu = false;
                  _seciliGunSayisi = gun;
                }),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSecimKutusu({
    required bool secili,
    required String baslik,
    required TemaRenkleri renkler,
    required VoidCallback onTap,
    IconData? ikon,
    bool buyukMetin = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: secili
                ? renkler.vurgu.withOpacity(0.15)
                : renkler.kartArkaPlan,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: secili ? renkler.vurgu : renkler.vurgu.withOpacity(0.15),
              width: secili ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (ikon != null) ...[
                Icon(
                  ikon,
                  color: secili ? renkler.vurgu : renkler.yaziSecondary,
                  size: 22,
                ),
                const SizedBox(height: 6),
              ],
              Text(
                baslik,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secili ? renkler.vurgu : renkler.yaziSecondary,
                  fontSize: buyukMetin ? 15 : 14,
                  fontWeight: secili ? FontWeight.bold : FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarihSatiri({
    required String baslik,
    required DateTime tarih,
    required TemaRenkleri renkler,
    required ValueChanged<DateTime> onSecildi,
    DateTime? ilkTarih,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final secilen = await showDatePicker(
            context: context,
            initialDate: tarih,
            firstDate:
                ilkTarih ?? DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (secilen != null) onSecildi(_saatsiz(secilen));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: renkler.kartArkaPlan,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: renkler.vurgu.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: renkler.vurgu,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  baslik,
                  style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
                ),
              ),
              Text(
                DateFormat('d MMMM yyyy', _getLocale()).format(tarih),
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHatirlaticiAyarlari(TemaRenkleri renkler) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renkler.vurgu.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: renkler.vurgu,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _languageService['hatim_plan_reminder_title'] ?? 'Hatırlatma',
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _hatirlaticiAcik,
                activeColor: renkler.vurgu,
                inactiveThumbColor: renkler.yaziSecondary,
                inactiveTrackColor: renkler.yaziSecondary.withOpacity(0.3),
                onChanged: (v) => setState(() => _hatirlaticiAcik = v),
              ),
            ],
          ),
          if (_hatirlaticiAcik)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ZamanSeciciSatiri(
                renkler: renkler,
                leading: Icon(
                  Icons.schedule_rounded,
                  color: renkler.vurgu,
                  size: 18,
                ),
                etiket:
                    _languageService['hatim_plan_reminder_time'] ??
                    'Bildirim Saati',
                saatMetni: _hatirlaticiSaati.format(context),
                onTap: () async {
                  final secilen = await showTimePicker(
                    context: context,
                    initialTime: _hatirlaticiSaati,
                  );
                  if (secilen != null) {
                    setState(() => _hatirlaticiSaati = secilen);
                  }
                },
              ),
            ),
          if (_hatirlaticiAcik)
            _buildSesSatiri(
              renkler: renkler,
              sesId: _hatirlaticiSesi,
              ozelSesYolu: _hatirlaticiOzelSesYolu,
              onSecildi: (id, yol) => setState(() {
                _hatirlaticiSesi = id;
                _hatirlaticiOzelSesYolu = yol;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildBaslatButonu(TemaRenkleri renkler) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [renkler.vurgu, renkler.vurguSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: renkler.vurgu.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _planOlustur,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _languageService['hatim_plan_start_button'] ?? 'Planı Başlat',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Aktif plan görünümü ----------------

  Widget _buildPlanGorunumu(HatimPlani plan, TemaRenkleri renkler) {
    final hedef = HatimPlanService.gunlukHedef(plan);
    final gunNo = plan.gunIndex().clamp(0, plan.toplamGun - 1) + 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: renkler.kartArkaPlan,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: renkler.vurgu.withOpacity(0.1), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _languageService['hatim_plan_progress'] ?? 'İlerleme',
                    style: TextStyle(
                      color: renkler.yaziSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '%${(plan.ilerlemeOrani * 100).toStringAsFixed(0)}',
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: plan.ilerlemeOrani,
                  backgroundColor: renkler.vurgu.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(renkler.vurgu),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                (_languageService['hatim_plan_day_of_total'] ??
                        'Gün {gun} / {toplam}')
                    .replaceAll('{gun}', '$gunNo')
                    .replaceAll('{toplam}', '${plan.toplamGun}'),
                style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (plan.tamamlandiMi)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: renkler.vurgu.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _languageService['hatim_plan_completed'] ??
                  'Tebrikler, hatmini tamamladın! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: renkler.vurgu,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  renkler.vurgu.withOpacity(0.85),
                  renkler.vurguSecondary.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: renkler.vurgu.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _kaldiginYerdenOku(plan),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _languageService['hatim_plan_today_goal'] ??
                            'BUGÜNÜN HEDEFİ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hedef.etiket,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            _languageService['hatim_plan_continue_reading'] ??
                                'Kaldığın Yerden Oku',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
