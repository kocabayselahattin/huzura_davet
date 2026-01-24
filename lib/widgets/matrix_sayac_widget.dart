import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

/// Matrix Sayaç - Matrix filmi tarzı düşen kod efektli hacker teması
class MatrixSayacWidget extends StatefulWidget {
  const MatrixSayacWidget({super.key});

  @override
  State<MatrixSayacWidget> createState() => _MatrixSayacWidgetState();
}

class _MatrixSayacWidgetState extends State<MatrixSayacWidget>
    with TickerProviderStateMixin {
  final TemaService _temaService = TemaService();
  final LanguageService _languageService = LanguageService();
  Timer? _timer;
  Timer? _matrixTimer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  double _ilerlemeOrani = 0.0;
  Map<String, String> _vakitSaatleri = {};

  late AnimationController _glowController;
  final List<_MatrixColumn> _columns = [];
  final math.Random _random = math.Random();

  // Matrix karakterleri
  static const String _matrixChars = 'ﺍﺏﺕﺙﺝﺡﺥﺩﺫﺭﺯﺱﺵﺹﺽﻁﻅﻉﻍﻑﻕﻙﻝﻡﻥﻩﻭﻱ0123456789';

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Matrix sütunlarını başlat
    _initMatrixColumns();

    // Matrix animasyonu için timer
    _matrixTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateMatrixColumns();
    });

    _vakitleriYukle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hesaplaKalanSure();
    });
    _temaService.addListener(_onTemaChanged);
    _languageService.addListener(_onTemaChanged);
  }

  void _initMatrixColumns() {
    for (int i = 0; i < 25; i++) {
      _columns.add(_MatrixColumn(
        x: i * 15.0,
        speed: 2 + _random.nextDouble() * 4,
        chars: List.generate(15, (_) => _matrixChars[_random.nextInt(_matrixChars.length)]),
        y: _random.nextDouble() * 300,
      ));
    }
  }

  void _updateMatrixColumns() {
    if (!mounted) return;
    setState(() {
      for (var column in _columns) {
        column.y += column.speed;
        if (column.y > 300) {
          column.y = -50;
          column.speed = 2 + _random.nextDouble() * 4;
          column.chars = List.generate(15, (_) => _matrixChars[_random.nextInt(_matrixChars.length)]);
        }
        // Rastgele karakter değişimi
        if (_random.nextDouble() < 0.1) {
          final idx = _random.nextInt(column.chars.length);
          column.chars[idx] = _matrixChars[_random.nextInt(_matrixChars.length)];
        }
      }
    });
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _matrixTimer?.cancel();
    _glowController.dispose();
    _temaService.removeListener(_onTemaChanged);
    _languageService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId != null) {
      final vakitler = await DiyanetApiService.getBugunVakitler(ilceId);
      if (vakitler != null && mounted) {
        setState(() {
          _vakitSaatleri = {
            'imsak': vakitler['Imsak'] ?? '05:30',
            'gunes': vakitler['Gunes'] ?? '07:00',
            'ogle': vakitler['Ogle'] ?? '12:30',
            'ikindi': vakitler['Ikindi'] ?? '15:45',
            'aksam': vakitler['Aksam'] ?? '18:15',
            'yatsi': vakitler['Yatsi'] ?? '19:45',
          };
        });
        _hesaplaKalanSure();
      }
    }
  }

  void _hesaplaKalanSure() {
    if (_vakitSaatleri.isEmpty) return;

    final now = DateTime.now();
    final nowTotalSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    final vakitListesi = [
      {'adi': _languageService['imsak'] ?? 'İmsak', 'saat': _vakitSaatleri['imsak']!},
      {'adi': _languageService['gunes'] ?? 'Güneş', 'saat': _vakitSaatleri['gunes']!},
      {'adi': _languageService['ogle'] ?? 'Öğle', 'saat': _vakitSaatleri['ogle']!},
      {'adi': _languageService['ikindi'] ?? 'İkindi', 'saat': _vakitSaatleri['ikindi']!},
      {'adi': _languageService['aksam'] ?? 'Akşam', 'saat': _vakitSaatleri['aksam']!},
      {'adi': _languageService['yatsi'] ?? 'Yatsı', 'saat': _vakitSaatleri['yatsi']!},
    ];

    List<int> vakitSaniyeleri = [];
    for (final vakit in vakitListesi) {
      final parts = vakit['saat']!.split(':');
      vakitSaniyeleri.add(int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60);
    }

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';
    double oran = 0.0;

    int sonrakiIndex = -1;
    for (int i = 0; i < vakitSaniyeleri.length; i++) {
      if (vakitSaniyeleri[i] > nowTotalSeconds) {
        sonrakiIndex = i;
        break;
      }
    }

    if (sonrakiIndex == -1) {
      final yarin = now.add(const Duration(days: 1));
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(yarin.year, yarin.month, yarin.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds - yatsiSaniye;
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else if (sonrakiIndex == 0) {
      final imsakParts = _vakitSaatleri['imsak']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(imsakParts[0]), int.parse(imsakParts[1]));
      sonrakiVakitAdi = _languageService['imsak'] ?? 'İmsak';
      final yatsiSaniye = vakitSaniyeleri.last;
      final imsakSaniye = vakitSaniyeleri.first;
      final toplamSure = (24 * 3600 - yatsiSaniye) + imsakSaniye;
      final gecenSure = nowTotalSeconds + (24 * 3600 - yatsiSaniye);
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    } else {
      final parts = vakitListesi[sonrakiIndex]['saat']!.split(':');
      sonrakiVakitZamani = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      sonrakiVakitAdi = vakitListesi[sonrakiIndex]['adi']!;
      final toplamSure = vakitSaniyeleri[sonrakiIndex] - vakitSaniyeleri[sonrakiIndex - 1];
      final gecenSure = nowTotalSeconds - vakitSaniyeleri[sonrakiIndex - 1];
      oran = (gecenSure / toplamSure).clamp(0.0, 1.0);
    }

    if (mounted) {
      setState(() {
        _kalanSure = sonrakiVakitZamani!.difference(now);
        _sonrakiVakit = sonrakiVakitAdi;
        _ilerlemeOrani = oran;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    final hours = _kalanSure.inHours;
    final minutes = _kalanSure.inMinutes % 60;
    final seconds = _kalanSure.inSeconds % 60;

    // Takvim bilgileri
    final now = DateTime.now();
    final miladiTarih = DateFormat('dd.MM.yyyy').format(now);
    final hicri = HijriCalendar.now();
    final hicriTarih = '${hicri.hDay} ${_getHicriAyAdi(hicri.hMonth)} ${hicri.hYear}';

    // Tema renklerini kullan
    final matrixGreen = renkler.vurgu;
    final darkGreen = renkler.vurguSecondary.withOpacity(0.5);
    final bgColor = renkler.arkaPlan;
    final cardBg = renkler.kartArkaPlan;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: bgColor,
        border: Border.all(color: matrixGreen.withOpacity(0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Matrix düşen kodlar
            ...List.generate(_columns.length, (index) {
              final column = _columns[index];
              return Positioned(
                left: column.x,
                top: column.y,
                child: Column(
                  children: List.generate(column.chars.length, (charIndex) {
                    final opacity = 1.0 - (charIndex / column.chars.length);
                    final isHead = charIndex == 0;
                    return Text(
                      column.chars[charIndex],
                      style: TextStyle(
                        color: isHead 
                            ? renkler.yaziPrimary 
                            : matrixGreen.withOpacity(opacity * 0.8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: isHead ? FontWeight.bold : FontWeight.normal,
                        shadows: isHead ? [
                          Shadow(color: matrixGreen, blurRadius: 10),
                        ] : null,
                      ),
                    );
                  }),
                ),
              );
            }),

            // İçerik
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withOpacity(0.7),
                    bgColor.withOpacity(0.5),
                    bgColor.withOpacity(0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst bilgi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '> $_sonrakiVakit',
                            style: TextStyle(
                              color: matrixGreen,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              shadows: [
                                Shadow(color: matrixGreen, blurRadius: 10),
                              ],
                            ),
                          ),
                          Text(
                            '// ${_languageService['time_remaining'] ?? 'Kalan Süre'}',
                            style: TextStyle(
                              color: darkGreen,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      // Terminal ikonu
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: matrixGreen.withOpacity(0.3 + _glowController.value * 0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.terminal,
                              color: matrixGreen,
                              size: 24,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Zaman göstergesi - Terminal stili (yukarı kaydırıldı)
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -10),
                      child: Center(
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: cardBg.withOpacity(0.8),
                              border: Border.all(
                                color: matrixGreen.withOpacity(0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: matrixGreen.withOpacity(0.1 + _glowController.value * 0.1),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'COUNTDOWN.exe',
                                  style: TextStyle(
                                    color: darkGreen,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildDigit(hours.toString().padLeft(2, '0'), matrixGreen),
                                    _buildColon(matrixGreen),
                                    _buildDigit(minutes.toString().padLeft(2, '0'), matrixGreen),
                                    _buildColon(matrixGreen),
                                    _buildDigit(seconds.toString().padLeft(2, '0'), matrixGreen),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // İlerleme çubuğu - ASCII style
                  Row(
                    children: [
                      Text(
                        '[',
                        style: TextStyle(
                          color: matrixGreen,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final filledWidth = constraints.maxWidth * _ilerlemeOrani;
                              final chars = (constraints.maxWidth / 8).floor();
                              final filledChars = (chars * _ilerlemeOrani).floor();
                              
                              return Row(
                                children: List.generate(chars, (index) {
                                  return Text(
                                    index < filledChars ? '█' : '░',
                                    style: TextStyle(
                                      color: index < filledChars 
                                          ? matrixGreen 
                                          : matrixGreen.withOpacity(0.3),
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                      Text(
                        '] ${(_ilerlemeOrani * 100).toInt()}%',
                        style: TextStyle(
                          color: matrixGreen,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Miladi ve Hicri Takvim
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '// ${_languageService['gregorian_date'] ?? 'Miladi'}',
                            style: TextStyle(
                              color: darkGreen,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            miladiTarih,
                            style: TextStyle(
                              color: matrixGreen.withOpacity(0.8),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '// ${_languageService['hijri_date'] ?? 'Hicri'}',
                            style: TextStyle(
                              color: darkGreen,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            hicriTarih,
                            style: TextStyle(
                              color: matrixGreen.withOpacity(0.8),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHicriAyAdi(int ay) {
    const aylar = ['', 'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 
      'Cemaziyelevvel', 'Cemaziyelahir', 'Recep', 'Şaban', 'Ramazan', 
      'Şevval', 'Zilkade', 'Zilhicce'];
    return aylar[ay];
  }

  Widget _buildDigit(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: 42,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        letterSpacing: 2,
        shadows: [
          Shadow(color: color, blurRadius: 15),
          Shadow(color: color.withOpacity(0.5), blurRadius: 30),
        ],
      ),
    );
  }

  Widget _buildColon(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: color.withOpacity(0.7),
          fontSize: 36,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _MatrixColumn {
  double x;
  double y;
  double speed;
  List<String> chars;

  _MatrixColumn({
    required this.x,
    required this.y,
    required this.speed,
    required this.chars,
  });
}
