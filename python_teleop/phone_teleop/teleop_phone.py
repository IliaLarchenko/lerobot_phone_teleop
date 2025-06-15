#!/usr/bin/env python

import asyncio
import base64
import json
import logging
import threading
import time
from queue import Empty, Queue
from typing import Any

import cv2
import numpy as np
import torch
import websockets

from lerobot.common.errors import DeviceAlreadyConnectedError, DeviceNotConnectedError
from lerobot.common.teleoperators.teleoperator import Teleoperator

from .configuration_phone import PhoneTeleopConfig

logger = logging.getLogger(__name__)


class PhoneTeleop(Teleoperator):
    """
    Phone-based teleoperator that connects as WebSocket client to phone server.
    
    Sends robot observations (state vector + camera feeds) to phone and 
    receives velocity commands back for robot control.
    
    Internally integrates joint velocities to positions and returns joint positions
    for arm control and velocities for base control.
    """

    config_class = PhoneTeleopConfig
    name = "phone"

    def __init__(self, config: PhoneTeleopConfig):
        super().__init__(config)
        self.config = config
        
        # WebSocket client connection
        self.websocket = None
        self.loop = None
        self.client_task = None
        self.websocket_thread = None
        
        # Communication queues
        self.action_queue = Queue(maxsize=10)
        self.observation_queue = Queue(maxsize=10)
        
        # Current action state (velocity commands from phone)
        self.current_velocity_action = {
            "x.vel": 0.0,           # Linear velocity X (forward/backward) 
            "y.vel": 0.0,           # Linear velocity Y (left/right)
            "theta.vel": 0.0,       # Angular velocity (rotation)
            "wrist_flex.vel": 0.0,  # Wrist flex velocity
            # Manipulator joint velocities
            "shoulder_pan.vel": 0.0,
            "shoulder_lift.vel": 0.0,
            "elbow_flex.vel": 0.0,
            "wrist_roll.vel": 0.0,
            "gripper.vel": 0.0,
        }
        
        # Joint position tracking for all arm joints (integrate velocities to positions)
        self.current_joint_positions = {
            "shoulder_pan": 0.0,
            "shoulder_lift": -90.0, 
            "elbow_flex": 90.0,
            "wrist_flex": -50.0,
            "wrist_roll": -50.0,
            "gripper": 50.0,
        }
        self.last_time = time.time()
        
        # Connection state
        self._connected = False
        self._phone_connected = False
        self.logs = {}

    @property
    def action_features(self) -> dict[str, type]:
        """Define the action features this teleoperator provides."""
        return {
            # Base movement velocities
            "x.vel": float,
            "y.vel": float, 
            "theta.vel": float,
            # Manipulator joint positions
            "arm_shoulder_pan.pos": float,
            "arm_shoulder_lift.pos": float,
            "arm_elbow_flex.pos": float,
            "arm_wrist_flex.pos": float,
            "arm_wrist_roll.pos": float,
            "arm_gripper.pos": float,
        }

    @property
    def feedback_features(self) -> dict[str, type]:
        """No feedback features needed for phone teleop."""
        return {}

    @property
    def is_connected(self) -> bool:
        """Check if teleoperator is connected to phone."""
        return self._connected and self._phone_connected

    @property
    def is_calibrated(self) -> bool:
        """No calibration needed for phone teleop."""
        return True

    def connect(self) -> None:
        """Connect to phone WebSocket server."""
        if self._connected:
            raise DeviceAlreadyConnectedError(
                "Phone teleoperator is already connected. Do not run `connect()` twice."
            )

        logger.info(f"Connecting to phone at {self.config.phone_ip}:{self.config.phone_port}")
        
        self._connected = True
        
        # Start WebSocket client in separate thread
        self.websocket_thread = threading.Thread(target=self._start_websocket_client, daemon=True)
        self.websocket_thread.start()
        
        # Wait for connection to be established
        start_time = time.time()
        while not self._phone_connected and (time.time() - start_time) < self.config.connection_timeout_s:
            time.sleep(0.1)
            
        if not self._phone_connected:
            self._connected = False
            raise DeviceNotConnectedError(
                f"Failed to connect to phone at {self.config.phone_ip}:{self.config.phone_port} "
                f"within {self.config.connection_timeout_s}s"
            )
            
        logger.info("Successfully connected to phone")

    def _start_websocket_client(self):
        """Start WebSocket client in its own event loop."""
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
        try:
            self.loop.run_until_complete(self._websocket_client())
        except Exception as e:
            logger.error(f"WebSocket client error: {e}")
        finally:
            self._phone_connected = False

    async def _websocket_client(self):
        """Main WebSocket client coroutine."""
        uri = f"ws://{self.config.phone_ip}:{self.config.phone_port}"
        
        while self._connected:
            try:
                async with websockets.connect(uri) as websocket:
                    self.websocket = websocket
                    self._phone_connected = True
                    logger.info("WebSocket connection established")
                    
                    # Handle incoming messages
                    async for message in websocket:
                        await self._process_message(message)
                        
            except websockets.exceptions.ConnectionClosed:
                logger.warning("Phone disconnected")
                self._phone_connected = False
                
            except Exception as e:
                logger.error(f"WebSocket connection error: {e}")
                self._phone_connected = False
                
            if self._connected:
                logger.info(f"Reconnecting in {self.config.reconnect_interval_s}s...")
                await asyncio.sleep(self.config.reconnect_interval_s)

    async def _process_message(self, message: str):
        """Process incoming message from phone."""
        try:
            data = json.loads(message)
            message_type = data.get("type")
            
            if message_type == "action":
                # Receive ALL commands from phone in single action message
                x_vel = data.get("x.vel", 0.0)
                y_vel = data.get("y.vel", 0.0)  
                theta_vel = data.get("theta.vel", 0.0)
                wrist_flex_vel = data.get("wrist_flex.vel", 0.0)
                
                # Get individual joint velocities
                shoulder_pan_vel = data.get("shoulder_pan.vel", 0.0)
                shoulder_lift_vel = data.get("shoulder_lift.vel", 0.0)
                elbow_flex_vel = data.get("elbow_flex.vel", 0.0)
                wrist_roll_vel = data.get("wrist_roll.vel", 0.0)
                gripper_vel = data.get("gripper.vel", 0.0)
                
                # Apply velocity limits to base commands
                x_vel = max(-self.config.max_linear_velocity, 
                           min(self.config.max_linear_velocity, x_vel))
                y_vel = max(-self.config.max_linear_velocity,
                           min(self.config.max_linear_velocity, y_vel))
                theta_vel = max(-self.config.max_angular_velocity,
                               min(self.config.max_angular_velocity, theta_vel))
                
                # Update current action with ALL commands
                self.current_velocity_action = {
                    "x.vel": x_vel,
                    "y.vel": y_vel,
                    "theta.vel": theta_vel,
                    "wrist_flex.vel": wrist_flex_vel,
                    "shoulder_pan.vel": shoulder_pan_vel,
                    "shoulder_lift.vel": shoulder_lift_vel,
                    "elbow_flex.vel": elbow_flex_vel,
                    "wrist_roll.vel": wrist_roll_vel,
                    "gripper.vel": gripper_vel,
                }
                
                # Log non-zero joint velocities only
                active_joints = {k: v for k, v in self.current_velocity_action.items() if abs(v) > 0.001}
                if active_joints:
                    logger.info(f"🎯 Active commands: {active_joints}")
                
                # Put action in queue for main thread
                try:
                    self.action_queue.put_nowait(self.current_velocity_action.copy())
                except:
                    pass  # Queue full, skip
                    
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON from phone: {e}")
        except Exception as e:
            logger.error(f"Error processing phone message: {e}")

    def calibrate(self) -> None:
        """No calibration needed for phone teleop."""
        pass

    def configure(self) -> None:
        """No configuration needed for phone teleop.""" 
        pass

    def get_action(self) -> dict[str, Any]:
        """Get latest action from phone - returns joint positions and base velocities."""
        before_read_t = time.perf_counter()

        if not self.is_connected:
            raise DeviceNotConnectedError(
                "Phone teleoperator is not connected. You need to run `connect()` before `get_action()`."
            )

        # Get latest action from queue, or use current action
        try:
            while True:
                self.current_velocity_action = self.action_queue.get_nowait()
        except Empty:
            pass  # Use last known action

        # Integrate joint velocities to positions
        current_time = time.time()
        dt = current_time - self.last_time
        self.last_time = current_time
        
        # Extract joint velocities from current action
        joint_velocities = {
            "shoulder_pan": self.current_velocity_action["shoulder_pan.vel"],
            "shoulder_lift": self.current_velocity_action["shoulder_lift.vel"],
            "elbow_flex": self.current_velocity_action["elbow_flex.vel"],
            "wrist_flex": self.current_velocity_action["wrist_flex.vel"],
            "wrist_roll": self.current_velocity_action["wrist_roll.vel"],
            "gripper": self.current_velocity_action["gripper.vel"],
        }
        
        # Integrate velocities to positions for all joints
        for joint_name, velocity in joint_velocities.items():
            if abs(velocity) > 0.01:  # Only update if significant velocity
                # Integrate velocity to position
                self.current_joint_positions[joint_name] += velocity * dt * 60  # Scale factor
                
                # Apply joint limits
                if joint_name == "gripper":
                    self.current_joint_positions[joint_name] = max(0, min(100, self.current_joint_positions[joint_name]))
                else:
                    self.current_joint_positions[joint_name] = max(-100, min(100, self.current_joint_positions[joint_name]))
        
        # Create action with joint positions and base velocities
        action = {
            # Base movement velocities
            "x.vel": self.current_velocity_action["x.vel"],
            "y.vel": self.current_velocity_action["y.vel"], 
            "theta.vel": self.current_velocity_action["theta.vel"],
            # Manipulator joint positions
            "arm_shoulder_pan.pos": self.current_joint_positions["shoulder_pan"],
            "arm_shoulder_lift.pos": self.current_joint_positions["shoulder_lift"], 
            "arm_elbow_flex.pos": self.current_joint_positions["elbow_flex"],
            "arm_wrist_flex.pos": self.current_joint_positions["wrist_flex"],
            "arm_wrist_roll.pos": self.current_joint_positions["wrist_roll"],
            "arm_gripper.pos": self.current_joint_positions["gripper"],
        }

        self.logs["read_pos_dt_s"] = time.perf_counter() - before_read_t
        
        return action

    def send_feedback(self, observation: dict[str, Any]) -> None:
        """Send robot observation to phone."""
        if not self._phone_connected or not self.websocket:
            return
            
        try:
            # Send observation asynchronously
            asyncio.run_coroutine_threadsafe(
                self._send_observation_async(observation), 
                self.loop
            )
        except Exception as e:
            logger.error(f"Error sending observation to phone: {e}")

    async def _send_observation_async(self, observation: dict[str, Any]):
        """Send observation to phone via WebSocket."""
        try:
            message = {
                "type": "observation",
                "timestamp": time.time(),
                "data": {}
            }
            
            # Process observation data
            for key, value in observation.items():
                if isinstance(value, torch.Tensor):
                    # Handle torch tensors (convert to numpy first)
                    value_np = value.numpy()
                    if value_np.ndim == 3:  # Camera image
                        # Convert RGB to BGR since torch tensors are usually RGB but cv2.imencode expects BGR
                        if value_np.shape[2] == 3:  # Only if it has 3 channels
                            value_np = cv2.cvtColor(value_np, cv2.COLOR_RGB2BGR)
                        # Convert to JPEG and encode as base64
                        _, buffer = cv2.imencode('.jpg', value_np, 
                                              [cv2.IMWRITE_JPEG_QUALITY, self.config.video_quality])
                        img_base64 = base64.b64encode(buffer).decode('utf-8')
                        message["data"][key] = {
                            "type": "image",
                            "data": img_base64
                        }
                    elif value_np.ndim == 1:  # State vector
                        message["data"][key] = {
                            "type": "state",
                            "data": value_np.tolist()
                        }
                    else:
                        message["data"][key] = {
                            "type": "array", 
                            "data": value_np.tolist()
                        }
                elif isinstance(value, np.ndarray):
                    if value.ndim == 3:  # Camera image
                        # If numpy array is RGB, convert to BGR for cv2.imencode
                        if value.shape[2] == 3:  # Only if it has 3 channels
                            value = cv2.cvtColor(value, cv2.COLOR_RGB2BGR)
                        # Convert to JPEG and encode as base64
                        _, buffer = cv2.imencode('.jpg', value, 
                                              [cv2.IMWRITE_JPEG_QUALITY, self.config.video_quality])
                        img_base64 = base64.b64encode(buffer).decode('utf-8')
                        message["data"][key] = {
                            "type": "image",
                            "data": img_base64
                        }
                    elif value.ndim == 1:  # State vector
                        message["data"][key] = {
                            "type": "state",
                            "data": value.tolist()
                        }
                    else:
                        message["data"][key] = {
                            "type": "array", 
                            "data": value.tolist()
                        }
                elif isinstance(value, (int, float)):
                    message["data"][key] = {
                        "type": "scalar",
                        "data": value
                    }
                else:
                    # Convert other types to string
                    message["data"][key] = {
                        "type": "string",
                        "data": str(value)
                    }
            
            await self.websocket.send(json.dumps(message))
            
        except Exception as e:
            logger.error(f"Error in _send_observation_async: {e}")

    def disconnect(self) -> None:
        """Disconnect from phone."""
        if not self._connected:
            raise DeviceNotConnectedError(
                "Phone teleoperator is not connected. You need to run `connect()` before `disconnect()`."
            )
        
        logger.info("Disconnecting from phone")
        self._connected = False
        self._phone_connected = False
        
        # Stop event loop
        if self.loop and not self.loop.is_closed():
            self.loop.call_soon_threadsafe(self.loop.stop)
        
        # Wait for thread to finish
        if self.websocket_thread and self.websocket_thread.is_alive():
            self.websocket_thread.join(timeout=2)
        
        logger.info("Phone teleoperator disconnected") 