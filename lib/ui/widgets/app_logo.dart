import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Vector application logo (speech bubble containing "jyut")
/// that adapts to both light and dark themes with a transparent background.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = scheme.primary;
    final jyutColor = isDark
        ? const Color(0xFF4FD8C8)
        : const Color(0xFF14B0A2);
    final fontFamily = DefaultTextStyle.of(context).style.fontFamily;

    return Semantics(
      label: 'Cantonese Pronunciation logo',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AppLogoPainter(
            bubbleColor: bubbleColor,
            jyutColor: jyutColor,
            fontFamily: fontFamily,
          ),
        ),
      ),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  const _AppLogoPainter({
    required this.bubbleColor,
    required this.jyutColor,
    this.fontFamily,
  });

  final Color bubbleColor;
  final Color jyutColor;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = math.min(w, h);

    // 1. Speech bubble outline with bottom-left tail.
    final bubblePaint = Paint()
      ..color = bubbleColor
      ..strokeWidth = s * 0.062
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final left = w * 0.04;
    final top = h * 0.04;
    final right = w * 0.96;
    final bottom = h * 0.77;
    final r = s * 0.11;

    final bubble = Path()
      ..moveTo(left + r, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(w * 0.39, bottom)
      ..lineTo(w * 0.21, h * 0.95)
      ..lineTo(w * 0.21, bottom)
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r))
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..close();

    canvas.drawPath(bubble, bubblePaint);

    // 2. "jyut" centered inside the speech bubble body.
    final maxInnerWidth = (right - left) - bubblePaint.strokeWidth * 2.1;
    var fontSize = s * 0.33;
    TextPainter buildTextPainter(double sizePx) {
      return TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: 'jyut',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: sizePx,
            fontWeight: FontWeight.w700,
            color: jyutColor,
            letterSpacing: -0.3,
            height: 1.0,
          ),
        ),
      )..layout();
    }

    var textPainter = buildTextPainter(fontSize);
    if (textPainter.width > maxInnerWidth && textPainter.width > 0) {
      fontSize *= maxInnerWidth / textPainter.width;
      textPainter = buildTextPainter(fontSize);
    }

    final textOffset = Offset(
      (w - textPainter.width) / 2,
      (top + bottom - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) {
    return oldDelegate.bubbleColor != bubbleColor ||
        oldDelegate.jyutColor != jyutColor ||
        oldDelegate.fontFamily != fontFamily;
  }
}
