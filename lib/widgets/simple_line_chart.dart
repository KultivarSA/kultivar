import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

import '../theme/app_typography.dart';
import '../utils/analytics_time_series.dart';

class SimpleLineChart extends StatelessWidget {
  final List<SeriesPoint> data;
  final Color color;
  final String label;
  final String suffix;

  const SimpleLineChart({
    super.key,
    required this.data,
    required this.color,
    required this.label,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Text(
        'Not enough data',
        style: AppTypography.bodySmall(context),
      );
    }

    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelLarge(context)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _LinePainter(
              data: data,
              maxY: maxY,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Latest: ${data.last.value.toStringAsFixed(1)}$suffix',
          style: TextStyle(color: color),
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<SeriesPoint> data;
  final double maxY;
  final Color color;

  _LinePainter({
    required this.data,
    required this.maxY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - (data[i].value / maxY) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
