#!/usr/bin/env python

"""
Phone teleoperator example with real LeKiwi robot.

This example:
1. Connects to LeKiwi robot to get real observations
2. Connects to phone for base velocity control and arm joint control
3. Sends robot observations to phone (state vector + camera feeds)
4. Receives complete robot actions from phone (joint positions + base velocities)
5. Sends actions directly to robot
"""

import logging
import time
import torch
import argparse

from lerobot.common.robots.lekiwi import LeKiwiClient, LeKiwiClientConfig
from lerobot.common.teleoperators.phone_teleop.configuration_phone import PhoneTeleopConfig
from lerobot.common.teleoperators.phone_teleop.teleop_phone import PhoneTeleop

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--robot-ip', type=str, default="192.168.1.1", help='IP address of the LeKiwi robot')
    parser.add_argument('--phone-ip', type=str, default="192.168.1.1", help='IP address of the phone')
    args = parser.parse_args()

    # Robot configuration
    robot_config = LeKiwiClientConfig(
        remote_ip=args.robot_ip,
        id="my_awesome_kiwi"
    )
    
    # Phone teleoperator configuration
    phone_config = PhoneTeleopConfig(
        phone_ip=args.phone_ip,
        phone_port=8080,
        video_quality=70,  # Lower quality for faster streaming
        max_linear_velocity=0.25,  # Updated to match app settings
        max_angular_velocity=60.0  # Updated to match app settings
    )
    
    # Create robot and phone teleoperator
    robot = LeKiwiClient(robot_config)
    phone_teleop = PhoneTeleop(phone_config)
    
    try:
        # Connect to robot and phone
        logger.info("Connecting to robot...")
        robot.connect()
        logger.info("Robot connected!")
        
        logger.info("Connecting to phone...")
        phone_teleop.connect()
        logger.info("Phone connected!")
        
        logger.info("Starting teleoperation loop...")
        logger.info("Phone controls: Base movement + all 6 arm joints")
        
        # Main control loop
        while True:
            # Get real robot observation
            observation = robot.get_observation()
            
            # Convert torch tensors to numpy for phone transmission
            processed_observation = {}
            for key, value in observation.items():
                if isinstance(value, torch.Tensor):
                    processed_observation[key] = value.numpy()
                else:
                    processed_observation[key] = value
            
            # Send observation to phone
            phone_teleop.send_feedback(processed_observation)
            
            # Get complete action from phone (joint positions + base velocities)
            # Phone teleop handles joint velocity integration internally
            robot_action = phone_teleop.get_action()
            robot.send_action(robot_action)
            
            # Small delay to avoid overwhelming the system
            time.sleep(0.02)  # 50 Hz
            
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received. Exiting...")
    except Exception as e:
        logger.error(f"Error occurred: {e}")
        import traceback
        traceback.print_exc()
    finally:
        # Clean shutdown
        logger.info("Shutting down...")
        try:
            phone_teleop.disconnect()
            logger.info("Disconnected from phone")
        except:
            pass
        try:
            robot.disconnect()
            logger.info("Disconnected from robot")
        except:
            pass
        logger.info("Example finished")

if __name__ == "__main__":
    main() 