import 'package:flutter/material.dart';

class IMUControlWidget extends StatelessWidget {
  final bool useIMU;
  final ValueChanged<bool> onToggle;

  const IMUControlWidget({
    super.key,
    required this.useIMU,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: useIMU ? Colors.blue.shade400 : Colors.grey.shade700, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.screen_rotation, color: useIMU ? Colors.blue.shade300 : Colors.white),
              const SizedBox(width: 8),
              const Text(
                'IMU Control',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Switch(
            value: useIMU,
            onChanged: onToggle,
            activeTrackColor: Colors.blue.shade700,
            activeColor: Colors.blue.shade300,
          ),
        ],
      ),
    );
  }
} 