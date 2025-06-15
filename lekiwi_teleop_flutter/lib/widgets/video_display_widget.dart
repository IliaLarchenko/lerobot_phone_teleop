import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoDisplayWidget extends StatelessWidget {
  final Map<String, dynamic>? feedbackData;
  final String cameraKey;

  const VideoDisplayWidget({
    super.key,
    required this.feedbackData,
    required this.cameraKey,
  });

  @override
  Widget build(BuildContext context) {
    // Get camera data from feedback
    final cameras = feedbackData?['cameras'] as Map<String, dynamic>?;
    final cameraData = cameras?[cameraKey] as String?;

    if (cameraData == null || cameraData.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('No Signal', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Decode base64 image
    try {
      final Uint8List imageBytes = base64Decode(cameraData);
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true, // Prevents blinking on image update
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text('Video Error', style: TextStyle(color: Colors.red)));
        },
      );
    } catch (e) {
      return Center(child: Text('Decoding Error', style: TextStyle(color: Colors.red)));
    }
  }
} 