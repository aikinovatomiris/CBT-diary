import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'liquid_ai_painter.dart';

class AnimatedAISphere extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const AnimatedAISphere({
    super.key,
    required this.isLoading,
    this.onTap,
  });

  @override
  State<AnimatedAISphere> createState() => _AnimatedAISphereState();
}

class _AnimatedAISphereState extends State<AnimatedAISphere>
    with TickerProviderStateMixin {
  // Morphing / breathing shape — 7s cycle
  late AnimationController _morphController;

  // Slow texture rotation — 20s cycle
  late AnimationController _rotationController;

  // Inner light streams — 13s cycle
  late AnimationController _lightController;

  // Pulse / glow intensity — 10s cycle
  late AnimationController _pulseController;

  // Highlight drift — 18s cycle
  late AnimationController _highlightController;

  // Touch interaction
  late AnimationController _touchController;
  late Animation<double> _touchScale;
  late Animation<double> _touchGlow;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20000),
    )..repeat();

    _lightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat(reverse: true);

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    )..repeat(reverse: true);

    _touchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _touchScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _touchController, curve: Curves.easeOutCubic),
    );

    _touchGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _touchController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _morphController.dispose();
    _rotationController.dispose();
    _lightController.dispose();
    _pulseController.dispose();
    _highlightController.dispose();
    _touchController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_isPressed) {
      _isPressed = true;
      _touchController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _releaseTap();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _releaseTap();
  }

  void _releaseTap() {
    if (_isPressed) {
      _isPressed = false;
      _touchController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final orbSize = screenWidth * 0.82;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: SizedBox(
        width: orbSize,
        height: orbSize,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _morphController,
            _rotationController,
            _lightController,
            _pulseController,
            _highlightController,
            _touchController,
          ]),
          builder: (context, _) {
            return Transform.scale(
              scale: _touchScale.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Orb canvas ──────────────────────────────────────────
                  CustomPaint(
                    size: Size(orbSize, orbSize),
                    painter: LiquidAIPainter(
                      morphValue: _morphController.value,
                      rotationValue: _rotationController.value,
                      lightValue: _lightController.value,
                      pulseValue: _pulseController.value,
                      highlightValue: _highlightController.value,
                      touchGlow: _touchGlow.value,
                      isDark: isDark,
                    ),
                    isComplex: true,
                    willChange: true,
                  ),

                  // ── Floating text & button ───────────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'КПТ-сессия',
                        style: TextStyle(
                          fontSize: orbSize * 0.094,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: -0.5,
                          shadows: isDark
                              ? [
                                  Shadow(
                                    color: const Color(0xFF3B82FF)
                                        .withOpacity(0.6),
                                    blurRadius: 20,
                                  )
                                ]
                              : [
                                  Shadow(
                                    color: const Color(0xFF8A5CFF)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                  )
                                ],
                        ),
                      ),
                      SizedBox(height: orbSize * 0.03),
                      Text(
                        'Начать сессию',
                        style: TextStyle(
                          fontSize: orbSize * 0.052,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white.withOpacity(0.65)
                              : const Color(0xFF6B7280),
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(height: orbSize * 0.07),
                      _StartButton(
                        size: orbSize * 0.16,
                        isLoading: widget.isLoading,
                        isDark: isDark,
                        touchGlow: _touchGlow.value,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating action button
// ─────────────────────────────────────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final double size;
  final bool isLoading;
  final bool isDark;
  final double touchGlow;

  const _StartButton({
    required this.size,
    required this.isLoading,
    required this.isDark,
    required this.touchGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF8A5CFF).withOpacity(0.85 + touchGlow * 0.15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A5CFF).withOpacity(0.5 + touchGlow * 0.3),
            blurRadius: 20 + touchGlow * 16,
            spreadRadius: 2 + touchGlow * 4,
          ),
        ],
      ),
      child: isLoading
          ? Padding(
              padding: EdgeInsets.all(size * 0.28),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.9)),
              ),
            )
          : Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: size * 0.44,
            ),
    );
  }
}
