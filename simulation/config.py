"""
Central configuration for the Southern Ocean environment simulation.
All synthetic model parameters live here so they can be tuned/documented
in one place (see README for assumptions).
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from enum import Enum


class EventType(str, Enum):
    NORMAL = "NORMAL"
    STORM = "STORM"
    LOW_TEMPERATURE = "LOW_TEMPERATURE"
    HIGH_CURRENT = "HIGH_CURRENT"
    LOW_SUNLIGHT = "LOW_SUNLIGHT"
    SEA_ICE = "SEA_ICE"
    SENSOR_DISTURBANCE = "SENSOR_DISTURBANCE"
    COMMUNICATION_OUTAGE = "COMMUNICATION_OUTAGE"


# Approximate Southern Ocean reference zones (documented assumption,
# not measured data). Values are illustrative starting points only.
ZONES = {
    "A": {"latitude": -45.0, "desc": "Subantarctic front, ~45S"},
    "B": {"latitude": -55.0, "desc": "Antarctic Circumpolar Current core, ~55S"},
    "C": {"latitude": -65.0, "desc": "Near sea-ice edge, ~65S"},
}


@dataclass
class SimConfig:
    seed: int = 42
    latitude: float = -55.0          # degrees, negative = south
    longitude: float = 60.0          # degrees east
    depth_m: float = 10.0            # sensor pod depth, 0-20 m range
    start_day_of_year: int = 1
    timestep_minutes: int = 60
    event: EventType = EventType.NORMAL
    fault_probability: float = 0.0   # 0-1 chance any sensor "fails" per step
    drift_enabled: bool = False
    start_datetime: Optional[datetime] = None  # sim clock = buoy-local solar time

    def clamp_depth(self):
        self.depth_m = max(0.0, min(20.0, self.depth_m))
