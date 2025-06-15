import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/websocket_service.dart';
import '../widgets/connection_widget.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/video_display_widget.dart';
import '../widgets/imu_control_widget.dart';
import '../widgets/theta_control_widget.dart';

class TeleopScreen extends StatefulWidget {
  const TeleopScreen({super.key});

  @override
  State<TeleopScreen> createState() => _TeleopScreenState();
}

class _TeleopScreenState extends State<TeleopScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  
  // State
  bool _useIMU = false;
  Map<String, dynamic>? _latestObservationData;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  @override
  void initState() {
    super.initState();
    _webSocketService.startServer();
    _webSocketService.messageStream.listen((message) {
      if (message['type'] == 'observation' && mounted) {
        setState(() => _latestObservationData = message);
      }
    });
    _initSensors();
  }

  void _initSensors() {
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      if (_useIMU) {
        // Use gyroscope for rotation control
        // event.z corresponds to yaw rotation when phone is in landscape
        _webSocketService.sendRotationInput(event.z);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Video Feeds
          _buildVideoBackground(),

          // Foreground UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  // Top bar with connection status (when not connected)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ConnectionWidget(webSocketService: _webSocketService),
                  ),

                  // Top middle - Robot State
                  Positioned(
                    top: 16,
                    left: 100,
                    right: 100,
                    child: _buildStateDisplay(),
                  ),

                  // Top right - IMU Control
                  Positioned(
                    top: 16,
                    right: 0,
                    child: IMUControlWidget(
                      useIMU: _useIMU,
                      onToggle: (value) => setState(() => _useIMU = value),
                    ),
                  ),

                  // Bottom left - Joystick
                  Positioned(
                    bottom: 16,
                    left: 0,
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: JoystickWidget(
                        onMove: (x, y) {
                          if (!_useIMU) {
                            _webSocketService.sendJoystickInput(x, y);
                          }
                        },
                      ),
                    ),
                  ),

                  // Bottom right - Theta Control
                  Positioned(
                    bottom: 80,
                    right: 0,
                    child: ThetaControlWidget(
                      onRotationChange: (theta) {
                        _webSocketService.sendRotationInput(theta);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground() {
    return Row(
      children: [
        // Front camera (left side)
        Expanded(
          child: VideoDisplayWidget(
            observationData: _latestObservationData, 
            cameraKey: 'front'
          )
        ),
        // Wrist camera (right side)  
        Expanded(
          child: VideoDisplayWidget(
            observationData: _latestObservationData, 
            cameraKey: 'wrist'
          )
        ),
      ],
    );
  }

  Widget _buildStateDisplay() {
    final data = _latestObservationData?['data'] as Map<String, dynamic>?;
    final stateData = data?['observation.state'] as Map<String, dynamic>?;
    
    if (stateData == null || stateData['type'] != 'state') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No robot state',
          style: TextStyle(color: Colors.grey, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      );
    }

    final List<dynamic> stateVector = stateData['data'] as List<dynamic>;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[900]?.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade600.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ROBOT STATE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Arm: ${stateVector.take(6).map((v) => v.toStringAsFixed(1)).join(", ")}',
            style: TextStyle(color: Colors.grey[300], fontSize: 9),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Base: ${stateVector.skip(6).take(3).map((v) => v.toStringAsFixed(2)).join(", ")}',
            style: TextStyle(color: Colors.grey[300], fontSize: 9),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
} 