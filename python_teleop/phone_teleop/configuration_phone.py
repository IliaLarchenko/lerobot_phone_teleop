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

from dataclasses import dataclass

from lerobot.common.teleoperators.config import TeleoperatorConfig


@TeleoperatorConfig.register_subclass("phone")
@dataclass
class PhoneTeleopConfig(TeleoperatorConfig):
    # Server settings for phone communication
    server_host: str = "0.0.0.0"  # Listen on all interfaces
    server_port: int = 8080
    
    # Phone IP address (optional, for direct connection)
    phone_ip: str = None
    
    # Video streaming settings
    video_quality: int = 80  # JPEG quality 0-100
    video_fps: int = 30
    
    # Control settings
    max_linear_velocity: float = 0.5  # m/s
    max_angular_velocity: float = 1.0  # rad/s
    
    mock: bool = False 