import 'package:flutter/material.dart';
import '../services/vibration_service.dart';

class VibrationTestPage extends StatefulWidget {
  const VibrationTestPage({super.key});

  @override
  State<VibrationTestPage> createState() => _VibrationTestPageState();
}

class _VibrationTestPageState extends State<VibrationTestPage> {
  String _sonDurum = 'Test başlamadı';

  Future<void> _testVibration(String type) async {
    setState(() => _sonDurum = 'Test ediliyor: $type');
    
    try {
      switch (type) {
        case 'light':
          await VibrationService.light();
          break;
        case 'medium':
          await VibrationService.medium();
          break;
        case 'heavy':
          await VibrationService.heavy();
          break;
        case 'selection':
          await VibrationService.selection();
          break;
        case 'success':
          await VibrationService.success();
          break;
      }
      setState(() => _sonDurum = '✅ $type titreşimi başarılı');
    } catch (e) {
      setState(() => _sonDurum = '❌ Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Titreşim Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _sonDurum,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Titreşim Testleri:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testVibration('light'),
              child: const Text('Hafif Titreşim (Light)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _testVibration('medium'),
              child: const Text('Orta Titreşim (Medium)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _testVibration('heavy'),
              child: const Text('Güçlü Titreşim (Heavy)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _testVibration('selection'),
              child: const Text('Seçim Titreşimi (Selection)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _testVibration('success'),
              child: const Text('Başarı Titreşimi (Success Pattern)'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Test Adımları:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Her butona basın ve titreşim hissedin'),
            const Text('2. Telefon sessize alınmış olabilir (kontrol edin)'),
            const Text('3. Cihazın titreşim ayarları açık olmalı'),
            const Text('4. Eğer hiçbiri çalışmazsa cihaz sorunu olabilir'),
          ],
        ),
      ),
    );
  }
}
