import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoDisplayWidget extends StatelessWidget {
  final Map<String, dynamic>? observationData;
  final String cameraKey; // Should be 'front' or 'wrist'
  final bool isThumbnail; // New parameter for thumbnail mode
  final VoidCallback? onTitleTap; // New parameter for click handling

  const VideoDisplayWidget({
    super.key,
    required this.observationData,
    required this.cameraKey,
    this.isThumbnail = false,
    this.onTitleTap,
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
              Icon(
                Icons.videocam_off, 
                size: isThumbnail ? 24 : 48, 
                color: Colors.grey
              ),
              SizedBox(height: isThumbnail ? 4 : 8),
              Text(
                '${cameraKey.toUpperCase()} Camera', 
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: isThumbnail ? 8 : 12
                )
              ),
              Text(
                'No Signal', 
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: isThumbnail ? 6 : 10
                )
              ),
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
                child: Text(
                  '${cameraKey.toUpperCase()} Error', 
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isThumbnail ? 8 : 12,
                  )
                )
              );
            },
          ),
          // Camera label overlay with click handling
          Positioned(
            top: isThumbnail ? 4 : 8,
            left: isThumbnail ? 4 : 8,
            child: GestureDetector(
              onTap: onTitleTap,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isThumbnail ? 4 : 8, 
                  vertical: isThumbnail ? 2 : 4
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cameraKey.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isThumbnail ? 8 : 12,
                    fontWeight: FontWeight.bold,
                  ),
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
              Icon(
                Icons.error, 
                size: isThumbnail ? 24 : 48, 
                color: Colors.red
              ),
              SizedBox(height: isThumbnail ? 4 : 8),
              Text(
                '${cameraKey.toUpperCase()} Camera', 
                style: TextStyle(
                  color: Colors.red, 
                  fontSize: isThumbnail ? 8 : 12
                )
              ),
              Text(
                'Decode Error', 
                style: TextStyle(
                  color: Colors.red, 
                  fontSize: isThumbnail ? 6 : 10
                )
              ),
            ],
          ),
        ),
      );
    }
  }
} 