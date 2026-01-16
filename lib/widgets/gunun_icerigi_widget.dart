import 'package:flutter/material.dart';

class GununIcerigiWidget extends StatelessWidget {
  const GununIcerigiWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _kart("GÜNÜN AYETİ", "Namaz müminin miracıdır.", Icons.menu_book),
        _kart("GÜNÜN HADİSİ", "Namaz dinin direğidir.", Icons.star_border),
        _kart("GÜNÜN DUASI", "Rabbim ilmimi artır.", Icons.favorite_border),
      ],
    );
  }

  Widget _kart(String baslik, String metin, IconData ikon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1B263B), borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(ikon, color: Colors.cyanAccent, size: 16), const SizedBox(width: 8), Text(baslik, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12))]),
          const SizedBox(height: 8),
          Text(metin, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}