import 'package:flutter/material.dart';
import 'dart:math' as math;

class JoystickWidget extends StatefulWidget {
  final Function(double x, double y) onMove;
  final double size;

  const JoystickWidget({
    super.key,
    required this.onMove,
    this.size = 200.0,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  double _knobX = 0.0;
  double _knobY = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // Ensures the entire area is responsive
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: JoystickPainter(
              knobX: _knobX,
              knobY: _knobY,
              isDragging: _isDragging,
            ),
            size: Size(widget.size, widget.size),
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    _updateKnobPosition(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _updateKnobPosition(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _knobX = 0.0;
      _knobY = 0.0;
    });
    widget.onMove(0.0, 0.0);
  }

  void _updateKnobPosition(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final radius = widget.size / 2 - 20;
    
    final deltaX = localPosition.dx - center.dx;
    final deltaY = localPosition.dy - center.dy;
    final distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);

    if (distance <= radius) {
      setState(() {
        _knobX = deltaX;
        _knobY = deltaY;
      });
    } else {
      // Constrain to circle boundary
      final angle = math.atan2(deltaY, deltaX);
      setState(() {
        _knobX = math.cos(angle) * radius;
        _knobY = math.sin(angle) * radius;
      });
    }

    // Convert to normalized values (-1 to 1)
    final normalizedX = _knobX / radius;
    final normalizedY = -_knobY / radius; // Invert Y for intuitive control

    widget.onMove(normalizedX, normalizedY);
  }
}

class JoystickPainter extends CustomPainter {
  final double knobX;
  final double knobY;
  final bool isDragging;

  JoystickPainter({
    required this.knobX,
    required this.knobY,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final knobRadius = 20.0;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey[800]!.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.grey[600]!.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius, borderPaint);

    // Draw knob
    final knobCenter = Offset(center.dx + knobX, center.dy + knobY);
    final knobPaint = Paint()
      ..color = isDragging ? Colors.blue[400]! : Colors.blue[600]!;
    canvas.drawCircle(knobCenter, knobRadius, knobPaint);
  }

  @override
  bool shouldRepaint(JoystickPainter oldDelegate) {
    return oldDelegate.knobX != knobX ||
           oldDelegate.knobY != knobY ||
           oldDelegate.isDragging != isDragging;
  }
} 