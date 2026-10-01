import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Zikir/tesbih sayımı için paylaşılan dokunmatik daire: nabız + dalga
/// animasyonu, dairesel ilerleme çizgisi ve ortada sayaç/zikir metni.
///
/// Sayma, hedef-tamamlama ve titreşim mantığı bu widget'ın **dışında**
/// tutulur — widget yalnızca mevcut [sayac]/[hedef] değerlerini gösterir ve
/// dokunulduğunda animasyonu oynatıp [onTap]'i çağırır. Böylece hem
/// [ZikirMatikSayfa] (açık uçlu, tekrar eden turlar) hem de rehberli
/// tesbihat akışı (sabit 33'te otomatik bir sonrakine geçen) aynı görsel
/// bileşeni, kendi sayma mantıklarını widget'a karıştırmadan kullanabilir.
class ZikirSayacCemberi extends StatefulWidget {
  final int sayac;
  final int hedef;
  final String zikirMetni;
  final VoidCallback onTap;
  final Color arkaPlanRengi;
  final Color oncekiArkaPlanRengi;
  final Color vurguRengi;
  final Color yaziSecondaryRengi;
  final double fontScale;
  final double boyut;

  const ZikirSayacCemberi({
    super.key,
    required this.sayac,
    required this.hedef,
    required this.zikirMetni,
    required this.onTap,
    required this.arkaPlanRengi,
    required this.oncekiArkaPlanRengi,
    required this.vurguRengi,
    required this.yaziSecondaryRengi,
    this.fontScale = 1.0,
    this.boyut = 260,
  });

  @override
  State<ZikirSayacCemberi> createState() => _ZikirSayacCemberiState();
}

class _ZikirSayacCemberiState extends State<ZikirSayacCemberi>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _dokunuldu() {
    _pulseController.forward().then((_) => _pulseController.reverse());
    _rippleController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.hedef > 0 ? widget.sayac / widget.hedef : 0.0;
    final cemberBoyutu = widget.boyut;
    final ictBoyut = widget.boyut - 40;

    return GestureDetector(
      onTap: _dokunuldu,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _rippleAnimation]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_rippleAnimation.value > 0)
                Container(
                  width: cemberBoyutu + (_rippleAnimation.value * 60),
                  height: cemberBoyutu + (_rippleAnimation.value * 60),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.vurguRengi.withOpacity(
                        1 - _rippleAnimation.value,
                      ),
                      width: 3,
                    ),
                  ),
                ),
              SizedBox(
                width: cemberBoyutu,
                height: cemberBoyutu,
                child: CustomPaint(
                  painter: _CircleProgressPainter(
                    progress: progress,
                    backgroundColor: widget.oncekiArkaPlanRengi.withOpacity(
                      0.3,
                    ),
                    progressColor: widget.vurguRengi,
                    strokeWidth: 8,
                  ),
                ),
              ),
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: ictBoyut,
                  height: ictBoyut,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.oncekiArkaPlanRengi,
                        widget.arkaPlanRengi,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.vurguRengi.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.sayac}',
                        style: TextStyle(
                          color: widget.vurguRengi,
                          fontSize: 72 * widget.fontScale,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          widget.zikirMetni,
                          style: TextStyle(
                            color: widget.yaziSecondaryRengi,
                            fontSize: 14 * widget.fontScale,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
