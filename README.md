# LeRobot Phone Teleoperation System

A complete mobile teleoperation system for LeKiwi robots using Flutter, providing intuitive dual-joystick control with real-time video streaming.

## Overview

This system enables remote control of LeKiwi mobile manipulator robots through a Flutter mobile app with advanced control features:

- **Dual-Mode Control**: Base movement + arm control, or full manipulator joint control
- **Real-Time Video Streaming**: Live camera feeds from robot (front + wrist cameras)
- **Advanced Joystick Control**: Deadzone logic, smooth movement, precision control
- **WebSocket Communication**: Low-latency bidirectional communication
- **Cross-Platform**: Single Flutter app for Android and iOS

## Architecture

```
Phone (Flutter App)     Python Client         LeKiwi Robot
    [Server]      <-->     [Client]      <-->    [lerobot]
   WebSocket               WebSocket              Robot API
  192.168.1.x:8080        Auto-connect          Local/Remote
```

**Key Design**: The phone acts as WebSocket server, Python connects as client. This allows the phone to maintain control and automatically handle reconnections.

## Installation

### 1. Move Python Code to LeRobot Library

The Python teleoperator should be integrated into your lerobot installation:

```bash
# Navigate to your lerobot installation
cd /path/to/lerobot

# Copy the phone teleoperator to lerobot teleoperators directory
cp -r /path/to/this/project/python_teleop/phone_teleop lerobot/common/teleoperators/

# The structure should be:
# lerobot/common/teleoperators/phone_teleop/
# ├── __init__.py
# ├── configuration_phone.py
# └── teleop_phone.py
```

### 2. Install Flutter App on Phone

**Prerequisites:**
- Flutter SDK 3.16+ installed
- Android Studio or VS Code with Flutter extension
- Android device (API 24+) or iOS device (iOS 12+)

**Install and run:**
```bash
cd lekiwi_teleop_flutter

# Get dependencies
flutter pub get

# Connect your phone via USB (enable Developer Options & USB Debugging)
flutter devices

# Install and run on your phone
flutter run
```

**For VS Code users:**
1. Open `lekiwi_teleop_flutter` folder in VS Code
2. Connect phone via USB
3. Press `F5` and select your device

## Usage

### 1. Start Phone App

1. Launch the Flutter app on your phone
2. App automatically starts WebSocket server on port 8080
3. Note the IP address displayed (e.g., `ws://192.168.1.102:8080`)

### 2. Create Robot Control Script

Create a Python script in your lerobot project:

```python
from lerobot.common.robots.lekiwi import LeKiwiClient, LeKiwiClientConfig
from lerobot.common.teleoperators.phone_teleop.configuration_phone import PhoneTeleopConfig
from lerobot.common.teleoperators.phone_teleop.teleop_phone import PhoneTeleop

# Robot configuration
robot_config = LeKiwiClientConfig(
    remote_ip="robotpi.local", 
    id="my_robot"
)

# Phone teleoperator configuration
phone_config = PhoneTeleopConfig(
    phone_ip="192.168.1.102",  # Your phone's IP from step 1
    phone_port=8080,
    max_linear_velocity=0.25,
    max_angular_velocity=60.0,
)

# Create and connect
robot = LeKiwiClient(robot_config)
phone_teleop = PhoneTeleop(phone_config)

robot.connect()
phone_teleop.connect()

# Control loop
while True:
    observation = robot.get_observation()
    phone_teleop.send_feedback(observation)  # Send robot data to phone
    
    action = phone_teleop.get_action()       # Get commands from phone
    robot.send_action(action)                # Control robot
```

### 3. Control the Robot

The app provides two control modes:

#### Base Control Mode (Default)
- **Left Joystick**: Base movement (forward/back, left/right)
- **Right Joystick**: Rotation + wrist flex control
- Sends: `x.vel`, `y.vel`, `theta.vel`, `wrist_flex.vel`

#### Manipulator Mode (Toggle "MAN" Switch)
- **6 Horizontal Joysticks**: Individual joint control
  - Left side: Shoulder Pan, Shoulder Lift, Elbow Flex
  - Right side: Wrist Flex, Wrist Roll, Gripper
- Each joystick controls one joint with max velocity ±1
- Base movement commands remain available

## Features

### Advanced Control
- **Deadzone Logic**: 0-15% input = 0 output, smooth scaling 15-30%
- **Fixed Number Display**: Consistent formatting prevents UI jumping
- **Dual Joystick Control**: Independent base movement and arm control
- **Mode Switching**: Easy toggle between base and manipulator control

### Real-Time Feedback
- **Live Video Streams**: Front and wrist camera feeds with adjustable quality
- **Robot State Display**: Real-time joint positions and base velocities
- **Connection Status**: Visual indicators for robot connection state

### Robust Communication
- **Automatic Reconnection**: Python client reconnects if connection drops
- **Low Latency**: WebSocket protocol for real-time control
- **Error Handling**: Graceful handling of network issues

## Configuration

### Phone App Configuration
```dart
// Automatically configured:
phone_ip: "192.168.1.102"  // Your phone's WiFi IP
phone_port: 8080           // WebSocket server port
video_quality: 80          // JPEG compression quality
```

### Python Configuration
```python
PhoneTeleopConfig(
    phone_ip="192.168.1.102",      # Phone's IP address
    phone_port=8080,               # Must match phone app
    connection_timeout_s=10.0,     # Connection timeout
    video_quality=80,              # Video compression
    max_linear_velocity=0.25,      # m/s limit
    max_angular_velocity=60.0,     # deg/s limit
)
```

## Message Protocol

### Phone → Python (Actions)
```json
{
  "type": "action",
  "x.vel": 0.1,
  "y.vel": 0.0,
  "theta.vel": 15.0,
  "wrist_flex.vel": 0.5
}
```

### Python → Phone (Observations)
```json
{
  "type": "observation",
  "data": {
    "observation.state": {"type": "state", "data": [0.1, 0.2, ...]},
    "observation.images.front": {"type": "image", "data": "base64..."},
    "observation.images.wrist": {"type": "image", "data": "base64..."}
  }
}
```

## Directory Structure

```
lerobot_phone_teleop/
├── README.md
├── python_teleop/                    # Move to lerobot/common/teleoperators/
│   └── phone_teleop/
│       ├── __init__.py
│       ├── configuration_phone.py
│       └── teleop_phone.py
└── lekiwi_teleop_flutter/            # Flutter mobile app
    ├── lib/
    │   ├── main.dart
    │   ├── screens/teleop_screen.dart
    │   ├── widgets/
    │   │   ├── joystick_widget.dart
    │   │   ├── arm_rotation_joystick_widget.dart
    │   │   ├── manipulator_joysticks_widget.dart
    │   │   └── video_display_widget.dart
    │   └── services/websocket_service.dart
    └── pubspec.yaml
```

## Technical Details

### Joystick Control Logic
- **Deadzone**: 15% prevents drift, 15-30% smooth ramp-up
- **Coordinate System**: Standard robot conventions (x=forward, y=left, θ=CCW)
- **Update Rate**: 20Hz for smooth control

### Video Streaming
- **Format**: JPEG compression with configurable quality
- **Color Space**: RGB→BGR conversion for proper display
- **Performance**: Optimized for mobile networks

### Connection Management
- **Server Discovery**: Phone displays connection URL
- **Reconnection**: Automatic retry with exponential backoff
- **Timeout Handling**: Graceful degradation on network issues

## Development

### Flutter Development
```bash
# Hot reload during development
flutter run

# Build release APK
flutter build apk

# Run tests
flutter test
```

### Python Integration
```python
# Import in your lerobot scripts
from lerobot.common.teleoperators.phone_teleop import PhoneTeleop, PhoneTeleopConfig

# Use like any other teleoperator
teleop = PhoneTeleop(config)
teleop.connect()
action = teleop.get_action()
```

## Troubleshooting

### Connection Issues
1. **Check WiFi**: Ensure phone and computer on same network
2. **IP Address**: Verify phone IP in app matches Python config
3. **Firewall**: Allow port 8080 on both devices
4. **Router**: Some routers block device-to-device communication

### Control Issues
1. **Deadzone Too High**: Reduce from 15% if needed
2. **Inverted Controls**: Check coordinate system configuration
3. **Lag**: Reduce video quality or check network performance

### Video Issues
1. **No Image**: Check robot camera connections
2. **Poor Quality**: Increase video_quality setting
3. **Color Issues**: Verify RGB/BGR conversion

## Capabilities Summary

✅ **Dual Joystick Control**: Independent base movement and arm control  
✅ **Manipulator Mode**: Individual joint velocity control  
✅ **Real-Time Video**: Dual camera feeds with compression  
✅ **Advanced Input**: Deadzone logic and smooth scaling  
✅ **Robust Networking**: Auto-reconnection and error handling  
✅ **Mobile Optimized**: Flutter UI designed for touchscreen control  
✅ **LeRobot Integration**: Standard teleoperator interface  
✅ **Cross-Platform**: Android and iOS support  

## License

Licensed under the Apache License 2.0.

---

**Note**: This system is designed for research and development use with LeKiwi robots. Ensure proper safety measures when operating real hardware. 