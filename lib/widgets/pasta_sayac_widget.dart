import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

class PastaSayacWidget extends StatelessWidget {
  const PastaSayacWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final mainSegments = <_Segment>[
      _Segment(
        'İmsak',
        const TimeOfDay(hour: 6, minute: 12),
        const TimeOfDay(hour: 7, minute: 45),
        const Color(0xFF7E819A),
      ),
      _Segment(
        'Güneş',
        const TimeOfDay(hour: 7, minute: 45),
        const TimeOfDay(hour: 9, minute: 6),
        const Color(0xFF8A8D9F),
      ),
      _Segment(
        'Kerahat Vakti',
        const TimeOfDay(hour: 9, minute: 6),
        const TimeOfDay(hour: 9, minute: 26),
        const Color(0xFFA1A4B7),
      ),
      _Segment(
        'Duha',
        const TimeOfDay(hour: 9, minute: 26),
        const TimeOfDay(hour: 12, minute: 0),
        const Color(0xFF8A8D9F),
      ),
      _Segment(
        'Kerahat Vakti',
        const TimeOfDay(hour: 12, minute: 0),
        const TimeOfDay(hour: 13, minute: 0),
        const Color(0xFFA1A4B7),
      ),
      _Segment(
        'Öğle',
        const TimeOfDay(hour: 13, minute: 0),
        const TimeOfDay(hour: 15, minute: 58),
        const Color(0xFF7E819A),
      ),
      _Segment(
        'İkindi',
        const TimeOfDay(hour: 15, minute: 58),
        const TimeOfDay(hour: 17, minute: 0),
        const Color(0xFF8A8D9F),
      ),
      _Segment(
        'Kerahat Vakti',
        const TimeOfDay(hour: 17, minute: 0),
        const TimeOfDay(hour: 18, minute: 5),
        const Color(0xFFA1A4B7),
      ),
      _Segment(
        'Akşam',
        const TimeOfDay(hour: 18, minute: 5),
        const TimeOfDay(hour: 19, minute: 0),
        const Color(0xFF8A8D9F),
      ),
      _Segment(
        'Yatsı',
        const TimeOfDay(hour: 19, minute: 0),
        const TimeOfDay(hour: 4, minute: 44),
        const Color(0xFF7B7F96),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ZamanUstBaslik(segments: mainSegments),
          const SizedBox(height: 3),
          const SizedBox(
            height: 18,
            child: CustomPaint(painter: _VakitTickPainter()),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 115,
            child: CustomPaint(
              painter: _VakitCizelgePainter(
                now: now,
                mainSegments: mainSegments,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZamanUstBaslik extends StatefulWidget {
  const _ZamanUstBaslik({required this.segments});

  final List<_Segment> segments;

  @override
  State<_ZamanUstBaslik> createState() => _ZamanUstBaslikState();
}

class _ZamanUstBaslikState extends State<_ZamanUstBaslik> {
  late final ScrollController _controller;
  Timer? _timer;
  DateTime? _lastTick;

  // px / second (keep slow and readable)
  static const double _speed = 30.0;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();

    // Slow continuous marquee (prevents the "it doesn't move" feeling).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) {
        _controller.jumpTo(0);
        _lastTick = DateTime.now();
        _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
          _tick();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _tick() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) return;

    final now = DateTime.now();
    final last = _lastTick ?? now;
    _lastTick = now;

    final dtSeconds = now.difference(last).inMilliseconds / 1000.0;
    final delta = _speed * dtSeconds;
    final next = _controller.offset + delta;

    if (next >= max) {
      _controller.jumpTo(0);
    } else {
      _controller.jumpTo(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121B3A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.06, 0.94, 1.0],
          ).createShader(rect);
        },
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(children: _buildItems()),
        ),
      ),
    );
  }

  List<Widget> _buildItems() {
    final widgets = <Widget>[];
    // Duplicate the list multiple times to create seamless loop
    final repeatedSegments = [
      ...widget.segments,
      ...widget.segments,
      ...widget.segments,
    ];
    for (int i = 0; i < repeatedSegments.length; i++) {
      final seg = repeatedSegments[i];
      final isKerahat = seg.label == 'Kerahat Vakti';
      final isDuha = seg.label == 'Duha';
      final isEvvabin = seg.label == 'Akşam'; // Evvabin aslında Akşam vakti
      
      if (i > 0) {
        widgets.add(const SizedBox(width: 6));
      }
      
      widgets.add(
        _BaslikItem(
          label: seg.label,
          time: _formatTime(seg.start),
          endTime: (isKerahat || isDuha || isEvvabin) ? _formatTime(seg.end) : null,
        ),
      );
    }
    return widgets;
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _BaslikItem extends StatelessWidget {
  const _BaslikItem({required this.label, required this.time, this.endTime});

  final String label;
  final String time;
  final String? endTime;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (endTime != null) ...[
            const SizedBox(height: 2),
            Text(
              endTime!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VakitTickPainter extends CustomPainter {
  const _VakitTickPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final startHour = 6;
    final endHour = 5;
    final totalHours = 24 - startHour + endHour;
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;

    for (int i = 0; i <= totalHours; i++) {
      final x = size.width * (i / totalHours);
      final isMajor = i % 2 == 0;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - (isMajor ? 10 : 6)),
        paint,
      );

      if (isMajor) {
        final hour = (startHour + i) % 24;
        final textPainter = TextPainter(
          text: TextSpan(
            text: hour.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, 0));
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _VakitCizelgePainter extends CustomPainter {
  const _VakitCizelgePainter({required this.now, required this.mainSegments});

  final TimeOfDay now;
  final List<_Segment> mainSegments;

  String _getCurrentVakit() {
    final nowMinutes = now.hour * 60 + now.minute;
    for (final seg in mainSegments) {
      final startMinutes = seg.start.hour * 60 + seg.start.minute;
      var endMinutes = seg.end.hour * 60 + seg.end.minute;
      
      // Gece geçişini ele al
      if (endMinutes < startMinutes) {
        endMinutes += 24 * 60;
      }
      
      var checkNowMinutes = nowMinutes;
      if (nowMinutes < startMinutes && seg.start.hour > 12) {
        checkNowMinutes += 24 * 60;
      }
      
      if (checkNowMinutes >= startMinutes && checkNowMinutes < endMinutes) {
        return seg.label;
      }
    }
    return '';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final startHour = 6;
    final endHour = 5;
    final totalMinutes = (24 - startHour + endHour) * 60;

    double toX(TimeOfDay t) {
      int hour = t.hour;
      if (hour < startHour) {
        hour += 24;
      }
      final minutes = hour * 60 + t.minute - startHour * 60;
      return size.width * (minutes / totalMinutes);
    }

    // Arka bant
    final bgPaint = Paint()..color = const Color(0xFF2B3151);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Ana vakit bantları
    final mainBandTop = 2.0;
    final mainBandHeight = 98.0;
    final gapWidth = 2.0; // Vakitler arası boşluk
    
    for (final seg in mainSegments) {
      final left = toX(seg.start) + gapWidth / 2;
      final right = toX(seg.end) - gapWidth / 2;
      final rect = Rect.fromLTWH(
        left,
        mainBandTop,
        right - left,
        mainBandHeight,
      );
      final paint = Paint()..color = seg.color;
      canvas.drawRect(rect, paint);

      // Yatsı yazısını yatay olarak ortala
      if (seg.label == 'Yatsı') {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'Yatsı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      } else {
        _paintRotatedLabel(
          canvas,
          seg.label,
          rect.center,
          math.pi / 2,
        );
      }
    }

    // Anlık zaman işareti + mevcut vakit adı
    final nowX = toX(now);
    final markerPaint = Paint()
      ..color = const Color(0xFFCC3333)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(nowX, 0),
      Offset(nowX, mainBandTop + mainBandHeight),
      markerPaint,
    );

    // Kırmızı üçgen işaretçi üstte
    final trianglePath = Path()
      ..moveTo(nowX - 6, 0)
      ..lineTo(nowX + 6, 0)
      ..lineTo(nowX, 8)
      ..close();
    canvas.drawPath(trianglePath, markerPaint);

    // Mevcut vakit adı kırmızı çizginin altında
    final currentVakit = _getCurrentVakit();
    if (currentVakit.isNotEmpty) {
      final vakitTextPainter = TextPainter(
        text: TextSpan(
          text: currentVakit,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      // Şeffaf kırmızı kutu
      final boxPadding = 6.0;
      final boxRect = Rect.fromLTWH(
        nowX - vakitTextPainter.width / 2 - boxPadding,
        mainBandTop + mainBandHeight + 3,
        vakitTextPainter.width + boxPadding * 2,
        vakitTextPainter.height + boxPadding,
      );
      final boxPaint = Paint()
        ..color = const Color(0xFFCC3333).withOpacity(0.7)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(4)),
        boxPaint,
      );
      
      vakitTextPainter.paint(
        canvas,
        Offset(
          nowX - vakitTextPainter.width / 2,
          mainBandTop + mainBandHeight + 3 + boxPadding / 2,
        ),
      );
    }

    // Evvabin etiketi
    final evvabinX = toX(const TimeOfDay(hour: 18, minute: 5));
    final evvRect = Rect.fromLTWH(
      evvabinX - 40,
      mainBandTop + mainBandHeight + 3,
      80,
      16,
    );
    final evvBg = Paint()..color = const Color(0xFF3D3F57);
    canvas.drawRect(evvRect, evvBg);
    _paintCenteredLabel(canvas, 'Evvabin', evvRect.center, 10, Colors.white);
  }

  void _paintRotatedLabel(
    Canvas canvas,
    String text,
    Offset center,
    double angle,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  void _paintCenteredLabel(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _Segment {
  _Segment(this.label, this.start, this.end, this.color);

  final String label;
  final TimeOfDay start;
  final TimeOfDay end;
  final Color color;
}
