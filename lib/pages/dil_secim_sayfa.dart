import 'package:flutter/material.dart';
import '../services/language_service.dart';

class DilSecimSayfa extends StatefulWidget {
  const DilSecimSayfa({super.key});

  @override
  State<DilSecimSayfa> createState() => _DilSecimSayfaState();
}

class _DilSecimSayfaState extends State<DilSecimSayfa> {
  final LanguageService _languageService = LanguageService();
  String _secilenDil = 'tr';

  @override
  void initState() {
    super.initState();
    print('🌍 DilSecimSayfa: initState');
    _languageService.load().then((_) {
      if (mounted) {
        setState(() {
          _secilenDil = _languageService.currentLanguage;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('🌍 DilSecimSayfa: build called');
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B2741), Color(0xFF2B3151), Color(0xFF1B2741)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Title
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.language,
                        size: 64,
                        color: Color(0xFF00BCD4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _languageService['select_language_title'] ??
                          (_languageService['select_language'] ?? ''),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _languageService['select_language_desc'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF00BCD4).withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Language list
                Expanded(
                  child: ListView.builder(
                    itemCount: _languageService.supportedLanguages.length,
                    itemBuilder: (context, index) {
                      final dil = _languageService.supportedLanguages[index];
                      final dilKodu = dil['code']!;
                      final secili = _secilenDil == dilKodu;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: const Color(0xFF2B3151),
                        elevation: secili ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: secili
                                ? const Color(0xFF00BCD4)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Text(
                            dil['flag']!,
                            style: const TextStyle(fontSize: 32),
                          ),
                          title: Text(
                            dil['name']!,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: secili
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: secili
                                      ? const Color(0xFF00BCD4)
                                      : Colors.white,
                                ),
                          ),
                          trailing: secili
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF00BCD4),
                                  size: 28,
                                )
                              : const Icon(
                                  Icons.circle_outlined,
                                  color: Colors.white38,
                                  size: 28,
                                ),
                          onTap: () {
                            setState(() {
                              _secilenDil = dilKodu;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _languageService.changeLanguage(_secilenDil);
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _languageService['continue'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
