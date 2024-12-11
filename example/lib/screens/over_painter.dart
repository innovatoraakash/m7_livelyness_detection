import 'dart:developer';

import 'package:flutter/material.dart';

class OvalFramePainter extends CustomPainter {
  final double progress;

  OvalFramePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.7);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final roundedRect = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.5,
        height: size.height * 0.5,
      ),
      topLeft: const Radius.circular(120),
      topRight: const Radius.circular(120),
      bottomLeft: const Radius.circular(120),
      bottomRight: const Radius.circular(120),
    );

    final roundedRectDotted = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.5 + 6,
        height: size.height * 0.5 + 6,
      ),
      topLeft: const Radius.circular(120),
      topRight: const Radius.circular(120),
      bottomLeft: const Radius.circular(120),
      bottomRight: const Radius.circular(120),
    );

    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addRRect(roundedRect),
    );

    canvas.drawPath(path, paint);

    drawDashedProgressPath(
      canvas,
      Path()..addRRect(roundedRectDotted),
      progress,
      dashWidth: 6,
      dashGap: 4,
    );
  }

  void drawDashedProgressPath(
    Canvas canvas,
    Path path,
    double progress, {
    required double dashWidth,
    required double dashGap,
  }) {
    final pathMetrics = path.computeMetrics();
    final totalLength =
        path.computeMetrics().fold(0.0, (sum, metric) => sum + metric.length);

    final activeLength = progress * totalLength;
    double currentLength = 0;

    for (final pathMetric in pathMetrics) {
      final pathLength = pathMetric.length;
      log(pathLength.toString());
      while (currentLength < pathLength) {
        final start = currentLength;
        final end = (currentLength + dashWidth).clamp(0, pathLength).toDouble();

        final isActive = start < activeLength;
        final color = isActive ? Colors.green : Colors.red;

        final borderPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        final segmentPath = pathMetric.extractPath(start, end);
        canvas.drawPath(segmentPath, borderPaint);

        currentLength += dashWidth + dashGap;
      }

      // Adjust for starting point (top-center)
      currentLength %= totalLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
