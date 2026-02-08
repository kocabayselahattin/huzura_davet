import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class EsmaulHusnaSayfa extends StatefulWidget {
  const EsmaulHusnaSayfa({super.key});

  @override
  State<EsmaulHusnaSayfa> createState() => _EsmaulHusnaSayfaState();
}

class _EsmaulHusnaSayfaState extends State<EsmaulHusnaSayfa> {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();

  List<Map<String, String>> _getEsmaList() {
    final data = _languageService['esmaul_husna_list'];
    if (data is! List) return [];
    return data.map<Map<String, String>>((item) {
      if (item is Map) {
        return {
          'arabic': item['arabic']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'meaning': item['meaning']?.toString() ?? '',
        };
      }
      return {'arabic': '', 'name': '', 'meaning': ''};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(_languageService['esmaul_husna_title']),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: renkler.arkaPlanGradient != null
            ? BoxDecoration(gradient: renkler.arkaPlanGradient)
            : null,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _getEsmaList().length,
          itemBuilder: (context, index) {
            final esma = _getEsmaList()[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    renkler.kartArkaPlan,
                    renkler.kartArkaPlan.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: renkler.ayirac),
                boxShadow: [
                  BoxShadow(
                    color: renkler.vurgu.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Number
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: renkler.vurgu.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: renkler.vurgu,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Arabic
                  Text(
                    esma['arabic']!,
                    style: TextStyle(
                      color: renkler.yaziPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Name
                  Text(
                    esma['name']!,
                    style: TextStyle(
                      color: renkler.vurgu,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Meaning
                  Expanded(
                    child: Text(
                      esma['meaning']!,
                      style: TextStyle(
                        color: renkler.yaziSecondary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
