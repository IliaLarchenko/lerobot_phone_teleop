import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoDisplayWidget extends StatelessWidget {
  final Map<String, dynamic>? observationData;
  final String cameraKey; // Should be 'front' or 'wrist'

  const VideoDisplayWidget({
    super.key,
    required this.observationData,
    required this.cameraKey,
  });

  @override
  Widget build(BuildContext context) {
    // Extract observation data from the message
    final data = observationData?['data'] as Map<String, dynamic>?;
    final imageKey = 'observation.images.$cameraKey';
    final imageData = data?[imageKey] as Map<String, dynamic>?;
    
    if (imageData == null || imageData['type'] != 'image') {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('${cameraKey.toUpperCase()} Camera', 
                   style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('No Signal', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      );
    }

    // Decode base64 image data
    try {
      final String base64String = imageData['data'] as String;
      final Uint8List imageBytes = base64Decode(base64String);
      
      return Stack(
        children: [
          Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true, // Prevents blinking on image update
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text('${cameraKey.toUpperCase()} Error', 
                           style: TextStyle(color: Colors.red))
              );
            },
          ),
          // Camera label overlay
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                cameraKey.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 48, color: Colors.red),
              SizedBox(height: 8),
              Text('${cameraKey.toUpperCase()} Camera', 
                   style: TextStyle(color: Colors.red, fontSize: 12)),
              Text('Decode Error', style: TextStyle(color: Colors.red, fontSize: 10)),
            ],
          ),
        ),
      );
    }
  }
} 