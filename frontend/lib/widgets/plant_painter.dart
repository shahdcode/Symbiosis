import 'package:flutter/material.dart';
import '../models/plant_model.dart';

class PlantPainter extends CustomPainter {
  final PlantSvgType type;
  final Color color;

  PlantPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 80;
    canvas.scale(s, s);

    switch (type) {
      case PlantSvgType.monstera:
        _drawMonstera(canvas);
        break;
      case PlantSvgType.calathea:
        _drawCalathea(canvas);
        break;
      case PlantSvgType.ficus:
        _drawFicus(canvas);
        break;
      case PlantSvgType.lily:
        _drawLily(canvas);
        break;
      case PlantSvgType.pothos:
        _drawPothos(canvas);
        break;
      case PlantSvgType.snake:
        _drawSnake(canvas);
        break;
      case PlantSvgType.zz:
        _drawZZ(canvas);
        break;
      case PlantSvgType.bird:
        _drawBird(canvas);
        break;
      case PlantSvgType.rubber:
        _drawRubber(canvas);
        break;
      case PlantSvgType.alocasia:
        _drawAlocasia(canvas);
        break;
    }
  }

  Paint _fill(Color c, {double opacity = 1.0}) =>
      Paint()..color = c.withOpacity(opacity)..style = PaintingStyle.fill;

  Paint _stroke(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  Color get _light => const Color(0xFFA8D5A2);
  Color get _dark => Color.lerp(color, Colors.black, 0.35)!;
  Color get _stem => const Color(0xFF5C8A3C);
  Color get _potL => const Color(0xFFC8A882);
  Color get _potD => const Color(0xFFB89060);

  void _drawPot(Canvas canvas) {
    final rr = RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 62, 16, 10), const Radius.circular(4));
    canvas.drawRRect(rr, _fill(_potL));
    final rr2 = RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 68, 20, 6), const Radius.circular(3));
    canvas.drawRRect(rr2, _fill(_potD));
  }

  void _drawShadow(Canvas canvas) {
    canvas.drawOval(const Rect.fromLTWH(26, 67, 28, 10),
        _fill(Colors.black.withOpacity(0.08)));
  }

  void _drawStem(Canvas canvas,
      {double x = 37, double y = 40, double w = 6, double h = 28, double r = 3}) {
    final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), Radius.circular(r));
    canvas.drawRRect(rr, _fill(_stem));
  }

  void _drawMonstera(Canvas canvas) {
    _drawShadow(canvas);
    _drawStem(canvas);

    final leaf = Path()
      ..moveTo(40, 42)
      ..cubicTo(28, 35, 18, 25, 22, 12)
      ..cubicTo(26, 0, 38, 5, 40, 20)
      ..cubicTo(42, 5, 54, 0, 58, 12)
      ..cubicTo(62, 25, 52, 35, 40, 42)
      ..close();
    canvas.drawPath(leaf, _fill(color));

    canvas.drawLine(const Offset(32, 28), const Offset(28, 24),
        _stroke(_dark, 1.5));
    canvas.drawLine(const Offset(48, 28), const Offset(52, 24),
        _stroke(_dark, 1.5));
    canvas.drawCircle(
        const Offset(30, 26), 2, _fill(_dark.withOpacity(0.4)));
    canvas.drawCircle(
        const Offset(50, 26), 2, _fill(_dark.withOpacity(0.4)));
    canvas.drawCircle(
        const Offset(38, 18), 2.5, _fill(_dark.withOpacity(0.3)));

    _drawPot(canvas);
  }

  void _drawCalathea(Canvas canvas) {
    _drawShadow(canvas);
    _drawStem(canvas, x: 38, y: 50, w: 4, h: 18, r: 2);

    canvas.save();
    canvas.translate(28, 38);
    canvas.rotate(-0.35);
    canvas.drawOval(const Rect.fromLTWH(-16, -10, 32, 20), _fill(color));
    canvas.restore();

    canvas.save();
    canvas.translate(52, 35);
    canvas.rotate(0.26);
    canvas.drawOval(const Rect.fromLTWH(-14, -9, 28, 18), _fill(color));
    canvas.restore();

    canvas.save();
    canvas.translate(38, 28);
    canvas.rotate(-0.09);
    canvas.drawOval(
        const Rect.fromLTWH(-12, -8, 24, 16), _fill(color));
    canvas.restore();

    _drawPot(canvas);
  }

  void _drawFicus(Canvas canvas) {
    _drawShadow(canvas);
    _drawStem(canvas, x: 38, y: 30, w: 4, h: 38, r: 2);

    final leaf1 = Path()
      ..moveTo(40, 32)
      ..cubicTo(35, 25, 28, 18, 30, 10)
      ..cubicTo(32, 4, 38, 6, 40, 14)
      ..close();
    canvas.drawPath(leaf1, _fill(color));

    final leaf2 = Path()
      ..moveTo(40, 32)
      ..cubicTo(45, 25, 52, 18, 50, 10)
      ..cubicTo(48, 4, 42, 6, 40, 14)
      ..close();
    canvas.drawPath(leaf2, _fill(color.withOpacity(0.85)));

    final leaf3 = Path()
      ..moveTo(40, 42)
      ..cubicTo(33, 35, 24, 30, 26, 20)
      ..close();
    canvas.drawPath(leaf3, _fill(color));

    final leaf4 = Path()
      ..moveTo(40, 42)
      ..cubicTo(47, 35, 56, 30, 54, 20)
      ..close();
    canvas.drawPath(leaf4, _fill(color.withOpacity(0.85)));

    _drawPot(canvas);
  }

  void _drawLily(Canvas canvas) {
    _drawShadow(canvas);
    _drawStem(canvas, x: 38, y: 40, w: 4, h: 28, r: 2);

    final leaf = Path()
      ..moveTo(40, 42)
      ..cubicTo(30, 38, 22, 30, 24, 18)
      ..cubicTo(26, 8, 36, 10, 40, 22)
      ..cubicTo(44, 10, 54, 8, 56, 18)
      ..cubicTo(58, 30, 50, 38, 40, 42)
      ..close();
    canvas.drawPath(leaf, _fill(color));

    canvas.drawOval(
        const Rect.fromLTWH(35, 16, 10, 24),
        _fill(Colors.white.withOpacity(0.6)));

    final tip = Path()
      ..moveTo(40, 20)
      ..cubicTo(38, 16, 36, 12, 40, 8)
      ..cubicTo(44, 12, 42, 16, 40, 20)
      ..close();
    canvas.drawPath(tip, _fill(Colors.white.withOpacity(0.8)));

    _drawPot(canvas);
  }

  void _drawPothos(Canvas canvas) {
    _drawShadow(canvas);

    final left = Path()
      ..moveTo(40, 55)
      ..cubicTo(35, 45, 25, 38, 20, 28)
      ..cubicTo(16, 20, 22, 12, 28, 18)
      ..cubicTo(32, 22, 36, 32, 40, 40)
      ..close();
    canvas.drawPath(left, _fill(color));

    final right = Path()
      ..moveTo(40, 55)
      ..cubicTo(45, 45, 55, 38, 60, 28)
      ..cubicTo(64, 20, 58, 12, 52, 18)
      ..cubicTo(48, 22, 44, 32, 40, 40)
      ..close();
    canvas.drawPath(right, _fill(color.withOpacity(0.8)));

    final rr = RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 62, 14, 10), const Radius.circular(3));
    canvas.drawRRect(rr, _fill(_potL));
  }

  void _drawSnake(Canvas canvas) {
    _drawShadow(canvas);

    for (var i = 0; i < 3; i++) {
      final x = 28.0 + i * 10;
      final w = 8.0 - i * 1.0;
      final h = 42.0 - i * 5;
      final y = 25.0 + i * 5;
      final op = 1.0 - i * 0.2;
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(4));
      canvas.drawRRect(rr, _fill(color.withOpacity(op)));
      canvas.drawLine(Offset(x, y + 14), Offset(x + w, y + 14),
          _stroke(_light.withOpacity(0.5), 1.5));
    }

    final rr = RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 64, 20, 8), const Radius.circular(3));
    canvas.drawRRect(rr, _fill(_potL));
  }

  void _drawZZ(Canvas canvas) {
    _drawShadow(canvas);

    final left = Path()
      ..moveTo(40, 60)
      ..cubicTo(36, 50, 30, 40, 28, 30)
      ..cubicTo(26, 22, 30, 16, 34, 22)
      ..cubicTo(36, 26, 38, 36, 40, 44)
      ..close();
    canvas.drawPath(left, _fill(color));

    final right = Path()
      ..moveTo(40, 60)
      ..cubicTo(44, 50, 50, 40, 52, 30)
      ..cubicTo(54, 22, 50, 16, 46, 22)
      ..cubicTo(44, 26, 42, 36, 40, 44)
      ..close();
    canvas.drawPath(right, _fill(color.withOpacity(0.8)));

    for (final offset in [
      const Offset(34, 28),
      const Offset(30, 36),
    ]) {
      canvas.drawCircle(offset, 4, _fill(color));
    }
    for (final offset in [
      const Offset(46, 28),
      const Offset(50, 36),
    ]) {
      canvas.drawCircle(offset, 3.5, _fill(color.withOpacity(0.8)));
    }

    final rr = RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 62, 14, 10), const Radius.circular(3));
    canvas.drawRRect(rr, _fill(_potL));
  }

  void _drawBird(Canvas canvas) {
    _drawShadow(canvas);
    _drawStem(canvas, x: 38, y: 35, w: 4, h: 32, r: 2);

    final green = Path()
      ..moveTo(40, 38)
      ..cubicTo(32, 30, 22, 22, 26, 12)
      ..cubicTo(30, 4, 40, 8, 40, 22)
      ..close();
    canvas.drawPath(green, _fill(color));

    final orange = Path()
      ..moveTo(40, 38)
      ..cubicTo(48, 30, 58, 22, 54, 12)
      ..cubicTo(50, 4, 40, 8, 40, 22)
      ..close();
    canvas.drawPath(orange, _fill(const Color(0xFFF4A261).withOpacity(0.9)));

    _drawPot(canvas);
  }

  void _drawRubber(Canvas canvas) {
    _drawShadow(canvas);
    _drawStem(canvas, x: 38, y: 30, w: 4, h: 38, r: 2);

    canvas.drawOval(const Rect.fromLTWH(28, 13, 24, 18), _fill(color));
    canvas.drawOval(const Rect.fromLTWH(22, 26, 22, 16), _fill(color.withOpacity(0.9)));
    canvas.drawOval(const Rect.fromLTWH(37, 31, 20, 14), _fill(color.withOpacity(0.8)));

    _drawPot(canvas);
  }

  void _drawAlocasia(Canvas canvas) {
    _drawShadow(canvas);
    _drawStem(canvas, x: 38, y: 42, w: 4, h: 26, r: 2);

    final left = Path()
      ..moveTo(40, 44)
      ..cubicTo(28, 36, 18, 20, 26, 10)
      ..cubicTo(32, 4, 42, 12, 40, 30)
      ..close();
    canvas.drawPath(left, _fill(color));

    final right = Path()
      ..moveTo(40, 44)
      ..cubicTo(52, 36, 62, 20, 54, 10)
      ..cubicTo(48, 4, 38, 12, 40, 30)
      ..close();
    canvas.drawPath(right, _fill(color.withOpacity(0.75)));

    final vein = Path()
      ..moveTo(34, 28)
      ..lineTo(40, 44)
      ..lineTo(46, 28);
    canvas.drawPath(vein, _stroke(_light.withOpacity(0.6), 1.5));

    _drawPot(canvas);
  }

  @override
  bool shouldRepaint(PlantPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

class PlantWidget extends StatefulWidget {
  final PlantSvgType type;
  final Color color;
  final double size;
  final bool animate;

  const PlantWidget({
    super.key,
    required this.type,
    required this.color,
    this.size = 80,
    this.animate = true,
  });

  @override
  State<PlantWidget> createState() => _PlantWidgetState();
}

class _PlantWidgetState extends State<PlantWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: PlantPainter(type: widget.type, color: widget.color),
      );
    }
    return AnimatedBuilder(
      animation: _float,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _float.value),
        child: child,
      ),
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: PlantPainter(type: widget.type, color: widget.color),
      ),
    );
  }
}
