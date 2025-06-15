import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WebSocketService {
  HttpServer? _server;
  WebSocketChannel? _channel;

  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();
  final StreamController<String?> _ipController = StreamController.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String?> get ipStream => _ipController.stream;

  bool get isConnected => _channel != null;
  String? _deviceIp;

  // Current velocity commands to send to Python
  double _xVel = 0.0;
  double _yVel = 0.0;
  double _thetaVel = 0.0;
  double _wristFlexVel = 0.0;

  // Manipulator joint velocities (6 joints)
  List<double> _manipulatorJointVel = List.filled(6, 0.0);

  // Speed limits
  static const double maxLinearVel = 0.25;
  static const double maxRotationVel = 60.0;
  static const double maxWristFlexVel = 1.0;

  Future<void> startServer() async {
    if (_server != null) {
      debugPrint('Server already running.');
      return;
    }

    try {
      _deviceIp = await NetworkInfo().getWifiIP();
      _ipController.add(_deviceIp);
      debugPrint('📱 Phone IP: $_deviceIp');

      var handler = webSocketHandler((WebSocketChannel webSocket) {
        debugPrint('🤖 Robot connected!');
        _channel = webSocket;
        _connectionController.add(true);

        _channel!.stream.listen(
          (message) {
            try {
              final data = json.decode(message);
              debugPrint('📨 Received from robot: ${data['type']}');
              
              // Handle observation data from Python
              if (data['type'] == 'observation') {
                _messageController.add(data);
              }
            } catch (e) {
              debugPrint('❌ Error decoding robot message: $e');
            }
          },
          onDone: () {
            debugPrint('🤖 Robot disconnected.');
            _connectionController.add(false);
            _channel = null;
          },
          onError: (error) {
            debugPrint('❌ Robot connection error: $error');
            _connectionController.add(false);
            _channel = null;
          },
        );
      });

      _server = await shelf_io.serve(handler, _deviceIp ?? '0.0.0.0', 8080);
      debugPrint('✅ WebSocket server started on ws://${_server!.address.host}:${_server!.port}');
    } catch (e) {
      debugPrint('❌ Error starting server: $e');
    }
  }

  // Apply deadzone logic: 0-15% = 0, 15-30% = proportional 0-30%, 30%+ = actual
  double _applyDeadzone(double value) {
    final absValue = value.abs();
    if (absValue < 0.15) {
      return 0.0;
    } else if (absValue < 0.30) {
      // Scale from 0.15-0.30 range to 0.0-0.30 range
      final scaledValue = (absValue - 0.15) / 0.15 * 0.30;
      return value > 0 ? scaledValue : -scaledValue;
    } else {
      return value;
    }
  }

  // Send velocity commands to Python (from joystick input)
  void sendJoystickInput(double x, double y) {
    // Apply deadzone first
    final deadzoneX = _applyDeadzone(x);
    final deadzoneY = _applyDeadzone(y);
    
    // Convert joystick input (-1 to 1) to velocity commands
    // y controls forward/backward (x.vel), x controls left/right (y.vel)
    _xVel = deadzoneY * maxLinearVel; // Forward/backward
    _yVel = -deadzoneX * maxLinearVel; // Left/right (inverted for intuitive control)
    // Don't reset _thetaVel here - keep rotation independent
    
    _sendActionMessage();
  }

  // Send rotation and wrist flex commands (from right joystick)
  void sendArmRotationInput(double rotation, double wristFlex) {
    // Apply deadzone first
    final deadzoneRotation = _applyDeadzone(rotation);
    final deadzoneWristFlex = _applyDeadzone(wristFlex);
    
    // Fix inversion issues: negate both rotation and wrist flex
    _thetaVel = -deadzoneRotation * maxRotationVel; // Fix rotation inversion
    _wristFlexVel = -deadzoneWristFlex * maxWristFlexVel; // Fix wrist flex inversion
    _sendActionMessage();
  }

  // Send rotation command (from IMU)
  void sendRotationInput(double theta) {
    _thetaVel = theta * maxRotationVel;
    _sendActionMessage();
  }

  // Send manipulator joint input (for manipulator mode)
  void sendManipulatorJointInput(int jointIndex, double value) {
    if (jointIndex >= 0 && jointIndex < 6) {
      _manipulatorJointVel[jointIndex] = value; // Max speed is 1 as specified
      debugPrint('🦾 Joint $jointIndex = ${value.toStringAsFixed(2)} | All joints: ${_manipulatorJointVel.map((v) => v.toStringAsFixed(2)).join(", ")}');
      
      // Always send as action message (not manipulator_action)
      _sendActionMessage();
    }
  }

  // Update specific velocity component
  void updateXVel(double xVel) {
    _xVel = xVel;
    _sendActionMessage();
  }

  void updateYVel(double yVel) {
    _yVel = yVel;
    _sendActionMessage();
  }

  void updateThetaVel(double thetaVel) {
    _thetaVel = thetaVel;
    _sendActionMessage();
  }

  void updateWristFlexVel(double wristFlexVel) {
    _wristFlexVel = wristFlexVel;
    _sendActionMessage();
  }

  // Emergency stop - reset all velocities
  void sendEmergencyStop() {
    _xVel = 0.0;
    _yVel = 0.0;
    _thetaVel = 0.0;
    _wristFlexVel = 0.0;
    _manipulatorJointVel.fillRange(0, 6, 0.0);
    _sendActionMessage();
  }

  void _sendActionMessage() {
    if (!isConnected) return;
    
    // Check if any manipulator joints are active
    bool manipulatorActive = _manipulatorJointVel.any((vel) => vel != 0.0);
    
    final message = {
      'type': 'action',
      'x.vel': _xVel,
      'y.vel': _yVel,
      'theta.vel': _thetaVel,
      // Wrist flex: use manipulator if active, otherwise use base mode
      'wrist_flex.vel': manipulatorActive ? _manipulatorJointVel[3] : _wristFlexVel,
      // All manipulator joint velocities
      'shoulder_pan.vel': _manipulatorJointVel[0],
      'shoulder_lift.vel': _manipulatorJointVel[1],
      'elbow_flex.vel': _manipulatorJointVel[2],
      'wrist_roll.vel': _manipulatorJointVel[4],
      'gripper.vel': _manipulatorJointVel[5],
    };
    
    debugPrint('📤 Sending action: ${json.encode(message)}');
    _sendMessage(message);
  }

  void _sendManipulatorActionMessage() {
    // Remove this method - we don't need it anymore
    // Everything goes through _sendActionMessage()
  }

  void _sendMessage(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(json.encode(message));
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
    }
  }

  Future<void> stopServer() async {
    debugPrint('🔌 Stopping server...');
    await _channel?.sink.close();
    await _server?.close(force: true);
    _server = null;
    _channel = null;
    _connectionController.add(false);
    debugPrint('🛑 Server stopped.');
  }

  void dispose() {
    stopServer();
    _messageController.close();
    _connectionController.close();
    _ipController.close();
  }
} 