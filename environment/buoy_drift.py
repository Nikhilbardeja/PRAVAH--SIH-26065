"""Step 12 — Buoy drift: ocean-current advection + wind drag (windage).

Assumption: buoy moves with the current plus ~3% of wind speed pushed
DOWNWIND (wind direction is the compass direction the wind comes FROM).
No Stokes drift / wave forcing beyond this simplification."""

import math

EARTH_RADIUS_M = 6_371_000.0
WINDAGE_FACTOR = 0.03


def _components(speed, heading_deg):
    h = math.radians(heading_deg)
    return speed * math.sin(h), speed * math.cos(h)  # east, north


def advect_position(lat, lon, current_speed_ms, current_dir_deg, dt_seconds,
                     wind_speed_ms=0.0, wind_from_deg=0.0):
    ce, cn = _components(current_speed_ms, current_dir_deg)
    we, wn = _components(WINDAGE_FACTOR * wind_speed_ms, (wind_from_deg + 180.0) % 360.0)
    d_east = (ce + we) * dt_seconds
    d_north = (cn + wn) * dt_seconds
    d_lat = math.degrees(d_north / EARTH_RADIUS_M)
    d_lon = math.degrees(d_east / (EARTH_RADIUS_M * math.cos(math.radians(lat))))
    return lat + d_lat, lon + d_lon


class BuoyDrift:
    def __init__(self, start_lat, start_lon):
        self.lat, self.lon = start_lat, start_lon
        self.total_distance_m = 0.0

    def step(self, current_speed_ms, current_dir_deg, dt_seconds,
             wind_speed_ms=0.0, wind_from_deg=0.0):
        new_lat, new_lon = advect_position(
            self.lat, self.lon, current_speed_ms, current_dir_deg, dt_seconds,
            wind_speed_ms, wind_from_deg)
        ce, cn = _components(current_speed_ms, current_dir_deg)
        we, wn = _components(WINDAGE_FACTOR * wind_speed_ms, (wind_from_deg + 180.0) % 360.0)
        self.total_distance_m += math.hypot(ce + we, cn + wn) * dt_seconds
        self.lat, self.lon = new_lat, new_lon
        return self.lat, self.lon
