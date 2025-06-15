import 'package:flutter/material.dart';
import 'dart:math' as math;

class IMUWidget extends StatelessWidget {
  final double roll;
  final double pitch;
  final double yaw;

  const IMUWidget({
    super.key,
    required this.roll,
    required this.pitch,
    required this.yaw,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[700]!, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sensors,
                  color: Colors.blue[400],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'IMU Control Active',
                  style: TextStyle(
                    color: Colors.blue[400],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Orientation Visualization
            Container(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: OrientationPainter(
                  roll: roll,
                  pitch: pitch,
                ),
                size: const Size(120, 120),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // IMU Values
            Column(
              children: [
                _buildIMUValue('Roll', roll, Colors.red),
                const SizedBox(height: 8),
                _buildIMUValue('Pitch', pitch, Colors.green),
                const SizedBox(height: 8),
                _buildIMUValue('Yaw', yaw, Colors.blue),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    'Tilt your phone to control the robot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Forward/Back: Tilt forward/backward\nLeft/Right: Tilt left/right',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIMUValue(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          width: 80,
          child: Text(
            '${value.toStringAsFixed(1)}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class OrientationPainter extends CustomPainter {
  final double roll;
  final double pitch;

  OrientationPainter({
    required this.roll,
    required this.pitch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw outer circle (horizon)
    final outerPaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius, outerPaint);

    // Draw horizon line (affected by roll)
    final rollRadians = roll * math.pi / 180;
    final horizonPaint = Paint()
      ..color = Colors.blue[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final horizonStart = Offset(
      center.dx - radius * math.cos(rollRadians + math.pi / 2),
      center.dy - radius * math.sin(rollRadians + math.pi / 2),
    );
    final horizonEnd = Offset(
      center.dx + radius * math.cos(rollRadians + math.pi / 2),
      center.dy + radius * math.sin(rollRadians + math.pi / 2),
    );
    
    canvas.drawLine(horizonStart, horizonEnd, horizonPaint);

    // Draw pitch indicator (vertical offset from center)
    final pitchOffset = (pitch / 90) * radius * 0.8;
    final pitchY = center.dy - pitchOffset;
    
    final pitchPaint = Paint()
      ..color = Colors.green[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(center.dx - 20, pitchY),
      Offset(center.dx + 20, pitchY),
      pitchPaint,
    );

    // Draw center crosshair
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(center.dx - 15, center.dy),
      Offset(center.dx + 15, center.dy),
      centerPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 15),
      Offset(center.dx, center.dy + 15),
      centerPaint,
    );

    // Draw center dot
    final centerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 3, centerDotPaint);

    // Draw roll angle indicator
    final rollIndicatorPaint = Paint()
      ..color = Colors.red[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rollIndicatorRadius = radius + 15;
    final rollIndicatorStart = Offset(
      center.dx + rollIndicatorRadius * math.cos(-math.pi / 2),
      center.dy + rollIndicatorRadius * math.sin(-math.pi / 2),
    );
    final rollIndicatorEnd = Offset(
      center.dx + rollIndicatorRadius * math.cos(rollRadians - math.pi / 2),
      center.dy + rollIndicatorRadius * math.sin(rollRadians - math.pi / 2),
    );

    canvas.drawLine(center, rollIndicatorStart, rollIndicatorPaint);
    canvas.drawLine(center, rollIndicatorEnd, rollIndicatorPaint);
    
    // Draw arc between the two lines
    final arcRect = Rect.fromCircle(center: center, radius: rollIndicatorRadius * 0.7);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      rollRadians,
      false,
      rollIndicatorPaint,
    );
  }

  @override
  bool shouldRepaint(OrientationPainter oldDelegate) {
    return oldDelegate.roll != roll || oldDelegate.pitch != pitch;
  }
} 