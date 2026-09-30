"""Automated FastAPI-layer check. Run where FastAPI is installed:
    pip install -r requirements-backend.txt httpx
    python -m unittest validation.test_api -v
Uses a throwaway temp database (does not touch output/buoy_telemetry.db)."""
import os, sys, tempfile, unittest

os.environ["SOUTHERN_DB_PATH"] = os.path.join(tempfile.mkdtemp(), "api_test.db")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from fastapi.testclient import TestClient
    from simulation.api import app
    HAVE = app is not None
except Exception:
    HAVE = False

from simulation.config import SimConfig
from simulation.main import run_simulation


@unittest.skipUnless(HAVE, "fastapi/httpx not installed - run: pip install -r requirements-backend.txt httpx")
class TestAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = TestClient(app)
        # fault_probability=0.5 -> payload contains nulls (real-world sensor faults)
        cls.batch = run_simulation(SimConfig(seed=2, fault_probability=0.5), 4)

    def test_1_health(self):
        self.assertEqual(self.c.get("/health").json(), {"status": "ok"})

    def test_2_ingest_with_faulty_sensors_then_read_back(self):
        before = self.c.get("/observations/count").json()["count"]
        r = self.c.post("/ingest/telemetry", json=self.batch)
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(r.json()["inserted"], 4)
        self.assertEqual(self.c.get("/observations/count").json()["count"], before + 4)
        latest = self.c.get("/observations/latest").json()
        self.assertIn("energy", latest); self.assertIn("wave_height_m", latest)
        self.assertEqual(len(self.c.get("/observations?limit=2").json()), 2)
        self.assertEqual(self.c.get(f"/observations/{latest['id']}").status_code, 200)
        self.assertEqual(self.c.get("/observations/99999999").status_code, 404)
        self.assertEqual(len(self.c.get(f"/observations/since/{latest['id'] - 2}").json()), 2)

    def test_3_rejects_garbage_and_bad_limit(self):
        self.assertEqual(self.c.post("/ingest/telemetry", json=[{"foo": 1}]).status_code, 422)
        self.assertEqual(self.c.get("/observations?limit=0").status_code, 422)

    def test_4_cors_header_for_flutter_web(self):
        r = self.c.get("/health", headers={"Origin": "http://localhost:5000"})
        self.assertIn("access-control-allow-origin", r.headers)


if __name__ == "__main__":
    unittest.main(verbosity=2)
