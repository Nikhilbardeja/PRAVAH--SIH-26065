"""
Synthetic Southern Ocean water-column model.

IMPORTANT: All equations here are simplified, physics-informed synthetic
approximations for a virtual prototype. They are NOT a real ocean
circulation model and must not be presented as real-time prediction.
Assumptions are documented inline; replace with real observational data
when/if available.
"""

import math
import numpy as np

from simulation.config import EventType


class OceanModel:
    def __init__(self, config, rng: np.random.Generator):
        self.cfg = config
        self.rng = rng

    # ---- helpers -------------------------------------------------
    def _season_factor(self, day_of_year: float) -> float:
        """-1..1 seasonal cycle, phase shifted for southern hemisphere
        (peak summer ~ day 15, mid-Jan)."""
        return math.cos(2 * math.pi * (day_of_year - 15) / 365.0)

    def _event_mods(self):
        """Returns dict of additive/multiplicative modifiers per event."""
        e = self.cfg.event
        mods = dict(temp_add=0.0, current_mult=1.0, turbidity_mult=1.0,
                    do_add=0.0)
        if e == EventType.STORM:
            mods["current_mult"] = 1.8
            mods["turbidity_mult"] = 3.0
        elif e == EventType.LOW_TEMPERATURE:
            mods["temp_add"] = -3.0
        elif e == EventType.HIGH_CURRENT:
            mods["current_mult"] = 2.2
            mods["turbidity_mult"] = 1.5
        elif e == EventType.SEA_ICE:
            # Ice cover: water sits near freezing, ice damps wave/current
            # mixing and shelters the surface from turbidity-stirring (assumption).
            mods["temp_add"] = -2.5
            mods["current_mult"] = 0.4
            mods["turbidity_mult"] = 0.5
        return mods

    # ---- 9.1 Temperature -------------------------------------------
    def water_temperature_c(self, day_of_year: float) -> float:
        lat = self.cfg.latitude
        depth = self.cfg.depth_m
        # Latitude effect: colder toward the pole (documented assumption:
        # linear interpolation between ~8C at 40S and ~-1.5C at 70S).
        lat_temp = np.interp(lat, [-70, -40], [-1.5, 8.0])
        season_amp = np.interp(abs(lat), [40, 70], [4.0, 1.5])
        seasonal = season_amp * self._season_factor(day_of_year)
        # Shallow thermocline effect within 0-20 m: slight cooling with depth.
        depth_effect = -0.05 * depth
        noise = self.rng.normal(0, 0.15)
        mods = self._event_mods()
        temp = lat_temp + seasonal + depth_effect + noise + mods["temp_add"]
        # Seawater freezes at ~-1.9C (S~34.5): physical floor
        return float(np.clip(temp, -1.9, 15.0))

    # ---- 9.2 Salinity ------------------------------------------------
    def salinity_psu(self, day_of_year: float) -> float:
        lat = self.cfg.latitude
        depth = self.cfg.depth_m
        # Antarctic Surface Water is freshest near the polar front (~55-60S) and
        # saltier toward the subantarctic (documented assumption, approximate)
        base = np.interp(abs(lat), [40, 58, 70], [34.4, 33.9, 34.2])
        depth_effect = 0.01 * depth
        # summer freshening from precipitation + ice melt, stronger poleward
        seasonal = -np.interp(abs(lat), [40, 70], [0.05, 0.15]) * self._season_factor(day_of_year)
        noise = self.rng.normal(0, 0.02)
        salinity = base + depth_effect + seasonal + noise
        return float(np.clip(salinity, 33.5, 35.5))

    # ---- 9.3 Pressure / depth ----------------------------------------
    def pressure_dbar(self) -> float:
        # 1 dbar approx 1 m depth in seawater (documented approximation).
        depth = self.cfg.depth_m
        noise = self.rng.normal(0, 0.05)
        return float(max(0.0, depth * 1.0197 + noise))

    # ---- 9.4 Dissolved oxygen -----------------------------------------
    def dissolved_oxygen_mg_l(self, water_temp_c: float, salinity_psu: float = 34.5) -> float:
        """Surface waters sit near O2 saturation. Saturation from the
        Garcia & Gordon (1992) solubility fit (mL/L -> mg/L x1.4291);
        ~98% saturated at the surface, slightly lower with depth."""
        ts = math.log((298.15 - water_temp_c) / (273.15 + water_temp_c))
        a = [2.00907, 3.22014, 4.05010, 4.94457, -0.256847, 3.88767]
        b = [-0.00624523, -0.00737614, -0.010341, -0.00817083]
        ln_c = sum(a[k] * ts ** k for k in range(6)) \
            + salinity_psu * sum(b[k] * ts ** k for k in range(4)) - 4.88682e-7 * salinity_psu ** 2
        sat_mg_l = math.exp(ln_c) * 1.4291
        do = sat_mg_l * (0.98 - 0.001 * self.cfg.depth_m) + self.rng.normal(0, 0.1)
        return float(np.clip(do, 3.0, 13.0))

    # ---- 9.5 Turbidity --------------------------------------------------
    def turbidity_ntu(self) -> float:
        mods = self._event_mods()
        base = 1.5  # clear open-ocean water, documented assumption
        noise = abs(self.rng.normal(0, 0.3))
        return float(max(0.0, (base + noise) * mods["turbidity_mult"]))

    # ---- Ocean current --------------------------------------------------
    def current(self):
        mods = self._event_mods()
        lat = self.cfg.latitude
        # Antarctic Circumpolar Current is strongest ~ 50-60S (documented
        # assumption, simplified bell-shaped profile).
        acc_strength = math.exp(-((abs(lat) - 55) ** 2) / (2 * 8 ** 2))
        base_speed = 0.15 + 0.45 * acc_strength
        noise = abs(self.rng.normal(0, 0.05))
        speed = (base_speed + noise) * mods["current_mult"]
        direction = float(self.rng.normal(90, 40) % 360)  # ACC flows eastward
        return float(np.clip(speed, 0.0, 2.5)), direction
