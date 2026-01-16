import 'package:flutter/material.dart';
import '../services/konum_service.dart';
import 'il_ilce_sec_sayfa.dart';

class ImsakiyeSayfa extends StatefulWidget {
  const ImsakiyeSayfa({super.key});

  @override
  State<ImsakiyeSayfa> createState() => _ImsakiyeSayfaState();
}

class _ImsakiyeSayfaState extends State<ImsakiyeSayfa> {
  String? secilenIl;
  String? secilenIlce;

  @override
  void initState() {
    super.initState();
    _konumBilgileriniYukle();
  }

  Future<void> _konumBilgileriniYukle() async {
    final il = await KonumService.getIl();
    final ilce = await KonumService.getIlce();
    setState(() {
      secilenIl = il;
      secilenIlce = ilce;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      appBar: AppBar(
        title: const Text('İmsakiye'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (secilenIl != null && secilenIlce != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3151),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Seçili Konum',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$secilenIl / $secilenIlce',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton.icon(
              onPressed: () async {
                // TODO: Geolocator ile konum al
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Konum servisi yakında eklenecek'),
                  ),
                );
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Konumumu Kullan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B3151),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IlIlceSecSayfa(),
                  ),
                );
                if (result == true) {
                  _konumBilgileriniYukle();
                }
              },
              icon: const Icon(Icons.location_city),
              label: const Text('İl/İlçe Seç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B3151),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
