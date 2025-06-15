# LeKiwi Phone Teleoperation System

This project provides a complete teleoperation system for the LeKiwi mobile manipulator robot using a Flutter mobile app. The system consists of two main components:

1. **Python Teleoperator** - A server-side component that integrates with the lerobot library
2. **Flutter Mobile App** - A cross-platform mobile application for controlling the robot

## Overview

The system allows you to control the LeKiwi robot remotely using your phone with the following features:

- **Virtual Joystick Control** - Touch-based joystick for precise movement control
- **IMU Sensor Control** - Use phone's motion sensors for intuitive robot control
- **Live Video Streaming** - View real-time camera feeds from the robot (up to 2 cameras)
- **Emergency Stop** - Immediate stop functionality for safety
- **WebSocket Communication** - Real-time, low-latency communication between phone and robot
- **Cross-Platform** - Works on both Android and iOS

## System Architecture

```
Flutter App <---> Python Teleoperator <---> LeKiwi Robot
  (WiFi)           (WebSocket Server)        (lerobot)
```

## Quick Start

### 1. Set up Python Teleoperator

```bash
./setup.sh
```

Or manually:
```bash
cd python_teleop
pip install -r requirements.txt
python example_phone_teleoperation.py
```

### 2. Build and Install Flutter App

**Prerequisites:**
- Install Flutter: `brew install flutter`
- Install VS Code with Flutter extension

**Build and run:**
```bash
cd lekiwi_teleop_flutter
flutter devices          # List connected devices
flutter run               # Build and run on connected device
```

**For VS Code users:**
1. Open `lekiwi_teleop_flutter` folder in VS Code
2. Press `F5` or use "Run → Start Debugging"
3. Select your device when prompted

## Features

### Robot Control
- **Base Movement**: Forward/backward, left/right, rotation
- **Velocity Control**: Adjustable maximum velocities
- **Dual Control Modes**: Switch between joystick and IMU control
- **Emergency Stop**: Immediate safety stop

### Video Streaming
- **Real-time Video**: JPEG-compressed video streams
- **Dual Camera Support**: Side-by-side camera feeds
- **Adjustable Quality**: Configurable video quality and frame rate

### Modern Flutter UI
- **Dark Theme**: Optimized for robot teleoperation
- **Landscape Mode**: Fullscreen experience
- **Responsive Design**: Adapts to different screen sizes
- **Hot Reload**: Instant development feedback

## Directory Structure

```
lerobot_phone_teleop/
├── python_teleop/           # Python server component
│   ├── phone_teleop/        # Phone teleoperator package
│   ├── example_phone_teleoperation.py
│   └── requirements.txt
├── lekiwi_teleop_flutter/   # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart        # App entry point
│   │   ├── screens/         # UI screens
│   │   ├── widgets/         # UI components
│   │   └── services/        # Business logic
│   └── pubspec.yaml         # Flutter dependencies
├── setup.sh                 # Quick setup script
└── README.md
```

## Requirements

### Python Side
- Python 3.8+
- lerobot library
- websockets, opencv-python, numpy, torch, rerun-sdk

### Flutter Side
- Flutter 3.16+
- Android 7.0+ (API 24) or iOS 12+
- WiFi connection to same network as Python server

## Configuration

### Python Configuration
Edit the phone teleoperator configuration in your script:

```python
phone_config = PhoneTeleopConfig(
    server_host="0.0.0.0",          # Listen on all interfaces
    server_port=8080,               # WebSocket port
    max_linear_velocity=0.5,        # m/s
    max_angular_velocity=1.0,       # rad/s
    video_quality=80,               # JPEG quality (0-100)
    video_fps=30                    # Video frame rate
)
```

### Flutter Configuration
The app allows you to:
- Enter server IP address (automatically saved)
- Switch between joystick and IMU control modes
- View connection status and video feeds in real-time

## Usage

1. **Start the Python server** on your laptop connected to the robot
2. **Run the Flutter app** on your phone:
   ```bash
   cd lekiwi_teleop_flutter
   flutter run
   ```
3. **Enter the server IP address** (your laptop's IP on the WiFi network)
4. **Connect** and start controlling the robot!

### Control Modes

#### Joystick Mode
- Use the virtual joystick on screen
- Drag the blue knob to control movement
- Forward/backward controls robot's forward/backward movement
- Left/right controls robot's sideways movement

#### IMU Mode
- Tilt the phone to control the robot
- Phone orientation directly translates to robot movement
- Visual orientation indicator shows current tilt angles
- More intuitive for some users

## Development

### Flutter Development
```bash
# Hot reload during development
flutter run

# Build for release
flutter build apk          # Android
flutter build ios          # iOS

# Run tests
flutter test
```

### VS Code Integration
1. Install Flutter and Dart extensions
2. Open project folder in VS Code
3. Use `F5` for debugging with hot reload
4. Full IntelliSense and debugging support

### Extending the Python Teleoperator
The `PhoneTeleop` class follows the same pattern as other lerobot teleoperators. You can extend it to:
- Add more control commands
- Implement haptic feedback
- Add more sensor data processing

### Extending the Flutter App
The Flutter app is built with clean architecture:
- `screens/` - UI screens and layouts
- `widgets/` - Reusable UI components
- `services/` - Business logic and communication
- Easy to add new features and maintain

## Troubleshooting

### Connection Issues
- Ensure both devices are on the same WiFi network
- Check if firewall is blocking port 8080
- Verify the IP address is correct
- Check Flutter app logs: `flutter logs`

### Video Not Showing
- Check robot camera connections
- Verify video encoding in robot observation data
- Monitor Python server logs for errors

### Performance Issues
- Reduce video quality or frame rate
- Check WiFi signal strength
- Close other network-intensive applications
- Use `flutter run --release` for better performance

### Flutter Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check Flutter installation
flutter doctor
```

## Advantages of Flutter

✅ **Cross-Platform**: Single codebase for Android and iOS
✅ **Hot Reload**: Instant feedback during development
✅ **VS Code Integration**: Excellent development experience
✅ **Modern UI**: Beautiful, responsive interface
✅ **Performance**: Native performance on both platforms
✅ **Easy Deployment**: Simple build and distribution

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with `flutter test`
5. Submit a pull request

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the Flutter documentation
3. Check the lerobot documentation
4. Open an issue on the repository

---

**Note**: This implementation focuses on base robot control using Flutter for modern mobile development. You can extend it to include manipulator control, additional sensors, and more advanced features as needed. 