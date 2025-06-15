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

import asyncio
import json
import logging
import time
import base64
import cv2
import numpy as np
from typing import Any, Optional
import threading
from queue import Queue, Empty

import websockets
from websockets import WebSocketServerProtocol

from lerobot.common.errors import DeviceAlreadyConnectedError, DeviceNotConnectedError
from lerobot.common.teleoperators.teleoperator import Teleoperator
from .configuration_phone import PhoneTeleopConfig

logger = logging.getLogger(__name__)


class PhoneTeleop(Teleoperator):
    """
    Teleoperator class for phone-based robot control via WebSocket connection.
    """

    config_class = PhoneTeleopConfig
    name = "phone"

    def __init__(self, config: PhoneTeleopConfig):
        super().__init__(config)
        self.config = config
        
        # WebSocket server
        self.server = None
        self.websocket = None
        self.server_task = None
        self.loop = None
        
        # Communication queues
        self.action_queue = Queue()
        self.video_queue = Queue()
        
        # Current action state
        self.current_action = {
            "vx": 0.0,  # Linear velocity X (forward/backward)
            "vy": 0.0,  # Linear velocity Y (left/right)
            "vz": 0.0,  # Angular velocity Z (rotation)
        }
        
        # IMU data
        self.imu_data = {
            "roll": 0.0,
            "pitch": 0.0,
            "yaw": 0.0,
        }
        
        self.logs = {}
        self._connected = False
        self._phone_connected = False

    @property
    def action_features(self) -> dict:
        return {
            "dtype": "float32",
            "shape": (3,),  # vx, vy, vz
            "names": ["vx", "vy", "vz"],
        }

    @property
    def feedback_features(self) -> dict:
        return {}

    @property
    def is_connected(self) -> bool:
        return self._connected and self._phone_connected

    @property
    def is_calibrated(self) -> bool:
        return True  # No calibration needed for phone

    def connect(self) -> None:
        if self._connected:
            raise DeviceAlreadyConnectedError(
                "Phone teleoperator is already connected. Do not run `connect()` twice."
            )

        logger.info(f"Starting phone teleoperator server on {self.config.server_host}:{self.config.server_port}")
        
        # Start WebSocket server in separate thread
        self._connected = True
        self.server_thread = threading.Thread(target=self._start_server, daemon=True)
        self.server_thread.start()
        
        # Wait a bit for server to start
        time.sleep(1)
        logger.info("Phone teleoperator server started. Waiting for phone connection...")

    def _start_server(self):
        """Start the WebSocket server in its own event loop"""
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
        start_server = websockets.serve(
            self._handle_client,
            self.config.server_host,
            self.config.server_port
        )
        
        self.loop.run_until_complete(start_server)
        self.loop.run_forever()

    async def _handle_client(self, websocket: WebSocketServerProtocol, path: str):
        """Handle incoming WebSocket connection from phone"""
        logger.info(f"Phone connected from {websocket.remote_address}")
        self.websocket = websocket
        self._phone_connected = True
        
        try:
            async for message in websocket:
                await self._process_message(message)
        except websockets.exceptions.ConnectionClosed:
            logger.info("Phone disconnected")
        except Exception as e:
            logger.error(f"Error handling phone connection: {e}")
        finally:
            self._phone_connected = False
            self.websocket = None

    async def _process_message(self, message: str):
        """Process incoming message from phone"""
        try:
            data = json.loads(message)
            message_type = data.get("type")
            
            if message_type == "joystick":
                # Update joystick-based velocities
                x = data.get("x", 0.0)  # -1 to 1
                y = data.get("y", 0.0)  # -1 to 1
                
                # Convert to robot velocities
                self.current_action["vx"] = y * self.config.max_linear_velocity
                self.current_action["vy"] = -x * self.config.max_linear_velocity  # Invert for intuitive control
                
                # Put action in queue for main thread
                try:
                    self.action_queue.put_nowait(self.current_action.copy())
                except:
                    pass  # Queue full, skip
                    
            elif message_type == "imu":
                # Update IMU data
                self.imu_data["roll"] = data.get("roll", 0.0)
                self.imu_data["pitch"] = data.get("pitch", 0.0)
                self.imu_data["yaw"] = data.get("yaw", 0.0)
                
                # Use IMU for angular velocity if enabled
                # For now, we'll use pitch for forward/backward and roll for rotation
                if data.get("use_imu", False):
                    self.current_action["vx"] = -self.imu_data["pitch"] * self.config.max_linear_velocity
                    self.current_action["vz"] = -self.imu_data["roll"] * self.config.max_angular_velocity
                    
                    try:
                        self.action_queue.put_nowait(self.current_action.copy())
                    except:
                        pass
                        
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON from phone: {e}")
        except Exception as e:
            logger.error(f"Error processing phone message: {e}")

    def calibrate(self) -> None:
        pass  # No calibration needed

    def configure(self):
        pass

    def get_action(self) -> dict[str, Any]:
        before_read_t = time.perf_counter()

        if not self.is_connected:
            raise DeviceNotConnectedError(
                "Phone teleoperator is not connected. You need to run `connect()` before `get_action()`."
            )

        # Get latest action from queue or use current action
        try:
            while True:
                self.current_action = self.action_queue.get_nowait()
        except Empty:
            pass  # Use last known action

        self.logs["read_pos_dt_s"] = time.perf_counter() - before_read_t
        
        return self.current_action.copy()

    def send_feedback(self, feedback: dict[str, Any]) -> None:
        """Send robot state and video back to phone"""
        if not self._phone_connected or not self.websocket:
            return
            
        try:
            # Send feedback asynchronously
            asyncio.run_coroutine_threadsafe(
                self._send_feedback_async(feedback), 
                self.loop
            )
        except Exception as e:
            logger.error(f"Error sending feedback to phone: {e}")

    async def _send_feedback_async(self, feedback: dict[str, Any]):
        """Send feedback to phone via WebSocket"""
        try:
            message = {
                "type": "feedback",
                "timestamp": time.time(),
                "data": {}
            }
            
            # Process different types of feedback
            for key, value in feedback.items():
                if isinstance(value, np.ndarray):
                    if value.ndim == 3:  # Likely an image
                        # Convert to JPEG and encode as base64
                        _, buffer = cv2.imencode('.jpg', value, 
                                              [cv2.IMWRITE_JPEG_QUALITY, self.config.video_quality])
                        img_base64 = base64.b64encode(buffer).decode('utf-8')
                        message["data"][key] = {
                            "type": "image",
                            "data": img_base64
                        }
                    else:
                        message["data"][key] = {
                            "type": "array",
                            "data": value.tolist()
                        }
                elif isinstance(value, str) and value.startswith('data:image'):
                    # Already base64 encoded image
                    message["data"][key] = {
                        "type": "image", 
                        "data": value
                    }
                else:
                    message["data"][key] = {
                        "type": "scalar",
                        "data": value
                    }
            
            await self.websocket.send(json.dumps(message))
            
        except Exception as e:
            logger.error(f"Error in _send_feedback_async: {e}")

    def disconnect(self) -> None:
        if not self._connected:
            raise DeviceNotConnectedError(
                "Phone teleoperator is not connected. You need to run `connect()` before `disconnect()`."
            )
        
        logger.info("Disconnecting phone teleoperator")
        self._connected = False
        self._phone_connected = False
        
        if self.loop:
            self.loop.call_soon_threadsafe(self.loop.stop)
        
        if self.server_thread and self.server_thread.is_alive():
            self.server_thread.join(timeout=2)
        
        logger.info("Phone teleoperator disconnected") 