import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

// ─────────────────────────────────────────────────────────────────────────────
// Color palette
// ─────────────────────────────────────────────────────────────────────────────
class _OrbColors {
  // Dark theme
  static const darkBg = Color(0xFF050816);
  static const primaryBlue = Color(0xFF3B82FF);
  static const electricBlue = Color(0xFF5BC8FF);
  static const purple = Color(0xFF8A5CFF);
  static const accent = Color(0xFFB084FF);
  static const coreDeep = Color(0xFF0A1240);

  // Light theme
  static const lightCore = Color(0xFFEEEBFF);
  static const lightBlue = Color(0xFFB8D4FF);
  static const lightPurple = Color(0xFFD4B8FF);
  static const lightAccent = Color(0xFFE8D5FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────
class LiquidAIPainter extends CustomPainter {
  final double morphValue;
  final double rotationValue;
  final double lightValue;
  final double pulseValue;
  final double highlightValue;
  final double touchGlow;
  final bool isDark;

  const LiquidAIPainter({
    required this.morphValue,
    required this.rotationValue,
    required this.lightValue,
    required this.pulseValue,
    required this.highlightValue,
    required this.touchGlow,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.46;

    // Save & clip to a slightly oversized rect so glow bleeds out naturally
    canvas.save();

    if (isDark) {
      _paintDark(canvas, size, center, baseRadius);
    } else {
      _paintLight(canvas, size, center, baseRadius);
    }

    canvas.restore();
  }

  // ───────────────────────────── DARK THEME ────────────────────────────────
  void _paintDark(Canvas canvas, Size size, Offset center, double radius) {
    final pulse = 0.92 + pulseValue * 0.08; // 0.92–1.00

    // 1. Outer ambient glow (behind everything)
    _paintOuterGlow(canvas, center, radius, pulse);

    // 2. Morphed orb body path
    final orbPath = _buildMorphPath(center, radius * pulse);

    // 3. Deep core gradient
    _paintDarkCore(canvas, orbPath, center, radius * pulse);

    // 4. Electric blue energy layer (rotates)
    _paintEnergyLayer(canvas, orbPath, center, radius * pulse);

    // 5. Purple energy streams
    _paintPurpleStreams(canvas, center, radius * pulse);

    // 6. Moving light swirls
    _paintLightSwirls(canvas, center, radius * pulse);

    // 7. Glass surface — rim + fresnel
    _paintGlassSurface(canvas, orbPath, center, radius * pulse);

    // 8. Dynamic specular highlight (top-left)
    _paintSpecularHighlight(canvas, center, radius * pulse);

    // 9. Touch wave
    if (touchGlow > 0.01) {
      _paintTouchWave(canvas, center, radius * pulse);
    }
  }

  // ───────────────────────────── LIGHT THEME ───────────────────────────────
  void _paintLight(Canvas canvas, Size size, Offset center, double radius) {
    final pulse = 0.93 + pulseValue * 0.07;
    final orbPath = _buildMorphPath(center, radius * pulse);

    _paintLightOuterGlow(canvas, center, radius * pulse);
    _paintLightCore(canvas, orbPath, center, radius * pulse);
    _paintLightStreams(canvas, center, radius * pulse);
    _paintLightGlassSurface(canvas, orbPath, center, radius * pulse);
    _paintLightSpecular(canvas, center, radius * pulse);

    if (touchGlow > 0.01) {
      _paintTouchWave(canvas, center, radius * pulse);
    }
  }

  // ─────────────────────────── MORPH SHAPE ────────────────────────────────
  /// Builds a smooth blob path with 8 control points animated at different
  /// phases so the shape breathes asymmetrically.
  Path _buildMorphPath(Offset center, double r) {
    // Phase offsets make each axis deform at different rates
    const points = 8;
    final angleStep = (math.pi * 2) / points;

    // Deformation amplitudes per control point (tuned by eye)
    final deformAmps = [0.07, 0.05, 0.09, 0.06, 0.08, 0.05, 0.07, 0.06];
    final phaseOffsets = [0.0, 0.8, 1.6, 2.3, 3.1, 3.9, 4.7, 5.5];

    final offsets = List.generate(points, (i) {
      final angle = angleStep * i - math.pi / 2;
      final t = morphValue * math.pi * 2;
      final deform = math.sin(t + phaseOffsets[i]) * deformAmps[i];
      final dr = r * (1.0 + deform);
      return Offset(
        center.dx + math.cos(angle) * dr,
        center.dy + math.sin(angle) * dr,
      );
    });

    // Catmull-Rom → cubic bezier conversion for smooth blob
    final path = Path();
    for (int i = 0; i < points; i++) {
      final p0 = offsets[(i - 1 + points) % points];
      final p1 = offsets[i];
      final p2 = offsets[(i + 1) % points];
      final p3 = offsets[(i + 2) % points];

      if (i == 0) path.moveTo(p1.dx, p1.dy);

      // Catmull-Rom to Bezier
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  // ─────────────────────────── DARK LAYERS ────────────────────────────────

  void _paintOuterGlow(Canvas canvas, Offset c, double r, double pulse) {
    final glowR = r * (1.35 + pulse * 0.08 + touchGlow * 0.12);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        c,
        glowR,
        [
          _OrbColors.primaryBlue.withOpacity(0.18 + touchGlow * 0.12),
          _OrbColors.purple.withOpacity(0.10),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(c, glowR, paint);

    // Purple secondary glow offset
    final purpleGlowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(c.dx + r * 0.2, c.dy + r * 0.15),
        r * 1.1,
        [
          _OrbColors.purple.withOpacity(0.14 + touchGlow * 0.1),
          Colors.transparent,
        ],
        [0.0, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(
        Offset(c.dx + r * 0.2, c.dy + r * 0.15), r * 1.1, purpleGlowPaint);
  }

  void _paintDarkCore(Canvas canvas, Path path, Offset c, double r) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(c.dx - r * 0.1, c.dy - r * 0.05),
        r * 1.05,
        [
          _OrbColors.electricBlue.withOpacity(0.55),
          _OrbColors.primaryBlue.withOpacity(0.75),
          _OrbColors.coreDeep.withOpacity(0.95),
          const Color(0xFF020510),
        ],
        [0.0, 0.35, 0.65, 1.0],
      );
    canvas.drawPath(path, paint);
  }

  void _paintEnergyLayer(Canvas canvas, Path path, Offset c, double r) {
    // Rotating elliptical energy blob — electric blue
    canvas.save();
    canvas.clipPath(path);

    final rot = rotationValue * math.pi * 2;
    final energyCenter = Offset(
      c.dx + math.cos(rot) * r * 0.3,
      c.dy + math.sin(rot * 0.7) * r * 0.25,
    );

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        energyCenter,
        r * 0.65,
        [
          _OrbColors.electricBlue.withOpacity(0.55),
          _OrbColors.primaryBlue.withOpacity(0.3),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(energyCenter, r * 0.65, paint);

    // Secondary energy blob (opposite side, slower)
    final rot2 = rotationValue * math.pi * 2 * 0.6 + math.pi;
    final energy2 = Offset(
      c.dx + math.cos(rot2) * r * 0.28,
      c.dy + math.sin(rot2 * 0.8) * r * 0.22,
    );
    final paint2 = Paint()
      ..shader = ui.Gradient.radial(
        energy2,
        r * 0.5,
        [
          _OrbColors.electricBlue.withOpacity(0.4),
          Colors.transparent,
        ],
        [0.0, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(energy2, r * 0.5, paint2);

    canvas.restore();
  }

  void _paintPurpleStreams(Canvas canvas, Offset c, double r) {
    // Two slow purple energy lenses rotating independently
    final rot = lightValue * math.pi * 2;

    for (int i = 0; i < 3; i++) {
      final angle = rot * 0.5 + (i * math.pi * 2 / 3);
      final dist = r * (0.18 + i * 0.08);
      final sc = Offset(
        c.dx + math.cos(angle) * dist,
        c.dy + math.sin(angle) * dist,
      );
      final streamR = r * (0.55 - i * 0.08);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          sc,
          streamR,
          [
            _OrbColors.purple.withOpacity(0.35 - i * 0.08),
            _OrbColors.accent.withOpacity(0.15),
            Colors.transparent,
          ],
          [0.0, 0.5, 1.0],
        )
        ..blendMode = BlendMode.screen;

      // Clip to orb shape to prevent overflow
      canvas.save();
      canvas.clipPath(_buildMorphPath(c, r));
      canvas.drawCircle(sc, streamR, paint);
      canvas.restore();
    }
  }

  void _paintLightSwirls(Canvas canvas, Offset c, double r) {
    // Moving white-ish light filaments that simulate volumetric rays
    canvas.save();
    canvas.clipPath(_buildMorphPath(c, r));

    final t = lightValue * math.pi * 2;

    for (int i = 0; i < 5; i++) {
      final phase = t + i * (math.pi * 2 / 5);
      final x = c.dx + math.cos(phase * 1.3) * r * 0.42;
      final y = c.dy + math.sin(phase * 0.9) * r * 0.38;
      final swirl = Offset(x, y);
      final sr = r * (0.18 + math.sin(phase * 0.7) * 0.06);
      final opacity = (0.12 + math.sin(phase * 1.1) * 0.06).clamp(0.0, 0.25);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          swirl,
          sr,
          [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(0.0),
          ],
          [0.0, 1.0],
        )
        ..blendMode = BlendMode.screen;
      canvas.drawOval(
        Rect.fromCenter(center: swirl, width: sr * 2.4, height: sr * 1.3),
        paint,
      );
    }

    canvas.restore();
  }

  void _paintGlassSurface(Canvas canvas, Path path, Offset c, double r) {
    // Rim / fresnel — bright edge ring
    final rimPaint = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r,
        [
          Colors.transparent,
          Colors.transparent,
          _OrbColors.electricBlue.withOpacity(0.08),
          _OrbColors.electricBlue.withOpacity(0.30),
          _OrbColors.primaryBlue.withOpacity(0.18),
        ],
        [0.0, 0.68, 0.80, 0.92, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, rimPaint);

    // Subtle inner shadow at the bottom to fake depth
    final shadowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(c.dx, c.dy + r * 0.55),
        r * 0.7,
        [
          Colors.black.withOpacity(0.35),
          Colors.transparent,
        ],
        [0.0, 1.0],
      )
      ..blendMode = BlendMode.multiply;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.55), r * 0.7, shadowPaint);
    canvas.restore();
  }

  void _paintSpecularHighlight(Canvas canvas, Offset c, double r) {
    // Dynamic top-left specular highlight that drifts slowly
    final h = highlightValue; // 0→1 back and forth
    final hx = c.dx - r * (0.28 + h * 0.10);
    final hy = c.dy - r * (0.30 + h * 0.08);
    final hCenter = Offset(hx, hy);

    // Save & clip to orb bounds (approximate circle for highlight)
    canvas.save();
    canvas.clipPath(_buildMorphPath(c, r));

    // Large soft haze
    final hazePaint = Paint()
      ..shader = ui.Gradient.radial(
        hCenter,
        r * 0.58,
        [
          Colors.white.withOpacity(0.18 + touchGlow * 0.08),
          Colors.white.withOpacity(0.06),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawOval(
      Rect.fromCenter(
          center: hCenter, width: r * 1.05, height: r * 0.62),
      hazePaint,
    );

    // Bright core of the specular
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        hCenter,
        r * 0.18,
        [
          Colors.white.withOpacity(0.75 + touchGlow * 0.15),
          Colors.white.withOpacity(0.0),
        ],
        [0.0, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawOval(
      Rect.fromCenter(
          center: hCenter, width: r * 0.32, height: r * 0.18),
      corePaint,
    );

    // Small secondary highlight (refraction illusion)
    final refractCenter = Offset(c.dx + r * 0.18, c.dy - r * 0.40);
    final refractPaint = Paint()
      ..shader = ui.Gradient.radial(
        refractCenter,
        r * 0.12,
        [
          Colors.white.withOpacity(0.30),
          Colors.transparent,
        ],
        [0.0, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawOval(
      Rect.fromCenter(
          center: refractCenter, width: r * 0.22, height: r * 0.10),
      refractPaint,
    );

    canvas.restore();
  }

  void _paintTouchWave(Canvas canvas, Offset c, double r) {
    // Expanding ring wave when tapped
    final waveR = r * (0.2 + touchGlow * 0.85);
    final opacity = (1.0 - touchGlow) * 0.5;
    final wavePaint = Paint()
      ..color = _OrbColors.electricBlue.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1.0 - touchGlow * 0.7);
    canvas.save();
    canvas.clipPath(_buildMorphPath(c, r));
    canvas.drawCircle(c, waveR, wavePaint);
    canvas.restore();
  }

  // ─────────────────────────── LIGHT LAYERS ────────────────────────────────

  void _paintLightOuterGlow(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r * 1.3,
        [
          _OrbColors.lightPurple.withOpacity(0.30 + touchGlow * 0.1),
          _OrbColors.lightBlue.withOpacity(0.15),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(c, r * 1.3, paint);
  }

  void _paintLightCore(Canvas canvas, Path path, Offset c, double r) {
    final pulse = 0.92 + pulseValue * 0.08;
    final rot = rotationValue * math.pi * 2;

    // Base white-lavender fill
    final basePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(c.dx - r * 0.1, c.dy - r * 0.1),
        r * 1.05,
        [
          Colors.white.withOpacity(0.95),
          _OrbColors.lightCore.withOpacity(0.90),
          _OrbColors.lightPurple.withOpacity(0.70),
          _OrbColors.lightBlue.withOpacity(0.55),
        ],
        [0.0, 0.3, 0.65, 1.0],
      );
    canvas.drawPath(path, basePaint);

    // Rotating blue energy blob
    final energyCenter = Offset(
      c.dx + math.cos(rot) * r * 0.28,
      c.dy + math.sin(rot * 0.7) * r * 0.22,
    );
    canvas.save();
    canvas.clipPath(path);
    final energyPaint = Paint()
      ..shader = ui.Gradient.radial(
        energyCenter,
        r * 0.6,
        [
          _OrbColors.lightBlue.withOpacity(0.55),
          Colors.transparent,
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(energyCenter, r * 0.6, energyPaint);

    // Purple swirl
    final purpleCenter = Offset(
      c.dx + math.cos(rot + math.pi * 0.8) * r * 0.32,
      c.dy + math.sin((rot + math.pi) * 0.6) * r * 0.28,
    );
    final purplePaint = Paint()
      ..shader = ui.Gradient.radial(
        purpleCenter,
        r * 0.55,
        [
          _OrbColors.lightPurple.withOpacity(0.50),
          Colors.transparent,
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(purpleCenter, r * 0.55, purplePaint);
    canvas.restore();
  }

  void _paintLightStreams(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.clipPath(_buildMorphPath(c, r));

    final t = lightValue * math.pi * 2;
    for (int i = 0; i < 4; i++) {
      final phase = t + i * (math.pi / 2);
      final x = c.dx + math.cos(phase * 1.2) * r * 0.38;
      final y = c.dy + math.sin(phase * 0.85) * r * 0.35;
      final sr = r * 0.22;
      final opacity = (0.20 + math.sin(phase * 1.0) * 0.1).clamp(0.0, 0.35);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          sr,
          [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(0.0),
          ],
          [0.0, 1.0],
        );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y), width: sr * 2.8, height: sr * 1.4),
        paint,
      );
    }
    canvas.restore();
  }

  void _paintLightGlassSurface(Canvas canvas, Path path, Offset c, double r) {
    // Soft rim
    final rimPaint = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r,
        [
          Colors.transparent,
          Colors.transparent,
          _OrbColors.lightPurple.withOpacity(0.08),
          _OrbColors.lightPurple.withOpacity(0.22),
          Colors.white.withOpacity(0.10),
        ],
        [0.0, 0.65, 0.78, 0.92, 1.0],
      );
    canvas.drawPath(path, rimPaint);
  }

  void _paintLightSpecular(Canvas canvas, Offset c, double r) {
    final h = highlightValue;
    final hx = c.dx - r * (0.24 + h * 0.10);
    final hy = c.dy - r * (0.28 + h * 0.07);
    final hCenter = Offset(hx, hy);

    canvas.save();
    canvas.clipPath(_buildMorphPath(c, r));

    final hazePaint = Paint()
      ..shader = ui.Gradient.radial(
        hCenter,
        r * 0.52,
        [
          Colors.white.withOpacity(0.55 + touchGlow * 0.15),
          Colors.white.withOpacity(0.0),
        ],
        [0.0, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(
          center: hCenter, width: r * 0.95, height: r * 0.58),
      hazePaint,
    );

    // Bright core
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        hCenter,
        r * 0.15,
        [
          Colors.white.withOpacity(0.90),
          Colors.white.withOpacity(0.0),
        ],
        [0.0, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(
          center: hCenter, width: r * 0.28, height: r * 0.16),
      corePaint,
    );

    canvas.restore();
  }

  // ─────────────────────────── REPAINT LOGIC ───────────────────────────────
  @override
  bool shouldRepaint(LiquidAIPainter old) {
    return old.morphValue != morphValue ||
        old.rotationValue != rotationValue ||
        old.lightValue != lightValue ||
        old.pulseValue != pulseValue ||
        old.highlightValue != highlightValue ||
        old.touchGlow != touchGlow ||
        old.isDark != isDark;
  }
}
