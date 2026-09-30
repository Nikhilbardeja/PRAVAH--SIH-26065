"""
Phase 11 — automated validation tests (todo.md §17).
Run: python -m unittest validation.test_phase11 -v
"""

import math
import sys
import os
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from simulation.config import SimConfig, EventType
from simulation.main import run_simulation
from validation.validation import validate_all


def run(event=EventType.NORMAL, hours=12, seed=1, **kw):
    cfg = SimConfig(seed=seed, event=event, **kw)
    return run_simulation(cfg, hours)


class TestPhase11BasicSoftwareValidation(unittest.TestCase):
    """§17 'Basic Software Validation' checklist."""

    def test_no_nan_values(self):
        for event in EventType:
            for o in run(event=event, hours=6):
                for k, v in o.items():
                    if isinstance(v, float):
                        self.assertFalse(math.isnan(v), f"{event}: NaN in {k}")

    def test_no_unexpected_negative_values(self):
        non_negative_fields = [
            "salinity_psu", "pressure_dbar", "dissolved_oxygen_mg_l",
            "turbidity_ntu", "current_speed_ms", "wind_speed_ms",
            "humidity_pct", "atm_pressure_hpa", "depth_m",
        ]
        for event in EventType:
            for o in run(event=event, hours=6):
                for k in non_negative_fields:
                    if o.get(k) is not None:
                        self.assertGreaterEqual(o[k], 0, f"{event}: negative {k}={o[k]}")

    def test_temperature_changes_smoothly_when_normal(self):
        obs = run(event=EventType.NORMAL, hours=24)
        temps = [o["water_temp_c"] for o in obs]
        for a, b in zip(temps, temps[1:]):
            self.assertLess(abs(b - a), 1.5, "temperature jumped >1.5C between steps under NORMAL")

    def test_salinity_changes_smoothly(self):
        obs = run(event=EventType.NORMAL, hours=24)
        sal = [o["salinity_psu"] for o in obs]
        for a, b in zip(sal, sal[1:]):
            self.assertLess(abs(b - a), 0.5)

    def test_pressure_increases_with_depth(self):
        shallow = run(event=EventType.NORMAL, hours=1, depth_m=2.0)[0]["pressure_dbar"]
        deep = run(event=EventType.NORMAL, hours=1, depth_m=18.0)[0]["pressure_dbar"]
        self.assertGreater(deep, shallow)

    def test_current_direction_within_0_360(self):
        for o in run(event=EventType.HIGH_CURRENT, hours=12):
            self.assertGreaterEqual(o["current_direction_deg"], 0)
            self.assertLess(o["current_direction_deg"], 360)

    def test_validate_all_reports_zero_errors_across_all_events(self):
        for event in EventType:
            obs = run(event=event, hours=12, fault_probability=0.0)
            report = validate_all(obs)
            self.assertEqual(report["total_errors"], 0,
                              f"{event}: {report['details']}")

    def test_reproducible_with_seed(self):
        a = run(event=EventType.STORM, hours=6, seed=99)
        b = run(event=EventType.STORM, hours=6, seed=99)
        self.assertEqual(
            [o["water_temp_c"] for o in a],
            [o["water_temp_c"] for o in b],
        )


class TestScenarios(unittest.TestCase):
    """§23 scenario expectations, one per documented event."""

    def test_storm_increases_wind_and_current_vs_normal(self):
        normal = run(event=EventType.NORMAL, hours=12, seed=3)
        storm = run(event=EventType.STORM, hours=12, seed=3)
        avg = lambda obs, k: sum(o[k] for o in obs) / len(obs)
        self.assertGreater(avg(storm, "wind_speed_ms"), avg(normal, "wind_speed_ms"))
        self.assertGreater(avg(storm, "current_speed_ms"), avg(normal, "current_speed_ms"))

    def test_low_temperature_lowers_water_and_air_temp(self):
        normal = run(event=EventType.NORMAL, hours=12, seed=3)
        cold = run(event=EventType.LOW_TEMPERATURE, hours=12, seed=3)
        avg = lambda obs, k: sum(o[k] for o in obs) / len(obs)
        self.assertLess(avg(cold, "water_temp_c"), avg(normal, "water_temp_c"))
        self.assertLess(avg(cold, "air_temp_c"), avg(normal, "air_temp_c"))

    def test_high_current_increases_current_speed(self):
        normal = run(event=EventType.NORMAL, hours=12, seed=3)
        hc = run(event=EventType.HIGH_CURRENT, hours=12, seed=3)
        avg = lambda obs, k: sum(o[k] for o in obs) / len(obs)
        self.assertGreater(avg(hc, "current_speed_ms"), avg(normal, "current_speed_ms"))

    def test_sensor_fault_reports_missing_reading_others_ok(self):
        obs = run(event=EventType.NORMAL, hours=20, fault_probability=1.0, seed=5)
        # With fault_probability=1.0 every sensor reading should be flagged.
        for o in obs:
            for status in o["sensor_status"].values():
                self.assertEqual(status, "FAULT")
            self.assertIsNone(o["water_temp_c"])

    def test_sea_ice_lowers_temp_and_dampens_current(self):
        normal = run(event=EventType.NORMAL, hours=12, seed=3)
        ice = run(event=EventType.SEA_ICE, hours=12, seed=3)
        avg = lambda obs, k: sum(o[k] for o in obs) / len(obs)
        self.assertLess(avg(ice, "water_temp_c"), avg(normal, "water_temp_c"))
        self.assertLess(avg(ice, "current_speed_ms"), avg(normal, "current_speed_ms"))

    def test_low_sunlight_reduces_solar_availability(self):
        normal = run(event=EventType.NORMAL, hours=24, seed=3)
        dim = run(event=EventType.LOW_SUNLIGHT, hours=24, seed=3)
        avg = lambda obs, k: sum(o["energy"][k] for o in obs) / len(obs)
        self.assertLess(avg(dim, "solar_availability"), avg(normal, "solar_availability"))

    def test_sensor_disturbance_increases_fault_rate(self):
        # Same nonzero base fault_probability; disturbance should push more FAULTs.
        normal = run(event=EventType.NORMAL, hours=200, fault_probability=0.05, seed=11)
        disturbed = run(event=EventType.SENSOR_DISTURBANCE, hours=200, fault_probability=0.05, seed=11)
        count_faults = lambda obs: sum(
            1 for o in obs for s in o["sensor_status"].values() if s == "FAULT"
        )
        self.assertGreater(count_faults(disturbed), count_faults(normal))

    def test_communication_outage_marks_untransmitted(self):
        obs = run(event=EventType.COMMUNICATION_OUTAGE, hours=6)
        self.assertTrue(all(o["transmitted"] is False for o in obs))
        normal = run(event=EventType.NORMAL, hours=6)
        self.assertTrue(all(o["transmitted"] is True for o in normal))


class TestWavesAndDrift(unittest.TestCase):
    def test_storm_waves_higher_than_normal(self):
        avg = lambda obs: sum(o["wave_height_m"] for o in obs if o["wave_height_m"] is not None) / len(obs)
        self.assertGreater(avg(run(event=EventType.STORM, seed=3)), avg(run(event=EventType.NORMAL, seed=3)))

    def test_sea_ice_damps_waves(self):
        avg = lambda obs: sum(o["wave_height_m"] for o in obs if o["wave_height_m"] is not None) / len(obs)
        self.assertLess(avg(run(event=EventType.SEA_ICE, seed=3)), avg(run(event=EventType.NORMAL, seed=3)))

    def test_wind_pushes_buoy_downwind(self):
        from environment.buoy_drift import advect_position
        # zero current, westerly wind (from 270) -> buoy moves east (lon increases)
        lat, lon = advect_position(-55.0, 60.0, 0.0, 0.0, 3600, 10.0, 270.0)
        self.assertGreater(lon, 60.0)
        self.assertAlmostEqual(lat, -55.0, places=4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
