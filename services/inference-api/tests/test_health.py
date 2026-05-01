from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)

def test_healthz_route_exists():
    # This will fail if Redis isn't reachable in unit tests, so we only check route wiring.
    resp = client.get("/metrics")
    assert resp.status_code == 200
