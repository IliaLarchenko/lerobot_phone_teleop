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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.screen_rotation,
          color: useIMU ? Colors.blue.shade300 : Colors.grey.shade400,
          size: 20,
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: useIMU,
            onChanged: onToggle,
            activeTrackColor: Colors.blue.shade700,
            activeColor: Colors.blue.shade300,
            inactiveTrackColor: Colors.grey.shade600,
            inactiveThumbColor: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
} 