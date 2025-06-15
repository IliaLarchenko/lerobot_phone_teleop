import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/teleop_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Keep screen on during teleoperation
  WakelockPlus.enable();
  
  // Set landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Hide system UI for fullscreen experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Request necessary permissions
  await _requestPermissions();
  
  runApp(const LeKiwiTeleopApp());
}

Future<void> _requestPermissions() async {
  // Request sensor permissions (some Android devices need this)
  await Permission.sensors.request();
}

class LeKiwiTeleopApp extends StatelessWidget {
  const LeKiwiTeleopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeKiwi Teleop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Dark theme for robot teleoperation
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        toggleButtonsTheme: ToggleButtonsThemeData(
          selectedColor: Colors.white,
          fillColor: Colors.blue[700],
          borderColor: Colors.grey[600],
          selectedBorderColor: Colors.blue[700],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      home: const TeleopScreen(),
    );
  }
}
