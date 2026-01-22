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

  final Map<String, Map<String, String>> _diller = {
    'tr': {'isim': 'Türkçe', 'bayrak': '🇹🇷'},
    'en': {'isim': 'English', 'bayrak': '🇬🇧'},
    'de': {'isim': 'Deutsch', 'bayrak': '🇩🇪'},
    'fr': {'isim': 'Français', 'bayrak': '🇫🇷'},
    'ar': {'isim': 'العربية', 'bayrak': '🇸🇦'},
    'fa': {'isim': 'فارسی', 'bayrak': '🇮🇷'},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Başlık
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.language,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Dil Seçimi / Choose Language',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lütfen uygulama dilini seçin\nPlease select app language',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Dil listesi
              Expanded(
                child: ListView.builder(
                  itemCount: _diller.length,
                  itemBuilder: (context, index) {
                    final dilKodu = _diller.keys.elementAt(index);
                    final dil = _diller[dilKodu]!;
                    final secili = _secilenDil == dilKodu;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: secili ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: secili
                              ? Theme.of(context).colorScheme.primary
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
                          dil['bayrak']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        title: Text(
                          dil['isim']!,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                            color: secili
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        trailing: secili
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: Colors.grey,
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
              
              // Devam et butonu
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
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
                        _secilenDil == 'tr'
                            ? 'Devam Et'
                            : _secilenDil == 'en'
                                ? 'Continue'
                                : _secilenDil == 'de'
                                    ? 'Weiter'
                                    : 'Continuer',
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
    );
  }
}
