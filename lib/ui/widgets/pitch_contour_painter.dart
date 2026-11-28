import 'package:material_ui/material_ui.dart';

/// Draws Cantonese Chao pitch contour curves (tones 1–6) and checked-stop bars.
class PitchContourPainter extends CustomPainter {
  const PitchContourPainter({
    required this.tone,
    required this.color,
    this.isCheckedTone = false,
    this.guideColor,
    this.strokeWidth = 2.6,
  });

  final int tone;
  final Color color;
  final bool isCheckedTone;
  final Color? guideColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final padX = w * 0.12;
    final padY = h * 0.16;
    final usableW = w - padX * 2;
    final usableH = h - padY * 2;

    double yForLevel(double level) {
      // Chao 1 (lowest) .. 5 (highest).
      final normalized = ((level - 1.0) / 4.0).clamp(0.0, 1.0);
      return padY + (1.0 - normalized) * usableH;
    }

    if (guideColor != null) {
      final guidePaint = Paint()
        ..color = guideColor!
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (final level in const [1.0, 3.0, 5.0]) {
        final y = yForLevel(level);
        canvas.drawLine(Offset(padX, y), Offset(w - padX, y), guidePaint);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (isCheckedTone && (tone == 1 || tone == 3 || tone == 6)) {
      // Short horizontal bar (~40% width) with brief stop tick for -p/-t/-k.
      final level = tone == 1 ? 5.0 : (tone == 3 ? 3.0 : 2.0);
      final y = yForLevel(level);
      final shortW = usableW * 0.42;
      final startX = (w - shortW) * 0.5;
      final endX = startX + shortW;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      canvas.drawLine(
        Offset(endX, y - 3.0),
        Offset(endX, y + 3.0),
        paint..strokeWidth = strokeWidth * 0.85,
      );
      return;
    }

    final path = Path();
    switch (tone) {
      case 1: // 55 High Level
        final y = yForLevel(5.0);
        path.moveTo(padX, y);
        path.lineTo(w - padX, y);
      case 2: // 35 High Rising
        path.moveTo(padX, yForLevel(3.0));
        path.quadraticBezierTo(
          padX + usableW * 0.45,
          yForLevel(2.8),
          w - padX,
          yForLevel(5.0),
        );
      case 3: // 33 Mid Level
        final y = yForLevel(3.0);
        path.moveTo(padX, y);
        path.lineTo(w - padX, y);
      case 4: // 21 Low Falling
        path.moveTo(padX, yForLevel(2.1));
        path.quadraticBezierTo(
          padX + usableW * 0.5,
          yForLevel(1.5),
          w - padX,
          yForLevel(1.0),
        );
      case 5: // 23 Low Rising
        path.moveTo(padX, yForLevel(2.0));
        path.quadraticBezierTo(
          padX + usableW * 0.45,
          yForLevel(2.0),
          w - padX,
          yForLevel(3.0),
        );
      case 6: // 22 Low Level
        final y = yForLevel(2.0);
        path.moveTo(padX, y);
        path.lineTo(w - padX, y);
      default:
        final y = yForLevel(3.0);
        path.moveTo(padX, y);
        path.lineTo(w - padX, y);
    }

    canvas.drawPath(path, paint);
    final endPt = path.computeMetrics().last.getTangentForOffset(
      path.computeMetrics().last.length,
    );
    if (endPt != null) {
      canvas.drawCircle(
        endPt.position,
        strokeWidth * 0.85,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PitchContourPainter oldDelegate) {
    return oldDelegate.tone != tone ||
        oldDelegate.color != color ||
        oldDelegate.isCheckedTone != isCheckedTone ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Sized widget rendering a [PitchContourPainter] curve or checked-stop bar.
class PitchContourBox extends StatelessWidget {
  const PitchContourBox({
    super.key,
    required this.tone,
    this.isCheckedTone = false,
    this.width = 48,
    this.height = 28,
    this.color,
    this.showGuides = true,
  });

  final int tone;
  final bool isCheckedTone;
  final double width;
  final double height;
  final Color? color;
  final bool showGuides;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: PitchContourPainter(
          tone: tone,
          isCheckedTone: isCheckedTone,
          color: color ?? scheme.primary,
          guideColor: showGuides
              ? scheme.outlineVariant.withValues(alpha: 0.45)
              : null,
        ),
      ),
    );
  }
}
