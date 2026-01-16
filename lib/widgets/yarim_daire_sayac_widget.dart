import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

class YarimDaireSayacWidget extends StatefulWidget {
  const YarimDaireSayacWidget({super.key});

  @override
  State<YarimDaireSayacWidget> createState() => _YarimDaireSayacWidgetState();
}

class _YarimDaireSayacWidgetState extends State<YarimDaireSayacWidget> {
  Timer? _timer;
  Duration _kalanSure = Duration.zero;
  String _sonrakiVakit = '';

  final List<_VakitDilimi> vakitler = [
    _VakitDilimi('Sabah', const TimeOfDay(hour: 6, minute: 12), const TimeOfDay(hour: 7, minute: 45)),
    _VakitDilimi('Güneş', const TimeOfDay(hour: 7, minute: 45), const TimeOfDay(hour: 12, minute: 0)),
    _VakitDilimi('Öğle', const TimeOfDay(hour: 13, minute: 22), const TimeOfDay(hour: 15, minute: 58)),
    _VakitDilimi('İkindi', const TimeOfDay(hour: 15, minute: 58), const TimeOfDay(hour: 18, minute: 25)),
    _VakitDilimi('Akşam', const TimeOfDay(hour: 18, minute: 25), const TimeOfDay(hour: 19, minute: 50)),
    _VakitDilimi('Yatsı', const TimeOfDay(hour: 19, minute: 50), const TimeOfDay(hour: 6, minute: 12)),
  ];

  @override
  void initState() {
    super.initState();
    _hesaplaKalanSure();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _hesaplaKalanSure();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _hesaplaKalanSure() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // Sonraki vakti bul
    DateTime? sonrakiVakitZamani;
    String sonrakiVakitAdi = '';

    final vakitSaatleri = [
      {'adi': 'İmsak', 'saat': 6, 'dakika': 12},
      {'adi': 'Güneş', 'saat': 7, 'dakika': 45},
      {'adi': 'Öğle', 'saat': 13, 'dakika': 22},
      {'adi': 'İkindi', 'saat': 15, 'dakika': 58},
      {'adi': 'Akşam', 'saat': 18, 'dakika': 25},
      {'adi': 'Yatsı', 'saat': 19, 'dakika': 50},
    ];

    for (final vakit in vakitSaatleri) {
      final vakitMinutes = (vakit['saat'] as int) * 60 + (vakit['dakika'] as int);
      if (vakitMinutes > nowMinutes) {
        sonrakiVakitZamani = DateTime(
          now.year,
          now.month,
          now.day,
          vakit['saat'] as int,
          vakit['dakika'] as int,
        );
        sonrakiVakitAdi = vakit['adi'] as String;
        break;
      }
    }

    // Eğer bugün için vakit kalmadıysa, yarının ilk vakti
    if (sonrakiVakitZamani == null) {
      final yarin = now.add(const Duration(days: 1));
      sonrakiVakitZamani = DateTime(
        yarin.year,
        yarin.month,
        yarin.day,
        vakitSaatleri[0]['saat'] as int,
        vakitSaatleri[0]['dakika'] as int,
      );
      sonrakiVakitAdi = vakitSaatleri[0]['adi'] as String;
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
    return Card(
      color: const Color(0xFF1B2741),
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: CustomPaint(
          painter: _YarimDairePainter(
            vakitler: vakitler,
            kalanSure: _kalanSure,
            sonrakiVakit: _sonrakiVakit,
            mevcutSaat: DateTime.now(),
          ),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Vaktin Çıkmasına',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(_kalanSure),
                  style: const TextStyle(
                    color: Colors.white,
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
  final List<_VakitDilimi> vakitler;
  final Duration kalanSure;
  final String sonrakiVakit;
  final DateTime mevcutSaat;

  _YarimDairePainter({
    required this.vakitler,
    required this.kalanSure,
    required this.sonrakiVakit,
    required this.mevcutSaat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.height - 30;
    final innerRadius = radius * 0.55;

    // Beyaz arka plan yarım daire
    final bgPaint = Paint()
      ..color = const Color(0xFFF5F5F5)
      ..style = PaintingStyle.fill;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      true,
      bgPaint,
    );

    // Turkuaz iç daire
    final innerPaint = Paint()
      ..color = const Color(0xFF2D9DA6)
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
      const Color(0xFFB8B8B8), // Sabah - gri
      const Color(0xFFE0E0E0), // Güneş - açık gri
      const Color(0xFFB8B8B8), // Öğle - gri
      const Color(0xFFD0D0D0), // İkindi - orta gri
      const Color(0xFFC0C0C0), // Akşam - gri
      const Color(0xFFE8E8E8), // Yatsı - açık gri
    ];

    final vakitAcilari = [
      {'start': 0.0, 'sweep': 0.12, 'label': 'Sabah'},      // 6-8
      {'start': 0.12, 'sweep': 0.20, 'label': 'Güneş'},     // 8-12
      {'start': 0.32, 'sweep': 0.15, 'label': 'Öğle'},      // 12-15
      {'start': 0.47, 'sweep': 0.12, 'label': 'İkindi'},    // 15-18
      {'start': 0.59, 'sweep': 0.08, 'label': 'Akşam'},     // 18-20
      {'start': 0.67, 'sweep': 0.33, 'label': 'Yatsı'},     // 20-6
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
          style: const TextStyle(
            color: Color(0xFF555555),
            fontSize: 11,
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
        ..color = const Color(0xFF2D9DA6)
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

    // Saat noktaları
    final saatler = [6, 10, 14, 18, 22, 2];
    for (int i = 0; i <= 6; i++) {
      final angle = math.pi + (i / 6) * math.pi;
      final dotRadius = radius - 8;
      
      // Nokta
      final dotPaint = Paint()
        ..color = const Color(0xFF888888)
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
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            center.dx + textRadius * math.cos(textAngle) - textPainter.width / 2,
            center.dy + textRadius * math.sin(textAngle) - textPainter.height / 2,
          ),
        );
      }
    }

    // Kadran (saat ibresi) - mevcut saate göre
    final hour = mevcutSaat.hour;
    final minute = mevcutSaat.minute;
    // 6'dan başlayıp 6'ya kadar (24 saat = pi radyan)
    // Saat 6 = 0, Saat 18 = pi/2, Saat 6 (ertesi gün) = pi
    double saatNormalize = hour + minute / 60.0;
    if (saatNormalize < 6) saatNormalize += 24;
    final saatOrani = (saatNormalize - 6) / 24.0; // 0-1 arası
    final kadranAcisi = math.pi + saatOrani * math.pi;
    
    // Kadran çizgisi
    final kadranPaint = Paint()
      ..color = const Color(0xFF2D9DA6)
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
    canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF2D9DA6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _VakitDilimi {
  final String adi;
  final TimeOfDay baslangic;
  final TimeOfDay bitis;

  _VakitDilimi(this.adi, this.baslangic, this.bitis);
}
