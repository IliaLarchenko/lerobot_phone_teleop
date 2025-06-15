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
import websockets
from websockets import WebSocketClientProtocol

from lerobot.common.errors import DeviceAlreadyConnectedError, DeviceNotConnectedError
from lerobot.common.teleoperators.teleoperator import Teleoperator

from .configuration_phone import PhoneTeleopConfig

# Import torch if available (for handling torch tensors from robot)
try:
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    torch = None
    TORCH_AVAILABLE = False

logger = logging.getLogger(__name__)


class PhoneTeleop(Teleoperator):
    """
    Phone-based teleoperator that connects as WebSocket client to phone server.
    
    Sends robot observations (state vector + camera feeds) to phone and 
    receives velocity commands back for robot control.
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
        self.current_action = {
            "x.vel": 0.0,           # Linear velocity X (forward/backward) 
            "y.vel": 0.0,           # Linear velocity Y (left/right)
            "theta.vel": 0.0,       # Angular velocity (rotation)
            "wrist_flex.vel": 0.0,  # Wrist flex velocity
        }
        
        # Connection state
        self._connected = False
        self._phone_connected = False
        self.logs = {}

    @property
    def action_features(self) -> dict[str, type]:
        """Define the action features this teleoperator provides."""
        return {
            "x.vel": float,
            "y.vel": float, 
            "theta.vel": float,
            "wrist_flex.vel": float,
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
                # Receive velocity commands from phone
                x_vel = data.get("x.vel", 0.0)
                y_vel = data.get("y.vel", 0.0)  
                theta_vel = data.get("theta.vel", 0.0)
                wrist_flex_vel = data.get("wrist_flex.vel", 0.0)
                
                # Apply velocity limits
                x_vel = max(-self.config.max_linear_velocity, 
                           min(self.config.max_linear_velocity, x_vel))
                y_vel = max(-self.config.max_linear_velocity,
                           min(self.config.max_linear_velocity, y_vel))
                theta_vel = max(-self.config.max_angular_velocity,
                               min(self.config.max_angular_velocity, theta_vel))
                # Wrist flex velocity doesn't need limiting - it's controlled by the app
                
                # Update current action
                self.current_action = {
                    "x.vel": x_vel,
                    "y.vel": y_vel,
                    "theta.vel": theta_vel,
                    "wrist_flex.vel": wrist_flex_vel,
                }
                
                # Put action in queue for main thread
                try:
                    self.action_queue.put_nowait(self.current_action.copy())
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
        """Get latest action from phone."""
        before_read_t = time.perf_counter()

        if not self.is_connected:
            raise DeviceNotConnectedError(
                "Phone teleoperator is not connected. You need to run `connect()` before `get_action()`."
            )

        # Get latest action from queue, or use current action
        try:
            while True:
                self.current_action = self.action_queue.get_nowait()
        except Empty:
            pass  # Use last known action

        self.logs["read_pos_dt_s"] = time.perf_counter() - before_read_t
        
        return self.current_action.copy()

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
                if TORCH_AVAILABLE and torch is not None and isinstance(value, torch.Tensor):
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