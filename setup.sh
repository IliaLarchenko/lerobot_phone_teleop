#!/bin/bash

echo "=== LeKiwi Phone Teleoperation Setup ==="
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or later."
    exit 1
fi

echo "✅ Python 3 found: $(python3 --version)"

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is not installed. Please install pip."
    exit 1
fi

echo "✅ pip3 found"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter is not installed."
    echo "📱 To install Flutter, run: brew install flutter"
    echo "   Or visit: https://docs.flutter.dev/get-started/install"
    echo ""
    read -p "Continue with Python setup only? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Flutter found: $(flutter --version | head -n 1)"
fi

# Navigate to python_teleop directory
cd python_teleop

echo ""
echo "📦 Installing Python dependencies..."
pip3 install -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✅ Python dependencies installed successfully!"
else
    echo "❌ Failed to install Python dependencies. Please check your Python environment."
    exit 1
fi

# Set up Flutter project if Flutter is available
if command -v flutter &> /dev/null; then
    echo ""
    echo "📱 Setting up Flutter project..."
    cd ../lekiwi_teleop_flutter
    
    echo "Getting Flutter dependencies..."
    flutter pub get
    
    if [ $? -eq 0 ]; then
        echo "✅ Flutter dependencies installed successfully!"
        
        echo ""
        echo "🔍 Checking connected devices..."
        flutter devices
        
        echo ""
        echo "📱 Flutter app is ready! To run it:"
        echo "   cd lekiwi_teleop_flutter"
        echo "   flutter run"
        echo ""
        echo "💡 For VS Code users:"
        echo "   1. Open 'lekiwi_teleop_flutter' folder in VS Code"
        echo "   2. Press F5 to run with debugging"
        echo "   3. Enjoy hot reload for instant changes!"
    else
        echo "❌ Failed to set up Flutter project."
    fi
    
    cd ..
fi

echo ""
echo "🤖 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Make sure your LeKiwi robot is connected and accessible"
echo "2. Update the robot IP in python_teleop/example_phone_teleoperation.py if needed"
echo "3. Start the Python server:"
echo "   python3 python_teleop/example_phone_teleoperation.py"
echo "4. Run the Flutter app on your phone:"
echo "   cd lekiwi_teleop_flutter && flutter run"
echo "5. Enter your laptop's IP address in the app and connect"
echo ""
echo "📱 To find your laptop's IP address, run:"
echo "   On macOS/Linux: ifconfig | grep inet"
echo "   On Windows: ipconfig"
echo ""
echo "🚀 Happy teleoperating with Flutter!" 