import 'package:flutter/material.dart';
import 'dart:math' as math;

class ArmRotationJoystickWidget extends StatefulWidget {
  final Function(double rotation, double wristFlex) onMove;
  final double size;

  const ArmRotationJoystickWidget({
    super.key,
    required this.onMove,
    this.size = 200.0,
  });

  @override
  State<ArmRotationJoystickWidget> createState() => _ArmRotationJoystickWidgetState();
}

class _ArmRotationJoystickWidgetState extends State<ArmRotationJoystickWidget> {
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
    final normalizedY = _knobY / radius; // No inversion - fix the direction issue

    // Apply deadzone logic
    final deadzonedX = _applyDeadzone(normalizedX);
    final deadzonedY = _applyDeadzone(normalizedY);

    // Rotation (left/right) and wrist flex (up/down) - fix inversion
    widget.onMove(deadzonedX, -deadzonedY); // Invert Y for correct wrist flex direction
  }

  // Apply deadzone logic: 0-15% = 0, 15-30% = proportional 0-30%, 30%+ = actual
  double _applyDeadzone(double value) {
    final absValue = value.abs();
    if (absValue < 0.15) {
      return 0.0;
    } else if (absValue < 0.30) {
      // Scale from 0.15-0.30 range to 0.0-0.30 range
      final scaledValue = (absValue - 0.15) / 0.15 * 0.30;
      return value > 0 ? scaledValue : -scaledValue;
    } else {
      return value;
    }
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