import 'package:flutter/material.dart';

class ManipulatorJoysticksWidget extends StatelessWidget {
  final String side; // 'left' or 'right'
  final Function(int jointIndex, double value) onJointMove;

  const ManipulatorJoysticksWidget({
    super.key,
    required this.side,
    required this.onJointMove,
  });

  @override
  Widget build(BuildContext context) {
    List<String> jointNames = side == 'left' 
        ? ['Shoulder Pan', 'Shoulder Lift', 'Elbow Flex']
        : ['Wrist Flex', 'Wrist Roll', 'Gripper'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: side == 'left' ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HorizontalJoystickWidget(
              label: jointNames[i],
              onMove: (value) => onJointMove(i, value),
              alignment: side == 'left' ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            ),
          ),
      ],
    );
  }
}

class HorizontalJoystickWidget extends StatefulWidget {
  final String label;
  final Function(double value) onMove;
  final CrossAxisAlignment alignment;

  const HorizontalJoystickWidget({
    super.key,
    required this.label,
    required this.onMove,
    required this.alignment,
  });

  @override
  State<HorizontalJoystickWidget> createState() => _HorizontalJoystickWidgetState();
}

class _HorizontalJoystickWidgetState extends State<HorizontalJoystickWidget> {
  double _knobX = 0.0;
  bool _isDragging = false;
  final double _width = 120.0;
  final double _height = 40.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.alignment,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: _width,
          height: _height,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              painter: HorizontalJoystickPainter(
                knobX: _knobX,
                isDragging: _isDragging,
                width: _width,
                height: _height,
              ),
              size: Size(_width, _height),
            ),
          ),
        ),
      ],
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
    });
    widget.onMove(0.0);
  }

  void _updateKnobPosition(Offset localPosition) {
    final center = _width / 2;
    final maxDistance = _width / 2 - 15;
    
    final deltaX = localPosition.dx - center;
    
    if (deltaX.abs() <= maxDistance) {
      setState(() {
        _knobX = deltaX;
      });
    } else {
      setState(() {
        _knobX = deltaX > 0 ? maxDistance : -maxDistance;
      });
    }

    // Convert to normalized value (-1 to 1) with deadzone
    final normalizedX = _knobX / maxDistance;
    final deadzonedValue = _applyDeadzone(normalizedX);
    widget.onMove(deadzonedValue);
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

class HorizontalJoystickPainter extends CustomPainter {
  final double knobX;
  final bool isDragging;
  final double width;
  final double height;

  HorizontalJoystickPainter({
    required this.knobX,
    required this.isDragging,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(width / 2, height / 2);
    final knobRadius = 12.0;

    // Draw background track
    final trackPaint = Paint()
      ..color = Colors.grey[800]!.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, height / 2 - 4, width, 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(trackRect, trackPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.grey[600]!.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawRRect(trackRect, borderPaint);

    // Draw center line
    final centerLinePaint = Paint()
      ..color = Colors.grey[500]!
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(width / 2, height / 2 - 6),
      Offset(width / 2, height / 2 + 6),
      centerLinePaint,
    );

    // Draw knob
    final knobCenter = Offset(center.dx + knobX, center.dy);
    final knobPaint = Paint()
      ..color = isDragging ? Colors.blue[400]! : Colors.blue[600]!;
    canvas.drawCircle(knobCenter, knobRadius, knobPaint);
  }

  @override
  bool shouldRepaint(HorizontalJoystickPainter oldDelegate) {
    return oldDelegate.knobX != knobX ||
           oldDelegate.isDragging != isDragging;
  }
} 