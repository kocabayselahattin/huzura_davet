import 'package:flutter/material.dart';

class VakitListesiWidget extends StatelessWidget {
  const VakitListesiWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _vakitSatiri("İmsak", "06:12", false),
          _vakitSatiri("Güneş", "07:45", false),
          _vakitSatiri("Öğle", "13:22", true), // Örnek aktif vakit
          _vakitSatiri("İkindi", "15:58", false),
          _vakitSatiri("Akşam", "18:25", false),
          _vakitSatiri("Yatsı", "19:50", false),
        ],
      ),
    );
  }

  Widget _vakitSatiri(String ad, String saat, bool aktif) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: aktif ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(ad, style: TextStyle(color: aktif ? Colors.cyanAccent : Colors.white)),
          Text(saat, style: TextStyle(color: aktif ? Colors.cyanAccent : Colors.white70, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}