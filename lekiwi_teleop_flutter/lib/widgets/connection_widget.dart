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

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green.shade50 : Colors.blue.shade50,
            border: Border.all(
              color: isConnected ? Colors.green.shade300 : Colors.blue.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isConnected
              ? _buildConnectedWidget()
              : _buildListeningWidget(),
        );
      },
    );
  }

  Widget _buildConnectedWidget() {
    return Row(
      children: [
        Icon(Icons.wifi_tethering, color: Colors.green.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Robot Connected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade800,
                ),
              ),
              Text(
                'Ready to receive commands.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListeningWidget() {
    return StreamBuilder<String?>(
      stream: webSocketService.ipStream,
      builder: (context, ipSnapshot) {
        final ipAddress = ipSnapshot.data;
        if (ipAddress == null) {
          return const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Initializing server...'),
            ],
          );
        }

        return Row(
          children: [
            Icon(Icons.radar, color: Colors.blue.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Listening for Robot...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    'Connect Python to: ws://$ipAddress:8080',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
} 