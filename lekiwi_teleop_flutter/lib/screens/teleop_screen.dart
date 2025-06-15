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
  Map<String, dynamic>? _latestFeedbackData;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  @override
  void initState() {
    super.initState();
    _webSocketService.startServer();
    _webSocketService.messageStream.listen((message) {
      if (message['type'] == 'feedback' && mounted) {
        setState(() => _latestFeedbackData = message);
      }
    });
    _initSensors();
  }

  void _initSensors() {
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      if (_useIMU) {
        // Send gyroscope data for robot control
        _webSocketService.sendFeedback({
          'type': 'imu',
          'roll': event.y, // Corresponds to roll on a phone held in landscape
          'pitch': event.x, // Corresponds to pitch
          'yaw': event.z,
          'use_imu': true,
        });
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
        Expanded(child: VideoDisplayWidget(feedbackData: _latestFeedbackData, cameraKey: 'camera1')),
        Expanded(child: VideoDisplayWidget(feedbackData: _latestFeedbackData, cameraKey: 'camera2')),
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
                  _webSocketService.sendFeedback({'type': 'joystick', 'x': x, 'y': y});
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
                // Emergency Stop
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _webSocketService.sendFeedback({'type': 'emergency_stop'}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700]?.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text('STOP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
              ],
            ),
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