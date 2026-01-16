import 'package:flutter/material.dart';
import 'dart:math' as math;

class PastaSayacWidget extends StatelessWidget {
  const PastaSayacWidget({super.key});

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final prayerTimes = [
      _parseTime("06:12"), // İmsak
      _parseTime("07:45"), // Güneş
      _parseTime("13:22"), // Öğle
      _parseTime("15:58"), // İkindi
      _parseTime("18:25"), // Akşam
      _parseTime("19:50"), // Yatsı
    ];
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // 1. Yarım Daire Kadran: Vakitlerin (Sabah, Öğle...) Pasta Dilimleri ve Saatler
            SizedBox(
              width: 360,
              height: 210,
              child: CustomPaint(
                painter: PastaDilimiPainter(prayerTimes: prayerTimes, now: now),
              ),
            ),

            // 2. Merkez Panel: Görseldeki turkuaz/yeşil yarım daire alan
            Positioned(
              bottom: 0,
              child: Container(
                width: 200,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(100),
                    topRight: Radius.circular(100),
                  ),
                  color: const Color(0xFF3AAFA9), // Görseldeki turkuaz ton
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text(
                        "Vaktin Çıkmasına",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "03:46:48", // Dinamik sayaç buraya gelecek
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PastaDilimiPainter extends CustomPainter {
  PastaDilimiPainter({required this.prayerTimes, required this.now});

  final List<TimeOfDay> prayerTimes;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height); // Merkez altta
    final radius = size.width / 2 - 55; // Dış saat rakamları için pay bıraktık
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 45; // Dilim kalınlığı

    final segmentCount = prayerTimes.length;
    final segmentAngle = math.pi / segmentCount;
    final angleOffset = _calculateAngleOffset(segmentAngle, segmentCount);

    // --- 0. DIŞ BEYAZ ÇEMBER (ARKA PLAN) ---
    final backgroundPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFF0EDE8); // Açık krem beyaz ton

    // Yarım daire dolgulu arka plan
    final path = Path();
    path.moveTo(center.dx - radius - 30, center.dy);
    path.arcToPoint(
      Offset(center.dx + radius + 30, center.dy),
      radius: Radius.circular(radius + 30),
      clockwise: false,
    );
    path.close();
    canvas.drawPath(path, backgroundPaint);

    // --- 1. VAKİT DİLİMLERİ (SABAH, ÖĞLE, İKİNDİ...) ---
    // Yarım daire şeklinde vakitler (sadece üst yarım)
    // Görseldeki gibi 6 dilim: Sabah, Öğle, İkindi, Akşam, Yatsı, (gece)

    // Dilim 1: Sabah (Koyu Gri)
    paint.color = const Color(0xFF8A8A8A);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi + angleOffset,
      segmentAngle,
      false,
      paint,
    );

    // Dilim 2: Öğle (Orta Gri)
    paint.color = const Color(0xFFA5A5A5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi + segmentAngle + angleOffset,
      segmentAngle,
      false,
      paint,
    );

    // Dilim 3: İkindi (Açık Gri)
    paint.color = const Color(0xFFC0C0C0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi + 2 * segmentAngle + angleOffset,
      segmentAngle,
      false,
      paint,
    );

    // Dilim 4: Akşam (Daha Açık Gri)
    paint.color = const Color(0xFFD5D5D5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi + 3 * segmentAngle + angleOffset,
      segmentAngle,
      false,
      paint,
    );

    // Dilim 5: Yatsı (En Açık Gri)
    paint.color = const Color(0xFFE8E8E8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi + 4 * segmentAngle + angleOffset,
      segmentAngle,
      false,
      paint,
    );

    // Dilim 6: Gece/İmsak (Beyazımsı)
    paint.color = const Color(0xFFF0F0F0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi + 5 * segmentAngle + angleOffset,
      segmentAngle,
      false,
      paint,
    );

    // --- 2. VAKİT AYRAÇLARI (İNCE TURKUAZ ÇİZGİLER) ---
    final separatorPaint = Paint()
      ..color =
          const Color(0xFF3AAFA9) // Turkuaz
      ..strokeWidth = 2;
    for (var i = 0; i <= segmentCount; i++) {
      double angle =
          -math.pi +
          segmentAngle * i +
          angleOffset; // Yarım daire için 0-180 derece
      canvas.drawLine(
        Offset(
          center.dx + (radius - 22) * math.cos(angle),
          center.dy + (radius - 22) * math.sin(angle),
        ),
        Offset(
          center.dx + (radius + 22) * math.cos(angle),
          center.dy + (radius + 22) * math.sin(angle),
        ),
        separatorPaint,
      );
    }

    // --- 2.5. DIŞ NOKTALAR (SAAT İŞARETLERİ) ---
    final dotPaint = Paint()..color = const Color(0xFF4A5568);
    // Noktalar (12 adet)
    for (var i = 0; i <= 12; i++) {
      double angle = -math.pi + (math.pi / 12) * i + angleOffset;
      double x = center.dx + (radius + 38) * math.cos(angle);
      double y = center.dy + (radius + 38) * math.sin(angle);

      // Her 2. nokta büyük (ana saat noktaları)
      double dotRadius = (i % 2 == 0) ? 3.5 : 2.0;
      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
    }

    // --- 3. DIŞ SAAT RAKAMLARI ---
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final saatler = ["06", "10", "14", "18", "22", "02"];

    for (int i = 0; i < saatler.length; i++) {
      double angle = -math.pi + segmentAngle * i + angleOffset;
      double x = center.dx + (radius + 52) * math.cos(angle);
      double y = center.dy + (radius + 52) * math.sin(angle);

      textPainter.text = TextSpan(
        text: saatler[i],
        style: const TextStyle(
          color: Color(0xFF2F3E4E), // Daha koyu ve belirgin
          fontSize: 20,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // --- 4. VAKİT İSİMLERİ (Sabah, Öğle, İkindi, Akşam, Yatsı) ---
    final vakitler = [
      {"isim": "İmsak", "index": 0},
      {"isim": "Güneş", "index": 1},
      {"isim": "Öğle", "index": 2},
      {"isim": "İkindi", "index": 3},
      {"isim": "Akşam", "index": 4},
      {"isim": "Yatsı", "index": 5},
    ];

    for (var vakit in vakitler) {
      int index = vakit["index"] as int;
      // Dilimin ortasına yaz
      double angle =
          -math.pi + segmentAngle * index + (segmentAngle / 2) + angleOffset;
      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);

      // Yazıyı daire boyunca döndür (radyal)
      // Sol taraftakiler (index 0,1,2) için farklı döndürme
      double rotation;
      if (index <= 2) {
        rotation = angle + math.pi / 2; // Sol taraf - aşağıdan yukarı okuma
      } else {
        rotation = angle - math.pi / 2; // Sağ taraf - yukarıdan aşağı okuma
      }
      canvas.rotate(rotation);

      textPainter.text = TextSpan(
        text: vakit["isim"] as String,
        style: const TextStyle(
          color: Color(0xFF4A5568), // Koyu gri
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // --- 5. GÜNCEL ZAMAN ÇİZGİSİ (TURKUAZ İBRE) ---
    // (Opsiyonel - şu an vakit ayraçları zaten turkuaz)
  }

  double _calculateAngleOffset(double segmentAngle, int segmentCount) {
    if (prayerTimes.isEmpty) {
      return 0;
    }

    final nowMinutes = now.hour * 60 + now.minute;
    final timeMinutes = prayerTimes
        .map((t) => t.hour * 60 + t.minute)
        .toList(growable: false);

    int activeIndex = 0;
    for (int i = 0; i < segmentCount; i++) {
      final start = timeMinutes[i];
      final end = timeMinutes[(i + 1) % segmentCount];
      if (i == segmentCount - 1) {
        if (nowMinutes >= start || nowMinutes < end) {
          activeIndex = i;
          break;
        }
      } else if (nowMinutes >= start && nowMinutes < end) {
        activeIndex = i;
        break;
      }
    }

    final activeMidAngle = -math.pi + (activeIndex + 0.5) * segmentAngle;
    final desiredAngle = -math.pi / 2;
    return desiredAngle - activeMidAngle;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
