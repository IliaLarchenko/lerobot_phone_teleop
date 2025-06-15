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
        remote_ip="LEKIWI_ROBOT_IP", 
        id="my_awesome_kiwi"
    )
    
    # Phone teleoperator configuration - set your phone's IP address here
    phone_config = PhoneTeleopConfig(
        phone_ip="PHONE_IP",  # Change this to your phone's IP
        phone_port=8080,
        video_quality=70,  # Lower quality for faster streaming
        max_linear_velocity=0.25,  # Updated to match app settings
        max_angular_velocity=60.0, # Updated to match app settings  
    )
    
    # Create robot and phone teleoperator
    robot = LeKiwiClient(robot_config)
    phone_teleop = PhoneTeleop(phone_config)
    
    # Joint position tracking for all arm joints (integrate velocities to positions)
    current_joint_positions = {
        "shoulder_pan": 0.0,
        "shoulder_lift": -90.0, 
        "elbow_flex": 90.0,
        "wrist_flex": -50.0,
        "wrist_roll": -50.0,
        "gripper": 50.0,
    }
    last_time = time.time()
    
    try:
        # Connect to robot and phone
        logger.info("Connecting to robot...")
        robot.connect()
        logger.info("Robot connected!")
        
        logger.info("Connecting to phone...")
        phone_teleop.connect()
        logger.info("Phone connected!")
        
        logger.info("Starting teleoperation loop...")
        logger.info("Phone controls: Base mode = movement + wrist, Arm mode = all 6 joints")
        
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
            
            # Handle ALL joint velocities - integrate to positions
            joint_velocities = {
                "shoulder_pan": phone_action["shoulder_pan.vel"],
                "shoulder_lift": phone_action["shoulder_lift.vel"],
                "elbow_flex": phone_action["elbow_flex.vel"],
                "wrist_flex": phone_action["wrist_flex.vel"],
                "wrist_roll": phone_action["wrist_roll.vel"],
                "gripper": phone_action["gripper.vel"],
            }
            
            # Integrate velocities to positions for all joints
            for joint_name, velocity in joint_velocities.items():
                if abs(velocity) > 0.01:  # Only update if significant velocity
                    # Integrate velocity to position
                    current_joint_positions[joint_name] += velocity * dt * 60  # Scale factor
                    
                    # Apply joint limits
                    if joint_name == "gripper":
                        current_joint_positions[joint_name] = max(0, min(100, current_joint_positions[joint_name]))
                    else:
                        current_joint_positions[joint_name] = max(-100, min(100, current_joint_positions[joint_name]))
            
            # Create full arm action with all controlled joints
            arm_action = {
                "arm_shoulder_pan.pos": current_joint_positions["shoulder_pan"],
                "arm_shoulder_lift.pos": current_joint_positions["shoulder_lift"], 
                "arm_elbow_flex.pos": current_joint_positions["elbow_flex"],
                "arm_wrist_flex.pos": current_joint_positions["wrist_flex"],
                "arm_wrist_roll.pos": current_joint_positions["wrist_roll"],
                "arm_gripper.pos": current_joint_positions["gripper"],
            }
            
            # Combine arm and base actions
            full_action = {**arm_action, **base_action}
            
            # Send combined action to robot
            robot.send_action(full_action)
            
            # Log the received action
            active_joints = {k: v for k, v in joint_velocities.items() if abs(v) > 0.01}
            if (any(abs(v) > 0.01 for v in base_action.values()) or active_joints):
                logger.info(f"Phone control: base=({base_action['x.vel']:.2f}, "
                           f"{base_action['y.vel']:.2f}, {base_action['theta.vel']:.1f})")
                if active_joints:
                    logger.info(f"Joint velocities: {active_joints}")
                    logger.info(f"Joint positions: {dict((k, f'{v:.1f}') for k, v in current_joint_positions.items())}")
            
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