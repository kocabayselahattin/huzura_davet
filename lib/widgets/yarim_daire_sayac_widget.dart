import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/diyanet_api_service.dart';
import '../services/konum_service.dart';
import '../services/tema_service.dart';

class YarimDaireSayacWidget extends StatefulWidget {
  const YarimDaireSayacWidget({super.key});

  @override
  State<YarimDaireSayacWidget> createState() => _YarimDaireSayacWidgetState();
}

class _YarimDaireSayacWidgetState extends State<YarimDaireSayacWidget> {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';
  final TemaService _temaService = TemaService();
  
  // API'den gelen vakitler (varsayılan değerler)
  Map<String, String> _vakitSaatleri = {
    'imsak': '05:30',
    'gunes': '07:00',
    'ogle': '12:30',
    'ikindi': '15:45',
    'aksam': '18:15',
    'yatsi': '19:45',
  };

  @override
  void initState() {
    super.initState();
    _vakitleriYukle();
    _hesaplaKalanSure();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hesaplaKalanSure();
    });
    _temaService.addListener(_onTemaChanged);
  }

  void _onTemaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _temaService.removeListener(_onTemaChanged);
    super.dispose();
  }

  Future<void> _vakitleriYukle() async {
    final ilceId = await KonumService.getIlceId();
    if (ilceId != null) {
      final vakitler = await DiyanetApiService.getVakitler(ilceId);
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

  TimeOfDay _parseVakit(String saat) {
    final parts = saat.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  void _hesaplaKalanSure() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';

    final vakitListesi = [
      {'adi': 'İmsak', 'saat': _vakitSaatleri['imsak']!},
      {'adi': 'Güneş', 'saat': _vakitSaatleri['gunes']!},
      {'adi': 'Öğle', 'saat': _vakitSaatleri['ogle']!},
      {'adi': 'İkindi', 'saat': _vakitSaatleri['ikindi']!},
      {'adi': 'Akşam', 'saat': _vakitSaatleri['aksam']!},
      {'adi': 'Yatsı', 'saat': _vakitSaatleri['yatsi']!},
    ];

    for (final vakit in vakitListesi) {
      final time = _parseVakit(vakit['saat']!);
      final vakitMinutes = time.hour * 60 + time.minute;
      
      if (vakitMinutes > nowMinutes) {
        sonrakiVakitZamani = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        sonrakiVakitAdi = vakit['adi']!;
        break;
      }
    }

    // Eğer bugün için vakit kalmadıysa, yarının ilk vakti
    if (sonrakiVakitZamani == null) {
      final yarin = now.add(const Duration(days: 1));
      final imsakTime = _parseVakit(_vakitSaatleri['imsak']!);
      sonrakiVakitZamani = DateTime(
        yarin.year,
        yarin.month,
        yarin.day,
        imsakTime.hour,
        imsakTime.minute,
      );
      sonrakiVakitAdi = 'İmsak';
    }

    setState(() {
      _kalanSure = sonrakiVakitZamani!.difference(now);
      _sonrakiVakit = sonrakiVakitAdi;
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final renkler = _temaService.renkler;
    
    return Card(
      color: renkler.kartArkaPlan,
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: CustomPaint(
          painter: _YarimDairePainter(
            vakitSaatleri: _vakitSaatleri,
            kalanSure: _kalanSure,
            sonrakiVakit: _sonrakiVakit,
            mevcutSaat: DateTime.now(),
            renkler: renkler,
          ),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Vaktin Çıkmasına',
                  style: TextStyle(
                    color: renkler.yaziSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(_kalanSure),
                  style: TextStyle(
                    color: renkler.yaziPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YarimDairePainter extends CustomPainter {
  final Map<String, String> vakitSaatleri;
  final Duration kalanSure;
  final String sonrakiVakit;
  final DateTime mevcutSaat;
  final TemaRenkleri renkler;

  _YarimDairePainter({
    required this.vakitSaatleri,
    required this.kalanSure,
    required this.sonrakiVakit,
    required this.mevcutSaat,
    required this.renkler,
  });

  TimeOfDay _parseVakit(String saat) {
    final parts = saat.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.height - 30;
    final innerRadius = radius * 0.55;

    // Arka plan yarım daire
    final bgPaint = Paint()
      ..color = renkler.yaziPrimary.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      true,
      bgPaint,
    );

    // Vurgu renkli iç daire
    final innerPaint = Paint()
      ..color = renkler.vurgu
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      math.pi,
      math.pi,
      true,
      innerPaint,
    );

    // Vakit dilimleri
    final vakitRenkleri = [
      renkler.arkaPlan.withValues(alpha: 0.7), // İmsak
      renkler.arkaPlan.withValues(alpha: 0.5), // Güneş
      renkler.arkaPlan.withValues(alpha: 0.7), // Öğle
      renkler.arkaPlan.withValues(alpha: 0.6), // İkindi
      renkler.arkaPlan.withValues(alpha: 0.65), // Akşam
      renkler.arkaPlan.withValues(alpha: 0.55), // Yatsı
    ];

    // Vakitleri parse et
    final imsak = _parseVakit(vakitSaatleri['imsak']!);
    final gunes = _parseVakit(vakitSaatleri['gunes']!);
    final ogle = _parseVakit(vakitSaatleri['ogle']!);
    final ikindi = _parseVakit(vakitSaatleri['ikindi']!);
    final aksam = _parseVakit(vakitSaatleri['aksam']!);
    final yatsi = _parseVakit(vakitSaatleri['yatsi']!);

    // Vakit açılarını hesapla - gece yarısından itibaren 24 saati yarım daireye sığdır
    double _saatToOran(int saat, int dakika) {
      double toplamSaat = saat + dakika / 60.0;
      // Gece yarısından (00:00) başlayarak 24 saati yarım daireye (pi) sığdır
      return toplamSaat / 24.0;
    }

    final vakitAcilari = [
      {
        'start': _saatToOran(imsak.hour, imsak.minute),
        'sweep': _saatToOran(gunes.hour, gunes.minute) - _saatToOran(imsak.hour, imsak.minute),
        'label': 'İmsak',
      },
      {
        'start': _saatToOran(gunes.hour, gunes.minute),
        'sweep': _saatToOran(ogle.hour, ogle.minute) - _saatToOran(gunes.hour, gunes.minute),
        'label': 'Güneş',
      },
      {
        'start': _saatToOran(ogle.hour, ogle.minute),
        'sweep': _saatToOran(ikindi.hour, ikindi.minute) - _saatToOran(ogle.hour, ogle.minute),
        'label': 'Öğle',
      },
      {
        'start': _saatToOran(ikindi.hour, ikindi.minute),
        'sweep': _saatToOran(aksam.hour, aksam.minute) - _saatToOran(ikindi.hour, ikindi.minute),
        'label': 'İkindi',
      },
      {
        'start': _saatToOran(aksam.hour, aksam.minute),
        'sweep': _saatToOran(yatsi.hour, yatsi.minute) - _saatToOran(aksam.hour, aksam.minute),
        'label': 'Akşam',
      },
      {
        'start': _saatToOran(yatsi.hour, yatsi.minute),
        'sweep': 1.0 - _saatToOran(yatsi.hour, yatsi.minute) + _saatToOran(imsak.hour, imsak.minute),
        'label': 'Yatsı',
      },
    ];

    for (int i = 0; i < vakitAcilari.length; i++) {
      final vakit = vakitAcilari[i];
      final startAngle = math.pi + (vakit['start'] as double) * math.pi;
      final sweepAngle = (vakit['sweep'] as double) * math.pi;

      final paint = Paint()
        ..color = vakitRenkleri[i]
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(
        center.dx + innerRadius * math.cos(startAngle),
        center.dy + innerRadius * math.sin(startAngle),
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius - 20),
        startAngle,
        sweepAngle,
        false,
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + sweepAngle,
        -sweepAngle,
        false,
      );
      path.close();
      canvas.drawPath(path, paint);

      // Vakit adını yaz
      final midAngle = startAngle + sweepAngle / 2;
      final labelRadius = (radius - 20 + innerRadius) / 2;
      final labelX = center.dx + labelRadius * math.cos(midAngle);
      final labelY = center.dy + labelRadius * math.sin(midAngle);

      canvas.save();
      canvas.translate(labelX, labelY);
      canvas.rotate(midAngle + math.pi / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: vakit['label'] as String,
          style: TextStyle(
            color: renkler.yaziPrimary.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();

      // Çizgi ayırıcı
      final linePaint = Paint()
        ..color = renkler.vurgu
        ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(
          center.dx + innerRadius * math.cos(startAngle),
          center.dy + innerRadius * math.sin(startAngle),
        ),
        Offset(
          center.dx + (radius - 20) * math.cos(startAngle),
          center.dy + (radius - 20) * math.sin(startAngle),
        ),
        linePaint,
      );
    }

    // Saat noktaları (00, 04, 08, 12, 16, 20, 24)
    final saatler = [0, 4, 8, 12, 16, 20, 24];
    for (int i = 0; i <= 6; i++) {
      final angle = math.pi + (i / 6) * math.pi;
      final dotRadius = radius - 8;

      // Nokta
      final dotPaint = Paint()
        ..color = renkler.yaziSecondary
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          center.dx + dotRadius * math.cos(angle),
          center.dy + dotRadius * math.sin(angle),
        ),
        3,
        dotPaint,
      );

      // Saat yazısı
      if (i < 6) {
        final textAngle = math.pi + ((i + 0.5) / 6) * math.pi;
        final textRadius = radius + 5;

        final textPainter = TextPainter(
          text: TextSpan(
            text: saatler[i].toString().padLeft(2, '0'),
            style: TextStyle(
              color: renkler.yaziSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            center.dx +
                textRadius * math.cos(textAngle) -
                textPainter.width / 2,
            center.dy +
                textRadius * math.sin(textAngle) -
                textPainter.height / 2,
          ),
        );
      }
    }

    // Kadran (saat ibresi) - mevcut saate göre
    final hour = mevcutSaat.hour;
    final minute = mevcutSaat.minute;
    final second = mevcutSaat.second;
    
    // Saati 0-24 arasında normalize et ve pi açısına çevir
    double saatOrani = (hour + minute / 60.0 + second / 3600.0) / 24.0;
    final kadranAcisi = math.pi + saatOrani * math.pi;

    // Kadran çizgisi
    final kadranPaint = Paint()
      ..color = renkler.vurgu
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(
        center.dx + (innerRadius - 5) * math.cos(kadranAcisi),
        center.dy + (innerRadius - 5) * math.sin(kadranAcisi),
      ),
      Offset(
        center.dx + (radius - 25) * math.cos(kadranAcisi),
        center.dy + (radius - 25) * math.sin(kadranAcisi),
      ),
      kadranPaint,
    );

    // Kadran ucu (üçgen)
    final arrowLength = 8.0;
    final arrowAngle = 0.3;
    final arrowTip = Offset(
      center.dx + (radius - 18) * math.cos(kadranAcisi),
      center.dy + (radius - 18) * math.sin(kadranAcisi),
    );
    final arrowPath = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(
        arrowTip.dx - arrowLength * math.cos(kadranAcisi - arrowAngle),
        arrowTip.dy - arrowLength * math.sin(kadranAcisi - arrowAngle),
      )
      ..lineTo(
        arrowTip.dx - arrowLength * math.cos(kadranAcisi + arrowAngle),
        arrowTip.dy - arrowLength * math.sin(kadranAcisi + arrowAngle),
      )
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = renkler.vurgu);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
