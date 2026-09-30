"""Dashboard server contract tests (Flask test client - no network needed).
   python -m unittest validation.test_server -v"""
import os, sys, tempfile, unittest

os.environ["SOUTHERN_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "server_test.db")
os.environ["BUOY_LIVE"] = "0"                       # tests tick manually
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "buoy_server"))

try:
    from api import app
    from services.engine import engine
    HAVE = True
except ImportError:
    HAVE = False


@unittest.skipUnless(HAVE, "pip install -r buoy_server/requirements.txt")
class TestDashboardContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = app.test_client()

    def get(self, url):
        r = self.c.get(url)
        self.assertEqual(r.status_code, 200, f"{url}: {r.data[:200]}")
        return r.get_json()

    def test_health_and_cors(self):
        r = self.c.get("/api/health")
        self.assertEqual(r.get_json()["status"], "ok")
        self.assertEqual(r.headers["Access-Control-Allow-Origin"], "*")

    def test_fleet_shape(self):
        f = self.get("/api/fleet")
        for k in ("region", "alert", "stats", "buoys", "satellite_link"):
            self.assertIn(k, f)
        for k in ("buoys_online", "avg_battery_pct", "sea_surface_temp_c", "wind_so_01_ms", "next_satellite_pass"):
            self.assertIn(k, f["stats"])
        ids = [b["id"] for b in f["buoys"]]
        self.assertEqual(ids, ["SO-01", "SO-02", "SO-03", "SO-04"])
        for b in f["buoys"][:3]:
            for k in ("name", "tagline", "latitude", "longitude", "status", "battery_pct", "trend"):
                self.assertIn(k, b)
            self.assertTrue(b["tagline"])
            self.assertTrue(0 <= b["battery_pct"] <= 100)
            self.assertGreaterEqual(len(b["trend"]), 2)
        self.assertEqual(f["buoys"][3]["status"], "scheduled")
        for k in ("title", "todays_uplink_b", "uplink_limit_b", "backlog_queued", "next_session"):
            self.assertIn(k, f["satellite_link"])

    def test_latest_shape_and_values(self):
        d = self.get("/api/buoys/SO-01/latest")
        for sec in ("position", "ocean", "atmosphere", "ocean_current", "sensor_status", "waves", "energy"):
            self.assertIn(sec, d)
        for k in ("depth_m", "water_temp_c", "salinity_psu", "pressure_dbar", "dissolved_oxygen_mg_l", "turbidity_ntu"):
            self.assertIn(k, d["ocean"])
        self.assertEqual(self.c.get("/api/buoys/NOPE/latest").status_code, 404)
        self.assertEqual(self.c.get("/api/buoys/SO-04/latest").status_code, 404)

    def test_history_shape(self):
        h = self.get("/api/buoys/SO-02/history?days=14")
        self.assertEqual(h["buoy"], "SO-02")
        self.assertEqual(len(h["rows"]), 14)
        keys = list(h["rows"][0])
        self.assertEqual(keys[0], "date")                      # Flutter takes the first string key as the label
        for k in ("battery_pct", "water_temp_c", "salinity_psu", "wind_ms", "samples_logged"):
            self.assertIn(k, keys)
        self.assertEqual(len(self.get("/api/buoys/SO-01/history?days=5")["rows"]), 5)

    def test_comparison_shape(self):
        c = self.get("/api/comparison")
        self.assertEqual(len(c["buoys"]), 3)
        self.assertEqual(len(c["radar"]), 3)
        for k in ("buoy", "note", "battery_pct", "battery_pct_delta", "water_temp_c", "salinity_psu",
                  "dissolved_oxygen_mg_l", "turbidity_ntu", "generation_w", "status"):
            self.assertIn(k, c["buoys"][0])
        for r in c["radar"]:
            self.assertEqual(set(r["values"]), {"battery", "stability", "do", "generation", "uptime"})
            self.assertTrue(all(0 <= v <= 1 for v in r["values"].values()))

    def test_interpretation_shape(self):
        i = self.get("/api/interpretation?buoy=SO-03")
        for k in ("insights", "energy_title", "energy_by_month", "note", "coupling", "daylight", "buoy"):
            self.assertIn(k, i)
        self.assertEqual(len(i["energy_by_month"]), 12)
        self.assertEqual(len(i["daylight"]), 12)
        self.assertGreaterEqual(len(i["insights"]), 3)
        self.assertTrue(all({"tag", "tone", "title", "body"} <= set(x) for x in i["insights"]))
        self.assertEqual(set(i["energy_by_month"][0]), {"month", "solar", "wind", "wave"})

    def test_physics_is_believable(self):
        i = self.get("/api/interpretation?buoy=SO-01")           # 63S: long summer days, short winter days
        dl = {d["month"]: d["hours"] for d in i["daylight"]}
        self.assertGreater(dl["Dec"], dl["Jun"] + 8)
        sol = {m["month"]: m["solar"] for m in i["energy_by_month"]}
        self.assertGreater(sol["Dec"], sol["Jun"])

    def test_storm_is_scripted_for_so03(self):
        f = self.get("/api/fleet")
        self.assertIsNotNone(f["alert"])
        self.assertIn("SO-03", f["alert"]["title"])

    def test_store_and_forward_hides_undelivered_and_flags_offline(self):
        from backend import database as db
        last = db.get_last("SO-01")
        shown_before = self.get("/api/buoys/SO-01/latest")["sim_time"]
        held = {k: last[k] for k in db.SCALAR_FIELDS}
        held.update(transmitted=False, sensor_status=last["sensor_status"], energy=last["energy"],
                    buoy_id="SO-01", sim_time="2999-01-01T00:00")
        db.insert_observation(held)                                  # link is down: reading stays on the buoy
        self.assertEqual(self.get("/api/buoys/SO-01/latest")["sim_time"], shown_before)
        f = self.get("/api/fleet")
        self.assertEqual(next(b for b in f["buoys"] if b["id"] == "SO-01")["status"], "offline")
        self.assertTrue(f["satellite_link"]["backlog_queued"].startswith("1 "))
        held.update(transmitted=True, sim_time="2999-01-01T01:00")
        db.insert_observation(held)                                  # link restored: buffered data flushes
        self.assertEqual(self.get("/api/buoys/SO-01/latest")["sim_time"], "2999-01-01T01:00")

    def test_live_tick_adds_a_reading(self):
        before = self.get("/api/buoys/SO-01/latest")["sim_time"]
        engine.tick()
        after = self.get("/api/buoys/SO-01/latest")["sim_time"]
        self.assertGreater(after, before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
