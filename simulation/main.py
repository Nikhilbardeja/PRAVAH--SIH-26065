"""
Milestone 1 + Phase 2 runner for the Southern Ocean Environment Simulation.

Usage:
    python simulation/main.py [--hours 10] [--zone B] [--event NORMAL]

Prints observations, writes output/telemetry.json, output/observations.csv,
and plots/environment_overview.png. NOT a real ocean prediction system —
synthetic/physics-informed values only.
"""

import argparse
import itertools
from datetime import timedelta
import csv
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from simulation.config import SimConfig, EventType, ZONES
from environment.ocean_model import OceanModel
from environment.atmosphere_model import AtmosphereModel
from environment.buoy_drift import BuoyDrift
from environment.energy_interface import energy_inputs
from environment.event_model import EventSchedule
from environment.wave_model import WaveModel
from sensors.sensor_model import SensorModel
from validation.validation import validate_all


def parse_args():
    p = argparse.ArgumentParser(description="Southern Ocean Environment Simulation")
    p.add_argument("--hours", type=int, default=10)
    p.add_argument("--zone", choices=list(ZONES.keys()), default="B")
    p.add_argument("--depth", type=float, default=10.0)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--event", choices=[e.value for e in EventType], default="NORMAL")
    p.add_argument("--fault-prob", type=float, default=0.0)
    p.add_argument("--day", type=int, default=15, help="day of year (season)")
    p.add_argument("--drift", action="store_true", help="enable buoy drift from current")
    p.add_argument("--schedule", type=str, default=None,
                    help="scheduled events as 'start:end:EVENT,start:end:EVENT' "
                         "(step indices), e.g. '2:4:STORM,6:7:SEA_ICE'")
    p.add_argument("--random-event-prob", type=float, default=0.0,
                    help="probability (0-1) each step draws a random non-NORMAL event "
                         "(ignored if --schedule is set)")
    return p.parse_args()


def parse_schedule(spec: str):
    windows = []
    for part in spec.split(","):
        start, end, event = part.split(":")
        windows.append((int(start), int(end), EventType(event)))
    return windows


def run_simulation(cfg: SimConfig, hours: int, event_schedule=None, random_event_prob=0.0):
    steps = max(1, int(hours * 60 / cfg.timestep_minutes))
    return list(iter_simulation(cfg, steps, event_schedule, random_event_prob))


def iter_simulation(cfg: SimConfig, steps=None, event_schedule=None, random_event_prob=0.0):
    """Generator: yields one observation per step. steps=None runs forever (live mode)."""
    rng = np.random.default_rng(cfg.seed)
    ocean = OceanModel(cfg, rng)
    atmo = AtmosphereModel(cfg, rng)
    waves = WaveModel(cfg, rng)
    sensors = SensorModel(cfg.fault_probability, rng)
    drift = BuoyDrift(cfg.latitude, cfg.longitude) if cfg.drift_enabled else None

    random_choices = [e for e in EventType if e != EventType.NORMAL]
    base_event = cfg.event
    event_steps_left = 0
    start_clock_min = (cfg.start_datetime.hour * 60 + cfg.start_datetime.minute) if cfg.start_datetime else 0

    for step in (range(steps) if steps is not None else itertools.count()):
        minutes_elapsed = step * cfg.timestep_minutes
        day_of_year = cfg.start_day_of_year + minutes_elapsed / (60 * 24)
        sim_time = None
        if cfg.start_datetime is not None:
            t = cfg.start_datetime + timedelta(minutes=minutes_elapsed)
            sim_time = t.isoformat(timespec="minutes")
            day_of_year = t.timetuple().tm_yday + (t.hour * 60 + t.minute) / 1440.0

        # Resolve which event is active this step (manual < schedule < random).
        if event_schedule is not None:
            cfg.event = event_schedule.event_at(step)
        elif random_event_prob > 0:
            # Random events last 3-12 steps, then return to the base event.
            if event_steps_left > 0:
                event_steps_left -= 1
                if event_steps_left == 0:
                    cfg.event = base_event
            if event_steps_left == 0 and rng.random() < random_event_prob:
                pool = [e for e in random_choices
                        if not (e == EventType.SEA_ICE and abs(cfg.latitude) < 60)]
                cfg.event = pool[int(rng.integers(0, len(pool)))]
                event_steps_left = int(rng.integers(3, 13))
        # else: cfg.event stays as manually set (--event), unchanged per step.

        water_temp = ocean.water_temperature_c(day_of_year)
        salinity = ocean.salinity_psu(day_of_year)
        pressure = ocean.pressure_dbar()
        do = ocean.dissolved_oxygen_mg_l(water_temp, salinity)
        turbidity = ocean.turbidity_ntu()
        current_speed, current_dir = ocean.current()
        air_temp = atmo.air_temperature_c(water_temp)
        humidity = atmo.relative_humidity_pct()
        atm_pressure = atmo.atmospheric_pressure_hpa()
        wind_speed, wind_dir = atmo.wind()
        wave_h, wave_t = waves.waves(wind_speed)

        true_values = {
            "water_temp_c": water_temp,
            "salinity_psu": salinity,
            "pressure_dbar": pressure,
            "dissolved_oxygen_mg_l": do,
            "turbidity_ntu": turbidity,
            "current_speed_ms": current_speed,
            "wind_speed_ms": wind_speed,
            "air_temp_c": air_temp,
            "humidity_pct": humidity,
            "atm_pressure_hpa": atm_pressure,
            "wave_height_m": wave_h,
            "wave_period_s": wave_t,
        }
        measured = sensors.measure(true_values, disturbed=(cfg.event == EventType.SENSOR_DISTURBANCE))

        obs = {k: v["value"] for k, v in measured.items()}
        obs["sensor_status"] = {k: v["status"] for k, v in measured.items()}
        obs["current_direction_deg"] = current_dir
        obs["wind_direction_deg"] = wind_dir
        obs["depth_m"] = cfg.depth_m
        obs["timestamp_min"] = minutes_elapsed
        obs["event"] = cfg.event.value
        if sim_time:
            obs["sim_time"] = sim_time

        if drift is not None:
            dt_seconds = cfg.timestep_minutes * 60
            new_lat, new_lon = drift.step(current_speed, current_dir, dt_seconds, wind_speed, wind_dir)
            obs["latitude"] = new_lat
            obs["longitude"] = new_lon
            cfg.latitude = new_lat  # feed back so next step's env models use it
        else:
            obs["latitude"] = cfg.latitude
            obs["longitude"] = cfg.longitude

        obs["energy"] = energy_inputs(
            minutes_elapsed=start_clock_min + minutes_elapsed,
            latitude_deg=obs["latitude"],
            day_of_year=day_of_year,
            wind_speed_ms=wind_speed,
            current_speed_ms=current_speed,
            event=cfg.event,
        )
        # Store-and-forward: data is always generated/logged locally, but a
        # COMMUNICATION_OUTAGE means it doesn't reach the backend this step
        # (documented assumption — mirrors the satellite-comms link, not a
        # sensor or environment fault).
        obs["transmitted"] = cfg.event != EventType.COMMUNICATION_OUTAGE

        yield obs


def export_json(observations, path):
    with open(path, "w") as f:
        json.dump(observations, f, indent=2)


def export_csv(observations, path):
    if not observations:
        return
    flat_rows = []
    for obs in observations:
        row = {k: v for k, v in obs.items() if k not in ("sensor_status", "energy")}
        for k, v in obs["sensor_status"].items():
            row[f"{k}_status"] = v
        for k, v in obs["energy"].items():
            row[k] = v
        flat_rows.append(row)
    fieldnames = list(flat_rows[0].keys())
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(flat_rows)


def plot_overview(observations, path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    t = [o["timestamp_min"] / 60.0 for o in observations]
    fig, axes = plt.subplots(3, 2, figsize=(11, 9))
    series = [
        ("water_temp_c", "Water Temp (C)"),
        ("salinity_psu", "Salinity (PSU)"),
        ("dissolved_oxygen_mg_l", "DO (mg/L)"),
        ("turbidity_ntu", "Turbidity (NTU)"),
        ("current_speed_ms", "Current Speed (m/s)"),
        ("wind_speed_ms", "Wind Speed (m/s)"),
    ]
    for ax, (key, title) in zip(axes.flat, series):
        vals = [o.get(key) if o.get(key) is not None else np.nan for o in observations]
        ax.plot(t, vals)
        ax.set_title(title)
        ax.set_xlabel("hours")
    fig.tight_layout()
    fig.savefig(path)


def main():
    args = parse_args()
    cfg = SimConfig(
        seed=args.seed,
        latitude=ZONES[args.zone]["latitude"],
        depth_m=args.depth,
        start_day_of_year=args.day,
        event=EventType(args.event),
        fault_probability=args.fault_prob,
        drift_enabled=args.drift,
    )
    cfg.clamp_depth()

    print(f"Starting simulation | zone={args.zone} lat={cfg.latitude} "
          f"depth={cfg.depth_m}m event={cfg.event.value} hours={args.hours}")

    observations = run_simulation(
        cfg, args.hours,
        event_schedule=EventSchedule(parse_schedule(args.schedule), default=cfg.event) if args.schedule else None,
        random_event_prob=args.random_event_prob,
    )

    def fmt(val, suffix, decimals=2):
        return f"{val:.{decimals}f}{suffix}" if val is not None else f"FAULT{suffix}"

    for i, obs in enumerate(observations):
        print(f"[{i:03d}] t+{obs['timestamp_min']}min "
              f"T={fmt(obs['water_temp_c'], 'C')} "
              f"Sal={fmt(obs['salinity_psu'], 'psu')} "
              f"P={fmt(obs['pressure_dbar'], 'dbar')} "
              f"DO={fmt(obs['dissolved_oxygen_mg_l'], 'mg/L')} "
              f"Turb={fmt(obs['turbidity_ntu'], 'NTU')} "
              f"Curr={fmt(obs['current_speed_ms'], 'm/s')} "
              f"Wind={fmt(obs['wind_speed_ms'], 'm/s', 1)}")

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_dir = os.path.join(base_dir, "output")
    plots_dir = os.path.join(base_dir, "plots")
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(plots_dir, exist_ok=True)

    export_json(observations, os.path.join(output_dir, "telemetry.json"))
    export_csv(observations, os.path.join(output_dir, "observations.csv"))
    plot_overview(observations, os.path.join(plots_dir, "environment_overview.png"))

    report = validate_all(observations)
    print(f"\nValidation: {report['total_errors']} range violations "
          f"across {len(observations)} observations.")
    if report["total_errors"]:
        for idx, errs in report["details"].items():
            print(f"  obs {idx}: {errs}")

    print(f"\nWrote: {output_dir}/telemetry.json")
    print(f"Wrote: {output_dir}/observations.csv")
    print(f"Wrote: {plots_dir}/environment_overview.png")
    print("Simulation finished without errors.")


if __name__ == "__main__":
    main()
