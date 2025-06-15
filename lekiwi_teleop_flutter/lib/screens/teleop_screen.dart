import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/websocket_service.dart';
import '../widgets/connection_widget.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/video_display_widget.dart';
import '../widgets/imu_control_widget.dart';

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
              child: Column(
                children: [
                  ConnectionWidget(webSocketService: _webSocketService),
                  const Spacer(), // Pushes controls to the bottom
                  _buildControlOverlay(),
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

  Widget _buildControlOverlay() {
    return SizedBox(
      height: 220, // Define a fixed height for the control area
      child: Row(
        children: [
          // Joystick
          Expanded(
            flex: 2,
            child: JoystickWidget(
              onMove: (x, y) {
                if (!_useIMU) {
                  _webSocketService.sendJoystickInput(x, y);
                }
              },
            ),
          ),
          const SizedBox(width: 24),
          // Side panel
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // IMU Control
                IMUControlWidget(
                  useIMU: _useIMU,
                  onToggle: (value) => setState(() => _useIMU = value),
                ),
                // State display
                _buildStateDisplay(),
                // Emergency Stop
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _webSocketService.sendEmergencyStop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700]?.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text(
                      'STOP', 
                      style: TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 18
                      )
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateDisplay() {
    final data = _latestObservationData?['data'] as Map<String, dynamic>?;
    final stateData = data?['observation.state'] as Map<String, dynamic>?;
    
    if (stateData == null || stateData['type'] != 'state') {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No robot state',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    final List<dynamic> stateVector = stateData['data'] as List<dynamic>;
    
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Robot State',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Arm: ${stateVector.take(6).map((v) => v.toStringAsFixed(2)).join(", ")}',
            style: TextStyle(color: Colors.grey[300], fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Base: ${stateVector.skip(6).take(3).map((v) => v.toStringAsFixed(2)).join(", ")}',
            style: TextStyle(color: Colors.grey[300], fontSize: 10),
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