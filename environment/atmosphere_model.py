"""Synthetic atmospheric model above the buoy mast (documented assumptions,
not a weather forecast)."""

import numpy as np
from simulation.config import EventType


class AtmosphereModel:
    def __init__(self, config, rng: np.random.Generator):
        self.cfg = config
        self.rng = rng

    def _event_mods(self):
        e = self.cfg.event
        mods = dict(wind_mult=1.0, pressure_add=0.0, humidity_add=0.0)
        if e == EventType.STORM:
            mods["wind_mult"] = 2.5
            mods["pressure_add"] = -25.0  # low-pressure system
            mods["humidity_add"] = 10.0
        elif e == EventType.LOW_TEMPERATURE:
            mods["pressure_add"] = 8.0
        elif e == EventType.SEA_ICE:
            # Ice sheet shelters the surface from wind mixing (assumption).
            mods["wind_mult"] = 0.5
            mods["pressure_add"] = 6.0
        elif e == EventType.LOW_SUNLIGHT:
            # Persistent overcast: slightly higher humidity, calmer wind.
            mods["humidity_add"] = 6.0
        return mods

    def air_temperature_c(self, water_temp_c: float) -> float:
        # Air temperature tracks water temperature closely at the sea
        # surface, with a small offset and noise (documented assumption).
        noise = self.rng.normal(0, 0.3)
        return float(np.clip(water_temp_c - 1.0 + noise, -15.0, 20.0))

    def relative_humidity_pct(self) -> float:
        mods = self._event_mods()
        base = 82.0  # Southern Ocean is persistently humid (assumption)
        noise = self.rng.normal(0, 3.0)
        return float(np.clip(base + mods["humidity_add"] + noise, 40.0, 100.0))

    def atmospheric_pressure_hpa(self) -> float:
        mods = self._event_mods()
        base = 1005.0  # Southern Ocean sits in a low-pressure belt (assumption)
        noise = self.rng.normal(0, 2.0)
        return float(np.clip(base + mods["pressure_add"] + noise, 940.0, 1040.0))

    def wind(self):
        mods = self._event_mods()
        base_speed = 8.0  # m/s, persistent westerlies ("Roaring Forties/
        # Furious Fifties/Screaming Sixties" — documented assumption)
        gust = abs(self.rng.normal(0, 2.0))
        speed = (base_speed + gust) * mods["wind_mult"]
        direction = float(self.rng.normal(270, 20) % 360)  # prevailing westerly
        return float(np.clip(speed, 0.0, 45.0)), direction
