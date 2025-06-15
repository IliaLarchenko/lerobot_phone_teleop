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
              // For now, we only receive control commands, not display them
               _messageController.add(data);
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

  void sendFeedback(Map<String, dynamic> feedbackData) {
    if (!isConnected) return;
    final message = {
      'type': 'feedback',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...feedbackData,
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