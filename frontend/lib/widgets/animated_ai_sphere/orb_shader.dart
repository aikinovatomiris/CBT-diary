import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';


class OrbShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double morph;
  final double pulse;
  final double touch;
  final bool isDark;
  final Size canvasSize;

  const OrbShaderPainter({
    required this.shader,
    required this.time,
    required this.morph,
    required this.pulse,
    required this.touch,
    required this.isDark,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, time);
    shader.setFloat(1, morph);
    shader.setFloat(2, pulse);
    shader.setFloat(3, touch);
    shader.setFloat(4, isDark ? 1.0 : 0.0);
    shader.setFloat(5, size.width);
    shader.setFloat(6, size.height);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(OrbShaderPainter old) =>
      old.time != time ||
      old.morph != morph ||
      old.pulse != pulse ||
      old.touch != touch ||
      old.isDark != isDark;
}

class OrbShaderWidget extends StatefulWidget {
  final bool isDark;
  final double size;
  final bool isLoading;
  final VoidCallback? onTap;

  const OrbShaderWidget({
    super.key,
    required this.isDark,
    required this.size,
    this.isLoading = false,
    this.onTap,
  });

  @override
  State<OrbShaderWidget> createState() => _OrbShaderWidgetState();
}

class _OrbShaderWidgetState extends State<OrbShaderWidget>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  Ticker? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
    })..start();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('assets/shaders/orb.frag');
      if (mounted) setState(() => _program = program);
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      return const SizedBox.shrink();
    }

    final t = _elapsed.inMilliseconds / 1000.0;
    final shader = _program!.fragmentShader();

    return GestureDetector(
      onTap: widget.onTap,
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: OrbShaderPainter(
          shader: shader,
          time: t,
          morph: (t * 0.143) % 1.0, // 7s cycle
          pulse: ((t * 0.1) % 1.0),  // 10s cycle
          touch: 0.0,
          isDark: widget.isDark,
          canvasSize: Size(widget.size, widget.size),
        ),
        isComplex: true,
        willChange: true,
      ),
    );
  }
}
