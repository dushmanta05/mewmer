import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class CatLogoMark extends StatelessWidget {
  final double size;

  const CatLogoMark({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MewmerTheme.cardSurface,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: MewmerTheme.brandViolet.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: MewmerTheme.brandViolet.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _CatEarsAndWhiskersPainter(),
      ),
    );
  }
}

class _CatEarsAndWhiskersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final headPaint = Paint()
      ..color = MewmerTheme.brandViolet
      ..style = PaintingStyle.fill;

    final headPath = Path();
    headPath.moveTo(w * 0.20, h * 0.42);
    headPath.lineTo(w * 0.16, h * 0.18);
    headPath.lineTo(w * 0.40, h * 0.32);
    headPath.quadraticBezierTo(w * 0.50, h * 0.35, w * 0.60, h * 0.32);
    headPath.lineTo(w * 0.84, h * 0.18);
    headPath.lineTo(w * 0.80, h * 0.42);
    headPath.cubicTo(w * 0.90, h * 0.56, w * 0.84, h * 0.78, w * 0.50, h * 0.82);
    headPath.cubicTo(w * 0.16, h * 0.78, w * 0.10, h * 0.56, w * 0.20, h * 0.42);
    headPath.close();

    canvas.drawPath(headPath, headPaint);

    final innerEarPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final leftInnerEar = Path()
      ..moveTo(w * 0.23, h * 0.38)
      ..lineTo(w * 0.22, h * 0.24)
      ..lineTo(w * 0.36, h * 0.34)
      ..close();
    canvas.drawPath(leftInnerEar, innerEarPaint);

    final rightInnerEar = Path()
      ..moveTo(w * 0.77, h * 0.38)
      ..lineTo(w * 0.78, h * 0.24)
      ..lineTo(w * 0.64, h * 0.34)
      ..close();
    canvas.drawPath(rightInnerEar, innerEarPaint);

    final whiskerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.08, h * 0.54), Offset(w * 0.30, h * 0.57), whiskerPaint);
    canvas.drawLine(Offset(w * 0.10, h * 0.65), Offset(w * 0.32, h * 0.63), whiskerPaint);

    canvas.drawLine(Offset(w * 0.92, h * 0.54), Offset(w * 0.70, h * 0.57), whiskerPaint);
    canvas.drawLine(Offset(w * 0.90, h * 0.65), Offset(w * 0.68, h * 0.63), whiskerPaint);

    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.36, h * 0.52), 1.8, eyePaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.52), 1.8, eyePaint);

    final nosePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final nosePath = Path()
      ..moveTo(w * 0.46, h * 0.62)
      ..lineTo(w * 0.54, h * 0.62)
      ..lineTo(w * 0.50, h * 0.67)
      ..close();
    canvas.drawPath(nosePath, nosePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MewmerBrandHeader extends StatelessWidget {
  final double iconSize;
  final double fontSize;

  const MewmerBrandHeader({
    super.key,
    this.iconSize = 34,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CatLogoMark(size: iconSize),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'mew',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: MewmerTheme.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              TextSpan(
                text: 'mer',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: MewmerTheme.brandViolet,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
