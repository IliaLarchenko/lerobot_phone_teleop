#!/usr/bin/env python

# Copyright 2024 The HuggingFace Inc. team. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Phone teleoperator example with real LeKiwi robot.

This example:
1. Connects to LeKiwi robot to get real observations
2. Connects to phone for base velocity control
3. Sends robot observations to phone (state vector + camera feeds)
4. Receives base velocity commands from phone
5. Combines phone base control with fixed arm positions
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
        max_linear_velocity=0.2,
        max_angular_velocity=0.3,
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
        
        # Fixed arm positions (safe home position)
        # You can modify these or get them from another teleoperator
        fixed_arm_action = {
            "arm_shoulder_pan.pos": 0,
            "arm_shoulder_lift.pos": -90, 
            "arm_elbow_flex.pos": 90,
            "arm_wrist_flex.pos": -50,
            "arm_wrist_roll.pos": -50,
            "arm_gripper.pos": 50.0,  # Half open
        }
        
        logger.info("Starting teleoperation loop...")
        
        # Main control loop
        while True:
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
            
            # Get base velocity commands from phone
            phone_action = phone_teleop.get_action()
            
            # Create base action from phone velocities
            base_action = {
                "x.vel": phone_action["x.vel"],
                "y.vel": phone_action["y.vel"], 
                "theta.vel": phone_action["theta.vel"],
            }
            
            # Combine fixed arm positions with phone base control
            full_action = {**fixed_arm_action, **base_action}
            
            # Send combined action to robot
            robot.send_action(full_action)
            
            # Log the received action
            if any(abs(v) > 0.01 for v in base_action.values()):
                logger.info(f"Phone control: x.vel={base_action['x.vel']:.2f}, "
                           f"y.vel={base_action['y.vel']:.2f}, theta.vel={base_action['theta.vel']:.2f}")
            
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