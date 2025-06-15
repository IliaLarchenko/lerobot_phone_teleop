import 'package:flutter/material.dart';

class ThetaControlWidget extends StatefulWidget {
  final Function(double) onRotationChange;

  const ThetaControlWidget({
    super.key,
    required this.onRotationChange,
  });

  @override
  State<ThetaControlWidget> createState() => _ThetaControlWidgetState();
}

class _ThetaControlWidgetState extends State<ThetaControlWidget> {
  double _currentRotation = 0.0;

  void _startRotation(double direction) {
    setState(() {
      _currentRotation = direction * 0.5; // Max rotation speed
    });
    widget.onRotationChange(_currentRotation);
  }

  void _stopRotation() {
    setState(() {
      _currentRotation = 0.0;
    });
    widget.onRotationChange(_currentRotation);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ROTATION',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left rotation button
            GestureDetector(
              onTapDown: (_) => _startRotation(-1.0),
              onTapUp: (_) => _stopRotation(),
              onTapCancel: () => _stopRotation(),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _currentRotation < 0 
                      ? Colors.blue.shade700.withOpacity(0.8)
                      : Colors.grey.shade800.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _currentRotation < 0 
                        ? Colors.blue.shade400 
                        : Colors.grey.shade600,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.rotate_left,
                  color: _currentRotation < 0 
                      ? Colors.white 
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right rotation button
            GestureDetector(
              onTapDown: (_) => _startRotation(1.0),
              onTapUp: (_) => _stopRotation(),
              onTapCancel: () => _stopRotation(),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _currentRotation > 0 
                      ? Colors.blue.shade700.withOpacity(0.8)
                      : Colors.grey.shade800.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _currentRotation > 0 
                        ? Colors.blue.shade400 
                        : Colors.grey.shade600,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.rotate_right,
                  color: _currentRotation > 0 
                      ? Colors.white 
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 