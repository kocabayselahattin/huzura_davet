import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/hadis_kutuphanesi_service.dart';
import 'hadis_kategori_sayfa.dart';

/// Kütüphane > Hadisler: Riyâzü's-Sâlihîn'den derlenen hadisler, konu
/// başlığına göre (Cömertlik, Kibir ve Gurur, Tevazu ve Şefkat, ...) dikey
/// bir liste hâlinde gösterilir.
class HadisKutuphanesiSayfa extends StatelessWidget {
  const HadisKutuphanesiSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    final temaService = TemaService();
    final renkler = temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          'HADİSLER',
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 14,
            color: renkler.yaziPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<MapEntry<String, int>>>(
            future: HadisKutuphanesiService.kategoriler(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: renkler.vurgu),
                );
              }
              final kategoriler = snapshot.data ?? const [];
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: kategoriler.length,
                itemBuilder: (context, index) {
                  final girdi = kategoriler[index];
                  return _kategoriOgesi(context, girdi.key, girdi.value, renkler);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kategoriOgesi(
    BuildContext context,
    String kategori,
    int sayi,
    TemaRenkleri renkler,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: renkler.vurgu.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final dualar = await HadisKutuphanesiService.kategoriyeGoreHadisler(
              kategori,
            );
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HadisKategoriSayfa(
                  kategoriBaslik: kategori,
                  hadisler: dualar,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kategori,
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$sayi',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: renkler.yaziSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
