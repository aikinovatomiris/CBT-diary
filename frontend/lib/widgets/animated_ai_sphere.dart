// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radius.dart';

class AnimatedAISphere extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final double? size;

  const AnimatedAISphere({
    super.key,
    required this.onTap,
    required this.isLoading,
    this.size,
  });

  @override
  State<AnimatedAISphere> createState() => _AnimatedAISphereState();
}

class _AnimatedAISphereState extends State<AnimatedAISphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // repeat() бесшовен, если все анимированные значения построены
    // только на sin(k*t) / cos(k*t) с целым k.
    // При progress==0.0 и progress==1.0 t==0 и t==2π — визуально одно и то же.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _resolveSize(BuildContext context) {
    if (widget.size != null) return widget.size!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(math.max(screenWidth * 0.80, 290), 350);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = _resolveSize(context);

    return Center(
      child: Semantics(
        button: true,
        label: widget.isLoading ? 'Создаю сессию' : 'КПТ-сессия — начать',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.isLoading ? null : widget.onTap,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(size),
                        painter: _AISpherePainter(
                          progress: _controller.value,
                          isDark: isDark,
                          backgroundColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                      widget.isLoading
                          ? _LoadingLabel(isDark: isDark)
                          : _StartLabel(isDark: isDark),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StartLabel extends StatelessWidget {
  final bool isDark;

  const _StartLabel({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'КПТ-сессия',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 21,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(isDark ? 0.58 : 0.40),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              Shadow(
                color: AppColors.blue.withOpacity(isDark ? 0.42 : 0.34),
                blurRadius: 22,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: AppRadius.medium,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isDark ? 0.16 : 0.20),
                borderRadius: AppRadius.medium,
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.16 : 0.22),
                  width: 1,
                ),
              ),
              child: Text(
                'начать',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.white,
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.25,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(isDark ? 0.44 : 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingLabel extends StatelessWidget {
  final bool isDark;

  const _LoadingLabel({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.white,
            ),
            backgroundColor: Colors.white.withOpacity(0.18),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Создаю...',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 20,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(isDark ? 0.58 : 0.40),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              Shadow(
                color: AppColors.blue.withOpacity(isDark ? 0.42 : 0.34),
                blurRadius: 22,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Радиус в каждой точке угла [angle]:
///   r(θ) = baseR
///        + a1 * sin(1*θ + φ1)   ← первая мода (вытянутый эллипс, вращается)
///        + a2 * sin(2*θ + φ2)   ← вторая мода (4 волны)
///        + a3 * sin(3*θ + φ3)   ← третья мода (6 волн)
///
/// Все фазовые сдвиги φk = k * t — целочисленные гармоники от t,
/// поэтому при t=0 и t=2π значения совпадают → стыка нет.
Path _buildMorphPath(Offset center, double baseR, double t,
    {int steps = 180}) {
  // Амплитуды: достаточно заметны, но шар остаётся «шаром».
  const a1 = 0.028; // ±2.8% — медленное вращение формы
  const a2 = 0.018; // ±1.8% — мягкие «волны» по контуру
  const a3 = 0.010; // ±1.0% — тонкая рябь

  final path = Path();
  for (int i = 0; i <= steps; i++) {
    final angle = (i / steps) * math.pi * 2;

    // Фазы — целые кратные t: φ1=t, φ2=2t, φ3=3t.
    final r = baseR *
        (1.0 +
            a1 * math.sin(1 * angle + t) +
            a2 * math.sin(2 * angle + 2 * t) +
            a3 * math.sin(3 * angle + 3 * t));

    final dx = center.dx + r * math.cos(angle);
    final dy = center.dy + r * math.sin(angle);

    if (i == 0) {
      path.moveTo(dx, dy);
    } else {
      path.lineTo(dx, dy);
    }
  }
  path.close();
  return path;
}

class _AISpherePainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color backgroundColor;

  const _AISpherePainter({
    required this.progress,
    required this.isDark,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // t — полный угол за цикл. Все тригонометрические функции ниже
    // принимают только целые кратные t, поэтому f(0) == f(2π) всегда.
    final t = progress * math.pi * 2;

    final s1 = math.sin(t);       // k=1
    final c1 = math.cos(t);       // k=1
    final s2 = math.sin(2 * t);   // k=2
    final c2 = math.cos(2 * t);   // k=2
    final s3 = math.sin(3 * t);   // k=3

    // Пульсы — плавные значения [0..1], бесшовные.
    final pulse  = 0.5 + 0.5 * s1;   // медленный
    final pulse2 = 0.5 + 0.5 * c2;   // быстрый, фаза сдвинута
    final pulse3 = 0.5 + 0.5 * s3;   // самый быстрый

    // Шар плавно растёт/сжимается ±3% с периодом одного цикла.
    // sin(t) при t=0 и t=2π равен 0 → стыка нет.
    final sphereRadius = radius * (0.865 + 0.026 * s1);

    final morphPath = _buildMorphPath(center, sphereRadius, t);

    final sphereRect = Rect.fromCircle(center: center, radius: sphereRadius);
    final auraRadius = radius * (1.05 + pulse * 0.06);
    canvas.drawCircle(
      center,
      auraRadius * 0.96,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7AE7FF).withOpacity(isDark ? 0.28 : 0.38),
            const Color(0xFF3B82F6).withOpacity(isDark ? 0.22 : 0.28),
            const Color(0xFF7C3AED).withOpacity(isDark ? 0.18 : 0.22),
            const Color(0xFF1E1B4B).withOpacity(isDark ? 0.10 : 0.0),
            Colors.transparent,
          ],
          stops: const [0.0, 0.30, 0.55, 0.80, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: auraRadius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );
    canvas.save();
    canvas.clipPath(morphPath);
    canvas.drawCircle(
      center,
      sphereRadius * 1.02, // чуть больше, чтобы не было зазора при морфинге
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.36 + s1 * 0.06, -0.44 + c1 * 0.06),
          radius: 1.18,
          colors: isDark
              ? [
                  const Color(0xFFBAF5FF).withOpacity(0.70),
                  const Color(0xFF4FB8FF).withOpacity(0.72),
                  const Color(0xFF2244DD).withOpacity(0.68),
                  const Color(0xFF0D1550).withOpacity(0.88),
                  backgroundColor.withOpacity(0.60),
                ]
              : [
                  const Color(0xFFE8FDFF).withOpacity(0.96),
                  const Color(0xFF96EEFF).withOpacity(0.92),
                  const Color(0xFF4BB8FF).withOpacity(0.84),
                  const Color(0xFF3355FF).withOpacity(0.68),
                  backgroundColor.withOpacity(0.24),
                ],
          stops: const [0.0, 0.18, 0.42, 0.70, 1.0],
        ).createShader(sphereRect),
    );

    canvas.drawCircle(
      center,
      sphereRadius * 1.02,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.44 + c1 * 0.06, 0.54 + s1 * 0.05),
          radius: 0.94,
          colors: [
            Colors.transparent,
            const Color(0xFF1E3A8A).withOpacity(isDark ? 0.22 : 0.10),
            Colors.black.withOpacity(isDark ? 0.52 : 0.18),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(sphereRect),
    );

    final bandCenter = Offset(
      center.dx + s1 * radius * 0.12,
      center.dy + radius * 0.06 + c2 * radius * 0.055,
    );
    final bandRect = Rect.fromCenter(
      center: bandCenter,
      width: radius * (2.32 + pulse2 * 0.22),
      height: radius * (0.82 + pulse * 0.20),
    );
    final bandPath = Path()
      ..moveTo(bandRect.left - radius * 0.22, bandCenter.dy - radius * 0.04)
      ..cubicTo(
        bandRect.left + bandRect.width * 0.12,
        bandRect.top - radius * (0.34 + pulse * 0.12),
        bandRect.left + bandRect.width * 0.32,
        bandRect.bottom + radius * (0.30 + pulse2 * 0.12),
        bandRect.left + bandRect.width * 0.52,
        bandCenter.dy - radius * (0.03 + s2 * 0.03),
      )
      ..cubicTo(
        bandRect.left + bandRect.width * 0.70,
        bandRect.top - radius * (0.30 + pulse2 * 0.12),
        bandRect.right - bandRect.width * 0.08,
        bandRect.bottom + radius * (0.22 + pulse * 0.10),
        bandRect.right + radius * 0.22,
        bandCenter.dy - radius * 0.06,
      )
      ..lineTo(bandRect.right + radius * 0.22, bandRect.bottom + radius * 0.12)
      ..cubicTo(
        bandRect.right - bandRect.width * 0.16,
        bandRect.bottom + radius * (0.30 + pulse * 0.10),
        bandRect.left + bandRect.width * 0.64,
        bandRect.top + radius * (0.26 + pulse2 * 0.10),
        bandRect.left - radius * 0.22,
        bandRect.bottom,
      )
      ..close();

    canvas.drawPath(
      bandPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF00FFF0).withOpacity(isDark ? 0.68 : 0.82),
            const Color(0xFF38C5FF).withOpacity(isDark ? 0.86 : 0.96),
            const Color(0xFF2563EB).withOpacity(isDark ? 0.82 : 0.90),
            const Color(0xFF7C3AED).withOpacity(isDark ? 0.84 : 0.86),
            const Color(0xFFD946EF).withOpacity(isDark ? 0.56 : 0.60),
          ],
          stops: const [0.0, 0.24, 0.50, 0.76, 1.0],
          // t = полный оборот → GradientRotation(t) бесшовен.
          transform: GradientRotation(t),
        ).createShader(bandRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final band2Center = Offset(
      center.dx - c1 * radius * 0.09,
      center.dy - radius * 0.04 + s2 * radius * 0.06,
    );
    final band2Rect = Rect.fromCenter(
      center: band2Center,
      width: radius * 2.10,
      height: radius * 0.66,
    );
    final band2Path = Path()
      ..moveTo(band2Rect.left - radius * 0.12, band2Center.dy + radius * 0.10)
      ..cubicTo(
        band2Rect.left + band2Rect.width * 0.16,
        band2Rect.bottom + radius * 0.22,
        band2Rect.left + band2Rect.width * 0.36,
        band2Rect.top - radius * 0.18,
        band2Rect.left + band2Rect.width * 0.58,
        band2Center.dy,
      )
      ..cubicTo(
        band2Rect.left + band2Rect.width * 0.76,
        band2Rect.bottom + radius * 0.24,
        band2Rect.right - band2Rect.width * 0.08,
        band2Rect.top - radius * 0.12,
        band2Rect.right + radius * 0.12,
        band2Center.dy + radius * 0.06,
      )
      ..lineTo(band2Rect.right + radius * 0.12, band2Rect.bottom)
      ..cubicTo(
        band2Rect.right - band2Rect.width * 0.26,
        band2Rect.top + radius * 0.14,
        band2Rect.left + band2Rect.width * 0.56,
        band2Rect.bottom + radius * 0.14,
        band2Rect.left - radius * 0.12,
        band2Rect.top + radius * 0.12,
      )
      ..close();

    canvas.drawPath(
      band2Path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF60A5FA).withOpacity(isDark ? 0.30 : 0.40),
            const Color(0xFF06B6D4).withOpacity(isDark ? 0.50 : 0.62),
            const Color(0xFF8B5CF6).withOpacity(isDark ? 0.54 : 0.60),
            const Color(0xFFC084FC).withOpacity(isDark ? 0.34 : 0.40),
            Colors.transparent,
          ],
          stops: const [0.0, 0.32, 0.62, 0.84, 1.0],
          transform: GradientRotation(-t), // обратный оборот — бесшовен
        ).createShader(band2Rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    final band3Center = Offset(
      center.dx + s3 * radius * 0.14,
      center.dy + c1 * radius * 0.22,
    );
    final band3Rect = Rect.fromCenter(
      center: band3Center,
      width: radius * (1.60 + pulse3 * 0.24),
      height: radius * (0.34 + pulse2 * 0.10),
    );
    final band3Path = Path()
      ..moveTo(band3Rect.left, band3Center.dy)
      ..cubicTo(
        band3Rect.left + band3Rect.width * 0.25,
        band3Rect.top - radius * 0.08,
        band3Rect.left + band3Rect.width * 0.60,
        band3Rect.bottom + radius * 0.08,
        band3Rect.right,
        band3Center.dy,
      )
      ..lineTo(band3Rect.right, band3Rect.bottom)
      ..cubicTo(
        band3Rect.left + band3Rect.width * 0.55,
        band3Rect.bottom + radius * 0.06,
        band3Rect.left + band3Rect.width * 0.22,
        band3Rect.top + radius * 0.04,
        band3Rect.left,
        band3Rect.bottom,
      )
      ..close();

    canvas.drawPath(
      band3Path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            const Color(0xFF7DD3FC).withOpacity(isDark ? 0.52 : 0.64),
            const Color(0xFFA78BFA).withOpacity(isDark ? 0.46 : 0.56),
            Colors.transparent,
          ],
          stops: const [0.0, 0.36, 0.70, 1.0],
        ).createShader(band3Rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final cyanCenter = Offset(
      center.dx - radius * 0.30 + c1 * radius * 0.11,
      center.dy - radius * 0.08 + s1 * radius * 0.08,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: cyanCenter,
        width: radius * (1.26 + pulse * 0.10),
        height: radius * (0.90 + pulse2 * 0.10),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB5FFFF).withOpacity(isDark ? 0.58 : 0.80),
            const Color(0xFF38BDF8).withOpacity(isDark ? 0.50 : 0.68),
            const Color(0xFF2563EB).withOpacity(isDark ? 0.24 : 0.28),
            Colors.transparent,
          ],
          stops: const [0.0, 0.30, 0.60, 1.0],
        ).createShader(Rect.fromCircle(center: cyanCenter, radius: radius * 0.78))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    final violetCenter = Offset(
      center.dx + radius * 0.32 + s2 * radius * 0.10,
      center.dy - radius * 0.20 + c1 * radius * 0.08,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: violetCenter,
        width: radius * (1.18 + pulse2 * 0.14),
        height: radius * (0.84 + pulse * 0.14),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE879F9).withOpacity(isDark ? 0.46 : 0.52),
            const Color(0xFF9333EA).withOpacity(isDark ? 0.56 : 0.64),
            const Color(0xFF3730A3).withOpacity(isDark ? 0.28 : 0.32),
            Colors.transparent,
          ],
          stops: const [0.0, 0.34, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: violetCenter, radius: radius * 0.72))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    final indigoCenter = Offset(
      center.dx - s2 * radius * 0.12,
      center.dy + radius * 0.28 + c1 * radius * 0.07,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: indigoCenter,
        width: radius * (0.92 + pulse3 * 0.12),
        height: radius * (0.68 + pulse2 * 0.10),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF818CF8).withOpacity(isDark ? 0.50 : 0.58),
            const Color(0xFF4F46E5).withOpacity(isDark ? 0.36 : 0.44),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(Rect.fromCircle(center: indigoCenter, radius: radius * 0.60))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    final windowCenter = Offset(
      center.dx + radius * 0.20 + s3 * radius * 0.05,
      center.dy + radius * 0.36 + c2 * radius * 0.05,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: windowCenter,
        width: radius * 1.12,
        height: radius * 0.74,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            backgroundColor.withOpacity(isDark ? 0.22 : 0.18),
            backgroundColor.withOpacity(isDark ? 0.12 : 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.44, 1.0],
        ).createShader(Rect.fromCircle(center: windowCenter, radius: radius * 0.58))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    final highlightCenter = Offset(
      center.dx - radius * 0.34 + s1 * radius * 0.045,
      center.dy - radius * 0.38 + c1 * radius * 0.040,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: highlightCenter,
        width: radius * 0.90,
        height: radius * 0.56,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(isDark ? 0.50 : 0.72),
            Colors.white.withOpacity(isDark ? 0.20 : 0.32),
            Colors.transparent,
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(Rect.fromCircle(center: highlightCenter, radius: radius * 0.56))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Маленький острый блик — «искра» стекла.
    final sparkCenter = Offset(
      center.dx - radius * 0.40 + s2 * radius * 0.02,
      center.dy - radius * 0.44 + c1 * radius * 0.02,
    );
    canvas.drawOval(
      Rect.fromCenter(center: sparkCenter, width: radius * 0.22, height: radius * 0.12),
      Paint()
        ..color = Colors.white.withOpacity(isDark ? 0.72 : 0.90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(
      center,
      sphereRadius * 1.02,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(isDark ? 0.34 : 0.14),
          ],
          stops: const [0.0, 0.68, 1.0],
        ).createShader(sphereRect),
    );

    canvas.restore();

    canvas.drawPath(
      morphPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = SweepGradient(
          transform: GradientRotation(t),
          colors: [
            Colors.white.withOpacity(isDark ? 0.34 : 0.50),
            const Color(0xFF7DD3FC).withOpacity(isDark ? 0.90 : 0.94),
            const Color(0xFF06B6D4).withOpacity(isDark ? 0.72 : 0.84),
            const Color(0xFF4F46E5).withOpacity(isDark ? 0.74 : 0.82),
            const Color(0xFFA855F7).withOpacity(isDark ? 0.62 : 0.70),
            const Color(0xFFEC4899).withOpacity(isDark ? 0.36 : 0.44),
            Colors.white.withOpacity(isDark ? 0.34 : 0.50),
          ],
          stops: const [0.0, 0.18, 0.38, 0.58, 0.76, 0.90, 1.0],
        ).createShader(sphereRect),
    );

    canvas.drawPath(
      morphPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xFF60A5FA).withOpacity(isDark ? 0.16 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      morphPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = const Color(0xFF7C3AED).withOpacity(isDark ? 0.08 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }

  @override
  bool shouldRepaint(covariant _AISpherePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}