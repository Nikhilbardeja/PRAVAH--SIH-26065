"""Basic physical-plausibility validation for generated observations."""

RANGES = {
    "water_temp_c": (-2.5, 15.0),
    "salinity_psu": (33.0, 36.0),
    "pressure_dbar": (0.0, 25.0),
    "dissolved_oxygen_mg_l": (2.0, 13.0),
    "turbidity_ntu": (0.0, 50.0),
    "current_speed_ms": (0.0, 3.0),
    "wind_speed_ms": (0.0, 50.0),
    "air_temp_c": (-20.0, 25.0),
    "humidity_pct": (0.0, 100.0),
    "atm_pressure_hpa": (900.0, 1050.0),
    "wave_height_m": (0.0, 20.0),
    "wave_period_s": (0.0, 25.0),
}


def validate_observation(obs: dict) -> list:
    """Returns a list of validation error strings (empty = all OK)."""
    errors = []
    for key, (lo, hi) in RANGES.items():
        val = obs.get(key)
        if val is None:
            continue  # sensor FAULT, not a range violation
        if not (lo <= val <= hi):
            errors.append(f"{key}={val} outside expected range [{lo},{hi}]")
    return errors


def validate_all(observations: list) -> dict:
    total_errors = 0
    per_obs_errors = {}
    for i, obs in enumerate(observations):
        errs = validate_observation(obs)
        if errs:
            per_obs_errors[i] = errs
            total_errors += len(errs)
    return {"total_errors": total_errors, "details": per_obs_errors}
