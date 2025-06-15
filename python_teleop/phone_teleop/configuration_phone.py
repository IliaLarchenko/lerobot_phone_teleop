#!/usr/bin/env python

from dataclasses import dataclass

from lerobot.common.teleoperators.config import TeleoperatorConfig


@TeleoperatorConfig.register_subclass("phone")
@dataclass
class PhoneTeleopConfig(TeleoperatorConfig):
    """
    Configuration for phone-based teleoperator.
    
    The Python code connects as WebSocket client to the phone server
    to send robot observations (state vector + camera feeds) and 
    receive velocity commands back.
    """
    
    # Phone connection settings (phone acts as server)
    phone_ip: str = "192.168.1.102"  # IP address of the phone
    phone_port: int = 8080           # Port where phone server listens
    
    # Connection settings
    connection_timeout_s: float = 10.0  # Timeout for connecting to phone
    reconnect_interval_s: float = 2.0   # Interval between reconnection attempts
    
    # Video streaming settings
    video_quality: int = 80  # JPEG quality 0-100 for compressing camera feeds
    
    # Control settings (updated to match app limits)
    max_linear_velocity: float = 0.25  # m/s limit for x.vel and y.vel
    max_angular_velocity: float = 60.0  # deg/s limit for theta.vel
    
    mock: bool = False 