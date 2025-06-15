#!/usr/bin/env python

"""
Robot Teleoperation Client
Connects to the phone app's WebSocket server to send video and receive commands.
"""
import argparse
import asyncio
import json
import logging
import time
import base64
import cv2
import numpy as np
import websockets

#
# TODO: Import your robot control library, e.g., from lerobot
#
# from lerobot.common.robots.lekiwi import LeKiwiClient, LeKiwiClientConfig
#

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class RobotClient:
    """
    Handles the connection to the phone, sends video streams, and receives control commands.
    """
    def __init__(self, phone_ip, port=8080):
        self.uri = f"ws://{phone_ip}:{port}"
        self.websocket = None
        
        #
        # TODO: Initialize your robot here
        #
        # robot_config = LeKiwiClientConfig(remote_ip="robotpi.local")
        # self.robot = LeKiwiClient(robot_config)
        # self.robot.connect()
        #
        
    def _get_camera_feed(self, camera_name: str) -> np.ndarray:
        """
        Retrieves a camera feed. Replace this mock implementation.
        """
        #
        # TODO: Replace with your actual robot's camera observation
        #
        # observation = self.robot.get_observation()
        # return observation[camera_name]
        #

        # Mock implementation for demonstration:
        img = np.zeros((480, 640, 3), dtype=np.uint8)
        color = [100, 0, 0] if "1" in camera_name else [0, 100, 0]
        img[:, :] = color
        ts = time.strftime('%H:%M:%S')
        cv2.putText(img, f"{camera_name} - {ts}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        return img

    async def _video_feedback_loop(self):
        """Encodes and sends video and robot status to the phone."""
        logger.info("Starting video feedback loop...")
        try:
            while True:
                cam1_img = self._get_camera_feed("camera_1")
                cam2_img = self._get_camera_feed("camera_2")
                
                _, buffer1 = cv2.imencode('.jpg', cam1_img, [cv2.IMWRITE_JPEG_QUALITY, 80])
                cam1_b64 = base64.b64encode(buffer1).decode('utf-8')
                
                _, buffer2 = cv2.imencode('.jpg', cam2_img, [cv2.IMWRITE_JPEG_QUALITY, 80])
                cam2_b64 = base64.b64encode(buffer2).decode('utf-8')
                
                feedback_msg = {
                    "type": "feedback",
                    "cameras": {"camera1": cam1_b64, "camera2": cam2_b64},
                    "robot_status": {"connected": True, "battery": 85, "temperature": 42.5}
                }
                
                await self.websocket.send(json.dumps(feedback_msg))
                await asyncio.sleep(1/30)
        except websockets.exceptions.ConnectionClosed:
            logger.warning("Connection to phone lost during video feedback.")
        except Exception as e:
            logger.error(f"Error in video feedback loop: {e}")
            raise

    async def _command_receive_loop(self):
        """Receives and processes control commands from the phone."""
        logger.info("Starting command receive loop...")
        async for message in self.websocket:
            try:
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "joystick":
                    # Convert phone joystick (-1 to 1) to robot velocities
                    vx = data.get('y', 0.0) * -0.5  # Invert Y for forward motion
                    vy = data.get('x', 0.0) * -0.5  # Invert X for strafing
                    logger.info(f"🕹️ Joystick Command: vx={vx:.2f}, vy={vy:.2f}")
                    
                    #
                    # TODO: Send action to your robot
                    #
                    # base_action = {"base_vx": vx, "base_vy": vy}
                    # self.robot.send_action(base_action)
                    #

                elif msg_type == "imu" and data.get('use_imu', False):
                    pitch = data.get('pitch', 0.0)
                    roll = data.get('roll', 0.0)
                    logger.info(f"📱 IMU Command: pitch={pitch:.2f}, roll={roll:.2f}")
                    
                    #
                    # TODO: Send action to your robot
                    #
                    # imu_action = {"base_vx": pitch * -0.5, "base_vz": roll * -1.0}
                    # self.robot.send_action(imu_action)
                    #

                elif msg_type == "emergency_stop":
                    logger.warning("🛑 EMERGENCY STOP Received")
                    
                    #
                    # TODO: Send STOP command to your robot
                    #
                    # self.robot.send_action({"base_vx": 0, "base_vy": 0, "base_vz": 0})
                    #

            except Exception as e:
                logger.error(f"Error processing command from phone: {e}")

    async def run(self):
        """Continuously tries to connect and run communication loops."""
        while True:
            try:
                logger.info(f"Attempting to connect to phone at {self.uri}...")
                async with websockets.connect(self.uri, ping_interval=5, ping_timeout=10) as websocket:
                    self.websocket = websocket
                    logger.info("✅ Connected to phone! Starting teleoperation.")
                    
                    video_task = asyncio.create_task(self._video_feedback_loop())
                    command_task = asyncio.create_task(self._command_receive_loop())
                    
                    await asyncio.gather(command_task, video_task)
            except (websockets.exceptions.WebSocketException, OSError) as e:
                logger.error(f"Connection failed: {e}. Retrying in 5 seconds...")
            except Exception as e:
                logger.error(f"An unexpected error occurred: {e}. Retrying...")
            
            logger.info("Connection lost. Attempting to reconnect...")
            await asyncio.sleep(3)

def main():
    """Parses arguments and starts the robot client."""
    parser = argparse.ArgumentParser(description="Robot client for phone teleoperation.")
    parser.add_argument("phone_ip", type=str, help="The IP address of the phone running the teleop app.")
    args = parser.parse_args()

    client = RobotClient(phone_ip=args.phone_ip)
    try:
        asyncio.run(client.run())
    except KeyboardInterrupt:
        logger.info("🛑 Shutting down robot client.")

if __name__ == "__main__":
    main() 