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

  // Send velocity commands to Python (from joystick input)
  void sendJoystickInput(double x, double y) {
    // Convert joystick input (-1 to 1) to velocity commands
    // y controls forward/backward (x.vel), x controls left/right (y.vel)
    _xVel = y * 0.3; // Forward/backward, max 0.3 m/s
    _yVel = -x * 0.3; // Left/right, max 0.3 m/s (inverted for intuitive control)
    // Don't reset _thetaVel here - keep rotation independent
    
    _sendActionMessage();
  }

  // Send rotation command (from theta controller or IMU)
  void sendRotationInput(double theta) {
    _thetaVel = theta; // Already limited in the widget
    _sendActionMessage();
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

  // Emergency stop - reset all velocities
  void sendEmergencyStop() {
    _xVel = 0.0;
    _yVel = 0.0;
    _thetaVel = 0.0;
    _sendActionMessage();
  }

  void _sendActionMessage() {
    if (!isConnected) return;
    
    final message = {
      'type': 'action',
      'x.vel': _xVel,
      'y.vel': _yVel,
      'theta.vel': _thetaVel,
    };
    
    _sendMessage(message);
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