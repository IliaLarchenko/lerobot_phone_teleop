#!/usr/bin/env python

"""
Phone teleoperator example with real LeKiwi robot.

This example:
1. Connects to LeKiwi robot to get real observations
2. Connects to phone for base velocity control and wrist flex control
3. Sends robot observations to phone (state vector + camera feeds)
4. Receives base velocity commands and wrist flex velocity from phone
5. Combines phone control with fixed arm positions (except wrist flex)
"""

import logging
import time
import numpy as np
import torch

from lerobot.common.robots.lekiwi import LeKiwiClient, LeKiwiClientConfig
from lerobot.common.teleoperators.phone_teleop.configuration_phone import PhoneTeleopConfig
from lerobot.common.teleoperators.phone_teleop.teleop_phone import PhoneTeleop

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    # Robot configuration
    robot_config = LeKiwiClientConfig(
        remote_ip="robotpi.local", 
        id="my_awesome_kiwi"
    )
    
    # Phone teleoperator configuration - set your phone's IP address here
    phone_config = PhoneTeleopConfig(
        phone_ip="192.168.1.102",  # Change this to your phone's IP
        phone_port=8080,
        video_quality=70,  # Lower quality for faster streaming
        max_linear_velocity=0.25,  # Updated to match app settings
        max_angular_velocity=60.0, # Updated to match app settings  
    )
    
    # Create robot and phone teleoperator
    robot = LeKiwiClient(robot_config)
    phone_teleop = PhoneTeleop(phone_config)
    
    # Wrist flex position tracking
    current_wrist_flex_pos = -50.0  # Starting position (from your fixed arm action)
    last_time = time.time()
    
    try:
        # Connect to robot and phone
        logger.info("Connecting to robot...")
        robot.connect()
        logger.info("Robot connected!")
        
        logger.info("Connecting to phone...")
        phone_teleop.connect()
        logger.info("Phone connected!")
        
        # Fixed arm positions (safe home position) - wrist flex will be controlled by phone
        base_arm_action = {
            "arm_shoulder_pan.pos": 0,
            "arm_shoulder_lift.pos": -90, 
            "arm_elbow_flex.pos": 90,
            "arm_wrist_roll.pos": -50,
            "arm_gripper.pos": 50.0,  # Half open
        }
        
        logger.info("Starting teleoperation loop...")
        logger.info("Phone controls: Left joystick = base movement, Right joystick = rotation + wrist flex")
        
        # Main control loop
        while True:
            current_time = time.time()
            dt = current_time - last_time
            last_time = current_time
            
            # Get real robot observation
            observation = robot.get_observation()
            
            # Convert torch tensors to numpy for phone transmission
            processed_observation = {}
            for key, value in observation.items():
                if isinstance(value, torch.Tensor):
                    # Convert torch tensor to numpy
                    processed_observation[key] = value.numpy()
                else:
                    processed_observation[key] = value
            
            # Send observation to phone
            phone_teleop.send_feedback(processed_observation)
            
            # Get commands from phone
            phone_action = phone_teleop.get_action()
            
            # Create base action from phone velocities
            base_action = {
                "x.vel": phone_action["x.vel"],
                "y.vel": phone_action["y.vel"], 
                "theta.vel": phone_action["theta.vel"],
            }
            
            # Handle wrist flex velocity - integrate to position
            wrist_flex_vel = phone_action["wrist_flex.vel"]
            if abs(wrist_flex_vel) > 0.01:  # Only update if significant velocity
                # Integrate velocity to position
                current_wrist_flex_pos += wrist_flex_vel * dt * 60  # Scale factor for reasonable movement
                # Clamp to reasonable wrist flex limits
                current_wrist_flex_pos = max(-90, min(90, current_wrist_flex_pos))
            
            # Create full arm action with controlled wrist flex
            arm_action = {
                **base_arm_action,
                "arm_wrist_flex.pos": current_wrist_flex_pos,
            }
            
            # Combine arm and base actions
            full_action = {**arm_action, **base_action}
            
            # Send combined action to robot
            robot.send_action(full_action)
            
            # Log the received action
            if (any(abs(v) > 0.01 for v in base_action.values()) or 
                abs(wrist_flex_vel) > 0.01):
                logger.info(f"Phone control: base=({base_action['x.vel']:.2f}, "
                           f"{base_action['y.vel']:.2f}, {base_action['theta.vel']:.1f}), "
                           f"wrist_flex={current_wrist_flex_pos:.1f} (vel={wrist_flex_vel:.2f})")
            
            # Small delay to avoid overwhelming the system
            time.sleep(0.05)  # 20 Hz
            
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