import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/websocket_service.dart';
import '../widgets/connection_widget.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/video_display_widget.dart';
import '../widgets/arm_rotation_joystick_widget.dart';
import '../widgets/manipulator_joysticks_widget.dart';

enum VideoDisplayMode { dual, frontFullscreen, wristFullscreen }

class TeleopScreen extends StatefulWidget {
  const TeleopScreen({super.key});

  @override
  State<TeleopScreen> createState() => _TeleopScreenState();
}

class _TeleopScreenState extends State<TeleopScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  
  // State
  bool _useIMU = false;
  bool _manipulatorMode = false; // New mode toggle
  VideoDisplayMode _videoDisplayMode = VideoDisplayMode.dual;
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

                  // Robot State - top right corner (moved down for better visibility)
                  Positioned(
                    top: 12, // Moved down from -4 to 12
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildCompactStateDisplay(),
                        const SizedBox(height: 8),
                        _buildModeSwitch(),
                      ],
                    ),
                  ),

                  // Conditional control layout based on mode
                  if (!_manipulatorMode) ..._buildBaseControls(),
                  if (_manipulatorMode) ..._buildManipulatorControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBaseControls() {
    return [
      // Bottom left - Joystick (closer to corner)
      Positioned(
        bottom: 4, // Closer to corner
        left: 4,   // Closer to corner
        child: JoystickWidget(
          size: 200,
          onMove: (x, y) {
            if (!_useIMU) {
              _webSocketService.sendJoystickInput(x, y);
            }
          },
        ),
      ),

      // Bottom right - Arm/Rotation Joystick (closer to corner)
      Positioned(
        bottom: 4, // Closer to corner
        right: 4,  // Closer to corner
        child: ArmRotationJoystickWidget(
          size: 200,
          onMove: (rotation, wristFlex) {
            _webSocketService.sendArmRotationInput(rotation, wristFlex);
          },
        ),
      ),
    ];
  }

  List<Widget> _buildManipulatorControls() {
    return [
      // Manipulator joysticks - 3 on left, 3 on right
      Positioned(
        bottom: 20,
        left: 8,
        child: ManipulatorJoysticksWidget(
          side: 'left', // Controls joints 0, 1, 2
          onJointMove: (jointIndex, value) {
            _webSocketService.sendManipulatorJointInput(jointIndex, value);
          },
        ),
      ),
      
      Positioned(
        bottom: 20,
        right: 8,
        child: ManipulatorJoysticksWidget(
          side: 'right', // Controls joints 3, 4, 5
          onJointMove: (jointIndex, value) {
            _webSocketService.sendManipulatorJointInput(jointIndex + 3, value);
          },
        ),
      ),
    ];
  }

  Widget _buildModeSwitch() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Arm',
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: _manipulatorMode,
            onChanged: (value) => setState(() => _manipulatorMode = value),
            activeTrackColor: Colors.blue.shade700,
            activeColor: Colors.blue.shade300,
            inactiveTrackColor: Colors.grey.shade600,
            inactiveThumbColor: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoBackground() {
    switch (_videoDisplayMode) {
      case VideoDisplayMode.dual:
        return Row(
          children: [
            // Front camera (left side)
            Expanded(
              child: VideoDisplayWidget(
                observationData: _latestObservationData, 
                cameraKey: 'front',
                onTitleTap: () => setState(() => _videoDisplayMode = VideoDisplayMode.frontFullscreen),
              )
            ),
            // Wrist camera (right side)  
            Expanded(
              child: VideoDisplayWidget(
                observationData: _latestObservationData, 
                cameraKey: 'wrist',
                onTitleTap: () => setState(() => _videoDisplayMode = VideoDisplayMode.wristFullscreen),
              )
            ),
          ],
        );
      case VideoDisplayMode.frontFullscreen:
        return Stack(
          children: [
            // Front camera fullscreen
            VideoDisplayWidget(
              observationData: _latestObservationData, 
              cameraKey: 'front',
              onTitleTap: () => setState(() => _videoDisplayMode = VideoDisplayMode.dual),
            ),
            // Wrist camera thumbnail in top-left
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 120,
                height: 90,
                child: VideoDisplayWidget(
                  observationData: _latestObservationData, 
                  cameraKey: 'wrist',
                  isThumbnail: true,
                  onTitleTap: () => setState(() => _videoDisplayMode = VideoDisplayMode.dual),
                ),
              ),
            ),
          ],
        );
      case VideoDisplayMode.wristFullscreen:
        return Stack(
          children: [
            // Wrist camera fullscreen
            VideoDisplayWidget(
              observationData: _latestObservationData, 
              cameraKey: 'wrist',
              onTitleTap: () => setState(() => _videoDisplayMode = VideoDisplayMode.dual),
            ),
            // Front camera thumbnail in top-left
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 120,
                height: 90,
                child: VideoDisplayWidget(
                  observationData: _latestObservationData, 
                  cameraKey: 'front',
                  isThumbnail: true,
                  onTitleTap: () => setState(() => _videoDisplayMode = VideoDisplayMode.dual),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildCompactStateDisplay() {
    final data = _latestObservationData?['data'] as Map<String, dynamic>?;
    final stateData = data?['observation.state'] as Map<String, dynamic>?;
    
    if (stateData == null || stateData['type'] != 'state') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200]?.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'No State',
          style: TextStyle(
            color: Colors.grey[800], 
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final List<dynamic> stateVector = stateData['data'] as List<dynamic>;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200]?.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'ARM: ${stateVector.take(6).map((v) => _formatFixed(v, 1)).join(" ")}',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'BASE: ${stateVector.skip(6).take(3).map((v) => _formatFixed(v, 2)).join(" ")}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 8,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Fixed-width number formatting to prevent jumping
  String _formatFixed(dynamic value, int decimals) {
    if (value is num) {
      String formatted = value.toStringAsFixed(decimals);
      // Pad positive numbers with space to match negative numbers width
      if (value >= 0 && decimals == 1) {
        return ' $formatted'; // Extra space for 1 decimal
      } else if (value >= 0 && decimals == 2) {
        return ' $formatted'; // Extra space for 2 decimals
      }
      return formatted;
    }
    return value.toString();
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
} 