import 'package:flutter/material.dart';
import 'dart:convert';

class VideoWidget extends StatelessWidget {
  final String? videoData;
  final String label;

  const VideoWidget({
    super.key,
    this.videoData,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[600]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Video content
            SizedBox.expand(
              child: videoData != null
                  ? _buildVideoFrame()
                  : _buildNoVideoPlaceholder(),
            ),
            
            // Label overlay
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            // Connection indicator
            if (videoData != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFrame() {
    try {
      final bytes = base64Decode(videoData!);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true, // Smooth video transitions
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder('Image decode error');
        },
      );
    } catch (e) {
      return _buildErrorPlaceholder('Invalid video data');
    }
  }

  Widget _buildNoVideoPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'No Video Signal',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(String errorMessage) {
    return Container(
      color: Colors.red[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            Text(
              'Video Error',
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 