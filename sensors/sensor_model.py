"""Sensor simulation layer: converts TRUE environmental values into
simulated sensor readings with noise, bias and occasional faults.
Keeps ENVIRONMENT and SENSOR layers separate per the engineering rule."""

import numpy as np

# Per-parameter (noise_std, bias) — documented assumptions per datasheet class.
SENSOR_PROFILES = {
    "water_temp_c": (0.05, 0.02),
    "salinity_psu": (0.03, 0.0),
    "pressure_dbar": (0.02, 0.0),
    "dissolved_oxygen_mg_l": (0.15, -0.1),
    "turbidity_ntu": (0.2, 0.0),
    "current_speed_ms": (0.02, 0.0),
    "wind_speed_ms": (0.3, 0.0),
    "air_temp_c": (0.1, 0.0),
    "humidity_pct": (1.0, 0.0),
    "atm_pressure_hpa": (0.5, 0.0),
    "wave_height_m": (0.1, 0.0),
    "wave_period_s": (0.2, 0.0),
}


NON_NEGATIVE = {"pressure_dbar", "turbidity_ntu", "current_speed_ms", "wind_speed_ms",
                "humidity_pct", "wave_height_m", "wave_period_s", "dissolved_oxygen_mg_l"}


class SensorModel:
    def __init__(self, fault_probability: float, rng: np.random.Generator):
        self.fault_probability = fault_probability
        self.rng = rng

    def measure(self, true_values: dict, disturbed: bool = False) -> dict:
        """Returns dict of {param: {"value":..., "status": "OK"/"FAULT"}}.
        During SENSOR_DISTURBANCE (e.g. biofouling/EMI, documented
        assumption) noise triples and fault probability is boosted."""
        noise_mult = 3.0 if disturbed else 1.0
        fault_prob = min(1.0, self.fault_probability + 0.15) if disturbed else self.fault_probability

        out = {}
        for key, true_val in true_values.items():
            if key not in SENSOR_PROFILES:
                out[key] = {"value": true_val, "status": "OK"}
                continue
            noise_std, bias = SENSOR_PROFILES[key]
            if self.rng.random() < fault_prob:
                out[key] = {"value": None, "status": "FAULT"}
            else:
                noisy = true_val + bias + self.rng.normal(0, noise_std * noise_mult)
                if key in NON_NEGATIVE:
                    noisy = max(0.0, noisy)
                out[key] = {"value": float(noisy), "status": "OK"}
        return out
