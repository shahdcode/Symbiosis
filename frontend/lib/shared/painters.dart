import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadialGaugePainter extends CustomPainter {
  RadialGaugePainter({
    required this.progress,
    required this.baseColor,
    required this.fillColor,
  });

  final double progress;
  final Color baseColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final basePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = baseColor;
    final fillPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [fillColor, fillColor.withOpacity(0.5)],
          ).createShader(Rect.fromCircle(center: center, radius: radius));

    const startAngle = -math.pi * 0.8;
    const sweep = math.pi * 1.6;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      basePaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep * progress,
      false,
      fillPaint,
    );

    final dotAngle = startAngle + sweep * progress;
    final dotCenter = Offset(
      center.dx + math.cos(dotAngle) * radius,
      center.dy + math.sin(dotAngle) * radius,
    );
    canvas.drawCircle(dotCenter, 7, Paint()..color = fillColor);
    canvas.drawCircle(dotCenter, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant RadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class SparklinePainter extends CustomPainter {
  SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final fillPaint =
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = (size.width / (values.length - 1)) * i;
      final dy = size.height - (values[i] * size.height);
      points.add(Offset(dx, dy));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlPoint1 = Offset((previous.dx + current.dx) / 2, previous.dy);
      final controlPoint2 = Offset((previous.dx + current.dx) / 2, current.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(point, 2.8, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class UrgencyChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final values = [0.18, 0.24, 0.31, 0.42, 0.39, 0.58, 0.69, 0.84, 0.88];
    final backgroundPaint =
        Paint()
          ..color = const Color(0xFFF3F7F3)
          ..style = PaintingStyle.fill;
    final axisPaint =
        Paint()
          ..color = const Color(0xFFDFE8E0)
          ..strokeWidth = 1;
    final linePaint =
        Paint()
          ..color = const Color(0xFF2F8F5B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final fillPaint =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x662F8F5B), Color(0x002F8F5B)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

    final chartRect = Rect.fromLTWH(10, 8, size.width - 20, size.height - 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(20)),
      backgroundPaint,
    );

    const left = 34.0;
    const right = 18.0;
    const top = 22.0;
    const bottom = 28.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;

    for (var i = 0; i < 4; i++) {
      final y = top + height * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        axisPaint,
      );
    }

    final path = Path();
    final area = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = left + (width / (values.length - 1)) * i;
      final dy = top + height - values[i] * height;
      points.add(Offset(dx, dy));
    }

    path.moveTo(points.first.dx, points.first.dy);
    area.moveTo(points.first.dx, top + height);
    area.lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final c1 = Offset((previous.dx + current.dx) / 2, previous.dy);
      final c2 = Offset((previous.dx + current.dx) / 2, current.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
      area.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
    }
    area.lineTo(points.last.dx, top + height);
    area.close();

    canvas.drawPath(area, fillPaint);
    canvas.drawPath(path, linePaint);

    final highlight = points[points.length - 2];
    canvas.drawCircle(
      highlight,
      8,
      Paint()..color = const Color(0xFF2F8F5B).withOpacity(0.15),
    );
    canvas.drawCircle(highlight, 4.5, Paint()..color = const Color(0xFF2F8F5B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WavePainter extends CustomPainter {
  WavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..style = PaintingStyle.fill;
    final path = Path();
    final waveHeight = size.height * (1 - progress);
    path.moveTo(0, size.height);
    path.lineTo(0, waveHeight);
    for (var i = 0; i <= 12; i++) {
      final x = size.width * i / 12;
      final y =
          waveHeight +
          math.sin((i / 12) * math.pi * 2 + progress * math.pi * 2) * 4;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
