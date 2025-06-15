#!/usr/bin/env python

"""
Example script for phone-based teleoperation of LeKiwi robot.
"""

import argparse
import logging
import time
import numpy as np

from lerobot.common.teleoperators.phone_teleop.teleop_phone import PhoneTeleop, PhoneTeleopConfig

# Configure logging
logging.basicConfig(level=logging.INFO)

def main():
    parser = argparse.ArgumentParser(description='Phone-based teleoperation')
    parser.add_argument('phone_ip', help='IP address of the phone running the app')
    args = parser.parse_args()

    # Create phone teleoperator
    config = PhoneTeleopConfig(phone_ip=args.phone_ip)
    phone_teleop = PhoneTeleop(config)

    try:
        # Connect to phone
        phone_teleop.connect()
        
        logging.info("🎮 Phone teleoperation started! Use the phone app to control.")
        logging.info("Press Ctrl+C to stop.")
        
        # Main control loop
        while True:
            try:
                # Get action from phone
                action = phone_teleop.get_action()
                
                # Mock robot observation with test images
                observation = {
                    "camera_left": np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8),
                    "camera_right": np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
                }
                
                # Send feedback to phone
                phone_teleop.send_feedback(observation)
                
                # Log commands
                if any(abs(v) > 0.01 for v in action.values()):
                    logging.info(f"Phone: vx={action['vx']:.2f}, vy={action['vy']:.2f}, vz={action['vz']:.2f}")
                
                # TODO: Send action to robot
                # robot.send_action(action)
                
                time.sleep(0.02)  # 50 Hz
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                logging.error(f"Error: {e}")
                time.sleep(0.1)

    finally:
        if phone_teleop.is_connected:
            phone_teleop.disconnect()

if __name__ == "__main__":
    main() 