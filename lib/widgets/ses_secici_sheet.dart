import 'package:flutter/material.dart';
import '../services/ses_onizleme_service.dart';
import '../services/tema_service.dart';

/// Ses seçimi için ortak alt panel: her satırda ön dinleme (play) ikonu
/// bulunur, satıra dokunmak o sesi seçer. Hem Bildirim Ayarları hem Hatim
/// Planı sayfası aynı paneli kullanır (aynı tasarım, farklı ses listeleri) —
/// tekrarlanan dropdown + ayrı play düğmesi yerine tek yerden bakımı yapılır.
///
/// [secenekler] her biri {'id':.., 'ad':..} olan çözümlenmiş (dil çevirisi
/// yapılmış) bir liste olmalı. "custom" id'li seçenek özel bir akış izler:
/// dokunulduğunda [ozelDosyaSec] çağrılır; döndürdüğü dosya yolu ile seçim
/// tamamlanır, null dönerse (kullanıcı vazgeçtiyse) panel açık kalır.
Future<({String id, String? ozelYol})?> sesSeciciSheetAc({
  required BuildContext context,
  required TemaRenkleri renkler,
  required String baslik,
  required List<Map<String, String>> secenekler,
  required String seciliSesId,
  Future<String?> Function()? ozelDosyaSec,
}) async {
  String? calanSesId;

  final sonuc = await showModalBottomSheet<({String id, String? ozelYol})>(
    context: context,
    backgroundColor: renkler.kartArkaPlan,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        baslik,
                        style: TextStyle(
                          color: renkler.yaziPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: secenekler.map((s) {
                        final id = s['id']!;
                        final ozel = id == 'custom';
                        final ad = s['ad'] ?? id;
                        final secili = id == seciliSesId;
                        final caliyor = calanSesId == id;
                        return ListTile(
                          leading: Icon(
                            ozel
                                ? Icons.folder_open_rounded
                                : (secili
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded),
                            color: secili
                                ? renkler.vurgu
                                : renkler.yaziSecondary,
                          ),
                          title: Text(
                            ad,
                            style: TextStyle(color: renkler.yaziPrimary),
                          ),
                          trailing: ozel
                              ? null
                              : IconButton(
                                  icon: Icon(
                                    caliyor
                                        ? Icons.stop_circle_outlined
                                        : Icons.play_circle_outline,
                                    color: renkler.vurgu,
                                  ),
                                  onPressed: () async {
                                    if (caliyor) {
                                      await SesOnizlemeService.durdur();
                                      setSheetState(() => calanSesId = null);
                                    } else {
                                      await SesOnizlemeService.cal(id);
                                      setSheetState(() => calanSesId = id);
                                    }
                                  },
                                ),
                          onTap: () async {
                            if (ozel) {
                              final yol = await ozelDosyaSec?.call();
                              if (yol != null && sheetContext.mounted) {
                                Navigator.pop(sheetContext, (
                                  id: 'custom',
                                  ozelYol: yol,
                                ));
                              }
                              return;
                            }
                            Navigator.pop(sheetContext, (
                              id: id,
                              ozelYol: null,
                            ));
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  await SesOnizlemeService.durdur();
  return sonuc;
}

/// Seçili sesi gösteren, dokunulunca [sesSeciciSheetAc] panelini açan
/// tıklanabilir satır. Bildirim Ayarları ve Hatim Planı sayfalarında aynı
/// görünümle kullanılır.
class SesSeciciSatiri extends StatelessWidget {
  final TemaRenkleri renkler;
  final IconData icon;
  final String etiket;
  final String secilenAd;
  final VoidCallback onTap;

  const SesSeciciSatiri({
    super.key,
    required this.renkler,
    required this.icon,
    required this.etiket,
    required this.secilenAd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: renkler.vurgu.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: renkler.vurgu.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: renkler.vurgu, size: 16),
              const SizedBox(width: 8),
              Text(
                etiket,
                style: TextStyle(color: renkler.yaziSecondary, fontSize: 13),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  secilenAd,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded, color: renkler.vurgu, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçili saati vurgulu, kenarlıklı bir kutu içinde gösteren, dokunulunca
/// [onTap] ile bir saat seçici açtırılan satır. [SesSeciciSatiri]'nin daha
/// belirgin (dolgulu/kenarlıklı) hâli — saat seçiminin de tıklanabilir
/// olduğu açıkça görünsün diye Hatim Planı sayfasındaki hatırlatma saati
/// satırıyla aynı tasarımı kullanır.
class ZamanSeciciSatiri extends StatelessWidget {
  final TemaRenkleri renkler;
  final Widget leading;
  final String etiket;
  final String saatMetni;
  final VoidCallback onTap;

  const ZamanSeciciSatiri({
    super.key,
    required this.renkler,
    required this.leading,
    required this.etiket,
    required this.saatMetni,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: renkler.vurgu.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: renkler.vurgu.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  leading,
                  const SizedBox(width: 8),
                  Text(
                    etiket,
                    style: TextStyle(
                      color: renkler.yaziSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    saatMetni,
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_rounded, color: renkler.vurgu, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
