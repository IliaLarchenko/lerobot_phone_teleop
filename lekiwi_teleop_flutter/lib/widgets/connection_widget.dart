import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class ConnectionWidget extends StatelessWidget {
  final WebSocketService webSocketService;

  const ConnectionWidget({
    super.key,
    required this.webSocketService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: webSocketService.connectionStream,
      initialData: false,
      builder: (context, connectionSnapshot) {
        final isConnected = connectionSnapshot.data ?? false;

        // Only show when NOT connected to save space
        if (isConnected) {
          return const SizedBox.shrink(); // Hide when connected
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.1),
            border: Border.all(
              color: Colors.blue.shade300.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildListeningWidget(),
        );
      },
    );
  }

  Widget _buildListeningWidget() {
    return StreamBuilder<String?>(
      stream: webSocketService.ipStream,
      builder: (context, ipSnapshot) {
        final ipAddress = ipSnapshot.data;
        if (ipAddress == null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Initializing server...',
                style: TextStyle(color: Colors.blue.shade300, fontSize: 14),
              ),
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, color: Colors.blue.shade300, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Waiting for Robot...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade300,
                  ),
                ),
                Text(
                  'ws://$ipAddress:8080',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.blue.shade200,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
} 