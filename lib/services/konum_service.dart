import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/konum_model.dart';

class KonumService {
  static const String _ilKey = 'selected_il';
  static const String _ilIdKey = 'selected_il_id';
  static const String _ilceKey = 'selected_ilce';
  static const String _ilceIdKey = 'selected_ilce_id';
  static const String _konumlarKey = 'saved_locations'; // Çoklu konum listesi
  static const String _aktifKonumIndexKey = 'active_location_index'; // Aktif konum indeksi

  // Seçilen il bilgisini kaydet
  static Future<void> setIl(String ilAdi, String ilId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ilKey, ilAdi);
    await prefs.setString(_ilIdKey, ilId);
  }

  // Seçilen ilçe bilgisini kaydet
  static Future<void> setIlce(String ilceAdi, String ilceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ilceKey, ilceAdi);
    await prefs.setString(_ilceIdKey, ilceId);
  }

  // Kaydedilen il adını getir
  static Future<String?> getIl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilKey);
  }

  // Kaydedilen il ID'sini getir
  static Future<String?> getIlId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilIdKey);
  }

  // Kaydedilen ilçe adını getir
  static Future<String?> getIlce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilceKey);
  }

  // Kaydedilen ilçe ID'sini getir
  static Future<String?> getIlceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ilceIdKey);
  }
  
  // İlçe ID'sinin geçerli olup olmadığını kontrol et
  // Bazı eski ilçe ID'leri API'de çalışmıyor (örn: 1219, 1823, 1421 vb.)
  static Future<bool> isIlceIdValid(String? ilceId) async {
    if (ilceId == null || ilceId.isEmpty) return false;
    
    // Bilinen geçersiz ID'ler (eski lokal veri ID'leri, API'de 500/400 hatası veren)
    const invalidIds = [
      '1219', '1823', '1020', '1003', '1421', // Eski sistem ID'leri
      '1200', '1201', '1202', '1203', '1204', '1205', // Diğer eski ID'ler
    ];
    if (invalidIds.contains(ilceId)) {
      return false;
    }
    
    // Geçerli ID'ler genelde 9000-18000 aralığında (yeni sistem)
    try {
      final idNum = int.parse(ilceId);
      if (idNum < 9000 || idNum > 20000) {
        return false;
      }
    } catch (e) {
      return false;
    }
    
    return true;
  }
  
  // Geçersiz konum varsa temizle
  static Future<bool> validateAndClearIfInvalid() async {
    final ilceId = await getIlceId();
    final isValid = await isIlceIdValid(ilceId);
    
    if (!isValid && ilceId != null) {
      print('⚠️ Geçersiz ilçe ID tespit edildi: $ilceId - Temizleniyor...');
      await clearKonum();
      return false;
    }
    
    return isValid;
  }

  // Tüm konum bilgilerini temizle
  static Future<void> clearKonum() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ilKey);
    await prefs.remove(_ilIdKey);
    await prefs.remove(_ilceKey);
    await prefs.remove(_ilceIdKey);
  }

  // ============ ÇOKLU KONUM SİSTEMİ ============
  
  // Tüm kayıtlı konumları getir
  static Future<List<KonumModel>> getKonumlar() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_konumlarKey) ?? [];
    
    if (jsonList.isEmpty) {
      // Eğer eski sistemden konum varsa, onu listeye ekle
      final il = await getIl();
      final ilId = await getIlId();
      final ilce = await getIlce();
      final ilceId = await getIlceId();
      
      if (il != null && ilId != null && ilce != null && ilceId != null) {
        final eskiKonum = KonumModel(
          ilAdi: il,
          ilId: ilId,
          ilceAdi: ilce,
          ilceId: ilceId,
          aktif: true,
        );
        await addKonum(eskiKonum);
        return [eskiKonum];
      }
      return [];
    }
    
    return jsonList.map((json) => KonumModel.fromJson(jsonDecode(json))).toList();
  }

  // Yeni konum ekle
  static Future<void> addKonum(KonumModel konum) async {
    final konumlar = await getKonumlar();
    
    // Aynı konum zaten varsa ekleme
    if (konumlar.any((k) => k.ilceId == konum.ilceId && k.ilId == konum.ilId)) {
      print('⚠️ Bu konum zaten kayıtlı: ${konum.tamAd}');
      return;
    }
    
    // Yeni konum ekle
    konumlar.add(konum);
    await _saveKonumlar(konumlar);
    print('✅ Yeni konum eklendi: ${konum.tamAd}');
  }

  // Konum sil
  static Future<void> removeKonum(int index) async {
    final konumlar = await getKonumlar();
    
    if (index >= 0 && index < konumlar.length) {
      final silinenKonum = konumlar[index];
      konumlar.removeAt(index);
      await _saveKonumlar(konumlar);
      
      // Eğer aktif konum silindiyse, ilk konumu aktif yap
      final aktifIndex = await getAktifKonumIndex();
      if (aktifIndex == index && konumlar.isNotEmpty) {
        await setAktifKonumIndex(0);
      }
      
      print('✅ Konum silindi: ${silinenKonum.tamAd}');
    }
  }

  // Aktif konum indeksini getir
  static Future<int> getAktifKonumIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_aktifKonumIndexKey) ?? 0;
  }

  // Aktif konum indeksini ayarla
  static Future<void> setAktifKonumIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aktifKonumIndexKey, index);
    
    // Aktif konumu eski sisteme de kaydet (uyumluluk için)
    final konumlar = await getKonumlar();
    if (index >= 0 && index < konumlar.length) {
      final aktifKonum = konumlar[index];
      await setIl(aktifKonum.ilAdi, aktifKonum.ilId);
      await setIlce(aktifKonum.ilceAdi, aktifKonum.ilceId);
      print('✅ Aktif konum değiştirildi: ${aktifKonum.tamAd}');
    }
  }

  // Aktif konumu getir
  static Future<KonumModel?> getAktifKonum() async {
    final konumlar = await getKonumlar();
    final index = await getAktifKonumIndex();
    
    if (konumlar.isEmpty) return null;
    if (index >= 0 && index < konumlar.length) {
      return konumlar[index];
    }
    return konumlar.first;
  }

  // Konumları kaydet (private)
  static Future<void> _saveKonumlar(List<KonumModel> konumlar) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = konumlar.map((k) => jsonEncode(k.toJson())).toList();
    await prefs.setStringList(_konumlarKey, jsonList);
  }
}

