"""PLACEHOLDER dashboard power model (battery + generation).

Battery management is another team member's job; this stands in so the
dashboard has consistent numbers. It consumes the simulation's energy inputs
(solar irradiance, wind power density) and wave height. All hardware constants
are ASSUMPTIONS - replace with the real energy model when it exists."""

SOLAR_AREA_M2, SOLAR_EFF = 0.12, 0.175       # small instrument-buoy panel
WIND_AREA_M2, WIND_CP = 0.005, 0.25          # micro turbine
WIND_CUT_IN, WIND_CUT_OUT = 3.0, 25.0        # m/s
WAVE_BASE_W = 0.35                           # wave harvester at ~2 m seas
BASE_LOAD_W, HEATER_W, HEATER_BELOW_C = 3.2, 1.2, -1.5      # instruments + Iridium + heater
LOW_POWER_SOC, CAPACITY_WH = 20.0, 250.0


def solar_w(energy):
    return energy["solar_irradiance_wm2"] * SOLAR_AREA_M2 * SOLAR_EFF


def wind_w(energy, wind_speed_ms):
    if wind_speed_ms is not None and not (WIND_CUT_IN <= wind_speed_ms <= WIND_CUT_OUT):
        return 0.0
    return energy["wind_energy_potential_wm2"] * WIND_AREA_M2 * WIND_CP


def wave_w(wave_height_m):
    h = 1.0 if wave_height_m is None else wave_height_m
    return WAVE_BASE_W * min(max(h / 2.0, 0.3), 2.0)


class PowerModel:
    def __init__(self, start_soc: float = 80.0):
        self.soc = start_soc

    def step(self, obs: dict, dt_hours: float) -> dict:
        en = obs["energy"]
        s, w, wv = solar_w(en), wind_w(en, obs.get("wind_speed_ms")), wave_w(obs.get("wave_height_m"))
        gen = s + w + wv
        air = obs.get("air_temp_c")
        load = BASE_LOAD_W + (HEATER_W if air is not None and air < HEATER_BELOW_C else 0.0)
        if self.soc < LOW_POWER_SOC:
            load *= 0.5                                   # low-power mode
        self.soc = min(100.0, max(0.0, self.soc + (gen - load) * dt_hours / CAPACITY_WH * 100.0))
        return {"generation_w": round(gen, 3), "solar_w": round(s, 3), "wind_w": round(w, 3),
                "wave_w": round(wv, 3), "load_w": round(load, 3), "battery_pct": round(self.soc, 1)}
