"""Simplified wind-wave model (synthetic, documented assumptions).

Fully-developed-sea approximations driven by wind speed U (m/s):
  Hs ~= 0.0246 * U^2   (significant wave height, m)
  Tp ~= 0.82 * U       (peak period, s)
Sea ice damps waves strongly (assumption: x0.1). Not a spectral wave model."""

import numpy as np
from simulation.config import EventType


class WaveModel:
    def __init__(self, config, rng: np.random.Generator):
        self.cfg = config
        self.rng = rng

    def waves(self, wind_speed_ms: float):
        damp = 0.1 if self.cfg.event == EventType.SEA_ICE else 1.0
        hs = 0.0246 * wind_speed_ms ** 2 * damp + abs(self.rng.normal(0, 0.1))
        tp = 0.82 * wind_speed_ms * (0.6 if damp < 1 else 1.0) + self.rng.normal(0, 0.3)
        # cap at 14 m: seas rarely fully develop
        return float(np.clip(hs, 0.0, 14.0)), float(np.clip(tp, 2.0, 22.0))
