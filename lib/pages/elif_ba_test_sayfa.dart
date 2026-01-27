import 'package:flutter/material.dart';
import '../services/tema_service.dart';

class ElifBaTestSayfa extends StatefulWidget {
  const ElifBaTestSayfa({super.key});

  @override
  State<ElifBaTestSayfa> createState() => _ElifBaTestSayfaState();
}

class _ElifBaTestSayfaState extends State<ElifBaTestSayfa> {
  final TemaService _temaService = TemaService();
  int _testType = 0; // 0: Harf Tanıma, 1: Hareke, 2: Harf+Tecvit
  int _currentQuestion = 0;
  int _score = 0;
  bool _showResult = false;
  List<Map<String, dynamic>> _questions = [];
  String? _selectedAnswer;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
  }

  void _selectTestType(int type) {
    setState(() {
      _testType = type;
      _generateQuestions();
      _currentQuestion = 0;
      _score = 0;
      _showResult = false;
      _answered = false;
      _selectedAnswer = null;
    });
  }

  void _generateQuestions() {
    _questions.clear();
    
    if (_testType == 0) {
      // Harf Tanıma Testi
      final harfler = [
        {'harf': 'ا', 'ad': 'Elif'},
        {'harf': 'ب', 'ad': 'Be'},
        {'harf': 'ت', 'ad': 'Te'},
        {'harf': 'ث', 'ad': 'Se'},
        {'harf': 'ج', 'ad': 'Cim'},
        {'harf': 'ح', 'ad': 'Ha'},
        {'harf': 'خ', 'ad': 'Hı'},
        {'harf': 'د', 'ad': 'Dal'},
        {'harf': 'ذ', 'ad': 'Zel'},
        {'harf': 'ر', 'ad': 'Ra'},
      ];
      
      for (var i = 0; i < 10; i++) {
        final harf = harfler[i];
        final yanlislar = harfler.where((h) => h['ad'] != harf['ad']).toList()..shuffle();
        final secenekler = [harf['ad'], ...yanlislar.take(3).map((h) => h['ad'])];
        secenekler.shuffle();
        
        _questions.add({
          'soru': 'Bu harfin adı nedir?\n${harf['harf']}',
          'cevap': harf['ad'],
          'secenekler': secenekler,
        });
      }
    } else if (_testType == 1) {
      // Hareke Testi
      final harekeler = [
        {'hareke': 'بَ', 'ad': 'Fetha (be)', 'ses': 'be'},
        {'hareke': 'بِ', 'ad': 'Kesra (bi)', 'ses': 'bi'},
        {'hareke': 'بُ', 'ad': 'Damma (bu)', 'ses': 'bu'},
        {'hareke': 'بْ', 'ad': 'Sükûn (sessiz b)', 'ses': 'b'},
        {'hareke': 'دَ', 'ad': 'Fetha (de)', 'ses': 'de'},
        {'hareke': 'دِ', 'ad': 'Kesra (di)', 'ses': 'di'},
        {'hareke': 'دُ', 'ad': 'Damma (du)', 'ses': 'du'},
        {'hareke': 'تَ', 'ad': 'Fetha (te)', 'ses': 'te'},
        {'hareke': 'تِ', 'ad': 'Kesra (ti)', 'ses': 'ti'},
        {'hareke': 'تُ', 'ad': 'Damma (tu)', 'ses': 'tu'},
      ];
      
      for (var i = 0; i < 10; i++) {
        final hareke = harekeler[i];
        final yanlislar = harekeler.where((h) => h['ad'] != hareke['ad']).toList()..shuffle();
        final secenekler = [hareke['ad'], ...yanlislar.take(3).map((h) => h['ad'])];
        secenekler.shuffle();
        
        _questions.add({
          'soru': 'Bu harf nasıl okunur?\n${hareke['hareke']}',
          'cevap': hareke['ad'],
          'secenekler': secenekler,
        });
      }
    } else {
      // Harf + Tecvit Testi
      final tecvitSorulari = [
        {
          'soru': 'İzhar kuralı hangi harflerle uygulanır?',
          'cevap': 'أ ع غ ح خ ه',
          'secenekler': ['أ ع غ ح خ ه', 'ب م و', 'ي ن ل', 'ق ك'],
        },
        {
          'soru': 'İdğam harfleri hangileridir?',
          'cevap': 'ي ر م ل و ن',
          'secenekler': ['ي ر م ل و ن', 'أ ع غ ح', 'ب ت ث', 'ك ق'],
        },
        {
          'soru': 'İhfa harfi kaç tanedir?',
          'cevap': '15 tane',
          'secenekler': ['15 tane', '6 tane', '4 tane', '10 tane'],
        },
        {
          'soru': 'Med harfleri hangileridir?',
          'cevap': 'ا و ي',
          'secenekler': ['ا و ي', 'ب ت ث', 'ح خ ع', 'د ذ ر'],
        },
        {
          'soru': 'Kalın harfler hangileridir?',
          'cevap': 'خ ص ض غ ط ق ظ',
          'secenekler': ['خ ص ض غ ط ق ظ', 'ب ت ث ج', 'د ذ ر ز', 'س ش ف'],
        },
        {
          'soru': 'Şedde (تشديد) ne demektir?',
          'cevap': 'Harfi iki kere okumak',
          'secenekler': ['Harfi iki kere okumak', 'Harfi uzatmak', 'Harfi gizlemek', 'Harfi sessiz okumak'],
        },
        {
          'soru': 'Tenvin (تنوين) ne demektir?',
          'cevap': 'İsmin sonunda -n sesi',
          'secenekler': ['İsmin sonunda -n sesi', 'Harfi uzatmak', 'İkiz harf', 'Sessiz harf'],
        },
        {
          'soru': 'Günning (غُنَّة) ne demektir?',
          'cevap': 'Burundan gelen ses',
          'secenekler': ['Burundan gelen ses', 'Boğazdan gelen ses', 'Dudaktan gelen ses', 'Dişten gelen ses'],
        },
        {
          'soru': 'Lam-ı Şemsiyye hangi harflerle gelir?',
          'cevap': '14 harf ile gelir',
          'secenekler': ['14 harf ile gelir', '6 harf ile gelir', '10 harf ile gelir', 'Tüm harflerle gelir'],
        },
        {
          'soru': 'Vakf (وَقْف) ne demektir?',
          'cevap': 'Okumayı durdurmak',
          'secenekler': ['Okumayı durdurmak', 'Hızlı okumak', 'Yavaş okumak', 'Sessiz okumak'],
        },
      ];
      
      _questions = tecvitSorulari;
    }
  }

  void _checkAnswer(String answer) {
    if (_answered) return;
    
    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      if (answer == _questions[_currentQuestion]['cevap']) {
        _score++;
      }
    });
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentQuestion < _questions.length - 1) {
        setState(() {
          _currentQuestion++;
          _answered = false;
          _selectedAnswer = null;
        });
      } else {
        setState(() {
          _showResult = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;

    if (_questions.isEmpty) {
      return _buildTestSelection(renkler);
    }

    if (_showResult) {
      return _buildResultScreen(renkler);
    }

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          _testType == 0 ? 'Harf Tanıma Testi' : _testType == 1 ? 'Hareke Testi' : 'Harf + Tecvit Testi',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: renkler.vurgu,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            setState(() {
              _questions.clear();
              _currentQuestion = 0;
              _score = 0;
              _showResult = false;
              _answered = false;
              _selectedAnswer = null;
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // İlerleme çubuğu
            Row(
              children: [
                Text(
                  'Soru ${_currentQuestion + 1}/${_questions.length}',
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Puan: $_score',
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (_currentQuestion + 1) / _questions.length,
              backgroundColor: renkler.kartArkaPlan,
              valueColor: AlwaysStoppedAnimation<Color>(renkler.vurgu),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 30),
            
            // Soru kartı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    renkler.vurgu.withOpacity(0.2),
                    renkler.vurgu.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: renkler.vurgu.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Text(
                _questions[_currentQuestion]['soru'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Seçenekler
            Expanded(
              child: ListView.builder(
                itemCount: _questions[_currentQuestion]['secenekler'].length,
                itemBuilder: (context, index) {
                  final secenek = _questions[_currentQuestion]['secenekler'][index];
                  final isCorrect = secenek == _questions[_currentQuestion]['cevap'];
                  final isSelected = secenek == _selectedAnswer;
                  
                  Color cardColor = renkler.kartArkaPlan;
                  if (_answered) {
                    if (isSelected) {
                      cardColor = isCorrect ? Colors.green : Colors.red;
                    } else if (isCorrect) {
                      cardColor = Colors.green;
                    }
                  }
                  
                  return GestureDetector(
                    onTap: () => _checkAnswer(secenek),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _answered && (isSelected || isCorrect)
                              ? Colors.white
                              : renkler.vurgu.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _answered && (isSelected || isCorrect)
                                ? cardColor.withOpacity(0.5)
                                : Colors.transparent,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _answered && (isSelected || isCorrect)
                                  ? Colors.white.withOpacity(0.3)
                                  : renkler.vurgu.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index),
                                style: TextStyle(
                                  color: _answered && (isSelected || isCorrect)
                                      ? Colors.white
                                      : renkler.yaziPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              secenek,
                              style: TextStyle(
                                color: _answered && (isSelected || isCorrect)
                                    ? Colors.white
                                    : renkler.yaziPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_answered && isCorrect)
                            const Icon(Icons.check_circle, color: Colors.white, size: 28),
                          if (_answered && isSelected && !isCorrect)
                            const Icon(Icons.cancel, color: Colors.white, size: 28),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSelection(TemaRenkleri renkler) {
    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: const Text('Test Seç', style: TextStyle(color: Colors.white)),
        backgroundColor: renkler.vurgu,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTestTypeCard(
              title: 'Harf Tanıma Testi',
              subtitle: '10 soru - Arap harflerini tanıyın',
              icon: Icons.abc,
              color: Colors.blue,
              onTap: () => _selectTestType(0),
            ),
            const SizedBox(height: 16),
            _buildTestTypeCard(
              title: 'Hareke Testi',
              subtitle: '10 soru - Harekeleri öğrenin',
              icon: Icons.edit,
              color: Colors.green,
              onTap: () => _selectTestType(1),
            ),
            const SizedBox(height: 16),
            _buildTestTypeCard(
              title: 'Harf + Tecvit Testi',
              subtitle: '10 soru - Tecvit kuralları',
              icon: Icons.school,
              color: Colors.orange,
              onTap: () => _selectTestType(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen(TemaRenkleri renkler) {
    final percentage = (_score / _questions.length * 100).toInt();
    final isPassed = percentage >= 70;
    
    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isPassed
                        ? [Colors.green, Colors.green.shade300]
                        : [Colors.orange, Colors.orange.shade300],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isPassed ? Colors.green : Colors.orange).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_questions.length}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                isPassed ? 'Tebrikler!' : 'Tekrar Dene!',
                style: TextStyle(
                  color: renkler.yaziPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Başarı Oranı: %$percentage',
                style: TextStyle(
                  color: renkler.yaziSecondary,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _generateQuestions();
                    _currentQuestion = 0;
                    _score = 0;
                    _showResult = false;
                    _answered = false;
                    _selectedAnswer = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: renkler.vurgu,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Tekrar Dene',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _questions.clear();
                  });
                },
                child: Text(
                  'Test Seçimine Dön',
                  style: TextStyle(
                    color: renkler.vurgu,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
