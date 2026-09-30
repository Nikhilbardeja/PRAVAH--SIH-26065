"""
Step 13 / Phase 10 — Energy-Environment Interface.

Per todo.md §16: provide environmental *inputs* to a future energy model
(solar availability, wind, current). Battery management is explicitly
OUT of scope here and is NOT implemented — this module only estimates
raw environmental energy-generation potential, kept fully separate from
the environment and sensor layers.
"""

import math

AIR_DENSITY_KG_M3 = 1.225
WATER_DENSITY_KG_M3 = 1025.0
SOLAR_CONSTANT_WM2 = 1000.0  # clear-sky reference irradiance, documented assumption


def solar_elevation_factor(hour_of_day: float, latitude_deg: float, day_of_year: float) -> float:
    """0..1 proportional insolation factor from simplified solar-position
    geometry (standard declination formula). 0 = sun below horizon."""
    declination_deg = 23.44 * math.sin(math.radians(360.0 / 365.0 * (day_of_year - 81)))
    hour_angle_deg = (hour_of_day - 12.0) * 15.0

    lat_r = math.radians(latitude_deg)
    decl_r = math.radians(declination_deg)
    hour_r = math.radians(hour_angle_deg)

    sin_elev = (math.sin(lat_r) * math.sin(decl_r)
                + math.cos(lat_r) * math.cos(decl_r) * math.cos(hour_r))
    return max(0.0, sin_elev)


def solar_availability(hour_of_day: float, latitude_deg: float, day_of_year: float,
                        event=None) -> dict:
    """Returns solar-availability parameter (0-1) and an estimated
    irradiance in W/m^2. STORM/LOW_SUNLIGHT apply cloud-cover reduction;
    SEA_ICE applies a stronger reduction (ice/snow blocks most light) —
    documented assumptions, not measured albedo data."""
    elev_factor = solar_elevation_factor(hour_of_day, latitude_deg, day_of_year)
    reduction = {
        "STORM": 0.25,
        "LOW_SUNLIGHT": 0.35,
        "SEA_ICE": 0.10,
    }.get(getattr(event, "value", event), 1.0)
    availability = elev_factor * reduction
    irradiance_wm2 = SOLAR_CONSTANT_WM2 * availability
    return {"solar_availability": round(availability, 4),
            "solar_irradiance_wm2": round(irradiance_wm2, 1)}


def wind_energy_potential_wm2(wind_speed_ms: float) -> float:
    """Simplified wind power density (W/m^2): P = 0.5 * rho * v^3.
    Physical potential estimate only, not a turbine's actual output."""
    return round(0.5 * AIR_DENSITY_KG_M3 * (max(0.0, wind_speed_ms) ** 3), 2)


def current_energy_potential_wm2(current_speed_ms: float) -> float:
    """Simplified current/hydrokinetic power density (W/m^2)."""
    return round(0.5 * WATER_DENSITY_KG_M3 * (max(0.0, current_speed_ms) ** 3), 2)


def energy_inputs(minutes_elapsed: float, latitude_deg: float, day_of_year: float,
                   wind_speed_ms: float, current_speed_ms: float, event=None) -> dict:
    """Bundles all energy-environment interface values for one observation."""
    hour_of_day = (minutes_elapsed / 60.0) % 24.0
    result = solar_availability(hour_of_day, latitude_deg, day_of_year, event)
    result["wind_energy_potential_wm2"] = wind_energy_potential_wm2(wind_speed_ms)
    result["current_energy_potential_wm2"] = current_energy_potential_wm2(current_speed_ms)
    return result
