"""Compare simulated values against reference data.

1) Built-in check: APPROXIMATE typical surface ranges per zone, written from
   general oceanographic knowledge (NOT downloaded data — no internet here).
   Replace with WOA23 / Argo statistics for anything beyond a sanity check.
2) Real-data check: pass a CSV of real observations (columns any of
   water_temp_c, salinity_psu, dissolved_oxygen_mg_l) and compare mean/std.

  python validation/reference_check.py
  python validation/reference_check.py --csv argo_zoneB.csv --zone B
"""
import argparse, csv, os, statistics, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from simulation.config import SimConfig, ZONES
from simulation.main import run_simulation

# (low, high) approximate surface ranges across seasons -- see caveat above
REFERENCE = {
    "A": {"water_temp_c": (2.0, 13.0), "salinity_psu": (33.8, 35.0), "dissolved_oxygen_mg_l": (8.0, 11.0)},
    "B": {"water_temp_c": (-0.5, 7.0), "salinity_psu": (33.6, 34.8), "dissolved_oxygen_mg_l": (9.0, 12.0)},
    "C": {"water_temp_c": (-2.0, 2.5), "salinity_psu": (33.5, 34.8), "dissolved_oxygen_mg_l": (10.0, 13.0)},
}
SEASON_DAYS = {"summer(d15)": 15, "autumn(d105)": 105, "winter(d196)": 196, "spring(d288)": 288}


def simulate(zone, day, hours=72):
    cfg = SimConfig(seed=1, latitude=ZONES[zone]["latitude"], start_day_of_year=day)
    return run_simulation(cfg, hours)


def builtin_check():
    ok_all = True
    print(f"{'zone':<5}{'season':<15}{'param':<24}{'sim mean':>9}{'in-range':>10}")
    for zone, params in REFERENCE.items():
        for season, day in SEASON_DAYS.items():
            obs = simulate(zone, day)
            for k, (lo, hi) in params.items():
                vals = [o[k] for o in obs]
                frac = sum(lo <= v <= hi for v in vals) / len(vals)
                ok_all &= frac >= 0.95
                print(f"{zone:<5}{season:<15}{k:<24}{statistics.mean(vals):>9.2f}{frac:>9.0%}{'' if frac>=0.95 else '  <-- CHECK'}")
    print("\nRESULT:", "all within approximate reference ranges" if ok_all else "some values outside reference ranges")
    return ok_all


def csv_check(path, zone):
    with open(path) as f:
        rows = list(csv.DictReader(f))
    sim = simulate(zone, 15, hours=24 * 30)
    print(f"{'param':<24}{'real mean':>10}{'sim mean':>10}{'bias':>8}{'real sd':>9}{'sim sd':>8}")
    for k in ("water_temp_c", "salinity_psu", "dissolved_oxygen_mg_l"):
        if k not in rows[0]: continue
        real = [float(r[k]) for r in rows if r[k] not in ("", None)]
        s = [o[k] for o in sim]
        print(f"{k:<24}{statistics.mean(real):>10.2f}{statistics.mean(s):>10.2f}"
              f"{statistics.mean(s)-statistics.mean(real):>8.2f}{statistics.pstdev(real):>9.2f}{statistics.pstdev(s):>8.2f}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv"); ap.add_argument("--zone", default="B", choices=list(ZONES))
    a = ap.parse_args()
    csv_check(a.csv, a.zone) if a.csv else builtin_check()
