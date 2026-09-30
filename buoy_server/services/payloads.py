"""Builds the JSON the Flutter app reads. Shapes match the teammate's original
hardcoded responses key-for-key; values now come from the simulation."""
import math
from datetime import datetime
from functools import lru_cache

from . import config, store
from .power_model import PowerModel
from environment.energy_interface import solar_elevation_factor
from simulation.config import SimConfig, EventType
from simulation.main import run_simulation

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
LOW_BATTERY = 35


def _r(v, n=2):
    return None if v is None else round(float(v), n)


def _mean(vals):
    vals = [v for v in vals if v is not None]
    return sum(vals) / len(vals) if vals else None


def _en(o, k):
    return (o.get("energy") or {}).get(k)


def _daily(obs, n_days):
    groups = {}
    for o in obs:
        groups.setdefault(o["sim_time"][:10], []).append(o)
    out = []
    for key in list(groups)[-n_days:]:
        rows = groups[key]
        out.append({
            "date": datetime.fromisoformat(key), "n": len(rows),
            "ok": sum(all(v == "OK" for v in r["sensor_status"].values()) for r in rows),
            "battery": _en(rows[-1], "battery_pct"),
            "temp": _mean(r["water_temp_c"] for r in rows), "sal": _mean(r["salinity_psu"] for r in rows),
            "wind": _mean(r["wind_speed_ms"] for r in rows), "wave": _mean(r["wave_height_m"] for r in rows),
            "air": _mean(r["air_temp_c"] for r in rows), "turb": _mean(r["turbidity_ntu"] for r in rows),
            "do": _mean(r["dissolved_oxygen_mg_l"] for r in rows),
        })
    return out


def _unknown(buoy_id):
    return buoy_id not in config.ACTIVE_IDS


# ---------------------------------------------------------------- latest ---
def latest(buoy_id):
    obs = store.visible(buoy_id)
    if not obs:
        return None
    o = obs[-1]
    en = o["energy"] or {}
    return {
        "buoy_id": buoy_id,
        "sim_time": o["sim_time"],
        "event": o["event"],
        "position": {"latitude": _r(o["latitude"], 4), "longitude": _r(o["longitude"], 4)},
        "ocean": {"depth_m": _r(o["depth_m"], 1), "water_temp_c": _r(o["water_temp_c"], 3),
                  "salinity_psu": _r(o["salinity_psu"], 3), "pressure_dbar": _r(o["pressure_dbar"], 3),
                  "dissolved_oxygen_mg_l": _r(o["dissolved_oxygen_mg_l"], 3),
                  "turbidity_ntu": _r(o["turbidity_ntu"], 3)},
        "atmosphere": {"air_temp_c": _r(o["air_temp_c"], 3), "humidity_pct": _r(o["humidity_pct"], 2),
                       "atm_pressure_hpa": _r(o["atm_pressure_hpa"], 2),
                       "wind_speed_ms": _r(o["wind_speed_ms"], 3),
                       "wind_direction_deg": _r(o["wind_direction_deg"], 2)},
        "ocean_current": {"speed_ms": _r(o["current_speed_ms"], 3),
                          "direction_deg": _r(o["current_direction_deg"], 2)},
        "waves": {"wave_height_m": _r(o["wave_height_m"], 2), "wave_period_s": _r(o["wave_period_s"], 1)},
        "energy": {"solar_irradiance_wm2": en.get("solar_irradiance_wm2"),
                   "generation_w": _r(en.get("generation_w"), 2), "load_w": _r(en.get("load_w"), 2),
                   "battery_pct": _r(en.get("battery_pct"), 1)},
        "sensor_status": o["sensor_status"],
    }


# --------------------------------------------------------------- history ---
def history(buoy_id, days):
    n = max(1, min(days, config.HISTORY_DAYS))
    rows = []
    prev = None
    for d in _daily(store.visible(buoy_id), n):
        dt = d["date"]
        label = f"{dt:%b} {dt.day}" if prev is None or dt.month != prev.month else str(dt.day)
        prev = dt
        rows.append({"date": label,
                     "battery_pct": None if d["battery"] is None else round(d["battery"]),
                     "water_temp_c": _r(d["temp"], 2), "salinity_psu": _r(d["sal"], 2),
                     "wind_ms": _r(d["wind"], 1), "wave_height_m": _r(d["wave"], 1),
                     "samples_logged": f"{d['ok']}/{d['n']}"})
    return {"buoy": buoy_id, "days": len(rows), "rows": rows}


# ----------------------------------------------------------------- fleet ---
_SEVERITY = ["STORM", "SEA_ICE", "HIGH_CURRENT", "LOW_TEMPERATURE", "SENSOR_DISTURBANCE",
             "COMMUNICATION_OUTAGE", "LOW_SUNLIGHT"]
_ALERTS = {
    "STORM": ("Storm conditions at {id} · {name}.",
              "Wind {wind:.0f} m/s, waves {hs:.1f} m. The buoy is conserving power - expect delayed satellite sessions."),
    "SEA_ICE": ("Sea ice around {id} · {name}.", "Ice cover is damping waves and currents and blocking most sunlight."),
    "HIGH_CURRENT": ("Strong current at {id} · {name}.", "Current {cur:.2f} m/s - expect faster drift."),
    "LOW_TEMPERATURE": ("Cold snap at {id} · {name}.", "Water temperature {temp:.1f} °C - heater load is up."),
    "SENSOR_DISTURBANCE": ("Sensor disturbance at {id} · {name}.", "Readings are noisy and some sensors are dropping out."),
    "COMMUNICATION_OUTAGE": ("Satellite link down at {id} · {name}.", "Readings are buffered on the buoy and will be delivered when the link returns."),
    "LOW_SUNLIGHT": ("Low sunlight at {id} · {name}.", "Persistent overcast is cutting solar generation."),
}


def _next_pass(sim_time):
    minutes = int(sim_time[11:13]) * 60 + int(sim_time[14:16])
    for k in range(0, 24 * 60, 360):                       # passes every 6 h from 03:40
        t = 220 + k
        if t > minutes:
            return f"{t // 60 % 24:02d}:{t % 60:02d} UTC"
    return "03:40 UTC"


def fleet():
    buoys, socs, temps, online, statuses = [], [], [], 0, []
    sim_time, uplink, backlog_total, so01_wind, lats = None, 0, 0, None, []
    for spec in config.BUOYS:
        if spec.get("scheduled"):
            buoys.append({"id": spec["id"], "name": spec["name"],
                          "tagline": spec.get("tagline", ""), "status": "scheduled"})
            continue
        bid = spec["id"]
        obs = store.visible(bid)
        if not obs:
            buoys.append({"id": bid, "name": spec["name"], "status": "offline"})
            continue
        last = obs[-1]
        battery = _en(last, "battery_pct")
        up = store.link_up(bid)
        online += up
        status = "offline" if not up else "low power" if battery < LOW_BATTERY else "online"
        trend = [round(d["battery"]) for d in _daily(obs, 7) if d["battery"] is not None]
        buoys.append({"id": bid, "name": spec["name"], "tagline": spec.get("tagline", ""),
                      "latitude": _r(last["latitude"], 3), "longitude": _r(last["longitude"], 3),
                      "status": status, "battery_pct": round(battery), "trend": trend})
        socs.append(battery)
        temps.append(last["water_temp_c"])
        lats.append(last["latitude"])
        statuses.append((bid, spec["name"], last, battery))
        backlog_total += store.backlog(bid)
        today = [o for o in obs if o["sim_time"][:10] == last["sim_time"][:10] and o["transmitted"]]
        uplink += len(today) * 4                           # ~4 bytes per packed reading (assumption)
        sim_time = max(sim_time or "", last["sim_time"])
        if bid == "SO-01":
            so01_wind = last["wind_speed_ms"]

    alert = None
    for ev in _SEVERITY:
        hit = next(((bid, nm, o) for bid, nm, o, _ in statuses if o["event"] == ev), None)
        if hit:
            bid, nm, o = hit
            title, msg = _ALERTS[ev]
            f = dict(id=bid, name=nm, wind=o["wind_speed_ms"] or 0, hs=o["wave_height_m"] or 0,
                     cur=o["current_speed_ms"] or 0, temp=o["water_temp_c"] or 0)
            alert = {"title": title.format(**f), "message": msg.format(**f)}
            break
    if alert is None:
        low = next(((bid, nm, b) for bid, nm, _, b in statuses if b < LOW_BATTERY), None)
        if low:
            alert = {"title": f"Low battery at {low[0]} · {low[1]}.",
                     "message": f"Battery at {low[2]:.0f}% - the buoy has switched to low-power mode."}

    mean_lat = abs(_mean(lats) or 0)
    return {
        "region": f"{mean_lat:.0f}°S, Southern Ocean transect (simulated)",
        "alert": alert,
        "stats": {"buoys_online": f"{online}/{len(config.ACTIVE)}",
                  "avg_battery_pct": round(_mean(socs) or 0),
                  "sea_surface_temp_c": _r(_mean(temps), 1),
                  "wind_so_01_ms": _r(so01_wind, 1),
                  "next_satellite_pass": _next_pass(sim_time) if sim_time else "—"},
        "buoys": buoys,
        "satellite_link": {"title": "Satellite link — Iridium SBD (simulated)",
                           "todays_uplink_b": min(uplink, 340), "uplink_limit_b": 340,
                           "backlog_queued": f"{backlog_total} readings",
                           "next_session": _next_pass(sim_time) if sim_time else "—"},
    }


# ------------------------------------------------------------ comparison ---
def _status_and_note(bid, last, battery, up):
    ev = last["event"]
    faults = any(v != "OK" for v in last["sensor_status"].values())
    if not up:
        return "Offline — link down", "Readings buffered on the buoy"
    if battery < LOW_BATTERY:
        return "Low power", "Power-constrained" + (", storm event active" if ev == "STORM" else "")
    if ev == "STORM":
        return "Watch — storm", "Storm event active"
    if (last["turbidity_ntu"] or 0) > 4:
        return "Watch — turbidity", "Turbidity elevated"
    if faults:
        return "Sensor fault", "One or more sensors not reporting"
    return "Nominal", "Stable, on schedule" if ev == "NORMAL" else ev.replace("_", " ").capitalize() + " active"


def comparison():
    rows, radar = [], []
    for spec in config.ACTIVE:
        bid = spec["id"]
        obs = store.visible(bid)
        if not obs:
            continue
        last, recent = obs[-1], obs[-24:]
        battery = _en(last, "battery_pct")
        days = [d["battery"] for d in _daily(obs, 7) if d["battery"] is not None]
        delta = round(battery - _mean(days)) if days else 0
        status, note = _status_and_note(bid, last, battery, store.link_up(bid))
        gen = _mean(_en(o, "generation_w") for o in recent)
        rows.append({"buoy": f"{bid} · {spec['name']}", "note": note, "battery_pct": round(battery),
                     "battery_pct_delta": delta,
                     "water_temp_c": _r(_mean(o["water_temp_c"] for o in recent), 1),
                     "salinity_psu": _r(_mean(o["salinity_psu"] for o in recent), 1),
                     "dissolved_oxygen_mg_l": _r(_mean(o["dissolved_oxygen_mg_l"] for o in recent), 1),
                     "turbidity_ntu": _r(_mean(o["turbidity_ntu"] for o in recent), 1),
                     "generation_w": _r(gen, 1), "status": status})
        week = obs[-24 * 7:]
        clip = lambda v: round(max(0.0, min(1.0, v)), 2)
        radar.append({"buoy": bid, "values": {
            "battery": clip(battery / 100),
            "stability": clip(1 - (_mean(o["wave_height_m"] for o in week) or 0) / 8),
            "do": clip((_mean(o["dissolved_oxygen_mg_l"] for o in week) or 0) / 12),
            "generation": clip((gen or 0) / 3.0),
            "uptime": clip(sum(bool(o["transmitted"]) for o in week) / max(1, len(week)))}})
    return {"subtitle": "Deltas shown are change vs. the trailing 7-day average.", "buoys": rows, "radar": radar}


# -------------------------------------------------------- interpretation ---
@lru_cache(maxsize=8)
def _year_model(buoy_id):
    """Modelled Wh/day per month + daylight hours, from the simulation itself."""
    spec = config.SPEC[buoy_id]
    year = datetime.now().year
    energy, daylight = [], []
    for m in range(1, 13):
        start = datetime(year, m, 15)
        cfg = SimConfig(seed=spec["seed"], latitude=spec["latitude"], longitude=spec["longitude"],
                        timestep_minutes=60, start_datetime=start, event=EventType.NORMAL)
        pm, gens = PowerModel(), []
        for o in run_simulation(cfg, 72):
            pm.soc = 60.0
            gens.append(pm.step(o, 1.0))
        per_day = lambda k: round(sum(g[k] for g in gens) / len(gens) * 24, 1)   # W avg -> Wh/day
        load = round(sum(g["load_w"] for g in gens) / len(gens) * 24, 1)
        energy.append({"month": MONTHS[m - 1], "solar": per_day("solar_w"), "wind": per_day("wind_w"),
                       "wave": per_day("wave_w"), "load": load})
        doy = start.timetuple().tm_yday
        hrs = sum(0.25 for k in range(96) if solar_elevation_factor(k * 0.25, spec["latitude"], doy) > 0)
        daylight.append({"month": MONTHS[m - 1], "hours": round(hrs, 1)})
    return energy, daylight


def interpretation(buoy_id):
    energy, daylight = _year_model(buoy_id)
    obs = store.visible(buoy_id)
    days = _daily(obs, config.HISTORY_DAYS)
    temps = [d["temp"] for d in days if d["temp"] is not None]
    insights = []

    if len(temps) >= 6:
        d_t = _mean(temps[-3:]) - _mean(temps[:3])
        sal = _mean(d["sal"] for d in days)
        kind = ("Cold layer strengthening." if d_t < -0.3 else "Surface warming." if d_t > 0.3
                else "Surface temperature steady.")
        insights.append({"tag": f"Ocean · {buoy_id}", "tone": "teal", "title": kind,
                         "body": f"Daily mean water temperature moved {d_t:+.1f} °C across {len(temps)} days "
                                 f"while salinity averaged {sal:.1f} PSU."})
        rt, rd = [d["turb"] for d in days], [d["do"] for d in days]
        if len(days) >= 6 and None not in rt[-6:] + rd[-6:]:
            dt_, dd_ = _mean(rt[-3:]) - _mean(rt[-6:-3]), _mean(rd[-3:]) - _mean(rd[-6:-3])
            up = dt_ > 0.05 and dd_ > 0.05
            insights.append({"tag": f"Ocean · {buoy_id}", "tone": "alert" if up else "teal",
                             "title": "Turbidity rising alongside DO." if up else "Turbidity and oxygen steady.",
                             "body": (f"Turbidity {dt_:+.2f} NTU and dissolved oxygen {dd_:+.2f} mg/L over the last "
                                      f"3 days" + (" - a joint uptick worth flagging." if up else "."))})
    recent = obs[-72:]
    if recent:
        hs = max((o["wave_height_m"] or 0) for o in recent)
        wind = max((o["wind_speed_ms"] or 0) for o in recent)
        rough = hs >= 6
        insights.append({"tag": f"Sea state · {buoy_id}", "tone": "alert" if rough else "wave",
                         "title": "Rough seas in the last 72 h." if rough else "Moderate seas.",
                         "body": f"Peak wave height {hs:.1f} m, peak wind {wind:.0f} m/s over the last 72 readings."})
    margins = [(e["solar"] + e["wind"] + e["wave"] - e["load"], e) for e in energy]
    worst = min(margins, key=lambda t: t[0])[1]
    gen_w = worst["solar"] + worst["wind"] + worst["wave"]
    insights.append({"tag": f"Energy · {buoy_id}", "tone": "alert" if gen_w < worst["load"] else "teal",
                     "title": f"{worst['month']} is the pinch point.",
                     "body": f"Modelled generation (~{gen_w:.0f} Wh/day) vs load (~{worst['load']:.0f} Wh/day) - "
                             f"the tightest margin in the yearly cycle."})

    best = max(energy, key=lambda e: e["solar"])
    dark = [d["month"] for d in daylight if d["hours"] < 1]
    note = ("Solar peaks in " + best["month"] + f" (~{best['solar']:.0f} Wh/day)"
            + (f" and is near zero in {', '.join(dark)}" if dark else " and fades sharply in winter")
            + ". Wind and waves fill part of the gap.\n\nGeneration here is a placeholder power model "
              "driven by the simulated sun, wind and waves - swap in the real energy model when available.")
    coupling = [{"air_temp_c": _r(d["air"], 1), "water_temp_c": _r(d["temp"], 1)}
                for d in days if d["air"] is not None and d["temp"] is not None]
    return {"buoy": buoy_id, "insights": insights,
            "energy_title": f"Energy generation, {buoy_id} — modelled by month",
            "energy_by_month": [{k: v for k, v in e.items() if k != "load"} for e in energy],
            "note": {"title": "Reading the shape, not just the total.", "body": note},
            "coupling": coupling, "daylight": daylight}
