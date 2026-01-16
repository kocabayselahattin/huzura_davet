import 'package:flutter/material.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';

class IlIlceSecSayfa extends StatefulWidget {
  const IlIlceSecSayfa({super.key});

  @override
  State<IlIlceSecSayfa> createState() => _IlIlceSecSayfaState();
}

class _IlIlceSecSayfaState extends State<IlIlceSecSayfa> {
  List<Map<String, dynamic>> iller = [];
  List<Map<String, dynamic>> ilceler = [];
  String? secilenIlAdi;
  String? secilenIlId;
  String? secilenIlceAdi;
  String? secilenIlceId;
  bool yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _illeriYukle();
  }

  Future<void> _illeriYukle() async {
    setState(() => yukleniyor = true);
    final data = await DiyanetApiService.getIller();
    setState(() {
      iller = data;
      yukleniyor = false;
    });
  }

  Future<void> _ilceleriYukle(String ilId) async {
    setState(() => yukleniyor = true);
    final data = await DiyanetApiService.getIlceler(ilId);
    setState(() {
      ilceler = data;
      yukleniyor = false;
    });
  }

  Future<void> _kaydet() async {
    if (secilenIlId != null && secilenIlceId != null) {
      await KonumService.setIl(secilenIlAdi!, secilenIlId!);
      await KonumService.setIlce(secilenIlceAdi!, secilenIlceId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum kaydedildi')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      appBar: AppBar(
        title: const Text('İl/İlçe Seç'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (secilenIlceId != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _kaydet,
            ),
        ],
      ),
      body: yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // İl Seçimi
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: secilenIlId,
                    decoration: const InputDecoration(
                      labelText: 'İl Seçin',
                      labelStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                    dropdownColor: const Color(0xFF2B3151),
                    style: const TextStyle(color: Colors.white),
                    items: iller.map((il) {
                      return DropdownMenuItem<String>(
                        value: il['IlceID'].toString(),
                        child: Text(il['IlceAdi'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final il = iller.firstWhere(
                          (il) => il['IlceID'].toString() == value,
                        );
                        setState(() {
                          secilenIlId = value;
                          secilenIlAdi = il['IlceAdi'];
                          secilenIlceId = null;
                          secilenIlceAdi = null;
                          ilceler = [];
                        });
                        _ilceleriYukle(value);
                      }
                    },
                  ),
                ),

                // İlçe Seçimi
                if (ilceler.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: ilceler.length,
                      itemBuilder: (context, index) {
                        final ilce = ilceler[index];
                        final isSelected =
                            secilenIlceId == ilce['IlceID'].toString();
                        return ListTile(
                          title: Text(
                            ilce['IlceAdi'] ?? '',
                            style: TextStyle(
                              color: isSelected ? Colors.cyan : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.cyan)
                              : null,
                          onTap: () {
                            setState(() {
                              secilenIlceId = ilce['IlceID'].toString();
                              secilenIlceAdi = ilce['IlceAdi'];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
