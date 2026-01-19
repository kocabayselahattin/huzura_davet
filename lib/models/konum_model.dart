class KonumModel {
  final String ilAdi;
  final String ilId;
  final String ilceAdi;
  final String ilceId;
  final bool aktif; // Hangi konum şu anda gösteriliyor

  KonumModel({
    required this.ilAdi,
    required this.ilId,
    required this.ilceAdi,
    required this.ilceId,
    this.aktif = false,
  });

  // JSON'dan oluştur
  factory KonumModel.fromJson(Map<String, dynamic> json) {
    return KonumModel(
      ilAdi: json['ilAdi'] ?? '',
      ilId: json['ilId'] ?? '',
      ilceAdi: json['ilceAdi'] ?? '',
      ilceId: json['ilceId'] ?? '',
      aktif: json['aktif'] ?? false,
    );
  }

  // JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'ilAdi': ilAdi,
      'ilId': ilId,
      'ilceAdi': ilceAdi,
      'ilceId': ilceId,
      'aktif': aktif,
    };
  }

  // String representation
  String get tamAd => '$ilAdi / $ilceAdi';

  // Kopyala ve değiştir
  KonumModel copyWith({
    String? ilAdi,
    String? ilId,
    String? ilceAdi,
    String? ilceId,
    bool? aktif,
  }) {
    return KonumModel(
      ilAdi: ilAdi ?? this.ilAdi,
      ilId: ilId ?? this.ilId,
      ilceAdi: ilceAdi ?? this.ilceAdi,
      ilceId: ilceId ?? this.ilceId,
      aktif: aktif ?? this.aktif,
    );
  }

  @override
  String toString() => tamAd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KonumModel &&
          runtimeType == other.runtimeType &&
          ilId == other.ilId &&
          ilceId == other.ilceId;

  @override
  int get hashCode => ilId.hashCode ^ ilceId.hashCode;
}
